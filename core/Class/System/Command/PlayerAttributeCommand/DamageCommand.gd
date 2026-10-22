extends PlayerAttributeCommand
class_name DamageCommand

## 伤害标签位掩码；CUSTOM 需配合自定义标签名使用
enum DamageTag { CUSTOM = 1 << 0, FIRE = 1 << 1, ICE = 1 << 2, LIGHTNING = 1 << 3, POISON = 1 << 4, BLEED = 1 << 5, HOLY = 1 << 6, SHADOW = 1 << 7 }
## 伤害来源机制分类
enum SourceMechanism { GENERAL = 0, NEGATIVE_STATE = 1, DRAIN = 2, CUSTOM = 3 }

## @context
class Context extends PlayerAttributeCommand.Context:
	## 生命伤害（正数伤害、负数治疗）
	var health_damage: int
	## 法力伤害（正数伤害、负数治疗）
	var mental_damage: int
	## 伤害来源机制（见 SourceMechanism）
	var source_mechanism: int
	## 伤害来源玩家 id
	var source_player_id: int
	## 自定义来源名（机制为 CUSTOM 时使用）
	var source_custom_name: StringName
	## 伤害标签位掩码
	var damage_tags_mask: int = 0
	## 自定义伤害标签名列表
	var custom_damage_tags: PackedStringArray = PackedStringArray()
	## 是否忽略治疗上限
	var ignore_cap: bool = false
	## 本次伤害的修饰器集合
	var damage_modifiers: AttributeModifiers = AttributeModifiers.new()
	## 是否允许生命结果为负
	var allow_negative_health_result: bool = false
	## 是否允许法力结果为负
	var allow_negative_mental_result: bool = false
	## 本次是否为生命伤害（而非治疗）
	var is_health_damage: bool = false
	## 本次是否为法力伤害（而非治疗）
	var is_mental_damage: bool = false

	## 准备阶段缓存的生命侧最终增减量
	var cached_health_delta: int = 0
	## 准备阶段缓存的法力侧最终增减量
	var cached_mental_delta: int = 0

	## 仅在 INIT 阶段可改写生命伤害值，并同步伤害/治疗标记
	func modify_health_damage(new_value: int) -> Context:
		if phase == Phase.INIT:
			health_damage = new_value
			is_health_damage = health_damage > 0
		return self

	## 仅在 INIT 阶段可改写法力伤害值，并同步伤害/治疗标记
	func modify_mental_damage(new_value: int) -> Context:
		if phase == Phase.INIT:
			mental_damage = new_value
			is_mental_damage = mental_damage > 0
		return self

	## 链式追加伤害标签；CUSTOM 需给出非空自定义名
	## @side_effect
	func add_damage_tag(tag: DamageTag, custom_name: StringName = &"") -> Context:
		if tag == DamageTag.CUSTOM:
			if custom_name.is_empty():
				return self
			var tag_str = String(custom_name)
			if custom_damage_tags.has(tag_str):
				return self
			custom_damage_tags.append(tag_str)
			damage_tags_mask |= DamageTag.CUSTOM
		else:
			damage_tags_mask |= tag
		return self

	## 链式移除伤害标签
	## @side_effect
	func remove_damage_tag(tag: DamageTag, custom_name: StringName = &"") -> Context:
		if tag == DamageTag.CUSTOM:
			if custom_name.is_empty():
				return self
			var tag_str = String(custom_name)
			var idx = custom_damage_tags.find(tag_str)
			if idx != -1:
				custom_damage_tags.remove_at(idx)
				if custom_damage_tags.is_empty():
					damage_tags_mask &= ~DamageTag.CUSTOM
		else:
			damage_tags_mask &= ~tag
		return self

	## 清空全部伤害标签
	## @side_effect
	func clear_damage_tags() -> Context:
		damage_tags_mask = 0
		custom_damage_tags.clear()
		return self

	## 预判生命侧最终值：把目标玩家的受击/受疗修饰器合入后求值
	## @side_effect
	func predict_health_final() -> int:
		var attr: StringName = &"received_hp_damage" if is_health_damage else &"received_hp_heal"
		damage_modifiers.merge_modifiers_from(target_player.attributeModifiers, attr, attr)
		var val: float = damage_modifiers.get_final_value(attr)
		if not allow_negative_health_result:
			val = max(0.0, val)
		return int(round(val))

	## 预判法力侧最终值：把目标玩家的受击/受疗修饰器合入后求值
	## @side_effect
	func predict_mental_final() -> int:
		var attr: StringName = &"received_mp_damage" if is_mental_damage else &"received_mp_heal"
		damage_modifiers.merge_modifiers_from(target_player.attributeModifiers, attr, attr)
		var val: float = damage_modifiers.get_final_value(attr)
		if not allow_negative_mental_result:
			val = max(0.0, val)
		return int(round(val))

