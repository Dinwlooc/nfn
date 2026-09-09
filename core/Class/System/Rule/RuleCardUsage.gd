## 卡牌使用规则静态工具类
@abstract
extends Rule
class_name RuleCardUsage

enum ErrorCode {
	NONE,
	CARD_NULL,
	DEFENSE_TOP_OWNER,
	SETTLE_COUNT_EXCEED,
	UNKNOWN_CARD_TYPE,
	WRONG_TURN,
	INVALID_CARD_TYPE,
	INVALID_DEFENSE_TARGET,
}

class UsageResult:
	var is_valid: bool
	var error_code: ErrorCode
	var message: String
	func _init(p_is_valid: bool, p_error_code: ErrorCode = ErrorCode.NONE, p_message: String = "") -> void:
		is_valid = p_is_valid
		error_code = p_error_code
		message = p_message

## 验证器名称常量
## @deep_inherit
@abstract class Validator:
	const STACK_LIMIT := &"stack_limit"
	const SPEED_LIMIT := &"speed_limit"
	const DEFENSE_TARGET := &"defense_target"
	const DYING_AVAILABLE := &"dying_available"

static var _allowed_validator_keys: Array[StringName] = [
	Validator.STACK_LIMIT,
	Validator.SPEED_LIMIT,
	Validator.DEFENSE_TARGET,
	Validator.DYING_AVAILABLE,
]

static var _card_rules: Dictionary[StringName, Variant] = {
	GlobalConstants.DefaultCard.ATTACK: {
		Validator.STACK_LIMIT: true,
		Validator.SPEED_LIMIT: true,
		Validator.DEFENSE_TARGET: true,
	},
	GlobalConstants.DefaultCard.DEFENCE: {
		Validator.STACK_LIMIT: true,
		Validator.DEFENSE_TARGET: true,
	},
	GlobalConstants.DefaultCard.SPELL: {},
}

static func _get_rule_config(card: Card) -> Dictionary[StringName, Variant]:
	var card_type: StringName = card.type
	var base: Dictionary[StringName, Variant]
	base.assign(_card_rules.get(card_type, {}))
	return Rule.get_rule_config(card, base, _allowed_validator_keys)

static func can_use_card_in_main(
	card: Card,
	source_player: Player,
	defense_area: AreaDefence,
	game_state: GameState
) -> UsageResult:
	if not card:
		return UsageResult.new(false, ErrorCode.CARD_NULL, "卡牌实例为空")
	var rule_config: Dictionary[StringName, Variant] = _get_rule_config(card)
	for validator_name in rule_config:
		if not rule_config[validator_name]:
			continue
		match validator_name:
			Validator.STACK_LIMIT:
				if defense_area:
					var res := _validate_stack_limit(defense_area, source_player)
					if not res.is_valid:
						return res
			Validator.SPEED_LIMIT:
				if defense_area:
					var res := _validate_speed_limit(defense_area, source_player, game_state)
					if not res.is_valid:
						return res
	return UsageResult.new(true)

static func can_use_card_in_defense(
	card: Card,
	source_player: Player,
	target_player: Player,
	defense_area: AreaDefence,
	attacker: Player,
	defender: Player,
	game_state: GameState
) -> UsageResult:
	if not card:
		return UsageResult.new(false, ErrorCode.CARD_NULL, "卡牌实例为空")
	var rule_config: Dictionary[StringName, Variant] = _get_rule_config(card)
	for validator_name in rule_config:
		if not rule_config[validator_name]:
			continue
		match validator_name:
			Validator.STACK_LIMIT:
				if defense_area:
					var res := _validate_stack_limit(defense_area, source_player)
					if not res.is_valid:
						return res
			Validator.SPEED_LIMIT:
				if defense_area:
					var res := _validate_speed_limit(defense_area, source_player, game_state)
					if not res.is_valid:
						return res
			Validator.DEFENSE_TARGET:
				var res := _validate_defense_target(source_player, target_player, defender)
				if not res.is_valid:
					return res
	return UsageResult.new(true)

static func can_use_card_in_dying_stage(card: Card) -> UsageResult:
	if not card:
		return UsageResult.new(false, ErrorCode.CARD_NULL, "卡牌实例为空")
	var rule_config: Dictionary[StringName, Variant] = _get_rule_config(card)
	var available: bool = rule_config.get(Validator.DYING_AVAILABLE, false)
	if not available:
		return UsageResult.new(false, ErrorCode.INVALID_CARD_TYPE, "此卡牌不能在濒死阶段使用")
	return UsageResult.new(true)

static func _validate_stack_limit(defense_area: AreaDefence, source: Player) -> UsageResult:
	if defense_area and not defense_area.is_empty():
		var top_card: Card = defense_area.get_top_card()
		if top_card and top_card.player == source:
			return UsageResult.new(false, ErrorCode.DEFENSE_TOP_OWNER, "守区顶部是自己的牌，不能使用")
	return UsageResult.new(true)

static func _validate_speed_limit(defense_area: AreaDefence, source: Player, _game_state: GameState) -> UsageResult:
	if defense_area and defense_area.settle_count >= source.get_attribute(&"speed"):
		return UsageResult.new(false, ErrorCode.SETTLE_COUNT_EXCEED, "守区结算次数已达攻击者速度上限")
	return UsageResult.new(true)

static func _validate_defense_target(source: Player, target: Player, defender: Player) -> UsageResult:
	if not target or target.get_id() != defender.get_id():
		return UsageResult.new(false, ErrorCode.INVALID_DEFENSE_TARGET, "此卡牌在守区攻防阶段只能以当前守区拥有者为目标")
	return UsageResult.new(true)
