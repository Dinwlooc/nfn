## 玩家濒死阶段：所有玩家可响应“濒死可用”卡牌，采用抢拍锁定机制，超时后若濒死玩家生命值仍≤0则生成死亡命令
extends Stage
class_name StageDying

## 默认超时时长（秒）
const DEFAULT_TIME_LIMIT: float = 10.0
## 动态超时下限（秒）
const MIN_TIME_LIMIT: float = 4.0
## 每次响应后减少的时长（秒）
const TIME_PENALTY_STEP: float = 2.0
## 濒死玩家实例
var dying_player: Player
## 当前动态时间限制
var _current_time_limit: float = DEFAULT_TIME_LIMIT
## 是否处于锁定状态（已接受一个请求，等待命令完成）
var _is_locked: bool = false
## 标记等待当前命令完成后结束阶段
var _pending_stage_end: bool = false
## 初始化濒死阶段
func _init(p_dying_player: Player) -> void:
	super._init()
	dying_player = p_dying_player
	temporary_stage_player_id = dying_player.get_id()
	stage_name = &"Dying"
	time_limit = DEFAULT_TIME_LIMIT
	_current_time_limit = DEFAULT_TIME_LIMIT
## 进入阶段：允许所有存活玩家响应
func enter(game_state: GameState) -> void:
	_grant_response_permission_to_all_players(game_state)
	_reset_timer()
	super.enter(game_state)
## 暂停阶段：断开响应权并停止计时
func pause(game_state: GameState) -> void:
	_revoke_response_permission(game_state)
	_stop_timer()
	super.pause(game_state)
## 恢复阶段：重新允许所有玩家响应，重置计时
func resume(game_state: GameState) -> void:
	_grant_response_permission_to_all_players(game_state)
	_reset_timer()
	super.resume(game_state)
## 结束阶段清理：若濒死玩家生命值≤0则生成死亡命令
func end_stage_effect(game_state: GameState) -> void:
	_revoke_response_permission(game_state)
	_stop_timer()
	if dying_player.HP <= 0:
		_generate_player_death_command(game_state)
	super.end_stage_effect(game_state)
## 超时处理：标记阶段结束，等待命令完成后退出
func timeout(game_state: GameState) -> void:
	if is_ended or is_paused:
		return
	_pending_stage_end = true
	_stop_timer()
	if _is_locked == false:
		end_stage(game_state)
## 处理玩家操作请求：仅支持出牌，且必须通过濒死可用验证
func process_operation_request(request: OperationRequest, game_state: GameState) -> void:
	if is_ended or is_paused or _is_locked:
		return
	match request.get_class_name():
		&"play_card":
			_process_play_card_request(request as OperationRequest.PlayCard, game_state)
		_:
			GlobalConsole._print(["濒死阶段：不支持的操作类型", request.get_class_name_static()])
			request.cancel()
## 处理出牌请求：验证濒死可用性、基础规则，通过后锁定并排队命令
func _process_play_card_request(request: OperationRequest.PlayCard, game_state: GameState) -> void:
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
	game_state.queue_behavior_with_callback(command, func():
		_on_command_completed(game_state)
	)
## 命令完成后的回调：解锁、减少时间限制、重置计时器
func _on_command_completed(game_state: GameState) -> void:
	if is_ended or is_paused:
		return
	_current_time_limit = max(_current_time_limit - TIME_PENALTY_STEP, MIN_TIME_LIMIT)
	_unlock_response(game_state)
	_reset_timer()
	GlobalConsole._print(["濒死阶段：命令完成，新时间限制", _current_time_limit])
## 所有命令完成时的处理（继承自 Stage）
func _on_all_commands_completed_impl(game_state: GameState) -> void:
	if is_ended or is_paused:
		return
	if _pending_stage_end:
		end_stage(game_state)
		return
	if _is_locked:
		_unlock_response(game_state)
## 授予所有存活玩家响应权
func _grant_response_permission_to_all_players(game_state: GameState) -> void:
	var all_player_ids: PackedInt32Array = []
	for player in game_state.player_manager.players:
		all_player_ids.append(player.get_id())
	game_state.set_responsive_players(all_player_ids)
## 撤销所有玩家的响应权（用于锁定或暂停）
func _revoke_response_permission(game_state: GameState) -> void:
	game_state.set_responsive_players(PackedInt32Array())
## 锁定响应：停止计时器，禁止新请求
func _lock_response(game_state: GameState) -> void:
	if _is_locked:
		return
	_is_locked = true
	_revoke_response_permission(game_state)
	_stop_timer()
## 解锁响应：允许所有玩家重新响应，启动计时器
func _unlock_response(game_state: GameState) -> void:
	if not _is_locked:
		return
	_is_locked = false
	_grant_response_permission_to_all_players(game_state)
	_reset_timer()
## 重置计时器（使用当前动态时间限制）
func _reset_timer() -> void:
	request_reset_timer.emit(_current_time_limit)
## 停止计时器
func _stop_timer() -> void:
	request_reset_timer.emit(0.0)
## 生成玩家死亡命令
func _generate_player_death_command(game_state: GameState) -> void:
	var death_cmd := PlayerDeathCommand.new(dying_player)
	game_state.queue_behavior(death_cmd)
	GlobalConsole._print(["濒死阶段：玩家", dying_player.get_id(), "死亡，已生成死亡命令"])
