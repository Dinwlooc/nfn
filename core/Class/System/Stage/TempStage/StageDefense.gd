extends Stage
class_name StageDefense

# ========== 常量 ==========
const DEFAULT_TIME_LIMIT: float = 30.0
const MIN_TIME_LIMIT: float = 5.0
const TIME_PENALTY_STEP: float = 30.0
const TIME_PENALTY_DECREMENT: float = 15.0
# ========== 引用 ==========
var defense_area: AreaDefence
var attacker: Player
var defender: Player
# ========== 计时相关 ==========
var last_timer_reset_time: int = 0
var current_responsive_player_id: int = -1
var total_time_used: Dictionary[int, float] = {}
var dynamic_time_limit: Dictionary[int, float] = {}
# ========== 其他信号绑定 ==========
var _defense_area_signal_binding: Callable = Callable()
# ========== 结束标志 ==========
var _pending_stage_end: bool = false

# ========== 初始化 ==========
func _init(defense_area: AreaDefence, attacker: Player) -> void:
	super._init()
	is_temporary = true
	self.defense_area = defense_area
	self.attacker = attacker
	self.defender = defense_area.player
	stage_name = &"DefenseBattle"
	time_limit = DEFAULT_TIME_LIMIT

# ========== 阶段生命周期 ==========
func enter(game_state: GameState) -> void:
	for p in [attacker.player_id, defender.player_id]:
		total_time_used[p] = 0.0
		dynamic_time_limit[p] = DEFAULT_TIME_LIMIT
	if defense_area.pending_card:
		defense_area.commit_pending_card()
	_update_responsive_player(game_state)
	_reset_timer_for_current_player()
	_connect_defense_area_signals(game_state)
	_check_and_generate_battle_command(game_state)
	super.enter(game_state)

func resume(game_state: GameState) -> void:
	_update_responsive_player(game_state)
	_reset_timer_for_current_player()
	_connect_defense_area_signals(game_state)
	super.resume(game_state)

func pause(game_state: GameState) -> void:
	_disconnect_defense_area_signals()
	super.pause(game_state)

func end_stage_effect(game_state: GameState) -> void:
	if defense_area.pending_card:
		defense_area.commit_pending_card()
	_disconnect_defense_area_signals()
	_pending_stage_end = false
	super.end_stage_effect(game_state)

# ========== 操作请求处理 ==========
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

func _process_play_card_request(request: OperationRequest.PlayCard, game_state: GameState) -> void:
	# 获取实例
	var card: Card = game_state.cardsmanager.get_card_by_id(request._card_id)
	var source_player: Player = game_state.player_manager.get_player_by_id(request.source_player_id)
	var target_player: Player = game_state.player_manager.get_player_by_id(request._target_id) if request._target_id >= 0 else null
	if not card or not source_player:
		GlobalConsole._print(["守区攻防阶段：卡牌或玩家实例获取失败"])
		request.cancel()
		return
	# Rule 验证
	var rule_result = Rule.check_and_create_command(card, source_player, target_player, false, game_state)
	if not rule_result.is_valid:
		GlobalConsole._print(["守区攻防阶段：", rule_result.message])
		request.cancel()
		return
	# 守区阶段专用验证
	var usage_result = _check_defense_battle_restrictions(card, source_player, game_state)
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

func timeout(game_state: GameState) -> void:
	if is_ended or is_paused:
		return
	var abandon_request := OperationRequest.AbandonResponse.new(current_responsive_player_id)
	process_operation_request(abandon_request, game_state)

func _process_settle_request(request: OperationRequest, game_state: GameState) -> void:
	var settle_cmd = SettleCommand.new(current_responsive_player_id, defense_area)
	game_state.queue_behavior(settle_cmd)
	_pending_stage_end = true
	request.complete()

