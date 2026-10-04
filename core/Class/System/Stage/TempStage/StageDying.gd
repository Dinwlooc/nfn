## 玩家濒死阶段：所有玩家可响应“濒死可用”卡牌，采用抢拍锁定机制，超时后若濒死玩家生命值仍≤0则生成死亡命令
extends Stage
class_name StageDying

#== Constants ==
const DEFAULT_TIME_LIMIT: float = 10.0
const MIN_TIME_LIMIT: float = 4.0
const TIME_PENALTY_STEP: float = 2.0

#== Properties ==
## 濒死玩家
var dying_player: Player
## 当前时间限制
var _current_time_limit: float = DEFAULT_TIME_LIMIT
## 是否已锁定响应
var _is_locked: bool = false
## 是否等待阶段结束
var _pending_stage_end: bool = false

#== Constructor ==
func _init(p_dying_player: Player) -> void:
	super._init()
	dying_player = p_dying_player
	temporary_stage_player_id = dying_player.get_id()
	stage_name = &"Dying"
	time_limit = DEFAULT_TIME_LIMIT
	_current_time_limit = DEFAULT_TIME_LIMIT

#== Static Methods ==
## 收集游戏中所有玩家的 ID
## @pure
static func create_all_player_ids(game_state: GameState) -> PackedInt32Array:
	var all_player_ids: PackedInt32Array = []
	for player: Player in game_state.player_manager.players:
		all_player_ids.append(player.get_id())
	return all_player_ids
## 判断玩家是否已死亡
## @pure
static func is_player_dead(player: Player) -> bool:
	return player.HP <= 0
## 根据当前时间限制计算扣减惩罚后的新时间限制
## @pure
static func calculate_new_time_limit(current_time_limit: float, penalty_step: float, min_limit: float) -> float:
	return max(current_time_limit - penalty_step, min_limit)
## 创建玩家死亡命令
## @factory
static func create_player_death_command(player: Player) -> PlayerDeathCommand:
	return PlayerDeathCommand.new(player)

#== Public Methods ==
## 进入阶段
## @override @hook @stack_local @side_effect
func enter(game_state: GameState, command_bus: CommandBus) -> void:
	_grant_response_permission_to_all_players(game_state, command_bus)
	_reset_timer()
	super.enter(game_state, command_bus)
## 暂停阶段
## @override @hook @stack_local @side_effect
func pause(game_state: GameState, command_bus: CommandBus) -> void:
	_revoke_response_permission(command_bus)
	_stop_timer()
	super.pause(game_state, command_bus)
## 恢复阶段
## @override @hook @stack_local @side_effect
func resume(game_state: GameState, command_bus: CommandBus) -> void:
	_grant_response_permission_to_all_players(game_state, command_bus)
	_reset_timer()
	super.resume(game_state, command_bus)
## 阶段结束时的清理效果
## @override @hook @stack_local @side_effect
func end_stage_effect(game_state: GameState, command_bus: CommandBus) -> void:
	_revoke_response_permission(command_bus)
	_stop_timer()
	if is_player_dead(dying_player):
		_generate_player_death_command(game_state, command_bus)
	super.end_stage_effect(game_state, command_bus)
## 超时处理
## @override @hook @stack_local @side_effect
func timeout(game_state: GameState, command_bus: CommandBus) -> void:
	if is_ended or is_paused:
		return
	_pending_stage_end = true
	_stop_timer()
	if _is_locked:
		return
	request_end_stage(command_bus)
## 处理玩家操作请求
## @override @hook @stack_local @side_effect
func process_operation_request(request: OperationRequest, game_state: GameState, command_bus: CommandBus) -> void:
	if is_ended or is_paused or _is_locked:
		return
	match request.get_class_name():
		&"play_card":
			_process_play_card_request(request as OperationRequest.PlayCard, game_state, command_bus)
		_:
			GlobalConsole._print(["濒死阶段：不支持的操作类型", request.get_class_name_static()])
			request.cancel()
