# Rule.gd - 统一出牌规则类
extends RefCounted
class_name Rule

# 规则检查结果
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

# 验证器名称（使用StringName）
class Validator:
	static var TARGET_SELF := &"target_self"          # 只能对自己使用
	static var TARGET_NOT_SELF := &"target_not_self"  # 不能对自己使用
	static var TARGET_OTHER := &"target_other"        # 只能对他人使用
	static var TARGET_CENTER := &"target_center"      # 是否能对中心区域使用
	static var DISTANCE_CHECK := &"distance_check"    # 距离检查（仅攻击牌使用）

# 卡牌规则配置表（静态，可从外部加载）
# 规则：未配置的键默认为false，配置时只需写true的情况
static var _card_rules: Dictionary = {
	&"attack": {
		# 验证器列表（必需配置）
		&"validators": [
			Validator.TARGET_CENTER,
			Validator.TARGET_NOT_SELF,
			Validator.DISTANCE_CHECK,
		],
		&"target_area": PlayCardsCommand.TargetAreaType.PLAYER_DEF,
		&"description": "攻击牌：对他人使用，需检查距离"
	},
	&"skill": {
		&"response_required": true,

		# 验证器列表
		&"validators": [
			Validator.TARGET_CENTER,
		],

		# 其他配置
		&"target_area": PlayCardsCommand.TargetAreaType.PLAYER_DEF,
		&"description": "技能牌：可使用自己或他人，不检查距离"
	},
	&"defense": {
		&"validators": [
			Validator.TARGET_CENTER,
			Validator.TARGET_SELF,
		],
		&"target_area": PlayCardsCommand.TargetAreaType.PLAYER_DEF,
		&"description": "防御牌：只能对自己使用"
	}
}

# ==================== 主接口方法 ====================

# 检查并创建出牌命令
static func check_and_create_command(
	card: Card,
	source_player_id: int,
	target_id: int,
	is_to_center: bool,
	game_state: GameState
) -> RuleResult:

	# 1. 基本验证（卡牌、玩家、目标存在性和手牌从属检验）
	var basic_result = _validate_basic(card, source_player_id, target_id, is_to_center, game_state)
	if not basic_result.is_valid:
		return basic_result

	# 2. 获取规则配置
	var card_type = card.type
	var rule_config = _card_rules.get(card_type)
	if not rule_config:
		return RuleResult.new(false, null, "不支持的卡牌类型: %s" % card_type)

	# 3. 执行验证器链
	var validation_result = _run_validators(
		card, source_player_id, target_id, is_to_center,
		rule_config, game_state
	)

	if not validation_result.is_valid:
		return validation_result

	# 4. 创建命令
	var command = PlayCardsCommand.new(
		source_player_id,
		PackedInt32Array([card.id]),
		target_id,
		rule_config.get("target_area", PlayCardsCommand.TargetAreaType.PLAYER_DEF)
	)
	# 5. 确定是否需要响应（未配置则默认为false）
	var should_respond = rule_config.get(&"response_required", false)
	var responsive_players = PackedInt32Array()
	if should_respond:
		responsive_players = _get_responsive_players(source_player_id, game_state)
	return RuleResult.new(
		true,
		command,
		"卡牌使用检查通过",
		should_respond,
		responsive_players
	)

# ==================== 基础验证实现 ====================

# 基本验证（卡牌、玩家、目标存在性和手牌从属等基础检查）
static func _validate_basic(card: Card, source_player_id: int, target_id: int, is_to_center: bool, game_state: GameState) -> RuleResult:
	# 1. 卡牌存在性检验
	if not card:
		return RuleResult.new(false, null, "卡牌不存在")

	# 2. 源玩家存在性检验
	var source_player = game_state.player_manager.get_player_by_id(source_player_id)
	if not source_player:
		return RuleResult.new(false, null, "玩家不存在")

	# 3. 手牌从属检验
	if not source_player.area_hand or not source_player.area_hand.has_card(card):
		return RuleResult.new(false, null, "玩家不拥有该卡牌")

	# 4. 目标存在性检验
	if not is_to_center:
		# 如果目标不是自己，需要检查目标玩家是否存在
		if target_id != source_player_id:
			var target_player = game_state.player_manager.get_player_by_id(target_id)
			if not target_player:
				return RuleResult.new(false, null, "目标玩家不存在")

	# 5. 对中心区域使用的特殊检查
	if is_to_center:
		# 暂时没有中心区域目标，返回错误
		return RuleResult.new(false, null, "暂不支持对中心区域使用")

	return RuleResult.new(true)

# ==================== 验证器实现 ====================

# 运行验证器链
static func _run_validators(
	card: Card,
	source_player_id: int,
	target_id: int,
	is_to_center: bool,
	rule_config: Dictionary,
	game_state: GameState
) -> RuleResult:

	var source_player = game_state.player_manager.get_player_by_id(source_player_id)
	var target_player = game_state.player_manager.get_player_by_id(target_id)

	# 获取验证器列表
	var validators = rule_config.get(&"validators", [])

	for validator_name in validators:
		var result = _execute_validator(
			validator_name, card, source_player, target_player,
			target_id, is_to_center, rule_config, game_state
		)
		if not result.is_valid:
			return result

	return RuleResult.new(true)

# 执行单个验证器
static func _execute_validator(
	validator_name: StringName,
	card: Card,
	source_player: Player,
	target_player: Player,
	target_id: int,
	is_to_center: bool,
	rule_config: Dictionary,
	game_state: GameState
) -> RuleResult:
	if validator_name == Validator.TARGET_CENTER:
		if is_to_center and not rule_config.get(&"target_center", false):
			return RuleResult.new(false, null, "此卡牌不能对中心区域使用")
	elif validator_name == Validator.TARGET_SELF:
		if target_id != source_player.player_id:
			return RuleResult.new(false, null, "此卡牌只能对自己使用")
	elif validator_name == Validator.TARGET_NOT_SELF:
		if target_id == source_player.player_id:
			return RuleResult.new(false, null, "此卡牌不能对自己使用")
	elif validator_name == Validator.TARGET_OTHER:
		if target_id == source_player.player_id:
			return RuleResult.new(false, null, "此卡牌只能对他人使用")
	elif validator_name == Validator.DISTANCE_CHECK:
		if target_player and target_id != source_player.player_id:
			var card_range:int = card.get_attribute(&"attack_range")
			if card_range >= 0:  # 只有攻击牌有range属性
				var distance:int = game_state.player_manager.calculate_distance(
					source_player.seat_index,
					target_player.seat_index
				)
				if distance > card_range:
					return RuleResult.new(false, null, "目标距离超出卡牌攻击范围: %d > %d" % [distance, card_range])
	return RuleResult.new(true)

static func _get_responsive_players(source_player_id: int, game_state: GameState) -> PackedInt32Array:
	var responsive_players = PackedInt32Array()
	var players = game_state.player_manager.players
	for player in players:
		if player.player_id != source_player_id:
			responsive_players.append(player.player_id)
	return responsive_players
