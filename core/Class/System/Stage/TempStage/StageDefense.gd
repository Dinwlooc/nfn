## 守区攻防阶段（管理斗牌命令的生成与取消）
extends Stage
class_name StageDefense

## 默认超时时长（秒）
const DEFAULT_TIME_LIMIT: float = 30.0
## 动态超时下限（秒）
const MIN_TIME_LIMIT: float = 5.0
## 时间惩罚累计步长（秒）
const TIME_PENALTY_STEP: float = 10.0
## 每步惩罚减少的时长（秒）
const TIME_PENALTY_DECREMENT: float = 5.0

## 目标守区
var defense_area: AreaDefence
## 进攻方玩家
var attacker: Player
## 防守方玩家
var defender: Player
## 最后一次重置计时器的时间戳（毫秒）
var last_timer_reset_time: int = 0
## 当前拥有响应权的玩家 ID
var current_responsive_player_id: int = 0
## 各玩家累计已用时间（秒）
var total_time_used: Dictionary[int, float] = {}
## 各玩家动态超时时限（秒）
var dynamic_time_limit: Dictionary[int, float] = {}
## 绑定至守区信号的 Callable 引用（用于断开连接）
var _defense_area_signal_binding: Callable = Callable()
## 标记等待当前命令完成后结束阶段
var _pending_stage_end: bool = false
## 当前活跃的斗牌命令
var _current_battle_command: BattleCommand = null
## 标记需要在命令全部完成后重新生成斗牌命令
var _need_regenerate_battle_command: bool = false

func _init(defense_area: AreaDefence, attacker: Player) -> void:
	super._init()
	is_temporary = true
	self.defense_area = defense_area
	self.attacker = attacker
	self.defender = defense_area.player
	stage_name = &"DefenseBattle"
	time_limit = DEFAULT_TIME_LIMIT

## 阶段进入：初始化各玩家时间数据，更新响应权，启动计时并生成首个斗牌命令
func enter(game_state: GameState) -> void:
	for p in [attacker.player_id, defender.player_id]:
		total_time_used[p] = 0.0
		dynamic_time_limit[p] = DEFAULT_TIME_LIMIT
	_update_responsive_player(game_state)
	_reset_timer_for_current_player()
	_connect_defense_area_signals(game_state)
	_generate_and_queue_battle_command(game_state, true)
	super.enter(game_state)

## 阶段恢复：刷新响应权与计时，重新连接守区信号
func resume(game_state: GameState) -> void:
	_update_responsive_player(game_state)
	_reset_timer_for_current_player()
	_connect_defense_area_signals(game_state)
	super.resume(game_state)

## 阶段暂停：断开守区信号以冻结阶段状态
func pause(game_state: GameState) -> void:
	_disconnect_defense_area_signals()
	super.pause(game_state)

## 阶段结束清理：断开信号、重置标记
func end_stage_effect(game_state: GameState) -> void:
	_disconnect_defense_area_signals()
	_pending_stage_end = false
	_current_battle_command = null
	super.end_stage_effect(game_state)

## 处理玩家操作请求（仅支持出牌与放弃响应）
func process_operation_request(request: OperationRequest, game_state: GameState) -> void:
	if is_ended or is_paused:
		return
	match request.get_class_name():
		&"play_card":
			_process_play_card_request(request as OperationRequest.PlayCard, game_state)
		&"abandon_response":
			_process_settle_request(request, game_state)
		_:
			GlobalConsole._print(["守区攻防阶段：不支持的操作类型", request.get_class_name_static()])
			request.cancel()

## 处理出牌请求：基础规则 + 防御阶段特殊限制，通过后排队行为命令并统计耗时
func _process_play_card_request(request: OperationRequest.PlayCard, game_state: GameState) -> void:
	var card: Card = game_state.cardsmanager.get_card_by_id(request._card_id)
	var source_player: Player = game_state.player_manager.get_player_by_id(request.source_player_id)
	var target_player: Player = game_state.player_manager.get_player_by_id(request._target_id) if request._target_id >= 0 else null
	if not card or not source_player:
		GlobalConsole._print(["守区攻防阶段：卡牌或玩家实例获取失败"])
		request.cancel()
		return
	# 出牌基础规则（目标、距离、消耗等）
	var rule_result: RuleCardPlay.RuleResult = RuleCardPlay.check_and_create_command(card, source_player, target_player, game_state)
	if not rule_result.is_valid:
		GlobalConsole._print(["守区攻防阶段：", rule_result.message])
		request.cancel()
		return
	# 防御阶段特殊限制（堆栈、速度、目标限定等）
	var usage_result: RuleCardUsage.UsageResult = _check_defense_battle_restrictions(card, source_player, target_player, game_state)
	if not usage_result.is_valid:
		GlobalConsole._print(["守区攻防阶段：", usage_result.message])
		request.cancel()
		return
	var command: BehaviorCommand = rule_result.command
	if not command:
		GlobalConsole._print(["守区攻防阶段：规则未返回命令"])
		request.cancel()
		return
	var elapsed: float = _get_elapsed_time_since_last_reset()
	game_state.queue_behavior_with_callback(command, func():
		_total_time_used_update(current_responsive_player_id, elapsed)
		GlobalConsole._print(["守区攻防阶段：出牌成功，等待所有命令完成后更新响应权"])
	)
	request.complete()

## 超时处理：为当前响应玩家生成一个放弃响应请求
func timeout(game_state: GameState) -> void:
	if is_ended or is_paused:
		return
	var abandon_request := OperationRequest.AbandonResponse.new(current_responsive_player_id)
	process_operation_request(abandon_request, game_state)

