## 决策机基类：以纯数据快照为唯一输入、以操作请求为唯一输出。
## 异步壳与「决策字典 → 操作请求」的装配在此固定；具体决策由子类实现 [method decide]（默认实现见 [AutoAgent]）。
## 随机性只经 rng_seed 进入，工作线程不推进全局随机源，故决策可复现、线程安全；本类无实例状态。
@abstract
extends RefCounted
class_name Agent

#== Constants ==
## 未注入种子：提交时从全局随机源取一次
const RNG_SEED_FROM_GLOBAL: int = -1

#== Public Methods ==
## 决策入口：同一快照与同一种子必得同一决策字典；子类必须实现
@abstract func decide(data: NPCDecisionData, rng_seed: int) -> Dictionary[StringName, Variant]

## 放弃决策
## @pure
static func decide_abandon() -> Dictionary[StringName, Variant]:
	return {&"type": &"abandon", &"card_id": 0, &"target_id": 0}

## 出牌决策：以指定卡牌对指定目标出牌
## @pure
static func play_card_decision(card_id: int, target_id: int) -> Dictionary[StringName, Variant]:
	return {&"type": &"play_card", &"card_id": card_id, &"target_id": target_id}

## 根据决策结果字典构造操作请求（主线程调用）；NPC 快照标记为 NPC 来源通道
## @factory
static func build_request_from_result(data: NPCDecisionData, result: Dictionary[StringName, Variant]) -> OperationRequest:
	var request: OperationRequest = null
	match result[&"type"]:
		&"abandon":
			request = OperationRequest.AbandonResponse.new(data.player_id)
		&"play_card":
			request = ItemsOperation.play_card(data.player_id, result[&"card_id"], result[&"target_id"])
		_:
			request = OperationRequest.AbandonResponse.new(data.player_id)
	if data.is_npc:
		request.use_npc_peer_id()
	return request

## 异步决策入口：种子在提交线程解析后随任务下传，回调在本线程收到操作请求
## 工作线程入口 _thread_decision 由引擎线程池调用，不属本方法的内部调用（同 @atomic 的引擎 API 豁免）
## @external @seam
func request_decision_async(data: NPCDecisionData, callback: Callable,
		rng_seed_overriding: int = RNG_SEED_FROM_GLOBAL) -> void:
	var rng_seed: int = rng_seed_overriding
	# 哨兵值表示未注入：在提交线程取一次全局随机数，工作线程不再触碰全局源
	if rng_seed == RNG_SEED_FROM_GLOBAL:
		rng_seed = randi()
	var handle_result: Callable = func(result: Dictionary[StringName, Variant]) -> void:
		callback.call(build_request_from_result(data, result))
	WorkerThreadPool.add_task(_thread_decision.bind(self, data, rng_seed, handle_result))

#== Private Methods ==
## 静态线程函数：在子类决策机上执行决策，完成后把结果推回主线程
## @delegates
static func _thread_decision(machine: Agent, data: NPCDecisionData, rng_seed: int, handle_result: Callable) -> void:
	var result: Dictionary[StringName, Variant] = machine.decide(data, rng_seed)
	handle_result.call_deferred(result)
