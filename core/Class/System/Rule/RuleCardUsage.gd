## 卡牌使用规则静态工具类
extends RefCounted
class_name RuleCardUsage


## 验证结果类
class UsageResult:
	var is_valid: bool
	var error_code: StringName   # 用于程序判断的错误码
	var message: String          # 调试用错误信息

	func _init(p_is_valid: bool, p_error_code: StringName = &"", p_message: String = "") -> void:
		is_valid = p_is_valid
		error_code = p_error_code
		message = p_message

## 错误码常量
const ERR_CARD_NULL: StringName = &"card_null"
const ERR_TARGET_SELF_ATTACK: StringName = &"target_self_attack"
const ERR_DEFENSE_TOP_OWNER: StringName = &"defense_top_owner"
const ERR_SETTLE_COUNT_EXCEED: StringName = &"settle_count_exceed"
const ERR_DEFENSE_EMPTY_SELF_DEFENSE: StringName = &"defense_empty_self_defense"
const ERR_TOP_CARD_NOT_SELF: StringName = &"top_card_not_self"
const ERR_GROUP_ATTACK_IN_DEFENSE: StringName = &"group_attack_in_defense"
const ERR_WRONG_TURN: StringName = &"wrong_turn"

## 检查在主阶段是否可以使用指定卡牌
static func can_use_card_in_main(
	card: Card,
	source_player: Player,
	target_player: Player,
	game_state: GameState
) -> UsageResult:
	if not card:
		return UsageResult.new(false, ERR_CARD_NULL, "卡牌实例为空")
	match card.type:
		&"attack":
			if target_player == source_player:
				return UsageResult.new(false, ERR_TARGET_SELF_ATTACK, "攻击牌不能对自己使用")
			var target_defense: AreaDefence = target_player.area_defensive
			if target_defense and not target_defense.is_empty():
				var top_card: Card = target_defense.get_top_card()
				if top_card and top_card.player == source_player:
					return UsageResult.new(false, ERR_DEFENSE_TOP_OWNER, "目标守区顶部是自己的牌，不能攻击")
			if target_defense and target_defense.settle_count >= source_player.get_attribute(&"speed"):
				return UsageResult.new(false, ERR_SETTLE_COUNT_EXCEED, "守区结算次数已达攻击者速度上限")
			return UsageResult.new(true)
		&"defence":
			if target_player == source_player:
				var self_defense: AreaDefence = source_player.area_defensive
				if self_defense and self_defense.is_empty():
					return UsageResult.new(true)
				var top_card: Card = self_defense.get_top_card()
				if top_card and top_card.player == source_player:
					return UsageResult.new(false, ERR_TOP_CARD_NOT_SELF, "自己守区顶部已是自己的牌，不能重复防御")
				return UsageResult.new(true)
			return UsageResult.new(false, ERR_TARGET_SELF_ATTACK, "防御牌只能对自己使用")
		&"skill":
			return UsageResult.new(true)
		_:
			return UsageResult.new(false, &"unknown_type", "未知卡牌类型")

## 检查在守区攻防阶段是否可以使用指定卡牌
static func can_use_card_in_defense(
	card: Card,
	source_player: Player,
	defense_area: AreaDefence,
	attacker: Player,
	defender: Player,
	current_responsive_player_id: int
) -> UsageResult:
	if not card:
		return UsageResult.new(false, ERR_CARD_NULL, "卡牌实例为空")
	var is_attacker_turn: bool = (current_responsive_player_id == attacker.player_id)
	var top_card: Card = defense_area.get_top_card()
	if top_card == null:
		if not is_attacker_turn:
			return UsageResult.new(false, ERR_WRONG_TURN, "守区为空时只有攻方可出牌")
		if card.type == &"attack":
			return UsageResult.new(true)
		elif card.type == &"skill":
			if card.get_attribute(&"is_group_attack"):
				return UsageResult.new(false, ERR_GROUP_ATTACK_IN_DEFENSE, "群体攻击技能禁止在守区攻防阶段使用")
			return UsageResult.new(true)
		else:
			return UsageResult.new(false, &"invalid_card_type", "守区为空时只能出攻击或技能牌")
	if top_card.player == defender:
		if not is_attacker_turn:
			return UsageResult.new(false, ERR_WRONG_TURN, "守区顶层是守方牌，只有攻方可出牌")
		if card.type == &"attack":
			return UsageResult.new(true)
		elif card.type == &"skill":
			if card.get_attribute(&"is_group_attack"):
				return UsageResult.new(false, ERR_GROUP_ATTACK_IN_DEFENSE, "群体攻击技能禁止在守区攻防阶段使用")
			return UsageResult.new(true)
		else:
			return UsageResult.new(false, &"invalid_card_type", "面对守方顶层牌只能出攻击或技能")
	if top_card.player == attacker:
		if is_attacker_turn:
			return UsageResult.new(false, ERR_WRONG_TURN, "守区顶层是攻方牌，只有守方可出牌")
		if card.type == &"defence":
			return UsageResult.new(true)
		else:
			return UsageResult.new(false, &"invalid_card_type", "面对攻方顶层牌只能出防御牌")
	return UsageResult.new(false, &"unknown_top_owner", "守区顶层牌归属异常")
