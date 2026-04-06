## 出牌规则类
extends RefCounted
class_name Rule

## 规则检查结果
class RuleResult:
	var is_valid: bool
	var command: BehaviorCommand
	var message: String
	func _init(p_is_valid: bool, p_command: BehaviorCommand = null, p_message: String = "") -> void:
		is_valid = p_is_valid
		command = p_command
		message = p_message

## 验证器
class Validator:
	const TARGET_SELF := &"target_self"
	const TARGET_NOT_SELF := &"target_not_self"
	const TARGET_OTHER := &"target_other"
	const TARGET_CENTER := &"target_center"
	const DISTANCE_CHECK := &"distance_check"

static var _card_rules: Dictionary = {
	&"attack": {
		&"validators": [
			Validator.TARGET_CENTER,
			Validator.TARGET_NOT_SELF,
			Validator.DISTANCE_CHECK,
		],
		&"description": "攻击牌：对他人使用，需检查距离"
	},
	&"spell": {
		&"response_required": true,
		&"validators": [
			Validator.TARGET_CENTER,
		],
		&"description": "技能牌：可使用自己或他人，不检查距离"
	},
	&"defence": {
		&"validators": [
			Validator.TARGET_CENTER,
			Validator.TARGET_SELF,
		],
		&"description": "防御牌：只能对自己使用"
	}
}

## 主要入口：检查并创建出牌命令（全部使用对象实例）
static func check_and_create_command(
	card: Card,
	source_player: Player,
	target_player: Player,
	is_to_center: bool,
	game_state: GameState
) -> RuleResult:
	if not card:
		return RuleResult.new(false, null, "卡牌实例为空")
	if not source_player:
		return RuleResult.new(false, null, "源玩家实例为空")
	if not source_player.area_hand or not source_player.area_hand.get_card_by_id(card.id):
		return RuleResult.new(false, null, "玩家不拥有该卡牌")
	var card_type = card.type
	var rule_config = _card_rules.get(card_type)
	if not rule_config:
		return RuleResult.new(false, null, "不支持的卡牌类型: %s" % card_type)
	var validation_result = _run_validators(
		card,
		source_player,
		target_player,
		rule_config,
		game_state
	)
	if not validation_result.is_valid:
		return validation_result
	var command = PlayCardsCommand.new(
		source_player.player_id,
		PackedInt32Array([card.id]),
		target_player.player_id if target_player else -1,
		rule_config.get(&"target_area", PlayCardsCommand.Context.TargetAreaType.PLAYER_DEF)
	)
	var should_respond = rule_config.get(&"response_required", false)
	# 响应玩家列表可根据需要设置，这里保持原有逻辑
	return RuleResult.new(true, command, "卡牌使用检查通过")

## 运行验证器链
static func _run_validators(
	card: Card,
	source_player: Player,
	target_player: Player,
	rule_config: Dictionary,
	game_state: GameState
) -> RuleResult:
	var validators: Array = rule_config.get(&"validators", [])
	for validator_name in validators:
		var result = _execute_validator(
			validator_name,
			card,
			source_player,
			target_player,
			rule_config,
			game_state
		)
		if not result.is_valid:
			return result
	return RuleResult.new(true)

## 执行单个验证器
static func _execute_validator(
	validator_name: StringName,
	card: Card,
	source_player: Player,
	target_player: Player,
	rule_config: Dictionary,
	game_state: GameState
) -> RuleResult:
	var target_id = target_player.player_id if target_player else -1
	match validator_name:
		Validator.TARGET_SELF:
			if target_id != source_player.player_id:
				return RuleResult.new(false, null, "此卡牌只能对自己使用")
		Validator.TARGET_NOT_SELF:
			if target_id == source_player.player_id:
				return RuleResult.new(false, null, "此卡牌不能对自己使用")
		Validator.TARGET_OTHER:
			if target_id == source_player.player_id:
				return RuleResult.new(false, null, "此卡牌只能对他人使用")
		Validator.DISTANCE_CHECK:
			if target_player and target_id != source_player.player_id:
				var card_range: int = card.get_attribute(&"attack_range")
				if card_range >= 0:
					var distance: int = game_state.player_manager.calculate_distance(
						source_player.seat_index,
						target_player.seat_index
					)
					if distance > card_range:
						return RuleResult.new(false, null, "目标距离超出卡牌攻击范围: %d > %d" % [distance, card_range])
	return RuleResult.new(true)