## 处理放弃响应/结算请求：生成 SettleCommand 并标记阶段即将结束
func _process_settle_request(request: OperationRequest, game_state: GameState) -> void:
	var settle_cmd := SettleCommand.new(current_responsive_player_id, defense_area, attacker)
	game_state.queue_behavior(settle_cmd)
	_pending_stage_end = true
	request.complete()

## 调用防御阶段卡牌使用限制规则
func _check_defense_battle_restrictions(
	card: Card,
	source_player: Player,
	target_player: Player,
	game_state: GameState
) -> RuleCardUsage.UsageResult:
	return RuleCardUsage.can_use_card_in_defense(
		card,
		source_player,
		target_player,
		defense_area,
		attacker,
		defender,
		game_state
	)

## 根据守区顶端卡牌归属更新当前响应权玩家 ID
func _update_responsive_player(game_state: GameState) -> void:
	var top: Card = defense_area.get_top_card()
	if top:
		current_responsive_player_id = attacker.player_id if top.player == defender else defender.player_id
	else:
		current_responsive_player_id = attacker.player_id
	game_state.set_responsive_players(PackedInt32Array([current_responsive_player_id]))
	GlobalConsole._print(["守区攻防阶段：更新响应权为玩家", current_responsive_player_id])

## 生成斗牌命令并排队，可选择保存引用供后续取消
func _generate_and_queue_battle_command(game_state: GameState, save_reference: bool = false) -> BattleCommand:
	if not defense_area.check_battle_formation():
		return null
	var top_card: Card = defense_area.get_top_card()
	var second_card: Card = defense_area.get_second_card()
	var battle_command := BattleCommand.new(defense_area, top_card, second_card)
	game_state.queue_behavior(battle_command)
	if save_reference:
		_current_battle_command = battle_command
	GlobalConsole._print(["守区攻防阶段：生成并排队斗牌命令"])
	return battle_command

## 取消当前未完成的斗牌命令
func _cancel_current_battle_command() -> void:
	if _current_battle_command and not _current_battle_command._is_completed:
		_current_battle_command.cancel()
		_current_battle_command = null
		GlobalConsole._print(["守区攻防阶段：取消当前斗牌命令"])

## 守区卡牌变化回调：取消当前斗牌命令，标记等待重新生成
func _on_defense_area_changed(_card: Card, _area: Area, game_state: GameState) -> void:
	if is_ended or is_paused:
		return
	_cancel_current_battle_command()
	_need_regenerate_battle_command = true

## 所有命令完成时的处理：结束阶段或重新生成斗牌命令，否则更新响应权并重置计时
func _on_all_commands_completed_impl(game_state: GameState) -> void:
	if is_ended or is_paused:
		return
	if _pending_stage_end:
		end_stage(game_state)
		return
	if _need_regenerate_battle_command:
		_need_regenerate_battle_command = false
		var new_cmd: BattleCommand = _generate_and_queue_battle_command(game_state, true)
		if new_cmd:
			GlobalConsole._print(["守区攻防阶段：重新生成斗牌命令，跳过响应权更新"])
			return
	_update_responsive_player(game_state)
	_reset_timer_for_current_player()
	GlobalConsole._print(["守区攻防阶段：命令全部完成，已更新玩家响应权"])

## 为当前响应玩家重置计时器，使用动态超时时限
func _reset_timer_for_current_player() -> void:
	if current_responsive_player_id == 0:
		return
	var limit: float = DEFAULT_TIME_LIMIT
	if dynamic_time_limit.has(current_responsive_player_id):
		limit = dynamic_time_limit[current_responsive_player_id]
	request_reset_timer.emit(limit)
	last_timer_reset_time = Time.get_ticks_msec()

## 返回距离上次计时重置的秒数
func _get_elapsed_time_since_last_reset() -> float:
	var now: int = Time.get_ticks_msec()
	var elapsed_ms: int = now - last_timer_reset_time
	return elapsed_ms / 1000.0

## 累积玩家已用时间并重新计算动态超时时限
func _total_time_used_update(player_id: int, elapsed: float) -> void:
	var new_total: float = total_time_used[player_id] + elapsed
	total_time_used[player_id] = new_total
	var steps: int = int(new_total / TIME_PENALTY_STEP)
	var new_limit: float = DEFAULT_TIME_LIMIT - steps * TIME_PENALTY_DECREMENT
	new_limit = max(new_limit, MIN_TIME_LIMIT)
	dynamic_time_limit[player_id] = new_limit
	GlobalConsole._print(["玩家", player_id, "总用时", new_total, "s，动态时间限", new_limit, "s"])

## 连接守区卡牌添加/移除信号
func _connect_defense_area_signals(game_state: GameState) -> void:
	_disconnect_defense_area_signals()
	_defense_area_signal_binding = _on_defense_area_changed.bind(game_state)
	defense_area.area_card_added.connect(_defense_area_signal_binding)
	defense_area.area_card_removed.connect(_defense_area_signal_binding)

## 断开守区卡牌添加/移除信号
func _disconnect_defense_area_signals() -> void:
	if _defense_area_signal_binding != Callable():
		if defense_area.area_card_added.is_connected(_defense_area_signal_binding):
			defense_area.area_card_added.disconnect(_defense_area_signal_binding)
		if defense_area.area_card_removed.is_connected(_defense_area_signal_binding):
			defense_area.area_card_removed.disconnect(_defense_area_signal_binding)
		_defense_area_signal_binding = Callable()
