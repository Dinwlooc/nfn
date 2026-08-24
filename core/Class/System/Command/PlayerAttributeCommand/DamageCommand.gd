extends PlayerAttributeCommand
class_name DamageCommand

enum DamageTag { CUSTOM = 1 << 0, FIRE = 1 << 1, ICE = 1 << 2, LIGHTNING = 1 << 3, POISON = 1 << 4, BLEED = 1 << 5, HOLY = 1 << 6, SHADOW = 1 << 7 }
enum SourceMechanism { GENERAL = 0, NEGATIVE_STATE = 1, DRAIN = 2, CUSTOM = 3 }

class Context extends PlayerAttributeCommand.Context:
	var health_damage: int
	var mental_damage: int
	var source_mechanism: int
	var source_player_id: int
	var source_custom_name: StringName
	var damage_tags_mask: int = 0
	var custom_damage_tags: PackedStringArray = PackedStringArray()
	var ignore_cap: bool = false
	## 内置属性修饰器，存储初始值及后续合并的目标修饰器
	var damage_modifiers: AttributeModifiers = AttributeModifiers.new()
	## 是否允许健康结果反转（最终值可为负）
	var allow_negative_health_result: bool = false
	## 是否允许精神结果反转（最终值可为负）
	var allow_negative_mental_result: bool = false
	## 当前命令对 HP 是伤害（true）还是治疗（false）
	var is_health_damage: bool = false
	## 当前命令对 MP 是伤害（true）还是治疗（false）
	var is_mental_damage: bool = false

	func modify_health_damage(new_value: int) -> void:
		if phase == PlayerAttributeCommand.Context.Phase.INIT:
			health_damage = new_value
			is_health_damage = health_damage > 0

	func modify_mental_damage(new_value: int) -> void:
		if phase == PlayerAttributeCommand.Context.Phase.INIT:
			mental_damage = new_value
			is_mental_damage = mental_damage > 0

	func add_damage_tag(tag: DamageTag, custom_name: StringName = &"") -> void:
		if tag == DamageTag.CUSTOM:
			if custom_name.is_empty():
				return
			var tag_str = String(custom_name)
			if custom_damage_tags.has(tag_str):
				return
			custom_damage_tags.append(tag_str)
			damage_tags_mask |= DamageTag.CUSTOM
		else:
			damage_tags_mask |= tag

	func remove_damage_tag(tag: DamageTag, custom_name: StringName = &"") -> void:
		if tag == DamageTag.CUSTOM:
			if custom_name.is_empty():
				return
			var tag_str = String(custom_name)
			var idx = custom_damage_tags.find(tag_str)
			if idx != -1:
				custom_damage_tags.remove_at(idx)
				if custom_damage_tags.is_empty():
					damage_tags_mask &= ~DamageTag.CUSTOM
		else:
			damage_tags_mask &= ~tag

	func clear_damage_tags() -> void:
		damage_tags_mask = 0
		custom_damage_tags.clear()

	## 预测健康最终值（伤害量或治疗量，正数）
	func predict_health_final() -> int:
		var attr: StringName = &"received_hp_damage" if is_health_damage else &"received_hp_heal"
		# 合并目标玩家的所有修饰器（同名覆盖）
		damage_modifiers.merge_modifiers_from(target_player.attributeModifiers, attr, attr)
		var val: float = damage_modifiers.get_final_value(attr)
		if not allow_negative_health_result:
			val = max(0.0, val)
		return int(round(val))

	## 预测精神最终值（伤害量或治疗量，正数）
	func predict_mental_final() -> int:
		var attr: StringName = &"received_mp_damage" if is_mental_damage else &"received_mp_heal"
		damage_modifiers.merge_modifiers_from(target_player.attributeModifiers, attr, attr)
		var val: float = damage_modifiers.get_final_value(attr)
		if not allow_negative_mental_result:
			val = max(0.0, val)
		return int(round(val))

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

	# 根据传入伤害的正负，将绝对值作为基础修饰写入 damage_modifiers
	if health_dmg > 0:
		context_overriding.damage_modifiers.add_modifier(&"received_hp_damage", AttributeModifiers.TYPE_BASE_ADD, &"initial", float(health_dmg))
	elif health_dmg < 0:
		context_overriding.damage_modifiers.add_modifier(&"received_hp_heal", AttributeModifiers.TYPE_BASE_ADD, &"initial", float(-health_dmg))
	if mental_dmg > 0:
		context_overriding.damage_modifiers.add_modifier(&"received_mp_damage", AttributeModifiers.TYPE_BASE_ADD, &"initial", float(mental_dmg))
	elif mental_dmg < 0:
		context_overriding.damage_modifiers.add_modifier(&"received_mp_heal", AttributeModifiers.TYPE_BASE_ADD, &"initial", float(-mental_dmg))

	super._init(target_player, name_overriding, context_overriding)

func get_update_event_type() -> RenderRequest.ItemSet.EventType:
	return RenderRequest.ItemSet.EventType.ATTACK

func _on_apply_phase(game_state: GameState, ctx: PlayerAttributeCommand.Context) -> void:
	if not ctx.target_player:
		return
	var c: Context = ctx as Context
	if not c:
		return
	# 应用健康变化
	if c.health_damage != 0:
		var final_abs: int = c.predict_health_final()
		var delta: int = final_abs if c.is_health_damage else -final_abs
		_apply_health_change(c.target_player, delta, c.ignore_cap)
	# 应用精神变化
	if c.mental_damage != 0:
		var final_abs: int = c.predict_mental_final()
		var delta: int = final_abs if c.is_mental_damage else -final_abs
		_apply_mental_change(c.target_player, delta, c.ignore_cap)

static func _apply_health_change(player: Player, delta: int, ignore_cap: bool) -> void:
	var new_value: int = player.HP - delta
	if delta <= 0 and not ignore_cap:
		new_value = min(new_value, player.get_attribute(&"HP_max"))
	player.HP = new_value

static func _apply_mental_change(player: Player, delta: int, ignore_cap: bool) -> void:
	var new_value: int = player.MP - delta
	if delta > 0:
		new_value = max(0, new_value)
	elif not ignore_cap:
		new_value = min(new_value, player.get_attribute(&"MP_max"))
	player.MP = new_value
