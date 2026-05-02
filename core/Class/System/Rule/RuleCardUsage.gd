## 卡牌使用规则静态工具类（调用方需传入守区实例）
extends RefCounted
class_name RuleCardUsage

enum ErrorCode {
	NONE,
	CARD_NULL,
	DEFENSE_TOP_OWNER,          # 守区顶部是自己的牌
	SETTLE_COUNT_EXCEED,        # 速度限制
	UNKNOWN_CARD_TYPE,
	WRONG_TURN,
	INVALID_CARD_TYPE,
	UNKNOWN_TOP_OWNER,
	GROUP_ATTACK_IN_DEFENSE,    # 群体攻击禁止在守区攻防阶段使用
}

class UsageResult:
	var is_valid: bool
	var error_code: ErrorCode
	var message: String
	func _init(p_is_valid: bool, p_error_code: ErrorCode = ErrorCode.NONE, p_message: String = "") -> void:
		is_valid = p_is_valid
		error_code = p_error_code
		message = p_message

class Validator:
	const STACK_LIMIT := &"stack_limit"      # 守区堆栈限制
	const SPEED_LIMIT := &"speed_limit"      # 速度限制

# ---------- 默认配置 ----------
static var _card_rules: Dictionary = {
	GlobalConstants.DefaultCard.ATTACK: {
		Validator.STACK_LIMIT: true,
		Validator.SPEED_LIMIT: true,
	},
	GlobalConstants.DefaultCard.DEFENCE: {
		Validator.STACK_LIMIT: true,
	},
	GlobalConstants.DefaultCard.SPELL: {
		Validator.STACK_LIMIT: true,
	},
}

## 获取卡牌的规则配置（支持卡牌自身覆盖）
static func _get_rule_config(card: Card) -> Dictionary:
	var card_type: StringName = card.type
	var base = _card_rules.get(card_type, {})
	var overrides = card.get_rule_overrides()
	if overrides.is_empty():
		return base
	var merged = base.duplicate()
	for key in overrides:
		if key == Validator.STACK_LIMIT or key == Validator.SPEED_LIMIT:
			merged[key] = overrides[key]
	return merged

## 检查卡牌在主阶段（出牌阶段）的使用合法性
## @param defense_area 需要检查堆栈限制的守区（攻击牌为目标守区，防御牌为自己守区，技能牌可为空）
static func can_use_card_in_main(
	card: Card,
	source_player: Player,
	defense_area: AreaDefence,
	game_state: GameState
) -> UsageResult:
	if not card:
		return UsageResult.new(false, ErrorCode.CARD_NULL, "卡牌实例为空")
	var rule_config: Dictionary = _get_rule_config(card)
	for validator_name in rule_config:
		if not rule_config[validator_name]:
			continue
		match validator_name:
			Validator.STACK_LIMIT:
				if defense_area:
					var result = _validate_stack_limit(defense_area, source_player)
					if not result.is_valid:
						return result
			Validator.SPEED_LIMIT:
				if defense_area:
					var result = _validate_speed_limit(defense_area, source_player, game_state)
					if not result.is_valid:
						return result
	return UsageResult.new(true)

## 堆栈限制验证：守区顶部不能有自己的牌
static func _validate_stack_limit(defense_area: AreaDefence, source: Player) -> UsageResult:
	if defense_area and not defense_area.is_empty():
		var top_card = defense_area.get_top_card()
		if top_card and top_card.player == source:
			return UsageResult.new(false, ErrorCode.DEFENSE_TOP_OWNER, "守区顶部是自己的牌，不能使用")
	return UsageResult.new(true)

## 速度限制验证：守区的结算次数不能达到或超过源玩家速度
static func _validate_speed_limit(defense_area: AreaDefence, source: Player, _game_state: GameState) -> UsageResult:
	if defense_area and defense_area.settle_count >= source.get_attribute(&"speed"):
		return UsageResult.new(false, ErrorCode.SETTLE_COUNT_EXCEED, "守区结算次数已达攻击者速度上限")
	return UsageResult.new(true)

## 防御阶段入口：检查卡牌是否可以在守区攻防阶段使用
static func can_use_card_in_defense(
	card: Card,
	source_player: Player,
	defense_area: AreaDefence,
	attacker: Player,
	defender: Player,
	current_responsive_player_id: int
) -> UsageResult:
	if not card:
		return UsageResult.new(false, ErrorCode.CARD_NULL, "卡牌实例为空")
	# 检查群体攻击：若触发类型为 GROUP_ATTACK，禁止使用
	var trigger_type = RuleCenterSkill.get_trigger_type(card)
	if trigger_type == RuleCenterSkill.TriggerType.GROUP_ATTACK:
		return UsageResult.new(false, ErrorCode.GROUP_ATTACK_IN_DEFENSE, "群体攻击技能禁止在守区攻防阶段使用")
	# 普通防御阶段只检查堆栈限制（不检查速度限制）
	var rule_config: Dictionary = _get_rule_config(card)
	if rule_config.get(Validator.STACK_LIMIT, false):
		var result = _validate_stack_limit(defense_area, source_player)
		if not result.is_valid:
			return result
	return UsageResult.new(true)