## @seam_override
func _init(
	target_player: Player,
	health_dmg: int,
	mental_dmg: int,
	mechanism: int = SourceMechanism.GENERAL,
	source_id: int = 0,
	source_custom: StringName = &"",
	damage_tags_mask: int = 0,
	custom_tags: PackedStringArray = PackedStringArray(),
	ignore_cap: bool = false,
	allow_negative_health: bool = false,
	allow_negative_mental: bool = false,
	name_overriding: StringName = &"DamageCommand",
	context_overriding: Context = Context.new()
) -> void:
	context_overriding.set_target_player(target_player)
	context_overriding.health_damage = health_dmg
	context_overriding.mental_damage = mental_dmg
	context_overriding.is_health_damage = health_dmg > 0
	context_overriding.is_mental_damage = mental_dmg > 0
	context_overriding.source_mechanism = mechanism
	context_overriding.source_player_id = source_id
	context_overriding.source_custom_name = source_custom
	context_overriding.damage_tags_mask = damage_tags_mask
	context_overriding.custom_damage_tags = custom_tags
	context_overriding.ignore_cap = ignore_cap
	context_overriding.allow_negative_health_result = allow_negative_health
	context_overriding.allow_negative_mental_result = allow_negative_mental

	if health_dmg > 0:
		context_overriding.damage_modifiers.add_modifier(&"received_hp_damage", AttributeModifiers.TYPE_BASE_ADD, &"initial", float(health_dmg))
	elif health_dmg < 0:
		context_overriding.damage_modifiers.add_modifier(&"received_hp_heal", AttributeModifiers.TYPE_BASE_ADD, &"initial", float(-health_dmg))
	if mental_dmg > 0:
		context_overriding.damage_modifiers.add_modifier(&"received_mp_damage", AttributeModifiers.TYPE_BASE_ADD, &"initial", float(mental_dmg))
	elif mental_dmg < 0:
		context_overriding.damage_modifiers.add_modifier(&"received_mp_heal", AttributeModifiers.TYPE_BASE_ADD, &"initial", float(-mental_dmg))

	super._init(target_player, name_overriding, context_overriding)

## 伤害命令对应的渲染事件类型为攻击
## @override @hook
func get_update_event_type() -> RenderRequest.ItemSet.EventType:
	return RenderRequest.ItemSet.EventType.ATTACK

## 静态准备：预计算最终伤害/治疗值并缓存
static func do_prepare(context: Context, _game_state: GameState) -> void:
	if not context.target_player:
		return
	if context.health_damage != 0:
		var abs_val = context.predict_health_final()
		context.cached_health_delta = abs_val if context.is_health_damage else -abs_val
	if context.mental_damage != 0:
		var abs_val = context.predict_mental_final()
		context.cached_mental_delta = abs_val if context.is_mental_damage else -abs_val

## 静态应用：使用缓存的最终值修改玩家属性
static func do_apply(context: Context, _game_state: GameState) -> void:
	if context.is_virtual:
		return
	if not context.target_player:
		return
	if context.health_damage != 0:
		_apply_health_change(context.target_player, context.cached_health_delta, context.ignore_cap)
	if context.mental_damage != 0:
		_apply_mental_change(context.target_player, context.cached_mental_delta, context.ignore_cap)

## 静态辅助：把生命侧增减量写入玩家（治疗受上限约束，除非 ignore_cap）
## @atomic
static func _apply_health_change(player: Player, delta: int, ignore_cap: bool) -> void:
	var new_value: int = player.HP - delta
	if delta <= 0 and not ignore_cap:
		new_value = min(new_value, player.get_attribute(&"HP_max"))
	player.HP = new_value

## 静态辅助：把法力侧增减量写入玩家（伤害下限 0，治疗受上限约束）
## @atomic
static func _apply_mental_change(player: Player, delta: int, ignore_cap: bool) -> void:
	var new_value: int = player.MP - delta
	if delta > 0:
		new_value = max(0, new_value)
	elif not ignore_cap:
		new_value = min(new_value, player.get_attribute(&"MP_max"))
	player.MP = new_value

## @hook
func _on_init_phase(game_state: GameState, context_overriding: PlayerAttributeCommand.Context = _context as Context) -> void:
	var ctx := context_overriding as Context
	if not ctx:
		return
	do_prepare(ctx, game_state)

## @hook
func _on_apply_phase(game_state: GameState, context_overriding: PlayerAttributeCommand.Context = _context as Context) -> void:
	var ctx := context_overriding as Context
	if not ctx:
		return
	do_apply(ctx, game_state)
