## 守区结算规则类（纯函数/验证器模式）
extends RefCounted
class_name RuleSettle

## 验证器名称常量
class Validator:
	const LIFE_DAMAGE_MODE: StringName = &"life_damage_mode"          ## 结算生命伤害模式
	const MENTAL_DAMAGE_MODE: StringName = &"mental_damage_mode"      ## 结算精神伤害模式
	const COMBAT_WILL_MODE: StringName = &"combat_will_mode"          ## 结算战意模式
	const ATTACK_ORIENTATION: StringName = &"attack_orientation"      ## 攻击朝向

## 伤害模式枚举
enum DamageMode {
	NONE = 0,           ## 不造成此类型伤害
	NO_DECAY = 1,       ## 造成且不受结算衰减
	DECAY_ON_WIN = 2,   ## 在拼点成功（不失败）时衰减对方威力，失败时衰减对方威力+差值
	DECAY_ON_LOSE = 3,  ## 在拼点失败时仅衰减差值
}

## 攻击朝向枚举
enum AttackOrientation {
	DEFENDER = 0,       ## 对防守方（守区玩家）造成伤害
	ATTACKER = 1,       ## 对攻击方（出牌玩家）造成伤害
}

## 战意掩码标志位
enum CombatWillFlag {
	ENABLE_BASE = 1 << 0,        ## 是否获得基础战意（数值为结算牌威力）
	TYPE_IS_DEFENSE = 1 << 1,    ## 战意类型：0=攻击，1=防御
	EXTRA_ON_SETTLE_WIN = 1 << 2, ## 结算牌拼点胜利（A_WIN）时，获得差值额外战意
	EXTRA_ON_OPPOSE_WIN = 1 << 3, ## 对抗牌拼点胜利（B_WIN）时，获得差值额外战意
}

## 结算结果类（纯数据容器）
class Result:
	var target: Player           ## 伤害目标玩家
	var health_damage_value: int               ## 生命伤害数值
	var mental_damage_value: int               ## 精神伤害数值
	var combat_will_grants: Array[CombatWillGrant]  ## 战意授予信息列表
	func _init() -> void:
		combat_will_grants = []

	## 战意授予条目
class CombatWillGrant:
	var target_player: Player   ## 获得战意的玩家
	var is_defense: bool        ## 是否为防御战意
	var base_value: int         ## 基础战意值
	var extra_value: int        ## 额外战意值（差值）
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

## 计算结算结果（纯函数）
## @param settle_card 结算牌实例
## @param oppose_card 对抗牌实例（可为 null）
## @param duel_result 拼点结果枚举
## @param duel_diff 拼点差值（非负整数）
## @param is_unilateral 是否单方面结算（无对抗牌）
## @param attacker 攻击方玩家（出牌者）
## @param defender 防守方玩家（守区玩家）
## @param override_rules 覆盖规则字典
## @return SettleResult 结算结果容器
static func evaluate(settle_card: Card, oppose_card: Card, duel_result: int, duel_diff: int, is_unilateral: bool, attacker: Player, defender: Player, override_rules: Dictionary = {}) -> Result:
	if not settle_card:
		return Result.new()
	var card_overrides: Dictionary = settle_card.get_rule_overrides()
	var merged_overrides = card_overrides.duplicate()
	for key in override_rules:
		merged_overrides[key] = override_rules[key]
	var card_type: StringName = settle_card.type
	var base_rules: Dictionary = _settle_rules.get(card_type, {})
	var rules: Dictionary = _merge_rules(base_rules, merged_overrides)
	var base_power: int = settle_card.get_attribute(&"power")
	var oppose_power: int = oppose_card.get_attribute(&"power") if oppose_card else 0
	# 计算伤害数值
	var health_mode: DamageMode = rules.get(Validator.LIFE_DAMAGE_MODE, DamageMode.NONE)
	var mental_mode: DamageMode = rules.get(Validator.MENTAL_DAMAGE_MODE, DamageMode.NONE)
	var health_dmg: int = _calc_damage(base_power, health_mode, duel_result, duel_diff, oppose_power, is_unilateral)
	var mental_dmg: int = _calc_damage(base_power, mental_mode, duel_result, duel_diff, oppose_power, is_unilateral)
	# 确定伤害目标
	var orientation: AttackOrientation = rules.get(Validator.ATTACK_ORIENTATION, AttackOrientation.DEFENDER)
	var target: Player = _get_player_by_orientation(orientation, attacker, defender)
	# 构建结果对象
	var result: Result = Result.new()
	result.target = target
	result.health_damage_value = health_dmg
	result.mental_damage_value = mental_dmg
	# 生成战意授予信息
	_generate_combat_will_grants(settle_card, oppose_card, duel_result, duel_diff, is_unilateral, rules.get(Validator.COMBAT_WILL_MODE, 0), attacker, defender, result.combat_will_grants)
	return result

## 合并基础规则与覆盖规则
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

## 根据朝向返回对应玩家
static func _get_player_by_orientation(orientation: AttackOrientation, attacker: Player, defender: Player) -> Player:
	match orientation:
		AttackOrientation.DEFENDER:
			return defender
		AttackOrientation.ATTACKER:
			return attacker
	return null

## 计算最终伤害值（纯函数）
## @param base 基础伤害
## @param mode 伤害衰减模式
## @param duel_result 拼点结果
## @param duel_diff 拼点差值
## @param oppose_power 对抗牌威力
## @param is_unilateral 是否单方面
static func _calc_damage(base: int, mode: DamageMode, duel_result: int, duel_diff: int, oppose_power: int, is_unilateral: bool) -> int:
	if base <= 0 or mode == DamageMode.NONE:
		return 0
	if is_unilateral or mode == DamageMode.NO_DECAY:
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

## 生成战意授予条目列表（无副作用）
static func _generate_combat_will_grants(settle_card: Card, oppose_card: Card, duel_result: int, duel_diff: int, is_unilateral: bool, mask: int, attacker: Player, defender: Player, out_grants: Array) -> void:
	if mask == 0:
		return
	var settle_owner: Player = settle_card.player if settle_card else null
	var oppose_owner: Player = oppose_card.player if oppose_card else null
	if not settle_owner:
		return
	var is_defense: bool = (mask & CombatWillFlag.TYPE_IS_DEFENSE) != 0
	# 基础战意
	if mask & CombatWillFlag.ENABLE_BASE:
		var base_val: int = settle_card.get_attribute(&"power")
		if base_val > 0:
			out_grants.append(CombatWillGrant.new(settle_owner, is_defense, base_val, 0))
	# 结算牌胜利额外战意
	if not is_unilateral and duel_result == DuelCommand.Context.Result.A_WIN and (mask & CombatWillFlag.EXTRA_ON_SETTLE_WIN) and duel_diff > 0:
		out_grants.append(CombatWillGrant.new(settle_owner, is_defense, 0, duel_diff))
	# 对抗牌胜利额外战意
	if not is_unilateral and duel_result == DuelCommand.Context.Result.B_WIN and oppose_owner and (mask & CombatWillFlag.EXTRA_ON_OPPOSE_WIN) and duel_diff > 0:
		out_grants.append(CombatWillGrant.new(oppose_owner, is_defense, 0, duel_diff))
