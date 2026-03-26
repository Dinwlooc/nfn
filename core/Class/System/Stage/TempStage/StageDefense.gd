extends Stage
class_name StageDefense
# ========== 常量 ==========
const DEFAULT_TIME_LIMIT: float = 3.0
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
# ========== 内部状态 ==========
var _game_state: GameState = null  # 用于信号回调中访问 game_state
# ========== 初始化 ==========
func _init(defense_area: AreaDefence, attacker: Player) -> void:
	super._init()
	self.defense_area = defense_area
	self.attacker = attacker
	self.defender = defense_area.player
	stage_name = &"DefenseBattle"
	time_limit = DEFAULT_TIME_LIMIT
	_connect_defense_area_signals()

func _connect_defense_area_signals() -> void:
	# 避免重复连接
	if defense_area.area_card_added.is_connected(_on_defense_area_card_changed):
		defense_area.area_card_added.disconnect(_on_defense_area_card_changed)
	if defense_area.area_card_removed.is_connected(_on_defense_area_card_changed):
		defense_area.area_card_removed.disconnect(_on_defense_area_card_changed)
	defense_area.area_card_added.connect(_on_defense_area_card_changed)
	defense_area.area_card_removed.connect(_on_defense_area_card_changed)

func _disconnect_defense_area_signals() -> void:
	if defense_area.area_card_added.is_connected(_on_defense_area_card_changed):
		defense_area.area_card_added.disconnect(_on_defense_area_card_changed)
	if defense_area.area_card_removed.is_connected(_on_defense_area_card_changed):
		defense_area.area_card_removed.disconnect(_on_defense_area_card_changed)

# ========== 阶段生命周期 ==========
func enter(game_state: GameState) -> void:
	super.enter(game_state)
	_game_state = game_state
	for p in [attacker.player_id, defender.player_id]:
		total_time_used[p] = 0.0
		dynamic_time_limit[p] = DEFAULT_TIME_LIMIT
	if defense_area.pending_card:
		defense_area.commit_pending_card()
	_update_responsive_player(game_state)
	_reset_timer_for_current_player()
	_check_and_generate_battle_command(game_state)
	GlobalConsole._print(["守区攻防阶段开始，当前响应玩家：", current_responsive_player_id])

func resume(game_state: GameState) -> void:
	super.resume(game_state)
	_game_state = game_state
	_update_responsive_player(game_state)
	_reset_timer_for_current_player()

func end_stage_effect(game_state: GameState) -> void:
	if defense_area.pending_card:
		defense_area.commit_pending_card()
	game_state.set_responsive_players(PackedInt32Array())
	_disconnect_defense_area_signals()
	_game_state = null
	GlobalConsole._print(["守区攻防阶段结束"])

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

# ---------- 出牌请求 ----------
func _process_play_card_request(request: OperationRequest.PlayCard, game_state: GameState) -> void:
	var rule_result = Rule.check_and_create_command(
		request._card_id,
		request.source_player_id,
		request._target_id,
		request._is_to_center,
		game_state
	)
	if not rule_result.is_valid:
		GlobalConsole._print(["守区攻防阶段：", rule_result.message])
		request.cancel()
		return
	if not _check_defense_battle_restrictions(request._card_id, game_state):
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
		_update_responsive_player(game_state)
		_reset_timer_for_current_player()
		GlobalConsole._print(["守区攻防阶段：出牌成功，当前响应玩家：", current_responsive_player_id])
	)
	request.complete()

# ---------- 结算请求 ----------
func timeout(game_state: GameState) -> void:
	# 超时时自动放弃响应，生成放弃响应请求
	if is_ended or is_paused:
		return
	var abandon_request = OperationRequest.AbandonResponse.new()
	abandon_request.source_player_id = current_responsive_player_id
	# 将请求交给阶段处理（会触发结算）
	process_operation_request(abandon_request, game_state)

# 完善 _process_settle_request
func _process_settle_request(request: OperationRequest, game_state: GameState) -> void:
	# 创建结算命令
	var settle_cmd = SettleCommand.new(current_responsive_player_id)
	settle_cmd.set_defense_context(defense_area, attacker)
	# 排队并附加回调，结算完成后结束阶段
	game_state.queue_behavior_with_callback(settle_cmd, func():
		if not is_ended:
			end_stage(game_state)
	)
	request.complete()

# ========== 守区攻防专用验证 ==========
func _check_defense_battle_restrictions(card_id: int, game_state: GameState) -> bool:
	var card: Card = game_state.cardsmanager.get_card_by_id(card_id)
	if not card:
		return false
	var top: Card = defense_area.get_top_card()
	var is_attacker_turn: bool = (current_responsive_player_id == attacker.player_id)
	if top == null:
		if not is_attacker_turn:
			GlobalConsole._print(["守区攻防阶段：顶层为空，只有攻方可出牌"])
			return false
		if card.type == &"attack":
			var distance: int = game_state.player_manager.calculate_distance(attacker.seat_index, defender.seat_index)
			var attack_range: int = card.get_attribute(&"attack_range")
			if attack_range <= distance:
				GlobalConsole._print(["守区攻防阶段：攻击距离不足"])
				return false
			return true
		elif card.type == &"skill":
			if card.get_attribute(&"is_group_attack"):
				GlobalConsole._print(["守区攻防阶段：不能使用群体攻击技能"])
				return false
			return true
		else:
			GlobalConsole._print(["守区攻防阶段：攻方只能使用攻击或技能牌"])
			return false
	if top.player == defender:
		if not is_attacker_turn:
			GlobalConsole._print(["守区攻防阶段：顶层为守方牌，只有攻方可出牌"])
			return false
		if card.type == &"attack":
			var distance: int = game_state.player_manager.calculate_distance(attacker.seat_index, defender.seat_index)
			var attack_range: int = card.get_attribute(&"attack_range")
			if attack_range <= distance:
				GlobalConsole._print(["守区攻防阶段：攻击距离不足"])
				return false
			return true
		elif card.type == &"skill":
			if card.get_attribute(&"is_group_attack"):
				GlobalConsole._print(["守区攻防阶段：不能使用群体攻击技能"])
				return false
			return true
		else:
			GlobalConsole._print(["守区攻防阶段：攻方只能使用攻击或技能牌"])
			return false
	if top.player == attacker:
		if is_attacker_turn:
			GlobalConsole._print(["守区攻防阶段：顶层为攻方牌，只有守方可出牌"])
			return false
		if card.type == &"defence":
			return true
		else:
			GlobalConsole._print(["守区攻防阶段：守方只能使用防御牌"])
			return false
	GlobalConsole._print(["守区攻防阶段：顶层所有者无效"])
	return false

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
	# 获取斗牌的两张牌
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

func _on_defense_area_card_changed(_card: Card, _area: Area) -> void:
	if is_ended or is_paused or not _game_state:
		return
	_check_and_generate_battle_command(_game_state)

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
