extends NPCPeer
class_name AutoNPCPeer

var _has_attacked_in_main_this_round: bool = false

## 决策数据快照（线程安全）
class DecisionData:
	var player_id: int
	var hand_cards: Array[Dictionary]   # {id: int, type: StringName}
	var defense_area_empty: bool
	var has_attacked_in_main: bool
	var current_stage_name: StringName
	var defense_stage_owner_id: int
	var is_responsive: bool
	var other_player_ids: PackedInt32Array

func _init(game_state: GameState, player_id: int) -> void:
	super._init(game_state, player_id)
	_game_state.start_round.connect(_on_start_round)

## 异步决策接口
func request_decision_async(callback: Callable) -> void:
	var data = _get_decision_data()
	var thread = Thread.new()
	thread.start(_thread_decision.bind(data, callback))

## 在线程中运行的静态函数
static func _thread_decision(data: DecisionData, callback: Callable) -> void:
	var result = _decision_task(data)
	var completion = func(res: Dictionary):
		var request = _build_request_from_result_static(res, data.player_id)
		callback.call(request)
	completion.call_deferred(result)

## 静态构建请求（用于回调）
static func _build_request_from_result_static(result: Dictionary, player_id: int) -> OperationRequest:
	match result["type"]:
		"abandon":
			return OperationRequest.AbandonResponse.new(player_id).use_npc_peer_id()
		"play_card":
			return OperationRequest.PlayCard.new(player_id, result["card_id"], result["target_id"]).use_npc_peer_id()
		"play_card_need_target":
			# 主线程中会通过实例方法补充目标
			return null
	return OperationRequest.AbandonResponse.new(player_id).use_npc_peer_id()

## 获取决策数据快照（主线程）
func _get_decision_data() -> DecisionData:
	var data = DecisionData.new()
	data.player_id = _player_id
	data.has_attacked_in_main = _has_attacked_in_main_this_round
	data.current_stage_name = _game_state.get_current_active_stage_name()
	var self_player = _game_state.player_manager.get_player_by_id(_player_id)
	if self_player:
		var hand_area = self_player.area_hand
		if hand_area:
			for card in hand_area.get_all_cards():
				data.hand_cards.append({"id": card.id, "type": card.type})
		var defense_area = self_player.area_defensive
		data.defense_area_empty = (defense_area == null or defense_area.get_all_cards().is_empty())
	else:
		data.defense_area_empty = true
	if data.current_stage_name == &"DefenseBattle":
		var defense_stage = _get_defense_stage()
		if defense_stage:
			data.defense_stage_owner_id = defense_stage.defender.player_id
			data.is_responsive = (defense_stage.current_responsive_player_id == _player_id)
		else:
			data.is_responsive = false
	else:
		data.is_responsive = true
	var others: PackedInt32Array = []
	for p in _game_state.player_manager.players:
		if p.player_id != _player_id:
			others.append(p.player_id)
	data.other_player_ids = others
	return data

## 静态决策函数（纯计算，线程安全）
static func _decision_task(data: DecisionData) -> Dictionary:
	var result = {"type": "abandon", "card_id": -1, "target_id": -1}
	match data.current_stage_name:
		&"Discard":
			result.type = "abandon"
		&"Main":
			if data.defense_area_empty:
				var defense_cards = []
				for card in data.hand_cards:
					if card["type"] == &"defence":
						defense_cards.append(card)
				if defense_cards.size() > 2:
					defense_cards.shuffle()
					result.type = "play_card"
					result.card_id = defense_cards[0]["id"]
					result.target_id = data.player_id
					return result
			if not data.has_attacked_in_main:
				var attack_cards = []
				for card in data.hand_cards:
					if card["type"] == &"attack":
						attack_cards.append(card)
				if not attack_cards.is_empty():
					attack_cards.shuffle()
					result.type = "play_card_need_target"
					result.card_id = attack_cards[0]["id"]
					return result
			result.type = "abandon"
		&"DefenseBattle":
			if not data.is_responsive:
				result.type = "abandon"
				return result
			if data.defense_stage_owner_id == data.player_id:
				for card in data.hand_cards:
					if card["type"] == &"defence":
						result.type = "play_card"
						result.card_id = card["id"]
						result.target_id = data.player_id
						return result
			else:
				for card in data.hand_cards:
					if card["type"] == &"attack":
						result.type = "play_card"
						result.card_id = card["id"]
						result.target_id = data.defense_stage_owner_id
						return result
			result.type = "abandon"
		_:
			result.type = "abandon"
	return result

## 实例方法：根据决策结果构建请求（主线程，用于 need_target 补充）
func _build_request_from_result(result: Dictionary) -> OperationRequest:
	match result["type"]:
		"abandon":
			return OperationRequest.AbandonResponse.new(_player_id).use_npc_peer_id()
		"play_card":
			return OperationRequest.PlayCard.new(_player_id, result["card_id"], result["target_id"]).use_npc_peer_id()
		"play_card_need_target":
			var target_id = _get_random_other_player_id()
			if target_id != -1:
				return OperationRequest.PlayCard.new(_player_id, result["card_id"], target_id).use_npc_peer_id()
			else:
				return OperationRequest.AbandonResponse.new(_player_id).use_npc_peer_id()
	return OperationRequest.AbandonResponse.new(_player_id).use_npc_peer_id()

## 随机获取其他玩家ID（主线程）
func _get_random_other_player_id() -> int:
	var candidates = []
	for p in _game_state.player_manager.players:
		if p.player_id != _player_id:
			candidates.append(p.player_id)
	if candidates.is_empty():
		return -1
	candidates.shuffle()
	return candidates[0]

## 获取当前守区攻防阶段实例
func _get_defense_stage() -> StageDefense:
	if not _game_state.stage_context:
		return null
	var cur_stage = _game_state.stage_context.current_stage
	return cur_stage if cur_stage is StageDefense else null

func await_npc_ready():
	var scene_tree = Engine.get_main_loop() as SceneTree
	if scene_tree:
		await scene_tree.create_timer(1.0).timeout

func cleanup() -> void:
	pass

## 回合开始时重置攻击标记
func _on_start_round(player_id: int) -> void:
	if player_id == _player_id:
		_has_attacked_in_main_this_round = false
