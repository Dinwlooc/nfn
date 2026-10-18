## 守区攻防阶段（管理斗牌命令的生成与取消）
extends Stage
class_name StageDefense

#== Constants ==
## 默认时限（秒）
const DEFAULT_TIME_LIMIT: float = 30.0
## 时限下限（秒）
const MIN_TIME_LIMIT: float = 5.0
## 每轮响应的时限步长（秒）
const TIME_PENALTY_STEP: float = 10.0
## 时限递减量（秒）
const TIME_PENALTY_DECREMENT: float = 5.0

#== Nested Classes ==
## 时间记录（累计用时与动态时间限制）
## @context
class TimeRecords:
	## 玩家 id → 已用时间（秒）
	var total_time_used: Dictionary[int, float] = {}
	## 玩家 id → 当前动态时限（秒）
	var dynamic_time_limit: Dictionary[int, float] = {}

#== Properties ==
## 守区区域
var defense_area: AreaDefence
## 攻击方玩家
var attacker: Player
## 防守方玩家
var defender: Player
## 上次计时器重置时间（毫秒）
var last_timer_reset_time: int = 0
## 当前拥有响应权的玩家 ID
var current_responsive_player_id: int = 0
## 各玩家累计用时
var total_time_used: Dictionary[int, float] = {}
## 各玩家动态时间限制
var dynamic_time_limit: Dictionary[int, float] = {}
## 守区信号绑定
var _defense_area_signal_binding: Callable = Callable()
## 是否等待阶段结束
var _pending_stage_end: bool = false
## 当前斗牌命令引用
var _current_battle_command: BattleCommand = null
## 是否需要重新生成斗牌命令
var _need_regenerate_battle_command: bool = false

#== Constructor ==
## 构造：绑定守区与攻击方
func _init(defense_area: AreaDefence, attacker: Player) -> void:
	super._init()
	self.defense_area = defense_area
	self.attacker = attacker
	self.defender = defense_area.player
	temporary_stage_player_id = defender.get_id()
	stage_name = &"DefenseBattle"
	time_limit = DEFAULT_TIME_LIMIT

#== 计时能力 ==
## 计算自上次重置以来的耗时（秒）
## @pure
static func calculate_elapsed_time(now_msec: int, last_reset_time: int) -> float:
	var elapsed_ms: int = now_msec - last_reset_time
	return elapsed_ms / 1000.0
## 根据累计用时计算新的动态时间限制
## @pure
static func calculate_new_time_limit(new_total: float, default_limit: float, step: float, decrement: float, min_limit: float) -> float:
	var steps: int = int(new_total / step)
	var new_limit: float = default_limit - steps * decrement
	return max(new_limit, min_limit)
## 根据玩家 ID 列表构造时间记录
## @factory
static func build_time_records(player_ids: Array[int]) -> TimeRecords:
	var records := TimeRecords.new()
	for player_id: int in player_ids:
		records.total_time_used[player_id] = 0.0
		records.dynamic_time_limit[player_id] = DEFAULT_TIME_LIMIT
	return records
## 更新玩家累计用时与动态时间限制
## @atomic
func update_total_time_used(player_id: int, elapsed: float) -> void:
	var new_total: float = total_time_used[player_id] + elapsed
	total_time_used[player_id] = new_total
	var new_limit: float = calculate_new_time_limit(new_total, DEFAULT_TIME_LIMIT, TIME_PENALTY_STEP, TIME_PENALTY_DECREMENT, MIN_TIME_LIMIT)
	dynamic_time_limit[player_id] = new_limit
	GlobalConsole._print(["玩家", player_id, "总用时", new_total, "s，动态时间限", new_limit, "s"])
## 获取自上次重置以来的耗时（秒）
## @pure
func get_elapsed_time_since_last_reset() -> float:
	return calculate_elapsed_time(Time.get_ticks_msec(), last_timer_reset_time)

#== 响应能力 ==
## 根据攻防与顶牌玩家计算响应玩家 ID
## @pure
static func calculate_responsive_player_id(attacker_id: int, defender_id: int, top_card: Card, defender: Player) -> int:
	if not top_card:
		return attacker_id
	return attacker_id if top_card.player == defender else defender_id

