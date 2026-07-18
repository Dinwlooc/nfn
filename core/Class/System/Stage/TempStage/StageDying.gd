## 玩家濒死阶段：所有玩家可响应“濒死可用”卡牌，采用抢拍锁定机制，超时后若濒死玩家生命值仍≤0则生成死亡命令
extends Stage
class_name StageDying

const DEFAULT_TIME_LIMIT: float = 10.0
const MIN_TIME_LIMIT: float = 4.0
const TIME_PENALTY_STEP: float = 2.0

var dying_player: Player
var _current_time_limit: float = DEFAULT_TIME_LIMIT
var _is_locked: bool = false
var _pending_stage_end: bool = false

func _init(p_dying_player: Player) -> void:
	super._init()
	dying_player = p_dying_player
	temporary_stage_player_id = dying_player.get_id()
	stage_name = &"Dying"
	time_limit = DEFAULT_TIME_LIMIT
	_current_time_limit = DEFAULT_TIME_LIMIT

func enter(game_state: GameState, command_bus: CommandBus) -> void:
	_grant_response_permission_to_all_players(game_state)
	_reset_timer()
	super.enter(game_state, command_bus)

func pause(game_state: GameState, command_bus: CommandBus) -> void:
	_revoke_response_permission(game_state)
	_stop_timer()
	super.pause(game_state, command_bus)

func resume(game_state: GameState, command_bus: CommandBus) -> void:
	_grant_response_permission_to_all_players(game_state)
	_reset_timer()
	super.resume(game_state, command_bus)

func end_stage_effect(game_state: GameState, command_bus: CommandBus) -> void:
	_revoke_response_permission(game_state)
	_stop_timer()
	if dying_player.HP <= 0:
		_generate_player_death_command(game_state, command_bus)
	super.end_stage_effect(game_state, command_bus)

func timeout(game_state: GameState, command_bus: CommandBus) -> void:
	if is_ended or is_paused:
		return
	_pending_stage_end = true
	_stop_timer()
	if _is_locked == false:
		end_stage(game_state, command_bus)

func process_operation_request(request: OperationRequest, game_state: GameState, command_bus: CommandBus) -> void:
	if is_ended or is_paused or _is_locked:
		return
	match request.get_class_name():
		&"play_card":
			_process_play_card_request(request as OperationRequest.PlayCard, game_state, command_bus)
		_:
			GlobalConsole._print(["濒死阶段：不支持的操作类型", request.get_class_name_static()])
			request.cancel()

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
	_lock_response(game_state)
	request.complete()
	command_bus.queue_behavior_with_callback(command, func():
		_on_command_completed(game_state, command_bus)
	)

func _on_command_completed(game_state: GameState, command_bus: CommandBus) -> void:
	if is_ended or is_paused:
		return
	_current_time_limit = max(_current_time_limit - TIME_PENALTY_STEP, MIN_TIME_LIMIT)
	_unlock_response(game_state)
	_reset_timer()
	GlobalConsole._print(["濒死阶段：命令完成，新时间限制", _current_time_limit])

func refresh_response(game_state: GameState, command_bus: CommandBus) -> void:
	if is_ended or is_paused:
		return
	if _pending_stage_end:
		end_stage(game_state, command_bus)
		return
	if _is_locked:
		_unlock_response(game_state)

func _grant_response_permission_to_all_players(game_state: GameState) -> void:
	var all_player_ids: PackedInt32Array = []
	for player in game_state.player_manager.players:
		all_player_ids.append(player.get_id())
	game_state.set_responsive_players(all_player_ids)

func _revoke_response_permission(game_state: GameState) -> void:
	game_state.set_responsive_players(PackedInt32Array())

func _lock_response(game_state: GameState) -> void:
	if _is_locked:
		return
	_is_locked = true
	_revoke_response_permission(game_state)
	_stop_timer()

func _unlock_response(game_state: GameState) -> void:
	if not _is_locked:
		return
	_is_locked = false
	_grant_response_permission_to_all_players(game_state)
	_reset_timer()

func _reset_timer() -> void:
	request_reset_timer.emit(_current_time_limit)

func _stop_timer() -> void:
	request_reset_timer.emit(0.0)

func _generate_player_death_command(game_state: GameState, command_bus: CommandBus) -> void:
	var death_cmd := PlayerDeathCommand.new(dying_player)
	command_bus.queue_behavior(death_cmd)
	GlobalConsole._print(["濒死阶段：玩家", dying_player.get_id(), "死亡，已生成死亡命令"])
