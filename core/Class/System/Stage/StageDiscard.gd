## 弃牌阶段：手牌超过上限的玩家弃置卡牌。
extends Stage
class_name StageDiscard

#== Constants ==
## 弃牌阶段时限（秒）
const TIME_LIMIT: float = 10.0

#== Properties ==
## 待弃牌玩家表：玩家 id → 还需弃置的张数
var _players_to_discard: Dictionary[int, int] = {}

#== Constructor ==
## 构造：设定阶段名与时限
func _init() -> void:
	super._init()
	stage_name = &"Discard"
	time_limit = TIME_LIMIT

#== 响应能力 ==
## 判断手牌数是否超过上限
## @pure
static func is_discard_required(hand_count: int, hand_limit: int) -> bool:
	return hand_count > hand_limit
## 计算需要弃置的卡牌数量
## @pure
static func calculate_need_discard(hand_count: int, hand_limit: int) -> int:
	return hand_count - hand_limit
## 根据玩家属性构造需弃牌字典
## @pure
static func build_players_to_discard(game_state: GameState) -> Dictionary[int, int]:
	var players_to_discard: Dictionary[int, int] = {}
	for player: Player in game_state.player_manager.players:
		var hand_area: AreaHand = game_state.get_hand_area(player.get_id())
		var hand_count: int = hand_area.get_all_cards().size() if hand_area else 0
		var hand_limit: int = player.get_hand_limit()
		if not is_discard_required(hand_count, hand_limit):
			continue
		players_to_discard[player.get_id()] = calculate_need_discard(hand_count, hand_limit)
	return players_to_discard
## 从字典内计算指定玩家剩余的弃牌需求（返回 0 表示无需弃牌）
## @pure
func calculate_remaining_need_for_player(player_id: int) -> int:
	return _players_to_discard.get(player_id, 0)
## 根据新的弃牌输入更新字典
## @atomic
func update_players_to_discard(player_id: int, new_need: int) -> void:
	if new_need <= 0:
		_players_to_discard.erase(player_id)
		return
	_players_to_discard[player_id] = new_need
## 从无序手牌区域中选择指定数量的卡牌 ID（区域无序，等效随机）
## @atomic @pure
static func select_random_card_ids(hand_area: AreaHand, count: int) -> PackedInt32Array:
	if count <= 0 or hand_area.is_empty():
		return PackedInt32Array()
	var selected_cards: Array[Card] = hand_area.get_top_cards(count)
	var result: PackedInt32Array = []
	for card: Card in selected_cards:
		result.append(card.id)
	return result
## 从有效候选中解析实际弃置的卡牌 ID（后选覆盖前选）
## @pure
static func resolve_actual_discard(valid_ids: PackedInt32Array, need_count: int) -> PackedInt32Array:
	if valid_ids.size() > need_count:
		return valid_ids.slice(valid_ids.size() - need_count, valid_ids.size())
	return valid_ids

#== 命令能力 ==
## 创建弃牌命令
## @factory
static func build_discard_command(player: Player, card_ids: PackedInt32Array) -> DiscardCardsCommand:
	return DiscardCardsCommand.new(player, card_ids)

#== Public Methods ==
## 进入阶段
## @override @hook @no_escape @side_effect
func enter(game_state: GameState, command_bus: CommandBus) -> void:
	super.enter(game_state, command_bus)
	_players_to_discard = build_players_to_discard(game_state)
	var responsive_players: PackedInt32Array = []
	for player_id: int in _players_to_discard.keys():
		responsive_players.append(player_id)
		GlobalConsole._print(["玩家", player_id, "需要弃置", _players_to_discard[player_id], "张牌"])
	if responsive_players.is_empty():
		request_end_stage(command_bus)
		return
	command_bus.set_responsive_players(responsive_players)
	_reset_timer()
	GlobalConsole._print(["弃牌阶段开始，响应玩家：", responsive_players])
## 恢复阶段
## @override @hook @no_escape @side_effect
func resume(game_state: GameState, command_bus: CommandBus) -> void:
	super.resume(game_state, command_bus)
	if _players_to_discard.is_empty():
		request_end_stage(command_bus)
		return
	_reset_timer()
	GlobalConsole._print(["弃牌阶段恢复，剩余需弃牌玩家：", _players_to_discard.keys()])
## 阶段结束时的清理效果
## @override @hook @no_escape
func end_stage_effect(game_state: GameState, command_bus: CommandBus) -> void:
	_force_discard_for_all(game_state, command_bus)
	command_bus.set_responsive_players(PackedInt32Array())
	_players_to_discard.clear()
	GlobalConsole._print(["弃牌阶段结束"])
## 处理玩家操作请求
## @override @hook @no_escape @side_effect
func process_operation_request(request: OperationRequest, game_state: GameState, command_bus: CommandBus) -> void:
	if is_ended or is_paused:
		return
	match request.get_class_name():
		&"discard_cards":
			_process_discard_request(request as OperationRequest.DiscardCards, game_state, command_bus)
		&"abandon_response":
			_process_abandon_response(request as OperationRequest.AbandonResponse, game_state, command_bus)
		_:
			request.cancel()
			GlobalConsole._print(["弃牌阶段：不支持的操作类型", request.get_class_name_static()])
	if _players_to_discard.is_empty():
		request_end_stage(command_bus)