#== 命令能力 ==
## 创建斗牌命令，无法形成斗牌时返回 null
## @nullable_pure
static func build_battle_command(defense_area: AreaDefence) -> BattleCommand:
	if not defense_area.check_battle_formation():
		return null
	var top_card: Card = defense_area.get_top_card()
	var second_card: Card = defense_area.get_second_card()
	return BattleCommand.new(defense_area, top_card, second_card)
## 创建结算命令
## @factory
static func build_settle_command(responsive_player_id: int, defense_area: AreaDefence, attacker: Player) -> SettleCommand:
	return SettleCommand.new(responsive_player_id, defense_area, attacker)
## 创建放弃响应请求
## @factory
static func build_abandon_response(player_id: int) -> OperationRequest.AbandonResponse:
	return OperationRequest.AbandonResponse.new(player_id)

#== Public Methods ==
## 进入阶段（计时由 refresh_response 统一管理）
## @override @hook @no_escape @side_effect
func enter(game_state: GameState, command_bus: CommandBus) -> void:
	var records: TimeRecords = build_time_records([attacker.get_id(), defender.get_id()])
	total_time_used = records.total_time_used
	dynamic_time_limit = records.dynamic_time_limit
	_update_responsive_player(game_state, command_bus)
	_connect_defense_area_signals(game_state)
	_generate_and_queue_battle_command(game_state, command_bus, true)
	super.enter(game_state, command_bus)
## 恢复阶段
## @override @hook @no_escape @side_effect
func resume(game_state: GameState, command_bus: CommandBus) -> void:
	_update_responsive_player(game_state, command_bus)
	_reset_timer_for_current_player()
	_connect_defense_area_signals(game_state)
	super.resume(game_state, command_bus)
## 暂停阶段
## @override @hook @no_escape @side_effect
func pause(game_state: GameState, command_bus: CommandBus) -> void:
	_disconnect_defense_area_signals()
	super.pause(game_state, command_bus)
## 阶段结束时的清理效果
## @override @hook @no_escape
func end_stage_effect(game_state: GameState, command_bus: CommandBus) -> void:
	_disconnect_defense_area_signals()
	_pending_stage_end = false
	_current_battle_command = null
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
			_process_settle_request(request, game_state, command_bus)
		_:
			GlobalConsole._print(["守区攻防阶段：不支持的操作类型", request.get_class_name_static()])
			request.cancel()
## 超时处理
## @override @hook @no_escape @side_effect
func timeout(game_state: GameState, command_bus: CommandBus) -> void:
	if is_ended or is_paused:
		return
	var abandon_request: OperationRequest.AbandonResponse = build_abandon_response(current_responsive_player_id)
	process_operation_request(abandon_request, game_state, command_bus)
## 刷新响应权：轮转命令结束后统一重设计时器
## @override @hook @no_escape @side_effect
func refresh_response(game_state: GameState, command_bus: CommandBus) -> void:
	if is_ended or is_paused:
		return
	if _pending_stage_end:
		request_end_stage(command_bus)
		return
	if _need_regenerate_battle_command:
		_need_regenerate_battle_command = false
		var new_cmd: BattleCommand = _generate_and_queue_battle_command(game_state, command_bus, true)
		if new_cmd:
			GlobalConsole._print(["守区攻防阶段：重新生成斗牌命令，跳过响应权更新"])
			return
	_update_responsive_player(game_state, command_bus)
	_reset_timer_for_current_player()
	GlobalConsole._print(["守区攻防阶段：命令全部完成，已更新玩家响应权"])

