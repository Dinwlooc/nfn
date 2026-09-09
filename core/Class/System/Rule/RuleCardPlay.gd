## 出牌规则类
@abstract
extends Rule
class_name RuleCardPlay

## 规则检查结果
class RuleResult:
	var is_valid: bool
	var command: BehaviorCommand
	var message: String

	func _init(p_is_valid: bool, p_command: BehaviorCommand = null, p_message: String = "") -> void:
		is_valid = p_is_valid
		command = p_command
		message = p_message

## 验证器名称常量
## @deep_inherit
@abstract class Validator:
	const TARGET_PERMISSION := &"target_permission"
	const DISTANCE_PERMISSION := &"distance_permission"
	const PLAY_AREA_MODE := &"play_area_mode"
	const CONSUME_MODE := &"consume_mode"
	const TARGET_SEATED := &"target_seated"

## 目标许可掩码枚举
enum TargetPermissionFlags {
	SELF  = 1 << 0,
	OTHER = 1 << 1,
}

## 出牌区域模式枚举（互斥）
enum PlayAreaMode {
	CENTER,
	TARGET_DEFENSE,
}

## 消耗模式枚举
enum ConsumeMode {
	CONSUME_CHECK,
	NO_COST,
	CONSUME_NO_CHECK
}

## 允许合并的验证器键列表
static var _allowed_validator_keys: Array[StringName] = [
	Validator.TARGET_PERMISSION,
	Validator.DISTANCE_PERMISSION,
	Validator.PLAY_AREA_MODE,
	Validator.CONSUME_MODE,
	Validator.TARGET_SEATED,
]

## 卡牌类型预设规则
static var _card_rules: Dictionary[StringName, Dictionary] = {
	GlobalConstants.DefaultCard.ATTACK: {
		&"target_permission": TargetPermissionFlags.OTHER,
		&"distance_check": true,
		&"play_area_mode": PlayAreaMode.TARGET_DEFENSE,
		&"consume_mode": ConsumeMode.CONSUME_CHECK,
		&"target_seated": true,
	},
	GlobalConstants.DefaultCard.SPELL: {
		&"target_permission": TargetPermissionFlags.SELF | TargetPermissionFlags.OTHER,
		&"distance_check": false,
		&"play_area_mode": PlayAreaMode.CENTER,
		&"consume_mode": ConsumeMode.CONSUME_CHECK,
		&"target_seated": true,
	},
	GlobalConstants.DefaultCard.DEFENCE: {
		&"target_permission": TargetPermissionFlags.SELF,
		&"distance_check": false,
		&"play_area_mode": PlayAreaMode.TARGET_DEFENSE,
		&"consume_mode": ConsumeMode.NO_COST,
		&"target_seated": true,
	}
}

## 主要入口：检查并创建出牌命令
static func check_and_create_command(
	card: Card,
	source_player: Player,
	target_player: Player,
	game_state: GameState,
	override_rules: Dictionary[StringName, Variant] = {}
) -> RuleResult:
	if not card:
		return RuleResult.new(false, null, "卡牌实例为空")
	if not source_player:
		return RuleResult.new(false, null, "源玩家实例为空")
	var hand_area: AreaHand = game_state.get_hand_area(source_player.get_id())
	if not hand_area or not hand_area.get_card_by_id(card.id):
		return RuleResult.new(false, null, "玩家不拥有该卡牌")
	var card_type: StringName = card.type
	var base_rule_config: Dictionary[StringName, Variant]
	base_rule_config.assign(_card_rules.get(card_type))
	if not base_rule_config:
		return RuleResult.new(false, null, "不支持的卡牌类型: %s" % card_type)
	var card_overrides: Dictionary[StringName, Variant] = card.get_rule_overrides()
	var rule_config := Rule.merge_rules(
		base_rule_config,
		card_overrides,
		override_rules,
		_allowed_validator_keys
	)
	# 验证目标许可
	var target_result: RuleResult = _validate_target_permission(
		rule_config[Validator.TARGET_PERMISSION],
		source_player,
		target_player,
		rule_config[Validator.PLAY_AREA_MODE]
	)
	if not target_result.is_valid:
		return target_result
	if target_player != null and rule_config.get(Validator.TARGET_SEATED, true):
		var seat_idx: int = game_state.player_manager.get_seat_index_by_player_id(target_player.get_id())
		if seat_idx == -1:
			return RuleResult.new(false, null, "目标玩家已不在座位上，无法对其使用卡牌")
	if rule_config.get(&"distance_check", false):
		var distance_result: RuleResult = _validate_distance(card, source_player, target_player, game_state)
		if not distance_result.is_valid:
			return distance_result
	var consume_mode: int = rule_config.get(Validator.CONSUME_MODE, ConsumeMode.CONSUME_CHECK)
	if consume_mode == ConsumeMode.CONSUME_CHECK:
		var total_cost: int = _calculate_total_cost(card, source_player)
		if total_cost > source_player.AP:
			return RuleResult.new(false, null, "行动点不足，需要 %d 点" % total_cost)
	var ap_source: Player = source_player if consume_mode != ConsumeMode.NO_COST else null
	var command: BehaviorCommand = _build_command(source_player, card, target_player, rule_config[Validator.PLAY_AREA_MODE], ap_source)
	return RuleResult.new(true, command, "卡牌使用检查通过")

static func _calculate_total_cost(card: Card, _source_player: Player) -> int:
	return card.get_attribute(&"cost")

## 验证目标许可
static func _validate_target_permission(
	permission_mask: int,
	source: Player,
	target: Player,
	area_mode: PlayAreaMode
) -> RuleResult:
	if area_mode == PlayAreaMode.CENTER and target == null:
		return RuleResult.new(true)
	if area_mode != PlayAreaMode.CENTER and target == null:
		return RuleResult.new(false, null, "此卡牌需要指定一个目标玩家")
	var is_self: bool = (target.get_id() == source.get_id())
	if is_self:
		if not (permission_mask & TargetPermissionFlags.SELF):
			return RuleResult.new(false, null, "此卡牌不能对自己使用")
	else:
		if not (permission_mask & TargetPermissionFlags.OTHER):
			return RuleResult.new(false, null, "此卡牌不能对其他玩家使用")
	return RuleResult.new(true)

## 验证距离限制
static func _validate_distance(card: Card, source: Player, target: Player, game_state: GameState) -> RuleResult:
	if target == null or target.get_id() == source.get_id():
		return RuleResult.new(true)
	var card_range: int = card.get_attribute(&"attack_range")
	if card_range <= 1:
		card_range = 1
	var distance: int = game_state.player_manager.calculate_distance(
		source.seat_index,
		target.seat_index
	)
	if distance > card_range:
		return RuleResult.new(false, null, "目标距离超出卡牌攻击范围: %d > %d" % [distance, card_range])
	return RuleResult.new(true)

## 构建出牌命令
static func _build_command(source: Player, card: Card, target: Player, area_mode: PlayAreaMode, ap_source_player: Player = null) -> BehaviorCommand:
	var target_player_id: int = target.get_id() if target else 0
	var target_area_type: int
	match area_mode:
		PlayAreaMode.CENTER:
			target_area_type = PlayCardsCommand.Context.TargetAreaType.CENTER
		PlayAreaMode.TARGET_DEFENSE:
			target_area_type = PlayCardsCommand.Context.TargetAreaType.PLAYER_DEF
	return PlayCardsCommand.new(
		source,
		PackedInt32Array([card.id]),
		target_player_id,
		target_area_type,
		ap_source_player
	)
