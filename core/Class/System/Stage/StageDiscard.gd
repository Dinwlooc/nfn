extends Stage
class_name StageDiscard

const TIME_LIMIT: float = 10.0   # 弃牌阶段总时间限制（秒）
var _players_to_discard: Dictionary[int, int] = {}          # player_id -> 还需弃牌的数量

# ========== 生命周期 ==========
func _init() -> void:
	super._init()
	stage_name = &"Discard"
	time_limit = TIME_LIMIT

func enter(game_state: GameState) -> void:
	super.enter(game_state)
	var responsive_players: PackedInt32Array = []
	for player in game_state.player_manager.players:
		var hand_area: AreaHand = game_state.get_hand_area(player.player_id)
		var hand_count: int = hand_area.get_all_cards().size() if hand_area else 0
		var hand_limit: int = player.get_hand_limit()
		if hand_count > hand_limit:
			var need_discard: int = hand_count - hand_limit
			_players_to_discard[player.player_id] = need_discard
			responsive_players.append(player.player_id)
			GlobalConsole._print(["玩家", player.player_id, "需要弃置", need_discard, "张牌（手牌", hand_count, "，上限", hand_limit, "）"])
	if responsive_players.is_empty():
		end_stage(game_state)
		return
	game_state.set_responsive_players(responsive_players)
	_reset_timer()
	_connect_all_commands_completed_signal(game_state)
	GlobalConsole._print(["弃牌阶段开始，响应玩家：", responsive_players])

func resume(game_state: GameState) -> void:
	super.resume(game_state)
	if _players_to_discard.is_empty():
		end_stage(game_state)
		return
	_reset_timer()
	_connect_all_commands_completed_signal(game_state)
	GlobalConsole._print(["弃牌阶段恢复，剩余需弃牌玩家：", _players_to_discard.keys()])

func pause(game_state: GameState) -> void:
	super.pause(game_state)
	_disconnect_all_commands_completed_signal(game_state)

func end_stage_effect(game_state: GameState) -> void:
	_force_discard_for_all(game_state)
	game_state.set_responsive_players(PackedInt32Array())
	_disconnect_all_commands_completed_signal(game_state)
	_players_to_discard.clear()
	GlobalConsole._print(["弃牌阶段结束"])

# ========== 操作请求处理 ==========
func process_operation_request(request: OperationRequest, game_state: GameState) -> void:
	if is_ended or is_paused:
		return
	match request.get_class_name():
		&"discard_cards":
			_process_discard_request(request as OperationRequest.DiscardCards, game_state)
		&"abandon_response":
			_process_abandon_response(request as OperationRequest.AbandonResponse, game_state)
		_:
			request.cancel()
			GlobalConsole._print(["弃牌阶段：不支持的操作类型", request.get_class_name_static()])
	if _players_to_discard.is_empty():
		end_stage(game_state)

func _process_discard_request(request: OperationRequest.DiscardCards, game_state: GameState) -> void:
	var player_id: int = request.source_player_id
	if not _players_to_discard.has(player_id):
		GlobalConsole._print(["弃牌阶段：玩家", player_id, "不在弃牌列表中"])
		request.complete()
		return
	var need_count: int = _players_to_discard[player_id]
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
	var seen: Dictionary = {}
	for id in submitted_ids:
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
	var actual_discard: PackedInt32Array
	if valid_ids.size() > need_count:
		actual_discard = valid_ids.slice(valid_ids.size() - need_count, valid_ids.size())
	else:
		actual_discard = valid_ids
	var discard_command := DiscardCardsCommand.new(player_id, actual_discard)
	game_state.queue_behavior(discard_command)
	var new_need: int = need_count - actual_discard.size()
	if new_need == 0:
		_players_to_discard.erase(player_id)
		GlobalConsole._print(["弃牌阶段：玩家", player_id, "弃牌完成"])
		request.complete()
	else:
		_players_to_discard[player_id] = new_need
		GlobalConsole._print(["弃牌阶段：玩家", player_id, "还需弃置", new_need, "张牌"])
		request.cancel()

func _process_abandon_response(request: OperationRequest.AbandonResponse, game_state: GameState) -> void:
	var player_id: int = request.source_player_id
	if not _players_to_discard.has(player_id):
		GlobalConsole._print(["弃牌阶段：玩家", player_id, "不在弃牌列表中，忽略放弃响应"])
		request.complete()
		return
	var need_count: int = _players_to_discard[player_id]
	var hand_area: AreaHand = game_state.get_hand_area(player_id)
	var hand_card_ids: PackedInt32Array = hand_area.get_card_ids()
	if hand_card_ids.size() < need_count:
		GlobalConsole._print(["弃牌阶段：玩家", player_id, "手牌不足", need_count, "张，将弃置所有手牌"])
		need_count = hand_card_ids.size()
	var selected: PackedInt32Array = _random_select(hand_area, need_count)
	var discard_command := DiscardCardsCommand.new(player_id, selected)
	game_state.queue_behavior(discard_command)
	_players_to_discard.erase(player_id)
	GlobalConsole._print(["弃牌阶段：玩家", player_id, "放弃响应，随机弃牌完成"])
	request.complete()

# ========== 超时处理 ==========
func timeout(game_state: GameState) -> void:
	if is_ended or is_paused:
		return
	_force_discard_for_all(game_state)
	end_stage(game_state)

# ========== 辅助函数 ==========
## 强制所有未完成弃牌的玩家随机选择所需卡牌并执行弃牌命令
func _force_discard_for_all(game_state: GameState) -> void:
	if _players_to_discard.is_empty():
		return
	for player_id in _players_to_discard.keys():
		var need_count: int = _players_to_discard[player_id]
		var hand_area: AreaHand = game_state.get_hand_area(player_id)
		if hand_area.is_empty():
			_players_to_discard.erase(player_id)
			continue
		var selected: PackedInt32Array = _random_select(hand_area, need_count)
		var discard_command := DiscardCardsCommand.new(player_id, selected)
		game_state.queue_behavior(discard_command)
		GlobalConsole._print(["弃牌阶段：玩家", player_id, "超时，随机弃牌完成"])
	_players_to_discard.clear()

## 从手牌区随机选择 count 张卡牌（不重复），利用 UnorderedArea 的随机能力
func _random_select(hand_area: AreaHand, count: int) -> PackedInt32Array:
	if count <= 0 or hand_area.is_empty():
		return PackedInt32Array()
	var temp_area := UnorderedArea.new()
	var cards: Array[Card] = hand_area.get_all_cards()
	temp_area.cards_add(cards)
	var selected_cards: Array[Card] = temp_area.get_top_cards(count)
	var result: PackedInt32Array = []
	for card in selected_cards:
		result.append(card.id)
	return result

## 重置计时器（固定时长）
func _reset_timer() -> void:
	request_reset_timer.emit(TIME_LIMIT)

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
