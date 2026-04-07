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
	GROUP_ATTACK_IN_DEFENSE,
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
	const STACK_LIMIT := &"stack_limit"      # 堆栈限制（主阶段）
	const SPEED_LIMIT := &"speed_limit"      # 速度限制（主阶段）
	const DEFENSE_STATE := &"defense_state"  # 防御阶段守区状态检查
	const DEFENSE_GROUP_ATTACK := &"defense_group_attack"

# ---------- 主阶段配置 ----------
static var _main_card_rules: Dictionary = {
	&"attack": {
		Validator.STACK_LIMIT: true,
		Validator.SPEED_LIMIT: true,
	},
	&"defence": {
		Validator.STACK_LIMIT: true,
	},
	&"skill": {},
}

# ---------- 防御阶段配置 ----------
static var _defense_state_allowed: Dictionary = {
	&"empty": {
		&"attack": true,
		&"defence": false,
		&"skill": true,
	},
	&"top_defender": {
		&"attack": true,
		&"defence": false,
		&"skill": true,
	},
	&"top_attacker": {
		&"attack": false,
		&"defence": true,
		&"skill": false,
	},
}

static var _defense_extra_validators: Dictionary = {
	&"skill": [Validator.DEFENSE_GROUP_ATTACK],
}

static var _defense_validator_funcs: Dictionary = {
	Validator.DEFENSE_STATE: _validate_defense_state,
	Validator.DEFENSE_GROUP_ATTACK: _validate_defense_group_attack,
}

static func _get_defense_validators_for_card(card_type: StringName) -> Array:
	var validators = [Validator.DEFENSE_STATE]
	var extra = _defense_extra_validators.get(card_type, [])
	validators.append_array(extra)
	return validators

# ---------- 主阶段入口 ----------
## @param defense_area 需要检查堆栈限制的守区（攻击牌为目标守区，防御牌为自己守区，技能牌可为空）
## @param speed_defense_area 需要检查速度限制的守区（攻击牌为目标守区，其他情况传 null，由配置决定是否调用）
static func can_use_card_in_main(
	card: Card,
	source_player: Player,
	defense_area: AreaDefence,
	game_state: GameState
) -> UsageResult:
	if not card:
		return UsageResult.new(false, ErrorCode.CARD_NULL, "卡牌实例为空")
	var card_type = card.type
	var rule_config = _main_card_rules.get(card_type)
	if not rule_config:
		return UsageResult.new(false, ErrorCode.UNKNOWN_CARD_TYPE, "未知卡牌类型: %s" % card_type)
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

# ---------- 防御阶段入口 ----------
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
	var card_type = card.type
	var validators = _get_defense_validators_for_card(card_type)
	for validator_name in validators:
		var func_ref = _defense_validator_funcs.get(validator_name)
		if not func_ref:
			continue
		var result = func_ref.call(card, source_player, defense_area, attacker, defender, current_responsive_player_id)
		if not result.is_valid:
			return result
	return UsageResult.new(true)

static func _validate_defense_state(
	card: Card,
	_source: Player,
	defense_area: AreaDefence,
	attacker: Player,
	defender: Player,
	current_responsive_player_id: int
) -> UsageResult:
	var is_attacker_turn = (current_responsive_player_id == attacker.player_id)
	var top_card = defense_area.get_top_card()
	var state_key: StringName
	if top_card == null:
		state_key = &"empty"
		if not is_attacker_turn:
			return UsageResult.new(false, ErrorCode.WRONG_TURN, "守区为空时只有攻方可出牌")
	elif top_card.player == defender:
		state_key = &"top_defender"
		if not is_attacker_turn:
			return UsageResult.new(false, ErrorCode.WRONG_TURN, "守区顶层是守方牌，只有攻方可出牌")
	elif top_card.player == attacker:
		state_key = &"top_attacker"
		if is_attacker_turn:
			return UsageResult.new(false, ErrorCode.WRONG_TURN, "守区顶层是攻方牌，只有守方可出牌")
	else:
		return UsageResult.new(false, ErrorCode.UNKNOWN_TOP_OWNER, "守区顶层牌归属异常")

	var allowed_map = _defense_state_allowed.get(state_key)
	if not allowed_map:
		return UsageResult.new(false, ErrorCode.INVALID_CARD_TYPE, "未知守区状态")
	var allowed = allowed_map.get(card.type, false)
	if not allowed:
		return UsageResult.new(false, ErrorCode.INVALID_CARD_TYPE, "当前守区状态下不允许使用该卡牌类型")
	return UsageResult.new(true)

static func _validate_defense_group_attack(
	card: Card,
	_source: Player,
	_defense_area: AreaDefence,
	_attacker: Player,
	_defender: Player,
	_current_responsive_player_id: int
) -> UsageResult:
	if card.get_attribute(&"is_group_attack"):
		return UsageResult.new(false, ErrorCode.GROUP_ATTACK_IN_DEFENSE, "群体攻击技能禁止在守区攻防阶段使用")
	return UsageResult.new(true)