#== Private Methods ==
## 处理出牌请求
## @side_effect
func _process_play_card_request(request: OperationRequest.PlayCard, game_state: GameState, command_bus: CommandBus) -> void:
	var card: Card = game_state.cardsmanager.get_card_by_id(request._card_id)
	var source_player: Player = game_state.player_manager.get_player_by_id(request.source_player_id)
	var target_player: Player = game_state.player_manager.get_player_by_id(request._target_id) if request._target_id >= 0 else null
	if not card or not source_player:
		GlobalConsole._print(["守区攻防阶段：卡牌或玩家实例获取失败"])
		request.cancel()
		return
	var rule_result: RuleCardPlay.RuleResult = RuleCardPlay.check_and_create_command(card, source_player, target_player, game_state)
	if not rule_result.is_valid:
		GlobalConsole._print(["守区攻防阶段：", rule_result.message])
		request.cancel()
		return
	var usage_result: RuleCardUsage.UsageResult = RuleCardUsage.can_use_card_in_defense(card, source_player, target_player, defense_area, attacker, defender, game_state)
	if not usage_result.is_valid:
		GlobalConsole._print(["守区攻防阶段：", usage_result.message])
		request.cancel()
		return
	var command: BehaviorCommand = rule_result.command
	if not command:
		GlobalConsole._print(["守区攻防阶段：规则未返回命令"])
		request.cancel()
		return
	var elapsed: float = get_elapsed_time_since_last_reset()
	command_bus.queue_behavior_with_callback(command, func() -> void:
		update_total_time_used(current_responsive_player_id, elapsed)
		GlobalConsole._print(["守区攻防阶段：出牌成功，等待所有命令完成后更新响应权"])
	)
	request.complete()
## 处理结算请求
## @side_effect
func _process_settle_request(request: OperationRequest, game_state: GameState, command_bus: CommandBus) -> void:
	var settle_cmd: SettleCommand = build_settle_command(current_responsive_player_id, defense_area, attacker)
	command_bus.queue_behavior(settle_cmd)
	_pending_stage_end = true
	request.complete()
## 更新响应权玩家
## @side_effect
func _update_responsive_player(game_state: GameState, command_bus: CommandBus) -> void:
	var top: Card = defense_area.get_top_card()
	current_responsive_player_id = calculate_responsive_player_id(attacker.get_id(), defender.get_id(), top, defender)
	command_bus.set_responsive_players(PackedInt32Array([current_responsive_player_id]))
	GlobalConsole._print(["守区攻防阶段：更新响应权为玩家", current_responsive_player_id])
## 生成并排队斗牌命令
## @side_effect
func _generate_and_queue_battle_command(game_state: GameState, command_bus: CommandBus, save_reference: bool = false) -> BattleCommand:
	var battle_command: BattleCommand = build_battle_command(defense_area)
	if not battle_command:
		return null
	command_bus.queue_behavior(battle_command)
	if save_reference:
		_current_battle_command = battle_command
	GlobalConsole._print(["守区攻防阶段：生成并排队斗牌命令"])
	return battle_command
## 取消当前斗牌命令
## @side_effect
func _cancel_current_battle_command() -> void:
	if _current_battle_command and not _current_battle_command._is_completed:
		_current_battle_command.cancel()
		_current_battle_command = null
		GlobalConsole._print(["守区攻防阶段：取消当前斗牌命令"])
## 守区区域变更回调
## @signal_listener
func _on_defense_area_changed(_card: Card, _area: Area, game_state: GameState) -> void:
	if is_ended or is_paused:
		return
	_cancel_current_battle_command()
	_need_regenerate_battle_command = true
## 重置当前玩家计时器（依据动态时间限制）
## @requester @side_effect
func _reset_timer_for_current_player() -> void:
	if current_responsive_player_id == 0:
		return
	var limit: float = DEFAULT_TIME_LIMIT
	if dynamic_time_limit.has(current_responsive_player_id):
		limit = dynamic_time_limit[current_responsive_player_id]
	request_reset_timer.emit(limit)
	last_timer_reset_time = Time.get_ticks_msec()
## 连接守区区域信号
## @signal_listener
func _connect_defense_area_signals(game_state: GameState) -> void:
	if not _defense_area_signal_binding.is_null():
		_disconnect_defense_area_signals()
	_defense_area_signal_binding = _on_defense_area_changed.bind(game_state)
	defense_area.area_card_added.connect(_defense_area_signal_binding)
	defense_area.area_card_removed.connect(_defense_area_signal_binding)
## 断开守区区域信号
## @signal_listener
func _disconnect_defense_area_signals() -> void:
	if _defense_area_signal_binding.is_null():
		return
	defense_area.area_card_added.disconnect(_defense_area_signal_binding)
	defense_area.area_card_removed.disconnect(_defense_area_signal_binding)
	_defense_area_signal_binding = Callable()
