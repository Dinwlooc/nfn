## 守区结算规则类（纯函数/验证器模式）
extends RefCounted
class_name RuleSettle

## 验证器名称常量
class Validator:
	const LIFE_DAMAGE_MODE: StringName = &"life_damage_mode"
	const MENTAL_DAMAGE_MODE: StringName = &"mental_damage_mode"
	const COMBAT_WILL_MODE: StringName = &"combat_will_mode"
	const ATTACK_ORIENTATION: StringName = &"attack_orientation"

## 伤害模式枚举
enum DamageMode {
	NONE = 0,
	NO_DECAY = 1,
	DECAY_ON_WIN = 2,
	DECAY_ON_LOSE = 3,
}

## 攻击朝向枚举
enum AttackOrientation {
	DEFENDER = 0,
	ATTACKER = 1,
}

## 战意掩码标志位
enum CombatWillFlag {
	ENABLE_BASE = 1 << 0,
	TYPE_IS_DEFENSE = 1 << 1,
	EXTRA_ON_SETTLE_WIN = 1 << 2,
	EXTRA_ON_OPPOSE_WIN = 1 << 3,
}

## 结算结果类（纯数据容器）
class Result:
	var target: Player
	var health_damage_value: int
	var mental_damage_value: int
	var combat_will_grants: Array[CombatWillGrant]

	func _init(p_target: Player = null, p_health: int = 0, p_mental: int = 0) -> void:
		target = p_target
		health_damage_value = p_health
		mental_damage_value = p_mental
		combat_will_grants = []

## 战意授予条目
class CombatWillGrant:
	var target_player: Player
	var is_defense: bool
	var base_value: int
	var extra_value: int

	func _init(p_target: Player, p_is_defense: bool, p_base: int, p_extra: int) -> void:
		target_player = p_target
		is_defense = p_is_defense
		base_value = p_base
		extra_value = p_extra

## 预设规则字典（键为卡牌类型 StringName）
static var _settle_rules: Dictionary = {
	GlobalConstants.DefaultCard.ATTACK: {
		Validator.LIFE_DAMAGE_MODE: DamageMode.DECAY_ON_LOSE,
		Validator.MENTAL_DAMAGE_MODE: DamageMode.DECAY_ON_WIN,
		Validator.COMBAT_WILL_MODE: CombatWillFlag.ENABLE_BASE | CombatWillFlag.EXTRA_ON_SETTLE_WIN | CombatWillFlag.EXTRA_ON_OPPOSE_WIN,
		Validator.ATTACK_ORIENTATION: AttackOrientation.DEFENDER,
	},
	GlobalConstants.DefaultCard.DEFENCE: {
		Validator.LIFE_DAMAGE_MODE: DamageMode.NONE,
		Validator.MENTAL_DAMAGE_MODE: DamageMode.DECAY_ON_LOSE,
		Validator.COMBAT_WILL_MODE: CombatWillFlag.ENABLE_BASE | CombatWillFlag.TYPE_IS_DEFENSE | CombatWillFlag.EXTRA_ON_SETTLE_WIN,
		Validator.ATTACK_ORIENTATION: AttackOrientation.ATTACKER,
	},
}

## 获取初始结算信息（纯函数）
## @param settle_card 结算牌
## @param oppose_card 对抗牌（可为 null）
## @param is_unilateral 是否单方面
## @param attacker 攻击方玩家
## @param defender 防守方玩家
## @param override_rules 覆盖规则
## @return Result 未衰减的结算结果（target 已确定，health/mental 为初始值）
static func get_initial_info(settle_card: Card, oppose_card: Card, is_unilateral: bool, attacker: Player, defender: Player, override_rules: Dictionary = {}) -> Result:
	if not settle_card:
		return Result.new()
	var rules: Dictionary = _get_merged_rules(settle_card, override_rules)
	var base_power: int = settle_card.get_attribute(&"power")
	var health_mode: DamageMode = rules.get(Validator.LIFE_DAMAGE_MODE, DamageMode.NONE)
	var mental_mode: DamageMode = rules.get(Validator.MENTAL_DAMAGE_MODE, DamageMode.NONE)
	var orientation: AttackOrientation = rules.get(Validator.ATTACK_ORIENTATION, AttackOrientation.DEFENDER)
	var target: Player = _get_player_by_orientation(orientation, attacker, defender)
	# 自伤保护
	if attacker == defender:
		return Result.new(target, 0, 0)
	var health_init: int = base_power if health_mode != DamageMode.NONE else 0
	var mental_init: int = base_power if mental_mode != DamageMode.NONE else 0
	return Result.new(target, health_init, mental_init)

