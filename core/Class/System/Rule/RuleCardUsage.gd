## 卡牌使用规则静态工具类
class_name RuleCardUsage
extends RefCounted

## 检查在主阶段是否可以使用指定卡牌
static func can_use_card_in_main(
	card: Card,
	source_player: Player,
	target_player: Player,
	game_state: GameState
) -> bool:
	# 卫语句：卡牌不存在
	if not card:
		return false
	match card.type:
		&"attack":
			# 不能对自己使用攻击牌
			if target_player == source_player:
				return false
			# 如果目标玩家守区不为空，检查顶部卡牌拥有者
			var target_defense: AreaDefence = target_player.area_defensive
			if target_defense and not target_defense.is_empty():
				var top_card: Card = target_defense.get_top_card()
				if top_card and top_card.player == source_player:
					# 目标守区顶部是自己的牌，不能攻击
					return false
			# 检查守区结算次数是否小于攻击者速度
			if target_defense and target_defense.settle_count >= source_player.get_attribute(&"speed"):
				return false
			return true
		&"defence":
			# 不能对自己使用防御牌？规则允许对自己使用防御牌（通常是自己守区）
			# 如果目标玩家是自己的守区，检查顶部是否为自己的牌
			if target_player == source_player:
				var self_defense: AreaDefence = source_player.area_defensive
				if self_defense and self_defense.is_empty():
					return true
				var top_card: Card = self_defense.get_top_card()
				if not top_card.player == source_player:
					return true
			return false
		&"skill":
			# 技能卡可能需要更多检查，这里简化，假设都可以使用
			return true
		_:
			return false

## 检查在守区攻防阶段是否可以使用指定卡牌
static func can_use_card_in_defense(
	card: Card,
	source_player: Player,
	defense_area: AreaDefence,
	attacker: Player,
	defender: Player,
	current_responsive_player_id: int
) -> bool:
	if not card:
		return false
	var is_attacker_turn: bool = (current_responsive_player_id == attacker.player_id)
	var top_card: Card = defense_area.get_top_card()
	# 如果守区为空
	if top_card == null:
		if not is_attacker_turn:
			return false
		# 攻方可出攻击或技能
		if card.type == &"attack":
			return true
		elif card.type == &"skill":
			# 群体攻击技能在守区攻防阶段禁止（示例）
			if card.get_attribute(&"is_group_attack"):
				return false
			return true
		else:
			return false
	# 守区有牌
	if top_card.player == defender:
		# 顶层是守方牌，只有攻方可出牌
		if not is_attacker_turn:
			return false
		if card.type == &"attack":
			return true
		elif card.type == &"skill":
			if card.get_attribute(&"is_group_attack"):
				return false
			return true
		else:
			return false
	if top_card.player == attacker:
		# 顶层是攻方牌，只有守方可出牌
		if is_attacker_turn:
			return false
		if card.type == &"defence":
			return true
		else:
			return false
	return false
