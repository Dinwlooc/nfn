extends Stage
class_name StageMain

# ========== 常量 ==========
const ENTER_TIME_LIMIT: float = 60.0
const RESUME_TIME_LIMIT: float = 30.0

# ========== 内部状态 ==========
var _current_attacker_id: int = -1
var _current_attacker: Player = null
var last_timer_reset_time: int = 0

# ========== 生命周期 ==========
func _init() -> void:
	super._init()
	stage_name = &"Main"
	time_limit = ENTER_TIME_LIMIT

func enter(game_state: GameState) -> void:
	# 先初始化自身状态，再调用基类（基类会连接信号）
	_current_attacker = game_state.player_manager.get_player_by_id(game_state.stage_manager.current_player_id)
	_current_attacker_id = _current_attacker.player_id
	game_state.set_responsive_players(PackedInt32Array([_current_attacker_id]))
	_reset_timer_for_current_player(ENTER_TIME_LIMIT)
	GlobalConsole._print(["主阶段开始，当前玩家：", _current_attacker_id])
	super.enter(game_state)   # 基类会连接 all_commands_completed 信号

func resume(game_state: GameState) -> void:
	# 恢复前先刷新状态
	_current_attacker = game_state.player_manager.get_player_by_id(game_state.stage_manager.current_player_id)
	_current_attacker_id = _current_attacker.player_id
	game_state.set_responsive_players(PackedInt32Array([_current_attacker_id]))
	_reset_timer_for_current_player(ENTER_TIME_LIMIT / 2)
	GlobalConsole._print(["主阶段恢复，当前玩家：", _current_attacker_id])
	super.resume(game_state)   # 基类会重新连接信号

func pause(game_state: GameState) -> void:
	super.pause(game_state)   # 基类会断开信号
	# 子类额外清理（如有）

func end_stage_effect(game_state: GameState) -> void:
	_current_attacker = null
	game_state.set_responsive_players(PackedInt32Array())
	GlobalConsole._print(["主阶段结束"])
	super.end_stage_effect(game_state)   # 可选，基类无操作

# ========== 操作请求处理 ==========
func process_operation_request(request: OperationRequest, game_state: GameState) -> void:
	if is_ended or is_paused:
		return
	match request.get_class_name():
		&"play_card":
			_process_play_card_request(request as OperationRequest.PlayCard, game_state)
		&"abandon_response":
			end_stage(game_state)
			request.complete()
			GlobalConsole._print(["主阶段：放弃响应，结束阶段"])
		_:
			request.cancel()
			GlobalConsole._print(["主阶段：不支持的操作类型", request.get_class_name_static()])

func _process_play_card_request(request: OperationRequest.PlayCard, game_state: GameState) -> void:
	if request.source_player_id != _current_attacker_id:
		GlobalConsole._print(["主阶段：非当前玩家操作，忽略"])
		request.cancel()
		return
	var rule_result = Rule.check_and_create_command(
		request._card_id,
		_current_attacker_id,
		request._target_id,
		game_state
	)
	if not rule_result.is_valid:
		GlobalConsole._print(["主阶段：", rule_result.message])
		request.cancel()
		return
	if not _check_main_stage_restrictions(request._card_id, request._target_id, game_state):
		request.cancel()
		return
	game_state.queue_behavior(rule_result.command)
	GlobalConsole._print(["主阶段：卡牌使用成功"])
	request.complete()

func _check_main_stage_restrictions(card_id: int, target_id: int, game_state: GameState) -> bool:
	var card: Card = game_state.cardsmanager.get_card_by_id(card_id)
	if not card:
		GlobalConsole._print(["主阶段：卡牌不存在"])
		return false
	var source_player: Player = game_state.player_manager.get_player_by_id(_current_attacker_id)
	var target_player: Player = game_state.player_manager.get_player_by_id(target_id) if target_id >= 0 else null
	var can_use = RuleCardUsage.can_use_card_in_main(card, source_player, target_player, game_state)
	if not can_use:
		GlobalConsole._print(["主阶段：规则不允许使用此卡牌"])
	return can_use

func _reset_timer_for_current_player(new_time_limit: int) -> void:
	request_reset_timer.emit(new_time_limit)
	last_timer_reset_time = Time.get_ticks_msec()

# ------------------ 实现基类抽象方法 ------------------
func _on_all_commands_completed_impl(game_state: GameState) -> void:
	# 空闲期：恢复响应权并重置计时器
	if is_ended or is_paused:
		return
	game_state.set_responsive_players(PackedInt32Array([_current_attacker_id]))
	_reset_timer_for_current_player(ENTER_TIME_LIMIT / 2)
	GlobalConsole._print(["主阶段：所有命令完成，已刷新响应权为玩家", _current_attacker_id])
