## 出牌规则类（重构版）
extends RefCounted
class_name RuleCardPlay

## 规则检查结果
class RuleResult:
	var is_valid: bool
	var command: BehaviorCommand
	var message: String

	## 初始化结果
	func _init(p_is_valid: bool, p_command: BehaviorCommand = null, p_message: String = "") -> void:
		is_valid = p_is_valid
		command = p_command
		message = p_message

## 验证器名称常量（仅用于标识，实际验证由规则字段完成）
class Validator:
	const TARGET_PERMISSION := &"target_permission"   ## 目标许可验证器
	const DISTANCE_PERMISSION := &"distance_permission" ## 距离许可验证器
	const PLAY_AREA_MODE := &"play_area_mode"         ## 出牌区域模式验证器

## 目标许可掩码枚举
enum TargetPermissionFlags {
	SELF  = 1 << 0,  ## 可对自己使用
	OTHER = 1 << 1,  ## 可对其他区域使用（其他玩家）
}

## 出牌区域模式枚举（互斥）
enum PlayAreaMode {
	CENTER,         ## 出牌到中心区（对指定目标生成技能效果）
	TARGET_DEFENSE, ## 出牌到目标守区
}

## 卡牌类型预设规则（键为卡牌类型 StringName）
static var _card_rules: Dictionary = {
	&"attack": {
		&"target_permission": TargetPermissionFlags.OTHER,
		&"distance_check": true,
		&"play_area_mode": PlayAreaMode.TARGET_DEFENSE,
	},
	&"spell": {
		&"target_permission": TargetPermissionFlags.SELF | TargetPermissionFlags.OTHER,
		&"distance_check": false,
		&"play_area_mode": PlayAreaMode.CENTER,
	},
	&"defence": {
		&"target_permission": TargetPermissionFlags.SELF,
		&"distance_check": false,
		&"play_area_mode": PlayAreaMode.TARGET_DEFENSE,
	}
}

## 主要入口：检查并创建出牌命令
## @param override_rules 卡牌内置覆盖规则字典，键为验证器名（如 Validator.TARGET_PERMISSION），值为对应规则值
static func check_and_create_command(
	card: Card,
	source_player: Player,
	target_player: Player,
	is_to_center: bool,
	game_state: GameState,
	override_rules: Dictionary = {}
) -> RuleResult:
	# 基础校验（卫语句）
	if not card:
		return RuleResult.new(false, null, "卡牌实例为空")
	if not source_player:
		return RuleResult.new(false, null, "源玩家实例为空")
	if not source_player.area_hand or not source_player.area_hand.get_card_by_id(card.id):
		return RuleResult.new(false, null, "玩家不拥有该卡牌")

	var card_type = card.type
	var base_rule_config = _card_rules.get(card_type)
	if not base_rule_config:
		return RuleResult.new(false, null, "不支持的卡牌类型: %s" % card_type)

	# 合并覆盖规则（仅在需要时创建副本）
	var rule_config = _merge_rule_config(base_rule_config, override_rules)

	# 区域模式验证
	var area_result = _validate_play_area_mode(rule_config[Validator.PLAY_AREA_MODE], is_to_center)
	if not area_result.is_valid:
		return area_result

	# 目标许可验证
	var target_result = _validate_target_permission(
		rule_config[Validator.TARGET_PERMISSION],
		source_player,
		target_player,
		rule_config[Validator.PLAY_AREA_MODE]
	)
	if not target_result.is_valid:
		return target_result

	# 距离验证
	if rule_config.get(&"distance_check", false):
		var distance_result = _validate_distance(card, source_player, target_player, game_state)
		if not distance_result.is_valid:
			return distance_result

	# 构建命令
	var command = _build_command(source_player, card, target_player, rule_config[Validator.PLAY_AREA_MODE])
	return RuleResult.new(true, command, "卡牌使用检查通过")

## 合并基础规则与覆盖规则（仅在存在有效覆盖时创建副本）
static func _merge_rule_config(base: Dictionary, overrides: Dictionary) -> Dictionary:
	# 快速检查是否有任何可覆盖的键
	var has_override := false
	for key in overrides:
		if key == Validator.TARGET_PERMISSION or key == Validator.DISTANCE_PERMISSION or key == Validator.PLAY_AREA_MODE:
			has_override = true
			break

	if not has_override:
		return base  # 直接引用静态字典，无额外分配

	# 存在覆盖，创建副本并应用
	var merged = base.duplicate()
	for key in overrides:
		if key == Validator.TARGET_PERMISSION or key == Validator.DISTANCE_PERMISSION or key == Validator.PLAY_AREA_MODE:
			merged[key] = overrides[key]
	return merged

## 验证出牌区域模式是否与玩家意图一致
static func _validate_play_area_mode(required_mode: PlayAreaMode, is_to_center: bool) -> RuleResult:
	match required_mode:
		PlayAreaMode.CENTER:
			if not is_to_center:
				return RuleResult.new(false, null, "此卡牌必须出牌到中心区")
		PlayAreaMode.TARGET_DEFENSE:
			if is_to_center:
				return RuleResult.new(false, null, "此卡牌必须出牌到目标守区")
	return RuleResult.new(true)

## 验证目标许可（基于掩码和区域模式）
static func _validate_target_permission(
	permission_mask: int,
	source: Player,
	target: Player,
	area_mode: PlayAreaMode
) -> RuleResult:
	# 中心区模式允许无目标玩家
	if area_mode == PlayAreaMode.CENTER and target == null:
		return RuleResult.new(true)
	# 非中心区模式必须有目标玩家
	if area_mode != PlayAreaMode.CENTER and target == null:
		return RuleResult.new(false, null, "此卡牌需要指定一个目标玩家")

	var is_self = (target.player_id == source.player_id)
	if is_self:
		if not (permission_mask & TargetPermissionFlags.SELF):
			return RuleResult.new(false, null, "此卡牌不能对自己使用")
	else:
		if not (permission_mask & TargetPermissionFlags.OTHER):
			return RuleResult.new(false, null, "此卡牌不能对其他玩家使用")
	return RuleResult.new(true)

## 验证距离限制
static func _validate_distance(card: Card, source: Player, target: Player, game_state: GameState) -> RuleResult:
	# 无目标或目标为自己时无需检查距离
	if target == null or target.player_id == source.player_id:
		return RuleResult.new(true)
	var card_range: int = card.get_attribute(&"attack_range")
	if card_range < 0:
		return RuleResult.new(true)  # 负数表示无距离限制
	var distance: int = game_state.player_manager.calculate_distance(
		source.seat_index,
		target.seat_index
	)
	if distance > card_range:
		return RuleResult.new(false, null, "目标距离超出卡牌攻击范围: %d > %d" % [distance, card_range])
	return RuleResult.new(true)

## 构建出牌命令
static func _build_command(source: Player, card: Card, target: Player, area_mode: PlayAreaMode) -> BehaviorCommand:
	var target_player_id = target.player_id if target else -1
	var target_area_type: int
	match area_mode:
		PlayAreaMode.CENTER:
			target_area_type = PlayCardsCommand.Context.TargetAreaType.CENTER
		PlayAreaMode.TARGET_DEFENSE:
			target_area_type = PlayCardsCommand.Context.TargetAreaType.PLAYER_DEF
	return PlayCardsCommand.new(
		source.player_id,
		PackedInt32Array([card.id]),
		target_player_id,
		target_area_type
	)
