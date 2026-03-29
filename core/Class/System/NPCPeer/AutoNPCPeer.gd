extends NPCPeer
class_name AutoNPCPeer

var _has_attacked_in_main_this_round: bool = false

## 初始化：连接回合开始信号
func _init(game_state: GameState, player_id: int) -> void:
	super._init(game_state, player_id)
	_game_state.start_round.connect(_on_start_round)

## 返回操作请求：根据当前阶段分别处理
func get_operation_request() -> OperationRequest:
	var stage_name: StringName = _game_state.get_current_active_stage_name()
	if stage_name == &"Discard":
		return OperationRequest.AbandonResponse.new(_player_id).use_npc_peer_id()
	if stage_name == &"Main":
		return _handle_main_stage()
	if stage_name == &"DefenseBattle":
		return _handle_defense_battle()
	return OperationRequest.AbandonResponse.new(_player_id).use_npc_peer_id()

## 清理资源
func cleanup() -> void:
	pass

func await_npc_ready():
	var scene_tree: SceneTree = Engine.get_main_loop() as SceneTree
	if not scene_tree:
		return
	await scene_tree.create_timer(1.0).timeout

# ========== 阶段处理函数 ==========
## 处理主阶段：优先使用防御牌（条件满足时），否则最多攻击一次
func _handle_main_stage() -> OperationRequest:
	if _should_play_defense_to_self():
		var defense_card: Card = _get_random_defense_card()
		if defense_card != null:
			return OperationRequest.PlayCard.new(_player_id, defense_card.id, _player_id).use_npc_peer_id()
	if _has_attacked_in_main_this_round:
		return OperationRequest.AbandonResponse.new(_player_id).use_npc_peer_id()
	var attack_card: Card = _get_random_attack_card()
	if attack_card != null:
		var target_id: int = _get_random_other_player_id()
		if target_id != -1:
			_has_attacked_in_main_this_round = true
			return OperationRequest.PlayCard.new(_player_id, attack_card.id, target_id).use_npc_peer_id()
	return OperationRequest.AbandonResponse.new(_player_id).use_npc_peer_id()

## 处理守区攻防阶段：若守区为自己则出防御牌，否则作为攻击方出攻击牌
func _handle_defense_battle() -> OperationRequest:
	var defense_stage: StageDefense = _get_defense_stage()
	if defense_stage == null:
		return OperationRequest.AbandonResponse.new(_player_id).use_npc_peer_id()
	if defense_stage.current_responsive_player_id != _player_id:
		return OperationRequest.AbandonResponse.new(_player_id).use_npc_peer_id()
	var self_player: Player = _game_state.player_manager.get_player_by_id(_player_id)
	if self_player == null:
		return OperationRequest.AbandonResponse.new(_player_id).use_npc_peer_id()
	var defense_owner_id: int = defense_stage.defender.player_id
	if defense_owner_id == _player_id:
		var defense_card: Card = _find_defense_card(self_player)
		if defense_card != null:
			return OperationRequest.PlayCard.new(_player_id, defense_card.id, _player_id).use_npc_peer_id()
	else:
		var attack_card: Card = _get_random_attack_card()
		if attack_card != null:
			return OperationRequest.PlayCard.new(_player_id, attack_card.id, defense_owner_id).use_npc_peer_id()
	return OperationRequest.AbandonResponse.new(_player_id).use_npc_peer_id()

# ========== 条件判断与辅助函数 ==========
## 判断是否应该对自己使用防御牌（守区为空且手牌防御牌数量 > 2）
func _should_play_defense_to_self() -> bool:
	var self_player: Player = _game_state.player_manager.get_player_by_id(_player_id)
	if self_player == null:
		return false
	var defense_area: AreaDefence = self_player.area_defensive
	if defense_area == null or defense_area.get_all_cards().size() > 0:
		return false
	var hand_area: AreaHand = self_player.area_hand
	if hand_area == null:
		return false
	var defense_count: int = 0
	for card in hand_area.get_all_cards():
		if card.type == &"defence":
			defense_count += 1
	return defense_count > 2

## 从手牌中随机获取一张防御牌
func _get_random_defense_card() -> Card:
	var self_player: Player = _game_state.player_manager.get_player_by_id(_player_id)
	if self_player == null:
		return null
	var hand_area: AreaHand = self_player.area_hand
	if hand_area == null:
		return null
	var defense_cards: Array[Card] = []
	for card in hand_area.get_all_cards():
		if card.type == &"defence":
			defense_cards.append(card)
	if defense_cards.is_empty():
		return null
	defense_cards.shuffle()
	return defense_cards[0]

## 从手牌中随机获取一张攻击牌
func _get_random_attack_card() -> Card:
	var self_player: Player = _game_state.player_manager.get_player_by_id(_player_id)
	if self_player == null:
		return null
	var hand_area: AreaHand = self_player.area_hand
	if hand_area == null:
		return null
	var attack_cards: Array[Card] = []
	for card in hand_area.get_all_cards():
		if card.type == &"attack":
			attack_cards.append(card)
	if attack_cards.is_empty():
		return null
	attack_cards.shuffle()
	return attack_cards[0]

## 随机获取一个其他玩家的ID（排除自己）
func _get_random_other_player_id() -> int:
	var all_players: Array[Player] = _game_state.player_manager.players
	if all_players.size() < 2:
		return -1
	var candidates: Array[int] = []
	for p in all_players:
		if p.player_id != _player_id:
			candidates.append(p.player_id)
	if candidates.is_empty():
		return -1
	candidates.shuffle()
	return candidates[0]

## 获取当前守区攻防阶段实例（若存在）
func _get_defense_stage() -> StageDefense:
	if not _game_state.stage_context:
		return null
	var cur_stage: Stage = _game_state.stage_context.current_stage
	if cur_stage is StageDefense:
		return cur_stage as StageDefense
	return null

## 从玩家手牌中寻找一张防御牌
func _find_defense_card(player: Player) -> Card:
	var hand_area: AreaHand = player.area_hand
	if hand_area == null:
		return null
	for card in hand_area.get_all_cards():
		if card.type == &"defence":
			return card
	return null

# ========== 回合记忆重置 ==========
## 当自己的回合开始时，重置攻击记录
func _on_start_round(player_id: int) -> void:
	if player_id == _player_id:
		_has_attacked_in_main_this_round = false
