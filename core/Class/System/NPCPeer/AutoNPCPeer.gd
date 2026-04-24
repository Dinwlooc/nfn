extends NPCPeer
class_name AutoNPCPeer

var _has_attacked_in_main_this_round: bool = false
var _current_thread: Thread = null

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
	# 主阶段决策所需额外数据
	var self_speed: int                      # 自身速度
	var other_players_settle_counts: Dictionary[int, int]  # 其他玩家守区已结算次数

func _init(game_state: GameState, player_id: int) -> void:
	super._init(game_state, player_id)
	_game_state.start_round.connect(_on_start_round)

## 异步决策接口
func request_decision_async(callback: Callable) -> void:
	if _current_thread and _current_thread.is_started():
		_current_thread.wait_to_finish()
		_current_thread = null
	var data: DecisionData = _get_decision_data()
	var handle_result: Callable = func(result: Dictionary):
		var request: OperationRequest = _build_request_from_result(result)
		callback.call(request)
		if _current_thread:
			_current_thread.wait_to_finish()
			_current_thread = null
	_current_thread = Thread.new()
	_current_thread.start(_thread_decision.bind(data, handle_result))

## 在线程中运行的静态函数
static func _thread_decision(data: DecisionData, handle_result: Callable) -> void:
	var result: Dictionary = _decision_task(data)
	handle_result.call_deferred(result)

## 获取决策数据快照（主线程）
func _get_decision_data() -> DecisionData:
	var data: DecisionData = DecisionData.new()
	data.player_id = _player_id
	data.has_attacked_in_main = _has_attacked_in_main_this_round
	data.current_stage_name = _game_state.get_current_active_stage_name()
	var self_player: Player = _game_state.player_manager.get_player_by_id(_player_id)
	if self_player:
		var hand_area: AreaHand = _game_state.get_hand_area(_player_id)
		if hand_area:
			for card in hand_area.get_all_cards():
				data.hand_cards.append({&"id": card.id, &"type": card.type})
		var defense_area: AreaDefence = _game_state.get_defense_area(_player_id)
		data.defense_area_empty = (defense_area == null or defense_area.is_empty())
		data.self_speed = self_player.get_attribute(&"speed")
	else:
		data.defense_area_empty = true
		data.self_speed = 0
	if data.current_stage_name == &"DefenseBattle":
		var defense_stage: StageDefense = _get_defense_stage()
		if defense_stage:
			data.defense_stage_owner_id = defense_stage.defender.player_id
			data.is_responsive = (defense_stage.current_responsive_player_id == _player_id)
		else:
			data.is_responsive = false
	else:
		data.is_responsive = true
	# 收集其他玩家ID及守区结算次数
	var others: PackedInt32Array = PackedInt32Array()
	data.other_players_settle_counts.clear()
	for p in _game_state.player_manager.players:
		if p.player_id != _player_id:
			others.append(p.player_id)
			var settle_count: int = 0
			var def_area: AreaDefence = _game_state.get_defense_area(p.player_id)
			if def_area:
				settle_count = def_area.settle_count
			data.other_players_settle_counts[p.player_id] = settle_count
	data.other_player_ids = others
	return data

## 静态决策函数（纯计算，线程安全）
static func _decision_task(data: DecisionData) -> Dictionary:
	var result: Dictionary = {&"type": &"abandon", &"card_id": -1, &"target_id": -1}
	match data.current_stage_name:
		&"Discard":
			result[&"type"] = &"abandon"
		&"Main":
			# 收集可用的攻击牌和防御牌
			var attack_cards: Array[Dictionary] = []
			var defense_cards: Array[Dictionary] = []
			for card in data.hand_cards:
				match card[&"type"]:
					&"attack":
						attack_cards.append(card)
					&"defence":
						defense_cards.append(card)
					_:
						pass
			# 优先考虑防御牌（如果守区为空且手牌中防御牌数量>2）
			if data.defense_area_empty and defense_cards.size() > 2:
				defense_cards.shuffle()
				result[&"type"] = &"play_card"
				result[&"card_id"] = defense_cards[0][&"id"]
				result[&"target_id"] = data.player_id
				return result
			# 如果没有攻击过，且存在攻击牌，选择合适目标
			if not data.has_attacked_in_main and not attack_cards.is_empty():
				# 筛选可攻击的目标（守区结算次数 < 自身速度）
				var valid_targets: Array[int]
				for pid in data.other_player_ids:
					var settle: int = data.other_players_settle_counts.get(pid, 999)
					if settle < data.self_speed:
						valid_targets.append(pid)
				if not valid_targets.is_empty():
					valid_targets.shuffle()
					var target_id: int = valid_targets[0]
					attack_cards.shuffle()
					result[&"type"] = &"play_card"
					result[&"card_id"] = attack_cards[0][&"id"]
					result[&"target_id"] = target_id
					return result
			# 否则放弃
			result[&"type"] = &"abandon"
		&"DefenseBattle":
			# 守区攻防阶段：有响应权时才能出牌
			if not data.is_responsive:
				result[&"type"] = &"abandon"
				return result
			if data.defense_stage_owner_id == data.player_id:
				# 守方只能出防御牌
				for card in data.hand_cards:
					if card[&"type"] == &"defence":
						result[&"type"] = &"play_card"
						result[&"card_id"] = card[&"id"]
						result[&"target_id"] = data.player_id
						return result
			else:
				# 攻方可出攻击或技能
				for card in data.hand_cards:
					if card[&"type"] == &"attack" or card[&"type"] == &"skill":
						result[&"type"] = &"play_card"
						result[&"card_id"] = card[&"id"]
						result[&"target_id"] = data.defense_stage_owner_id
						return result
			result[&"type"] = &"abandon"
		_:
			result[&"type"] = &"abandon"
	return result

## 实例方法：根据决策结果构建请求（主线程，可访问游戏状态）
func _build_request_from_result(result: Dictionary) -> OperationRequest:
	match result[&"type"]:
		&"abandon":
			return OperationRequest.AbandonResponse.new(_player_id).use_npc_peer_id()
		&"play_card":
			return OperationRequest.PlayCard.new(_player_id, result[&"card_id"], result[&"target_id"]).use_npc_peer_id()
	return OperationRequest.AbandonResponse.new(_player_id).use_npc_peer_id()

## 随机获取其他玩家ID（主线程）
func _get_random_other_player_id() -> int:
	var candidates: Array[int]
	for p in _game_state.player_manager.players:
		if p.player_id != _player_id:
			candidates.append(p.player_id)
	if candidates.is_empty():
		return -1
	candidates.shuffle()
	return candidates[0]

## 获取当前守区攻防阶段实例
func _get_defense_stage() -> StageDefense:
	if not _game_state.stage_manager:
		return null
	var cur_stage: Stage = _game_state.stage_manager.current_stage
	return cur_stage as StageDefense if cur_stage is StageDefense else null

func await_npc_ready() -> void:
	var scene_tree: SceneTree = Engine.get_main_loop() as SceneTree
	if scene_tree:
		await scene_tree.create_timer(1.0).timeout

## 清理资源，确保线程正确结束
func cleanup() -> void:
	if _current_thread and _current_thread.is_started():
		_current_thread.wait_to_finish()
		_current_thread = null

## 回合开始时重置攻击标记
func _on_start_round(player_id: int) -> void:
	if player_id == _player_id:
		_has_attacked_in_main_this_round = false