## 超时处理
## @override @hook @facade @side_effect
func timeout(game_state: GameState, command_bus: CommandBus) -> void:
	if is_ended or is_paused:
		return
	_force_discard_for_all(game_state, command_bus)
	request_end_stage(command_bus)

#== Private Methods ==
## 处理弃牌请求
## @side_effect
func _process_discard_request(request: OperationRequest.DiscardCards, game_state: GameState, command_bus: CommandBus) -> void:
	var player_id: int = request.source_player_id
	var need_count: int = calculate_remaining_need_for_player(player_id)
	if need_count <= 0:
		GlobalConsole._print(["弃牌阶段：玩家", player_id, "不在弃牌列表中"])
		request.complete()
		return
	var hand_area: AreaHand = game_state.get_hand_area(player_id)
	if not hand_area:
		GlobalConsole._print(["弃牌阶段：无法获取玩家", player_id, "的手牌区"])
		request.cancel()
		return
	var submitted_ids: PackedInt32Array = request._card_ids
	if submitted_ids.is_empty():
		GlobalConsole._print(["弃牌阶段：玩家", player_id, "提交空弃牌列表"])
		request.cancel()
		return
	var valid_ids: PackedInt32Array = []
	var seen: Dictionary[int, bool] = {}
	for id: int in submitted_ids:
		if not hand_area.get_card_by_id(id):
			GlobalConsole._print(["弃牌阶段：卡牌", id, "不在玩家", player_id, "手牌中，已忽略"])
			continue
		if seen.has(id):
			continue
		seen[id] = true
		valid_ids.append(id)
	if valid_ids.is_empty():
		GlobalConsole._print(["弃牌阶段：玩家", player_id, "提交的卡牌均无效"])
		request.cancel()
		return
	var actual_discard: PackedInt32Array = resolve_actual_discard(valid_ids, need_count)
	var player: Player = game_state.player_manager.get_player_by_id(player_id)
	if not player:
		GlobalConsole._print(["弃牌阶段：无法获取玩家", player_id, "实例"])
		request.cancel()
		return
	var discard_command: DiscardCardsCommand = build_discard_command(player, actual_discard)
	command_bus.queue_behavior(discard_command)
	var new_need: int = need_count - actual_discard.size()
	update_players_to_discard(player_id, new_need)
	if new_need <= 0:
		GlobalConsole._print(["弃牌阶段：玩家", player_id, "弃牌完成"])
		request.complete()
		return
	GlobalConsole._print(["弃牌阶段：玩家", player_id, "还需弃置", new_need, "张牌"])
	request.cancel()
## 处理放弃响应请求
## @side_effect
func _process_abandon_response(request: OperationRequest.AbandonResponse, game_state: GameState, command_bus: CommandBus) -> void:
	var player_id: int = request.source_player_id
	var need_count: int = calculate_remaining_need_for_player(player_id)
	if need_count <= 0:
		GlobalConsole._print(["弃牌阶段：玩家", player_id, "不在弃牌列表中，忽略放弃响应"])
		request.complete()
		return
	var hand_area: AreaHand = game_state.get_hand_area(player_id)
	if not hand_area:
		GlobalConsole._print(["弃牌阶段：无法获取玩家", player_id, "的手牌区"])
		request.cancel()
		return
	var hand_card_ids: PackedInt32Array = hand_area.get_card_ids()
	if hand_card_ids.size() < need_count:
		GlobalConsole._print(["弃牌阶段：玩家", player_id, "手牌不足", need_count, "张，将弃置所有手牌"])
		need_count = hand_card_ids.size()
	var selected: PackedInt32Array = select_random_card_ids(hand_area, need_count)
	var player: Player = game_state.player_manager.get_player_by_id(player_id)
	if not player:
		GlobalConsole._print(["弃牌阶段：无法获取玩家", player_id, "实例"])
		request.cancel()
		return
	var discard_command: DiscardCardsCommand = build_discard_command(player, selected)
	command_bus.queue_behavior(discard_command)
	update_players_to_discard(player_id, 0)
	GlobalConsole._print(["弃牌阶段：玩家", player_id, "放弃响应，随机弃牌完成"])
	request.complete()
## 请求重置计时器
## @requester
func _reset_timer() -> void:
	request_reset_timer.emit(TIME_LIMIT)
## 强制所有仍需弃牌的玩家随机弃牌
## @side_effect
func _force_discard_for_all(game_state: GameState, command_bus: CommandBus) -> void:
	if _players_to_discard.is_empty():
		return
	for player_id: int in _players_to_discard.keys():
		var need_count: int = _players_to_discard[player_id]
		var hand_area: AreaHand = game_state.get_hand_area(player_id)
		if not hand_area:
			GlobalConsole._print(["弃牌阶段：无法获取玩家", player_id, "的手牌区，跳过强制弃牌"])
			continue
		if hand_area.is_empty():
			continue
		var selected: PackedInt32Array = select_random_card_ids(hand_area, need_count)
		var player: Player = game_state.player_manager.get_player_by_id(player_id)
		if not player:
			GlobalConsole._print(["弃牌阶段：无法获取玩家", player_id, "实例，跳过"])
			continue
		var discard_command: DiscardCardsCommand = build_discard_command(player, selected)
		command_bus.queue_behavior(discard_command)
		GlobalConsole._print(["弃牌阶段：玩家", player_id, "超时，随机弃牌完成"])
	_players_to_discard.clear()
