## 群体攻击响应阶段：给每个目标一次"打一张牌响应"的机会，收齐后一次性交给 GroupAttackCommand 结算
## 时序纪律（H 审查 2026-10-27）：
##   - 本阶段只负责收集表态；真正结算由 GroupAttackCommand 以伴生命令完成。
##   - 阶段结束不得与结算命令同批入队：END_CURRENT 先入栈会先执行，导致临时阶段 ROLLBACK、伤害命令悬空。
##     因此 resolve 时只入队结算命令并置 _pending_stage_end，等命令全部完成后的 refresh_response 再 request_end_stage。
##   - 每次只授权"尚未表态"的目标，避免已响应者被重新放权打第二张。
extends Stage
class_name StageGroupAttack

## 默认响应时限（秒）
const DEFAULT_TIME_LIMIT: float = 30.0

## 群体攻击命令脚本（preload 规避新建 class_name 未进全局类缓存）
const GroupAttackCommandScript := preload("res://core/Class/System/Command/LightCommand/GroupAttackCommand.gd")

## 群体攻击来源卡（中央区技能牌）
var source_card: Card
## 攻击方玩家（来源卡持有者）
var attacker: Player
## 目标玩家（结算顺序）
var target_players: Array[Player] = []
## 尚未表态的目标玩家 id
var pending_player_ids: PackedInt32Array = PackedInt32Array()
## 已表态目标 → 响应牌；未响应者不在表中
var response_cards: Dictionary[int, Card] = {}
## 是否已入队结算命令、等待阶段收尾
var _pending_stage_end: bool = false
## 是否已发起过结算（防重复）
var _resolved: bool = false

## 构造：绑定来源卡、攻击方与目标快照
func _init(card: Card, attacker_player: Player, targets: Array[Player]) -> void:
	super._init()
	source_card = card
	attacker = attacker_player
	target_players = targets
	temporary_stage_player_id = attacker.get_id()
	stage_name = &"GroupAttack"
	time_limit = DEFAULT_TIME_LIMIT

## 进入阶段：把全部目标标为待表态并授权
## @override @hook @no_escape @side_effect
func enter(game_state: GameState, command_bus: CommandBus) -> void:
	_rebuild_pending()
	_refresh_responsive_players(command_bus)
	request_reset_timer.emit(time_limit)
	_notify(RenderRequest.GroupAttackNotify.State.START)
	super.enter(game_state, command_bus)

## 广播群体攻击通知（目标 / 待表态 / 威力 / 时机）
## @delegates(send_group_attack_notify) @side_effect
func _notify(notify_state: RenderRequest.GroupAttackNotify.State) -> void:
	var power: int = source_card.get_power() if source_card else 0
	RuleTrans.send_group_attack_notify(source_card, attacker, target_players, pending_player_ids, power, notify_state)

## 结束清理：收回所有响应权，并通知前端清理群体攻击展示
## @override @hook @no_escape @side_effect
func end_stage_effect(game_state: GameState, command_bus: CommandBus) -> void:
	command_bus.set_responsive_players(PackedInt32Array())
	_notify(RenderRequest.GroupAttackNotify.State.FINISHED)
	super.end_stage_effect(game_state, command_bus)

## 处理玩家操作请求
## @override @hook @no_escape @side_effect
func process_operation_request(request: OperationRequest, game_state: GameState, command_bus: CommandBus) -> void:
	if is_ended or is_paused:
		return
	match request.get_operation_name():
		&"play_card":
			_process_play_card_request(request as ItemsOperation, game_state, command_bus)
		&"respond_card":
			_process_respond_card_request(request as ItemsOperation, game_state, command_bus)
		&"abandon_response":
			_process_abandon_request(request, command_bus)
		_:
			GlobalConsole._print(["群体攻击阶段：不支持的操作类型", request.get_operation_name()])
			request.cancel()

## 超时：未表态者一律视为放弃响应（设计：未响应 = 单方面攻击）
## @override @hook @no_escape @side_effect
func timeout(game_state: GameState, command_bus: CommandBus) -> void:
	if is_ended or is_paused:
		return
	pending_player_ids = PackedInt32Array()
	_refresh_responsive_players(command_bus)
	_try_resolve(command_bus)

