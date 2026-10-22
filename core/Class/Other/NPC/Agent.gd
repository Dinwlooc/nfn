## Agent：以纯数据快照为唯一输入、以操作请求为唯一输出的决策代理。
## 快照取数在系统层与渲染层各自的 NPC 管理器桥接中完成，Agent 不接触游戏状态与渲染上下文。
extends RefCounted
class_name Agent

## 最新决策请求的 ID，用于在回调中丢弃过期结果
var _latest_request_id: int = 0

## 异步决策入口：立即提交新任务，旧任务的结果将被丢弃
## @side_effect
func request_decision_async(data: NPCDecisionData, callback: Callable) -> void:
	_latest_request_id += 1
	var request_id := _latest_request_id
	# 捕获 request_id 到闭包中，用于过期检测
	var handle_result: Callable = func(result: Dictionary):
		if request_id != _latest_request_id:
			return
		var request: OperationRequest = _build_request_from_result(data, result)
		callback.call(request)
	WorkerThreadPool.add_task(_thread_decision.bind(data, handle_result))

## 静态线程函数：执行决策计算，完成后将结果推回主线程
## @delegates
static func _thread_decision(data: NPCDecisionData, handle_result: Callable) -> void:
	var result: Dictionary = decide(data)
	handle_result.call_deferred(result)

## 核心决策树（纯函数，线程安全），返回决策字典
## @pure
static func decide(data: NPCDecisionData) -> Dictionary:
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
			if data.defense_area_empty and defense_cards.size() > 1:
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

## 根据决策结果字典构造操作请求（主线程调用）；NPC 快照标记为 NPC 来源通道
## @factory
static func _build_request_from_result(data: NPCDecisionData, result: Dictionary) -> OperationRequest:
	var request: OperationRequest = null
	match result[&"type"]:
		&"abandon":
			request = OperationRequest.AbandonResponse.new(data.player_id)
		&"play_card":
			request = OperationRequest.PlayCard.new(data.player_id, result[&"card_id"], result[&"target_id"])
		_:
			request = OperationRequest.AbandonResponse.new(data.player_id)
	if data.is_npc:
		request.use_npc_peer_id()
	return request
