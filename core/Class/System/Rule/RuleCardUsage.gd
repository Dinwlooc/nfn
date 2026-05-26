## 卡牌使用规则静态工具类（调用方需传入守区实例）
extends RefCounted
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
class Validator:
	const STACK_LIMIT := &"stack_limit"
	const SPEED_LIMIT := &"speed_limit"
	const DEFENSE_TARGET := &"defense_target"
	const DYING_AVAILABLE := &"dying_available"

## 每种卡牌类型启用的验证器（其余类型无限制）
static var _card_rules: Dictionary = {
	GlobalConstants.DefaultCard.ATTACK: {
		Validator.STACK_LIMIT: true,
		Validator.SPEED_LIMIT: true,
		Validator.DEFENSE_TARGET: true,
	},
	GlobalConstants.DefaultCard.DEFENCE: {
		Validator.STACK_LIMIT: true,
		Validator.DEFENSE_TARGET: true,
	},
	GlobalConstants.DefaultCard.SPELL: {
	},
}

## 获取卡牌的规则配置（合并卡牌自身的覆盖规则）
static func _get_rule_config(card: Card) -> Dictionary:
	var card_type: StringName = card.type
	var base: Dictionary = _card_rules.get(card_type, {})
	var overrides: Dictionary = card.get_rule_overrides()
	if overrides.is_empty():
		return base
	var merged: Dictionary = base.duplicate()
	for key in overrides:
		if key in [Validator.STACK_LIMIT, Validator.SPEED_LIMIT, Validator.DEFENSE_TARGET]:
			merged[key] = overrides[key]
	return merged

## 检查卡牌在主阶段（出牌阶段）的使用合法性
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
					var res := _validate_stack_limit(defense_area, source_player)
					if not res.is_valid:
						return res
			Validator.SPEED_LIMIT:
				if defense_area:
					var res := _validate_speed_limit(defense_area, source_player, game_state)
					if not res.is_valid:
						return res
			# 主阶段不需要 DEFENSE_TARGET 验证，忽略
	return UsageResult.new(true)

## 防御阶段入口：检查卡牌是否可以在守区攻防阶段使用
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
	var rule_config: Dictionary = _get_rule_config(card)
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

## 检查卡牌是否可以在濒死阶段使用
static func can_use_card_in_dying_stage(card: Card) -> UsageResult:
	if not card:
		return UsageResult.new(false, ErrorCode.CARD_NULL, "卡牌实例为空")
	var rule_config: Dictionary = _get_rule_config(card)
	var available = rule_config.get(Validator.DYING_AVAILABLE, false)
	if not available:
		return UsageResult.new(false, ErrorCode.INVALID_CARD_TYPE, "此卡牌不能在濒死阶段使用")
	return UsageResult.new(true)


## 堆栈限制验证：守区顶部不能有自己的牌
static func _validate_stack_limit(defense_area: AreaDefence, source: Player) -> UsageResult:
	if defense_area and not defense_area.is_empty():
		var top_card: Card = defense_area.get_top_card()
		if top_card and top_card.player == source:
			return UsageResult.new(false, ErrorCode.DEFENSE_TOP_OWNER, "守区顶部是自己的牌，不能使用")
	return UsageResult.new(true)

## 速度限制验证：守区结算次数不能达到或超过源玩家速度
static func _validate_speed_limit(defense_area: AreaDefence, source: Player, _game_state: GameState) -> UsageResult:
	if defense_area and defense_area.settle_count >= source.get_attribute(&"speed"):
		return UsageResult.new(false, ErrorCode.SETTLE_COUNT_EXCEED, "守区结算次数已达攻击者速度上限")
	return UsageResult.new(true)

## 防御阶段目标限定：攻击/防御牌只能以守区拥有者为目标
static func _validate_defense_target(source: Player, target: Player, defender: Player) -> UsageResult:
	if not target or target.get_id() != defender.get_id():
		return UsageResult.new(false, ErrorCode.INVALID_DEFENSE_TARGET, "此卡牌在守区攻防阶段只能以当前守区拥有者为目标")
	return UsageResult.new(true)