## 应用拼点衰减（纯函数）
## @param initial 初始结果（未衰减）
## @param is_unilateral 是否单方面
## @param duel_result 拼点结果枚举
## @param duel_diff 拼点差值
## @param oppose_power 对抗牌威力
## @param health_mode 生命伤害衰减模式
## @param mental_mode 精神伤害衰减模式
## @return Result 应用衰减后的新结果（原 initial 不受影响）
static func apply_decay(initial: Result, is_unilateral: bool, duel_result: int, duel_diff: int, oppose_power: int, health_mode: DamageMode, mental_mode: DamageMode) -> Result:
	var result: Result = Result.new(initial.target, initial.health_damage_value, initial.mental_damage_value)
	if is_unilateral:
		return result
	result.health_damage_value = _apply_single_decay(initial.health_damage_value, health_mode, duel_result, duel_diff, oppose_power)
	result.mental_damage_value = _apply_single_decay(initial.mental_damage_value, mental_mode, duel_result, duel_diff, oppose_power)
	return result

## 生成战意授予条目列表（纯函数）
static func generate_combat_will_grants(settle_card: Card, oppose_card: Card, duel_result: int, duel_diff: int, is_unilateral: bool, mask: int, attacker: Player, defender: Player) -> Array:
	var out_grants: Array = []
	if mask == 0 or not settle_card:
		return out_grants
	var settle_owner: Player = settle_card.player
	var oppose_owner: Player = oppose_card.player if oppose_card else null
	if not settle_owner:
		return out_grants
	var is_defense: bool = (mask & CombatWillFlag.TYPE_IS_DEFENSE) != 0
	if mask & CombatWillFlag.ENABLE_BASE:
		var base_val: int = settle_card.get_attribute(&"power")
		if base_val > 0:
			out_grants.append(CombatWillGrant.new(settle_owner, is_defense, base_val, 0))
	if not is_unilateral and duel_result == DuelCommand.Context.Result.A_WIN and (mask & CombatWillFlag.EXTRA_ON_SETTLE_WIN) and duel_diff > 0:
		out_grants.append(CombatWillGrant.new(settle_owner, is_defense, 0, duel_diff))
	if not is_unilateral and duel_result == DuelCommand.Context.Result.B_WIN and oppose_owner and (mask & CombatWillFlag.EXTRA_ON_OPPOSE_WIN) and duel_diff > 0:
		out_grants.append(CombatWillGrant.new(oppose_owner, is_defense, 0, duel_diff))
	return out_grants

# --- 内部辅助函数 ---

static func _apply_single_decay(base: int, mode: DamageMode, duel_result: int, duel_diff: int, oppose_power: int) -> int:
	if base <= 0 or mode == DamageMode.NONE or mode == DamageMode.NO_DECAY:
		return base
	match mode:
		DamageMode.DECAY_ON_WIN:
			if duel_result == DuelCommand.Context.Result.B_WIN:
				return max(0, base - (oppose_power + duel_diff))
			return max(0, base - oppose_power)
		DamageMode.DECAY_ON_LOSE:
			if duel_result == DuelCommand.Context.Result.B_WIN:
				return max(0, base - duel_diff)
			return base
	return base

static func _get_merged_rules(settle_card: Card, override_rules: Dictionary) -> Dictionary:
	var card_overrides: Dictionary = settle_card.get_rule_overrides()
	var merged := card_overrides.duplicate()
	for key in override_rules:
		merged[key] = override_rules[key]
	var base_rules: Dictionary = _settle_rules.get(settle_card.type, {})
	return _merge_rules(base_rules, merged)

static func _merge_rules(base: Dictionary, overrides: Dictionary) -> Dictionary:
	var has_override := false
	for key in overrides:
		if key in [Validator.LIFE_DAMAGE_MODE, Validator.MENTAL_DAMAGE_MODE, Validator.COMBAT_WILL_MODE, Validator.ATTACK_ORIENTATION]:
			has_override = true
			break
	if not has_override:
		return base
	var merged: Dictionary = base.duplicate()
	for key in overrides:
		if key in [Validator.LIFE_DAMAGE_MODE, Validator.MENTAL_DAMAGE_MODE, Validator.COMBAT_WILL_MODE, Validator.ATTACK_ORIENTATION]:
			merged[key] = overrides[key]
	return merged

static func _get_player_by_orientation(orientation: AttackOrientation, attacker: Player, defender: Player) -> Player:
	match orientation:
		AttackOrientation.DEFENDER:
			return defender
		AttackOrientation.ATTACKER:
			return attacker
	return null
