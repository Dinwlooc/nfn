## 出牌规则类
extends RefCounted
class_name Rule

## 规则检查结果
class RuleResult:
	var is_valid: bool
	var command: BehaviorCommand
	var message: String
	var should_respond: bool = false  # 是否需要响应
	var responsive_players: PackedInt32Array = PackedInt32Array()  # 响应玩家列表

	func _init(p_is_valid: bool, p_command: BehaviorCommand = null, p_message: String = "",
			 p_should_respond: bool = false, p_responsive_players: PackedInt32Array = PackedInt32Array()) -> void:
		is_valid = p_is_valid
		command = p_command
		message = p_message
		should_respond = p_should_respond
		responsive_players = p_responsive_players

## 验证器
class Validator:
	const TARGET_SELF := &"target_self"          # 只能对自己使用
	const TARGET_NOT_SELF := &"target_not_self"  # 不能对自己使用
	const TARGET_OTHER := &"target_other"        # 只能对他人使用
	const TARGET_CENTER := &"target_center"      # 是否能对中心区域使用
	const DISTANCE_CHECK := &"distance_check"    # 距离检查（仅攻击牌使用）

static var _card_rules: Dictionary = {
	&"attack": {
		&"validators": [
			Validator.TARGET_CENTER,
			Validator.TARGET_NOT_SELF,
			Validator.DISTANCE_CHECK,
		],
		&"description": "攻击牌：对他人使用，需检查距离"
	},
	&"skill": {
		&"response_required": true,
		&"validators": [
			Validator.TARGET_CENTER,
		],
		&"description": "技能牌：可使用自己或他人，不检查距离"
	},
	&"defense": {
		&"validators": [
			Validator.TARGET_CENTER,
			Validator.TARGET_SELF,
		],
		&"description": "防御牌：只能对自己使用"
	}
}

## 检查并创建出牌命令（使用ID参数接口）
static func check_and_create_command(
	card_id: int,
	source_player_id: int,
	target_id: int,
	is_to_center: bool,
	game_state: GameState
) -> RuleResult:
	var basic_result = _validate_basic_by_ids(
		card_id, source_player_id, target_id, is_to_center, game_state
	)
	if not basic_result.is_valid:
		return basic_result
	return _check_and_create_with_instances(
		card_id, source_player_id, target_id, is_to_center, game_state
	)

## 使用实例参数的内部方法
static func _check_and_create_with_instances(
	card_id: int,
	source_player_id: int,
	target_id: int,
	is_to_center: bool,
	game_state: GameState
) -> RuleResult:
	var card = game_state.cardsmanager.get_card_by_id(card_id)
	var source_player = game_state.player_manager.get_player_by_id(source_player_id)
	var target_player = null
	if not is_to_center and target_id >= 0:
		target_player = game_state.player_manager.get_player_by_id(target_id)
	var card_type = card.type
	var rule_config = _card_rules.get(card_type)
	if not rule_config:
		return RuleResult.new(false, null, "不支持的卡牌类型: %s" % card_type)
	var validation_result = _run_validators_with_instances(
		card,
		source_player,
		target_player,
		is_to_center,
		rule_config,
		game_state
	)
	if not validation_result.is_valid:
		return validation_result
	var command = PlayCardsCommand.new(
		source_player_id,
		PackedInt32Array([card_id]),
		target_id,
		rule_config.get(&"target_area", PlayCardsCommand.Context.TargetAreaType.PLAYER_DEF)
	)
	var should_respond = rule_config.get(&"response_required", false)
	var responsive_players = PackedInt32Array()
	if should_respond:
		responsive_players = _get_responsive_players_by_id(source_player_id, game_state)
	return RuleResult.new(
		true,
		command,
		"卡牌使用检查通过",
		should_respond,
		responsive_players
	)

