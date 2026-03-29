extends Stage
class_name StageMain

# ========== 常量 ==========
const ENTER_TIME_LIMIT: float = 60.0   # 进入时的计时上限
const RESUME_TIME_LIMIT: float = 30.0  # 恢复时的计时上限

# ========== 内部状态 ==========
var _current_attacker_id: int = -1
var _current_attacker: Player = null
var _current_time_limit: float = ENTER_TIME_LIMIT  # 当前计时上限（动态变化）
var last_timer_reset_time: int = 0                 # 用于计时（虽然不惩罚，但保持接口统一）
var _all_commands_completed_binding: Callable = Callable()  # 命令完成信号绑定

# ========== 生命周期 ==========
func _init() -> void:
	super._init()
	stage_name = &"Main"
	time_limit = ENTER_TIME_LIMIT   # 初始值（由 enter 覆盖）

func enter(game_state: GameState) -> void:
	super.enter(game_state)
	_current_attacker = game_state.player_manager.get_player_by_id(game_state.stage_context.current_player_id)
	_current_attacker_id = _current_attacker.player_id
	_current_time_limit = ENTER_TIME_LIMIT
	# 设置响应玩家并启动计时
	game_state.set_responsive_players(PackedInt32Array([_current_attacker_id]))
	_reset_timer_for_current_player()
	# 连接所有命令完成信号
	_connect_all_commands_completed_signal(game_state)
	GlobalConsole._print(["主阶段开始，当前玩家：", _current_attacker_id])

func resume(game_state: GameState) -> void:
	super.resume(game_state)
	# 恢复时重新同步当前玩家（可能未变）
	_current_attacker = game_state.player_manager.get_player_by_id(game_state.stage_context.current_player_id)
	_current_attacker_id = _current_attacker.player_id
	_current_time_limit = RESUME_TIME_LIMIT
	# 重新设置响应玩家（确保正确）并重置计时
	game_state.set_responsive_players(PackedInt32Array([_current_attacker_id]))
	_reset_timer_for_current_player()
	# 重新连接信号（确保信号连接）
	_connect_all_commands_completed_signal(game_state)
	GlobalConsole._print(["主阶段恢复，当前玩家：", _current_attacker_id])

func pause(game_state: GameState) -> void:
	super.pause(game_state)
	_disconnect_all_commands_completed_signal(game_state)

func end_stage_effect(game_state: GameState) -> void:
	_current_attacker = null
	game_state.set_responsive_players(PackedInt32Array())
	_disconnect_all_commands_completed_signal(game_state)
	GlobalConsole._print(["主阶段结束"])

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
	# 规则校验
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
	# 主阶段专属限制检查
	if not _check_main_stage_restrictions(request._card_id, request._target_id, game_state):
		request.cancel()
		return
	# 执行命令
	game_state.queue_behavior(rule_result.command)
	# 如果规则指定了响应权变化，立即设置（但命令完成后会刷新）
	if rule_result.should_respond:
		game_state.set_responsive_players(rule_result.responsive_players)
		GlobalConsole._print(["主阶段：技能牌使用成功，响应权已更新"])
	else:
		GlobalConsole._print(["主阶段：卡牌使用成功"])
	request.complete()

# ========== 主阶段专属限制 ==========
func _check_main_stage_restrictions(card_id: int, target_id: int, game_state: GameState) -> bool:
	var card: Card = game_state.cardsmanager.get_card_by_id(card_id)
	if not card:
		GlobalConsole._print(["主阶段：卡牌不存在"])
		return false
	var card_type = card.type
	match card_type:
		&"attack":
			# 对守区使用攻击牌时，检查目标守区已结算次数是否小于攻击者速度
			if target_id >= 0:
				var target_player: Player = game_state.player_manager.get_player_by_id(target_id)
				if target_player:
					var defense_area: AreaDefence = target_player.area_defensive
					if defense_area and defense_area.settle_count >= _current_attacker.get_attribute(&"speed"):
						GlobalConsole._print(["主阶段：目标守区已结算次数(%d) >= 攻击者速度(%d)，不能攻击" % [defense_area.settle_count, _current_attacker.get_attribute(&"speed")]])
						return false
			return _check_defensive_restrictions(card_id, target_id, game_state)
		&"defence":
			return _check_defensive_restrictions(card_id, target_id, game_state)
		&"skill":
			return true
		_:
			GlobalConsole._print(["主阶段：不明类型卡牌，尝试打出"])
			return true

func _check_defensive_restrictions(card_id: int, target_id: int, game_state: GameState) -> bool:
	var card: Card = game_state.cardsmanager.get_card_by_id(card_id)
	if not card:
		return false
	var card_type = card.type
	var target_player = game_state.player_manager.get_player_by_id(target_id) if target_id >= 0 else null
	match card_type:
		&"attack":
			if target_player and target_player.area_defensive.get_top_card() and target_player.area_defensive.get_top_card().player == _current_attacker:
				GlobalConsole._print(["主阶段：目标守区顶部仍是你的牌，你不能攻击"])
				return false
			return true
		&"defence":
			if _current_attacker.area_defensive.get_top_card() and _current_attacker.area_defensive.get_top_card().player == _current_attacker:
				GlobalConsole._print(["主阶段：自身守区顶部仍是你的牌，你不能使用防御牌"])
				return false
			return true
		_:
			return true

# ========== 计时辅助 ==========
func _reset_timer_for_current_player() -> void:
	request_reset_timer.emit(_current_time_limit)
	last_timer_reset_time = Time.get_ticks_msec()

# ========== 信号管理 ==========
func _connect_all_commands_completed_signal(game_state: GameState) -> void:
	_disconnect_all_commands_completed_signal(game_state)
	_all_commands_completed_binding = _on_all_commands_completed.bind(game_state)
	game_state.all_commands_completed.connect(_all_commands_completed_binding)

func _disconnect_all_commands_completed_signal(game_state: GameState) -> void:
	if _all_commands_completed_binding != Callable():
		if game_state and game_state.all_commands_completed.is_connected(_all_commands_completed_binding):
			game_state.all_commands_completed.disconnect(_all_commands_completed_binding)
	_all_commands_completed_binding = Callable()

func _on_all_commands_completed(game_state: GameState) -> void:
	if is_ended or is_paused:
		return
	# 命令全部完成后，重新设置响应玩家（刷新阻塞）并重置计时器
	game_state.set_responsive_players(PackedInt32Array([_current_attacker_id]))
	_reset_timer_for_current_player()
	GlobalConsole._print(["主阶段：所有命令完成，已刷新响应权为玩家", _current_attacker_id])