## 命令全部完成后：先收尾，再刷新授权
## @override @hook @no_escape @side_effect
func refresh_response(game_state: GameState, command_bus: CommandBus) -> void:
	if is_ended or is_paused:
		return
	if _pending_stage_end:
		request_end_stage(command_bus)
		return
	_refresh_responsive_players(command_bus)
	_try_resolve(command_bus)

## 处理出牌请求：只登记、不移动牌（响应牌保持在手牌区，结算后由 GroupAttackCommand 弃置）；目标字段由本阶段无视
## @side_effect
func _process_play_card_request(request: ItemsOperation, game_state: GameState, command_bus: CommandBus) -> void:
	_try_accept_response(request.source_player_id, request.get_primary_id(), request, game_state, command_bus)

## 处理响应声明请求（respond_card）：不带目标参数，语义就是"我出这张牌响应"
## @side_effect
func _process_respond_card_request(request: ItemsOperation, game_state: GameState, command_bus: CommandBus) -> void:
	_try_accept_response(request.source_player_id, request.get_primary_id(), request, game_state, command_bus)

## 校验并登记响应牌（play_card 与 respond_card 两个入口共用）
## @internal @side_effect
func _try_accept_response(player_id: int, card_id: int, request: OperationRequest, game_state: GameState, command_bus: CommandBus) -> void:
	if not pending_player_ids.has(player_id):
		GlobalConsole._print(["群体攻击阶段：玩家无权响应或已表态", player_id])
		request.cancel()
		return
	var card: Card = game_state.cardsmanager.get_card_by_id(card_id)
	var usage: RuleCardUsage.UsageResult = RuleCardUsage.can_use_card_in_group_attack(card, game_state.player_manager.get_player_by_id(player_id), game_state)
	if not card or not usage.is_valid:
		GlobalConsole._print(["群体攻击阶段：", usage.message if usage else "响应牌无效"])
		request.cancel()
		return
	response_cards[player_id] = card
	_remove_pending(player_id)
	request.complete()
	_refresh_responsive_players(command_bus)
	_notify(RenderRequest.GroupAttackNotify.State.UPDATE)
	_try_resolve(command_bus)

## 处理放弃响应请求
## @side_effect
func _process_abandon_request(request: OperationRequest, command_bus: CommandBus) -> void:
	var player_id: int = request.source_player_id
	if not pending_player_ids.has(player_id):
		request.cancel()
		return
	_remove_pending(player_id)
	request.complete()
	_refresh_responsive_players(command_bus)
	_notify(RenderRequest.GroupAttackNotify.State.UPDATE)
	_try_resolve(command_bus)

## 全部目标表态后入队结算命令（只入队，阶段收尾交给下一次 refresh_response）
## @side_effect @delegates(queue_behavior)
func _try_resolve(command_bus: CommandBus) -> void:
	if _pending_stage_end or _resolved:
		return
	if not pending_player_ids.is_empty():
		return
	_resolved = true
	_pending_stage_end = true
	command_bus.queue_behavior(GroupAttackCommandScript.new(source_card, target_players, response_cards))
	_notify(RenderRequest.GroupAttackNotify.State.RESOLVED)
	GlobalConsole._print(["群体攻击阶段：全部目标已表态，入队结算命令"])

## 按目标快照重建待表态列表
## @internal
func _rebuild_pending() -> void:
	pending_player_ids = PackedInt32Array()
	for target: Player in target_players:
		if target and not pending_player_ids.has(target.get_id()):
			pending_player_ids.append(target.get_id())

## 从待表态列表移除
## @internal
func _remove_pending(player_id: int) -> void:
	var index: int = pending_player_ids.find(player_id)
	if index != -1:
		pending_player_ids.remove_at(index)

## 只把响应权授给尚未表态的目标（传空即全部收回）
## @delegates(set_responsive_players)
func _refresh_responsive_players(command_bus: CommandBus) -> void:
	command_bus.set_responsive_players(pending_player_ids.duplicate())
