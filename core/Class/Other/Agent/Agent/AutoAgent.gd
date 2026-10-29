## 自动出牌决策机：Agent 的默认实现，按当前阶段给出出牌 / 放弃决策。
## 规则：空守区先垫一张防御牌；否则对可命中的目标出攻击牌；守区攻防阶段按守方 / 攻方角色出第一张可用牌；其余放弃。
## 决策是静态纯函数族，仅 decide 作为基类契约的实现而保留实例形态；本类无实例状态。
extends Agent
class_name AutoAgent

#== Public Methods ==
## 决策入口：按当前阶段分派到主阶段 / 守区攻防 / 放弃
## @override
func decide(data: NPCDecisionData, rng_seed: int) -> Dictionary[StringName, Variant]:
	match data.current_stage_name:
		&"Discard":
			return decide_abandon()
		&"Main":
			return decide_main(data, rng_seed)
		&"DefenseBattle":
			return decide_defense_battle(data)
	return decide_abandon()

## 主阶段决策：空守区先垫一张防御牌；否则对可命中的目标出攻击牌；都不成立则放弃
## @pure
static func decide_main(data: NPCDecisionData, rng_seed: int) -> Dictionary[StringName, Variant]:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = rng_seed
	var attack_cards: Array[Dictionary] = cards_of_type(data.hand_cards, GlobalConstants.DefaultCard.ATTACK)
	if data.defense_area_empty:
		var defense_cards: Array[Dictionary] = cards_of_type(data.hand_cards, GlobalConstants.DefaultCard.DEFENCE)
		if defense_cards.size() > 1:
			var fill_index: int = rng.randi_range(0, defense_cards.size() - 1)
			var fill_card_id: int = defense_cards[fill_index][&"id"]
			return play_card_decision(fill_card_id, data.player_id)
	if data.has_attacked_in_main or attack_cards.is_empty():
		return decide_abandon()
	var targets: Array[int] = attack_targets(data)
	if targets.is_empty():
		return decide_abandon()
	# 抽取顺序与旧实现一致：先定目标、再定攻击牌
	var target_index: int = rng.randi_range(0, targets.size() - 1)
	var card_index: int = rng.randi_range(0, attack_cards.size() - 1)
	var attack_card_id: int = attack_cards[card_index][&"id"]
	return play_card_decision(attack_card_id, targets[target_index])

## 守区攻防阶段决策：持有响应权时按守方 / 攻方角色出对应的第一张牌；否则放弃
## @pure
static func decide_defense_battle(data: NPCDecisionData) -> Dictionary[StringName, Variant]:
	if not data.is_responsive:
		return decide_abandon()
	if data.defense_stage_owner_id == data.player_id:
		for card: Dictionary in data.hand_cards:
			if card[&"type"] == GlobalConstants.DefaultCard.DEFENCE:
				var defense_card_id: int = card[&"id"]
				return play_card_decision(defense_card_id, data.player_id)
		return decide_abandon()
	for card: Dictionary in data.hand_cards:
		if card[&"type"] == GlobalConstants.DefaultCard.ATTACK or card[&"type"] == &"skill":
			var attack_card_id: int = card[&"id"]
			return play_card_decision(attack_card_id, data.defense_stage_owner_id)
	return decide_abandon()

## 可命中目标：守区结算次数低于自身速度的其它玩家
## @pure
static func attack_targets(data: NPCDecisionData) -> Array[int]:
	var targets: Array[int] = []
	for pid in data.other_player_ids:
		var settle: int = data.other_players_settle_counts.get(pid, 999)
		if settle < data.self_speed:
			targets.append(pid)
	return targets

## 按类型筛选手牌快照，保持手牌原顺序
## @pure
static func cards_of_type(cards: Array[Dictionary], card_type: StringName) -> Array[Dictionary]:
	var matched: Array[Dictionary] = []
	for card: Dictionary in cards:
		if card[&"type"] == card_type:
			matched.append(card)
	return matched