## 基本验证（使用ID参数）
static func _validate_basic_by_ids(
	card_id: int,
	source_player_id: int,
	target_id: int,
	is_to_center: bool,
	game_state: GameState
) -> RuleResult:
	var card = game_state.cardsmanager.get_card_by_id(card_id)
	if not card:
		return RuleResult.new(false, null, "卡牌不存在")
	var source_player = game_state.player_manager.get_player_by_id(source_player_id)
	if not source_player:
		return RuleResult.new(false, null, "玩家不存在")
	if not source_player.area_hand or not source_player.area_hand.get_card_by_id(card_id):
		return RuleResult.new(false, null, "玩家不拥有该卡牌")
	if not is_to_center:
		if target_id != source_player_id:
			var target_player = game_state.player_manager.get_player_by_id(target_id)
			if not target_player:
				return RuleResult.new(false, null, "目标玩家不存在")
	if is_to_center:
		return RuleResult.new(false, null, "暂不支持对中心区域使用")
	return RuleResult.new(true)

## 运行验证器链（使用实例参数）
static func _run_validators_with_instances(
	card: Card,
	source_player: Player,
	target_player: Player,
	is_to_center: bool,
	rule_config: Dictionary,
	game_state: GameState
) -> RuleResult:
	var validators:Array = rule_config.get(&"validators", [])
	for validator_name in validators:
		var result = _execute_validator_with_instances(
			validator_name,
			card,
			source_player,
			target_player,
			is_to_center,
			rule_config,
			game_state
		)
		if not result.is_valid:
			return result
	return RuleResult.new(true)

## 执行单个验证器（使用实例参数）
static func _execute_validator_with_instances(
	validator_name: StringName,
	card: Card,
	source_player: Player,
	target_player: Player,
	is_to_center: bool,
	rule_config: Dictionary,
	game_state: GameState
) -> RuleResult:
	var target_id = target_player.player_id if target_player else -1
	match validator_name:
		Validator.TARGET_CENTER:
			if is_to_center and not rule_config.get(&"target_center", false):
				return RuleResult.new(false, null, "此卡牌不能对中心区域使用")
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

static func _get_responsive_players_by_id(source_player_id: int, game_state: GameState) -> PackedInt32Array:
	var responsive_players := PackedInt32Array()
	var players:Array[Player] = game_state.player_manager.players
	for player in players:
		if player.player_id != source_player_id:
			responsive_players.append(player.player_id)
	return responsive_players

## 可选：提供实例参数的版本，用于内部调用或特殊场景
static func check_and_create_command_with_instances(
	card: Card,
	source_player: Player,
	target_player: Player,
	is_to_center: bool,
	game_state: GameState
) -> RuleResult:
	if not card:
		return RuleResult.new(false, null, "卡牌不存在")
	if not source_player:
		return RuleResult.new(false, null, "玩家不存在")
	if not source_player.area_hand or not source_player.area_hand.get_card_by_id(card.id):
		return RuleResult.new(false, null, "玩家不拥有该卡牌")
	var card_type = card.type
	var rule_config = _card_rules.get(card_type)
	if not rule_config:
		return RuleResult.new(false, null, "不支持的卡牌类型: %s" % card_type)
	var validation_result:RuleResult = _run_validators_with_instances(
		card,
		source_player,
		target_player,
		is_to_center,
		rule_config,
		game_state
	)
	if not validation_result.is_valid:
		return validation_result
	var command = PlayCardsCommand.new(
		source_player.player_id,
		PackedInt32Array([card.id]),
		target_player.player_id if target_player else -1,
		rule_config.get("target_area", PlayCardsCommand.Context.TargetAreaType.PLAYER_DEF)
	)
	var should_respond = rule_config.get(&"response_required", false)
	var responsive_players = PackedInt32Array()
	if should_respond:
		responsive_players = _get_responsive_players_by_id(source_player.player_id, game_state)
	return RuleResult.new(
		true,
		command,
		"卡牌使用检查通过",
		should_respond,
		responsive_players
	)
