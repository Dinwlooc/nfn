## 卡牌使用规则静态工具类
@abstract
extends Rule
class_name RuleCardUsage

## 卡牌使用校验的失败原因码
enum ErrorCode {
	NONE,
	CARD_NULL,
	DEFENSE_TOP_OWNER,
	SETTLE_COUNT_EXCEED,
	UNKNOWN_CARD_TYPE,
	WRONG_TURN,
	INVALID_CARD_TYPE,
	INVALID_DEFENSE_TARGET,
	NOT_IN_HAND,
	NOT_OWNER,
	RESPONSE_FORBIDDEN,
}

## 校验结果记录：是否可用 + 失败原因 + 提示文本
## @record
class UsageResult:
	## 是否通过校验
	var is_valid: bool
	## 失败原因码
	var error_code: ErrorCode
	## 面向玩家的提示文本
	var message: String
	## 构造：默认视为通过
	func _init(p_is_valid: bool, p_error_code: ErrorCode = ErrorCode.NONE, p_message: String = "") -> void:
		is_valid = p_is_valid
		error_code = p_error_code
		message = p_message

## 验证器名称常量
## @deep_inherit
@abstract class Validator:
	## 守区顶部归属校验
	const STACK_LIMIT := &"stack_limit"
	## 攻速上限校验
	const SPEED_LIMIT := &"speed_limit"
	## 守区目标校验
	const DEFENSE_TARGET := &"defense_target"
	## 濒死阶段可用校验
	const DYING_AVAILABLE := &"dying_available"
	## 群体攻击响应可用校验（卡牌级开关，缺省按"可用"处理）
	const GROUP_ATTACK_AVAILABLE := &"group_attack_available"

## 允许参与规则合并的校验器键
static var _allowed_validator_keys: Array[StringName] = [
	Validator.STACK_LIMIT,
	Validator.SPEED_LIMIT,
	Validator.DEFENSE_TARGET,
	Validator.DYING_AVAILABLE,
	Validator.GROUP_ATTACK_AVAILABLE,
]

## 各卡牌类型默认启用的校验器
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

## 取某张卡合并后的校验器配置
## @delegates
static func _get_rule_config(card: Card) -> Dictionary[StringName, Variant]:
	var card_type: StringName = card.type
	var base: Dictionary[StringName, Variant]
	base.assign(_card_rules.get(card_type, {}))
	return Rule.get_rule_config(card, base, _allowed_validator_keys)

## 主阶段可用性校验（叠放归属 + 攻速上限）
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

## 守备阶段可用性校验（额外校验守区目标）
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

## 群体攻击响应可用性校验：响应者必须是牌主、牌必须在手牌区、卡牌级开关允许
static func can_use_card_in_group_attack(
	card: Card,
	source_player: Player,
	game_state: GameState
) -> UsageResult:
	if not card:
		return UsageResult.new(false, ErrorCode.CARD_NULL, "卡牌实例为空")
	if not source_player:
		return UsageResult.new(false, ErrorCode.NOT_OWNER, "响应者不存在")
	if card.get_owner_id() != source_player.get_id():
		return UsageResult.new(false, ErrorCode.NOT_OWNER, "只能用自己的牌响应")
	if card.area_name != GlobalConstants.DefaultArea.HAND:
		return UsageResult.new(false, ErrorCode.NOT_IN_HAND, "响应牌必须来自手牌")
	var rule_config: Dictionary[StringName, Variant] = _get_rule_config(card)
	if rule_config.has(Validator.GROUP_ATTACK_AVAILABLE):
		if not rule_config[Validator.GROUP_ATTACK_AVAILABLE]:
			return UsageResult.new(false, ErrorCode.RESPONSE_FORBIDDEN, "此卡牌不能用于响应群体攻击")
	return UsageResult.new(true)

## 濒死阶段可用性校验
static func can_use_card_in_dying_stage(card: Card) -> UsageResult:
	if not card:
		return UsageResult.new(false, ErrorCode.CARD_NULL, "卡牌实例为空")
	var rule_config: Dictionary[StringName, Variant] = _get_rule_config(card)
	var available: bool = rule_config.get(Validator.DYING_AVAILABLE, false)
	if not available:
		return UsageResult.new(false, ErrorCode.INVALID_CARD_TYPE, "此卡牌不能在濒死阶段使用")
	return UsageResult.new(true)

## 叠放归属校验：守区顶部不能是自己的牌
static func _validate_stack_limit(defense_area: AreaDefence, source: Player) -> UsageResult:
	if defense_area and not defense_area.is_empty():
		var top_card: Card = defense_area.get_top_card()
		if top_card and top_card.player == source:
			return UsageResult.new(false, ErrorCode.DEFENSE_TOP_OWNER, "守区顶部是自己的牌，不能使用")
	return UsageResult.new(true)

## 攻速上限校验：守区结算次数已达速度上限
static func _validate_speed_limit(defense_area: AreaDefence, source: Player, _game_state: GameState) -> UsageResult:
	if defense_area and defense_area.settle_count >= source.get_attribute(&"speed"):
		return UsageResult.new(false, ErrorCode.SETTLE_COUNT_EXCEED, "守区结算次数已达攻击者速度上限")
	return UsageResult.new(true)

## 守区目标校验：只能以当前守区拥有者为目标
static func _validate_defense_target(source: Player, target: Player, defender: Player) -> UsageResult:
	if not target or target.get_id() != defender.get_id():
		return UsageResult.new(false, ErrorCode.INVALID_DEFENSE_TARGET, "此卡牌在守区攻防阶段只能以当前守区拥有者为目标")
	return UsageResult.new(true)
