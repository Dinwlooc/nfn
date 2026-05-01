extends NPCPeer
class_name AutoNPCPeer

## 决策数据快照（纯数据值对象，线程安全）
class DecisionData:
	var player_id: int
	var hand_cards: Array[Dictionary]   # {id: int, type: StringName}
	var defense_area_empty: bool
	var has_attacked_in_main: bool
	var current_stage_name: StringName
	var defense_stage_owner_id: int
	var is_responsive: bool
	var other_player_ids: PackedInt32Array
	var self_speed: int
	var other_players_settle_counts: Dictionary[int, int]

## 本回合主阶段是否已出手攻击
var _has_attacked_in_main_this_round: bool = false
## 最新决策请求的 ID，用于在回调中丢弃过期结果
var _latest_request_id: int = 0

func _init(game_state: GameState, player_id: int) -> void:
	super._init(game_state, player_id)
	_game_state.start_round.connect(_on_start_round)

## 异步决策入口：立即提交新任务，旧任务的结果将被丢弃
func request_decision_async(callback: Callable) -> void:
	_latest_request_id += 1
	var request_id := _latest_request_id
	var data: DecisionData = _get_decision_data()
	# 捕获 request_id 到闭包中，用于过期检测
	var handle_result: Callable = func(result: Dictionary):
		if request_id != _latest_request_id:
			return
		var request: OperationRequest = _build_request_from_result(result)
		callback.call(request)
	WorkerThreadPool.add_task(_thread_decision.bind(data, handle_result))

## 获取当前游戏状态的纯数据快照（主线程调用）
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

## 静态线程函数：执行决策计算，完成后将结果推回主线程
static func _thread_decision(data: DecisionData, handle_result: Callable) -> void:
	var result: Dictionary = _decision_task(data)
	handle_result.call_deferred(result)

## 核心决策树（纯函数，线程安全），返回决策字典
static func _decision_task(data: DecisionData) -> Dictionary:
	var result: Dictionary = {&"type": &"abandon", &"card_id": 0, &"target_id": 0}
	match data.current_stage_name:
		&"Discard":
			result[&"type"] = &"abandon"
		&"Main":
			var attack_cards: Array[Dictionary] = []
			var defense_cards: Array[Dictionary] = []
			for card in data.hand_cards:
				match card[&"type"]:
					GlobalConstants.DefaultCard.ATTACK:
						attack_cards.append(card)
					GlobalConstants.DefaultCard.DEFENCE:
						defense_cards.append(card)
					_:
						pass
			if data.defense_area_empty and defense_cards.size() > 2:
				defense_cards.shuffle()
				result[&"type"] = &"play_card"
				result[&"card_id"] = defense_cards[0][&"id"]
				result[&"target_id"] = data.player_id
				return result
			if not data.has_attacked_in_main and not attack_cards.is_empty():
				var valid_targets: Array[int] = []
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
			result[&"type"] = &"abandon"
		&"DefenseBattle":
			if not data.is_responsive:
				result[&"type"] = &"abandon"
				return result
			if data.defense_stage_owner_id == data.player_id:
				for card in data.hand_cards:
					if card[&"type"] == GlobalConstants.DefaultCard.DEFENCE:
						result[&"type"] = &"play_card"
						result[&"card_id"] = card[&"id"]
						result[&"target_id"] = data.player_id
						return result
			else:
				for card in data.hand_cards:
					if card[&"type"] == GlobalConstants.DefaultCard.ATTACK or card[&"type"] == &"skill":
						result[&"type"] = &"play_card"
						result[&"card_id"] = card[&"id"]
						result[&"target_id"] = data.defense_stage_owner_id
						return result
			result[&"type"] = &"abandon"
		_:
			result[&"type"] = &"abandon"
	return result

## 根据决策结果字典生成对应的 OperationRequest（主线程调用）
func _build_request_from_result(result: Dictionary) -> OperationRequest:
	match result[&"type"]:
		&"abandon":
			return OperationRequest.AbandonResponse.new(_player_id).use_npc_peer_id()
		&"play_card":
			return OperationRequest.PlayCard.new(_player_id, result[&"card_id"], result[&"target_id"]).use_npc_peer_id()
	return OperationRequest.AbandonResponse.new(_player_id).use_npc_peer_id()

## 随机获取另一位玩家 ID（主线程调用）
func _get_random_other_player_id() -> int:
	var candidates: Array[int] = []
	for p in _game_state.player_manager.players:
		if p.player_id != _player_id:
			candidates.append(p.player_id)
	if candidates.is_empty():
		return 0
	candidates.shuffle()
	return candidates[0]

## 获取当前守区攻防阶段实例
func _get_defense_stage() -> StageDefense:
	if not _game_state.stage_manager:
		return null
	var cur_stage: Stage = _game_state.stage_manager.current_stage
	return cur_stage as StageDefense if cur_stage is StageDefense else null

## 等待 NPC 就绪（简单延时）
func await_npc_ready() -> void:
	var scene_tree: SceneTree = Engine.get_main_loop() as SceneTree
	if scene_tree:
		await scene_tree.create_timer(1.0).timeout

## 清理资源：由于任务已通过 ID 丢弃，无需等待线程结束
func cleanup() -> void:
	pass

## 新回合重置攻击标记
func _on_start_round(player_id: int) -> void:
	if player_id == _player_id:
		_has_attacked_in_main_this_round = false
