## 主阶段：当前玩家出牌与响应。
extends Stage
class_name StageMain

#== Constants ==
## 进入阶段时的时限（秒）
const ENTER_TIME_LIMIT: float = 60.0
## 恢复阶段（响应后返回）时的时限（秒）
const RESUME_TIME_LIMIT: float = 30.0

#== Properties ==
## 当前攻击者玩家 id，也是响应权归属
var _current_attacker_id: int = 0
## 当前攻击者实例，阶段结束时置空
var _current_attacker: Player = null
## 上次重置计时器的时刻（毫秒）
var last_timer_reset_time: int = 0
## 本阶段是否已做过首次响应刷新
var _has_entered_refresh: bool = false

#== Constructor ==
## 构造：设定阶段名与进入时限
func _init() -> void:
	super._init()
	stage_name = &"Main"
	time_limit = ENTER_TIME_LIMIT

#== 响应能力 ==
## 创建仅包含指定玩家的响应玩家数组
## @pure
static func build_responsive_players(player_id: int) -> PackedInt32Array:
	return PackedInt32Array([player_id])

#== Public Methods ==
## 进入阶段
## @override @hook @no_escape @side_effect
func enter(game_state: GameState, command_bus: CommandBus) -> void:
	_current_attacker = game_state.player_manager.get_player_by_id(game_state.stage_manager.current_player_id)
	_current_attacker_id = _current_attacker.get_id()
	command_bus.set_responsive_players(build_responsive_players(_current_attacker_id))
	_has_entered_refresh = false
	super.enter(game_state, command_bus)
## 恢复阶段
## @override @hook @no_escape @side_effect
func resume(game_state: GameState, command_bus: CommandBus) -> void:
	_current_attacker = game_state.player_manager.get_player_by_id(game_state.stage_manager.current_player_id)
	_current_attacker_id = _current_attacker.get_id()
	command_bus.set_responsive_players(build_responsive_players(_current_attacker_id))
	_reset_timer_for_current_player(RESUME_TIME_LIMIT)
	super.resume(game_state, command_bus)
## 阶段结束时的清理效果
## @override @hook @no_escape
func end_stage_effect(game_state: GameState, command_bus: CommandBus) -> void:
	_current_attacker = null
	command_bus.set_responsive_players(PackedInt32Array())
	super.end_stage_effect(game_state, command_bus)
## 处理玩家操作请求
## @override @hook @no_escape @side_effect
func process_operation_request(request: OperationRequest, game_state: GameState, command_bus: CommandBus) -> void:
	if is_ended or is_paused:
		return
	match request.get_class_name():
		&"play_card":
			_process_play_card_request(request as OperationRequest.PlayCard, game_state, command_bus)
		&"abandon_response":
			request_end_stage(command_bus)
			request.complete()
			GlobalConsole._print(["主阶段：放弃响应，结束阶段"])
		_:
			request.cancel()
			GlobalConsole._print(["主阶段：不支持的操作类型", request.get_class_name_static()])
## 刷新响应权：轮转命令结束后由触发器调用，统一管理计时
## @override @hook @no_escape @side_effect
func refresh_response(game_state: GameState, command_bus: CommandBus) -> void:
	if is_ended or is_paused:
		return
	command_bus.set_responsive_players(build_responsive_players(_current_attacker_id))
	if not _has_entered_refresh:
		_has_entered_refresh = true
		_reset_timer_for_current_player(ENTER_TIME_LIMIT)
		GlobalConsole._print(["主阶段：首次刷新响应权，计时", ENTER_TIME_LIMIT])
		return
	_reset_timer_for_current_player(RESUME_TIME_LIMIT)
	GlobalConsole._print(["主阶段：所有命令完成，已刷新响应权为玩家", _current_attacker_id])

#== Private Methods ==
## 处理出牌请求
## @side_effect
func _process_play_card_request(request: OperationRequest.PlayCard, game_state: GameState, command_bus: CommandBus) -> void:
	if request.source_player_id != _current_attacker_id:
		GlobalConsole._print(["主阶段：非当前玩家操作，忽略"])
		request.cancel()
		return
	var card: Card = game_state.cardsmanager.get_card_by_id(request._card_id)
	var source_player: Player = game_state.player_manager.get_player_by_id(request.source_player_id)
	var target_player: Player = game_state.player_manager.get_player_by_id(request._target_id) if request._target_id >= 0 else null
	if not card or not source_player:
		GlobalConsole._print(["主阶段：卡牌或玩家实例获取失败"])
		request.cancel()
		return
	var rule_result: RuleCardPlay.RuleResult = RuleCardPlay.check_and_create_command(card, source_player, target_player, game_state)
	if not rule_result.is_valid:
		GlobalConsole._print(["主阶段：", rule_result.message])
		request.cancel()
		return
	var target_defense: AreaDefence = game_state.get_defense_area(request._target_id) if target_player else null
	var usage_result: RuleCardUsage.UsageResult = RuleCardUsage.can_use_card_in_main(card, source_player, target_defense, game_state)
	if not usage_result.is_valid:
		GlobalConsole._print(["主阶段：", usage_result.message])
		request.cancel()
		return
	command_bus.queue_behavior(rule_result.command)
	GlobalConsole._print(["主阶段：卡牌使用成功"])
	request.complete()
## 请求重置计时器并记录时间
## @side_effect @requester
func _reset_timer_for_current_player(new_time_limit: float) -> void:
	request_reset_timer.emit(new_time_limit)
	last_timer_reset_time = Time.get_ticks_msec()