## 刷新响应权
## @override @hook @stack_local @side_effect
func refresh_response(game_state: GameState, command_bus: CommandBus) -> void:
	if is_ended or is_paused:
		return
	if _pending_stage_end:
		request_end_stage(command_bus)
		return
	if not _is_locked:
		return
	_unlock_response(game_state, command_bus)

#== Private Methods ==
## 处理出牌请求
## @side_effect
func _process_play_card_request(request: OperationRequest.PlayCard, game_state: GameState, command_bus: CommandBus) -> void:
	var card: Card = game_state.cardsmanager.get_card_by_id(request._card_id)
	var source_player: Player = game_state.player_manager.get_player_by_id(request.source_player_id)
	var target_player: Player = game_state.player_manager.get_player_by_id(request._target_id) if request._target_id >= 0 else null
	if not card or not source_player:
		GlobalConsole._print(["濒死阶段：卡牌或玩家实例获取失败"])
		request.cancel()
		return
	var usage_result: RuleCardUsage.UsageResult = RuleCardUsage.can_use_card_in_dying_stage(card)
	if not usage_result.is_valid:
		GlobalConsole._print(["濒死阶段：", usage_result.message])
		request.cancel()
		return
	var rule_result: RuleCardPlay.RuleResult = RuleCardPlay.check_and_create_command(card, source_player, target_player, game_state)
	if not rule_result.is_valid:
		GlobalConsole._print(["濒死阶段：", rule_result.message])
		request.cancel()
		return
	var command: BehaviorCommand = rule_result.command
	if not command:
		GlobalConsole._print(["濒死阶段：规则未返回命令"])
		request.cancel()
		return
	_lock_response(game_state, command_bus)
	request.complete()
	command_bus.queue_behavior_with_callback(command, func() -> void:
		_on_command_completed(game_state, command_bus)
	)
## 命令完成回调
## @side_effect
func _on_command_completed(game_state: GameState, command_bus: CommandBus) -> void:
	if is_ended or is_paused:
		return
	_current_time_limit = calculate_new_time_limit(_current_time_limit, TIME_PENALTY_STEP, MIN_TIME_LIMIT)
	_unlock_response(game_state, command_bus)
	_reset_timer()
	GlobalConsole._print(["濒死阶段：命令完成，新时间限制", _current_time_limit])
## 授予所有玩家响应权
## @side_effect
func _grant_response_permission_to_all_players(game_state: GameState, command_bus: CommandBus) -> void:
	var all_player_ids: PackedInt32Array = create_all_player_ids(game_state)
	command_bus.set_responsive_players(all_player_ids)
## 撤销响应权
## @side_effect
func _revoke_response_permission(command_bus: CommandBus) -> void:
	command_bus.set_responsive_players(PackedInt32Array())
## 锁定响应
## @side_effect
func _lock_response(game_state: GameState, command_bus: CommandBus) -> void:
	if _is_locked:
		return
	_is_locked = true
	_revoke_response_permission(command_bus)
	_stop_timer()
## 解锁响应
## @side_effect
func _unlock_response(game_state: GameState, command_bus: CommandBus) -> void:
	if not _is_locked:
		return
	_is_locked = false
	_grant_response_permission_to_all_players(game_state, command_bus)
	_reset_timer()
## 请求重置计时器
## @requester @side_effect
func _reset_timer() -> void:
	request_reset_timer.emit(_current_time_limit)
## 请求停止计时器
## @requester @side_effect
func _stop_timer() -> void:
	request_reset_timer.emit(0.0)
## 生成玩家死亡命令
## @side_effect
func _generate_player_death_command(game_state: GameState, command_bus: CommandBus) -> void:
	var death_cmd: PlayerDeathCommand = create_player_death_command(dying_player)
	command_bus.queue_behavior(death_cmd)
	GlobalConsole._print(["濒死阶段：玩家", dying_player.get_id(), "死亡，已生成死亡命令"])