# ========== 守区攻防专用验证 ==========
func _check_defense_battle_restrictions(card: Card, source_player: Player, game_state: GameState) -> RuleCardUsage.UsageResult:
	return RuleCardUsage.can_use_card_in_defense(
		card,
		source_player,
		defense_area,
		attacker,
		defender,
		current_responsive_player_id
	)

# ========== 响应权更新 ==========
func _update_responsive_player(game_state: GameState) -> void:
	var top: Card = defense_area.get_top_card()
	if top:
		current_responsive_player_id = attacker.player_id if top.player == defender else defender.player_id
	else:
		current_responsive_player_id = attacker.player_id
	game_state.set_responsive_players(PackedInt32Array([current_responsive_player_id]))
	GlobalConsole._print(["守区攻防阶段：更新响应权为玩家", current_responsive_player_id])

# ========== 斗牌处理 ==========
func _check_and_generate_battle_command(game_state: GameState) -> void:
	if not defense_area.check_battle_formation():
		return
	var top_card: Card
	var second_card: Card
	if defense_area.pending_card:
		top_card = defense_area.pending_card
		second_card = defense_area.get_top_card()
	else:
		top_card = defense_area.get_top_card()
		second_card = defense_area.get_second_card()
	var battle_command = BattleCommand.new(defense_area, top_card, second_card)
	game_state.queue_behavior(battle_command)

func _on_defense_area_card_changed(_card: Card, _area: Area, game_state: GameState) -> void:
	if is_ended or is_paused:
		return
	_check_and_generate_battle_command(game_state)

# ========== 计时辅助 ==========
func _reset_timer_for_current_player() -> void:
	if current_responsive_player_id == -1:
		return
	var limit: float = DEFAULT_TIME_LIMIT
	if dynamic_time_limit.has(current_responsive_player_id):
		limit = dynamic_time_limit[current_responsive_player_id]
	request_reset_timer.emit(limit)
	last_timer_reset_time = Time.get_ticks_msec()

func _get_elapsed_time_since_last_reset() -> float:
	var now: int = Time.get_ticks_msec()
	var elapsed_ms: int = now - last_timer_reset_time
	return elapsed_ms / 1000.0

func _total_time_used_update(player_id: int, elapsed: float) -> void:
	var new_total: float = total_time_used[player_id] + elapsed
	total_time_used[player_id] = new_total
	var steps: int = int(new_total / TIME_PENALTY_STEP)
	var new_limit: float = DEFAULT_TIME_LIMIT - steps * TIME_PENALTY_DECREMENT
	new_limit = max(new_limit, MIN_TIME_LIMIT)
	dynamic_time_limit[player_id] = new_limit
	GlobalConsole._print(["玩家", player_id, "总用时", new_total, "s，动态时间限", new_limit, "s"])

# ========== 防御区信号管理（独立） ==========
func _connect_defense_area_signals(game_state: GameState) -> void:
	_disconnect_defense_area_signals()
	_defense_area_signal_binding = _on_defense_area_card_changed.bind(game_state)
	defense_area.area_card_added.connect(_defense_area_signal_binding)
	defense_area.area_card_removed.connect(_defense_area_signal_binding)

func _disconnect_defense_area_signals() -> void:
	if _defense_area_signal_binding != Callable():
		if defense_area.area_card_added.is_connected(_defense_area_signal_binding):
			defense_area.area_card_added.disconnect(_defense_area_signal_binding)
		if defense_area.area_card_removed.is_connected(_defense_area_signal_binding):
			defense_area.area_card_removed.disconnect(_defense_area_signal_binding)
		_defense_area_signal_binding = Callable()

# ------------------ 实现基类抽象方法 ------------------
func _on_all_commands_completed_impl(game_state: GameState) -> void:
	if is_ended or is_paused:
		return
	if _pending_stage_end:
		end_stage(game_state)
		return
	_update_responsive_player(game_state)
	_reset_timer_for_current_player()
	GlobalConsole._print(["守区攻防阶段：命令全部完成，已更新玩家响应权"])
