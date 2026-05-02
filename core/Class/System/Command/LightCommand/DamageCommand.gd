extends BehaviorCommand
class_name DamageCommand

## 伤害标签掩码枚举
enum DamageTag {
	CUSTOM = 1 << 0,
	FIRE = 1 << 1,
	ICE = 1 << 2,
	LIGHTNING = 1 << 3,
	POISON = 1 << 4,
	BLEED = 1 << 5,
	HOLY = 1 << 6,
	SHADOW = 1 << 7,
}

## 伤害来源机制枚举
enum SourceMechanism {
	GENERAL = 0,
	NEGATIVE_STATE = 1,
	DRAIN = 2,
	CUSTOM = 3,
}

class Context extends CommandContext:
	var target_player: Player
	var health_damage: int          # 负数代表治疗
	var mental_damage: int          # 负数代表治疗
	var source_mechanism: int
	var source_player_id: int
	var source_custom_name: StringName
	var damage_tags_mask: int = 0
	var custom_damage_tags: PackedStringArray = PackedStringArray()
	var cached_health_damage: int
	var cached_mental_damage: int
	var ignore_cap: bool = false

	func modify_health_damage(new_value: int) -> void:
		if phase == 1:
			cached_health_damage = new_value

	func modify_mental_damage(new_value: int) -> void:
		if phase == 1:
			cached_mental_damage = new_value

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
	name_overriding: StringName = &"DamageCommand",
	context_overriding: Context = Context.new()
) -> void:
	super._init(source_id, name_overriding, context_overriding)
	_context.target_player = target_player
	_context.health_damage = health_dmg
	_context.mental_damage = mental_dmg
	_context.source_mechanism = mechanism
	_context.source_player_id = source_id
	_context.source_custom_name = source_custom
	_context.damage_tags_mask = damage_tags_mask
	_context.custom_damage_tags = custom_tags
	_context.ignore_cap = ignore_cap

func execute(game_state: GameState) -> void:
	var ctx = _context as Context
	match ctx.phase:
		0:
			ctx.cached_health_damage = ctx.health_damage
			ctx.cached_mental_damage = ctx.mental_damage
			ctx.phase = 1
		1:
			if not ctx.target_player:
				complete()
				return
			if ctx.cached_health_damage != 0:
				_apply_health_change(ctx.target_player, ctx.cached_health_damage, ctx.ignore_cap)
			if ctx.cached_mental_damage != 0:
				_apply_mental_change(ctx.target_player, ctx.cached_mental_damage, ctx.ignore_cap)
			RuleTrans.send_player_delta_updates([ctx.target_player], RenderRequest.ItemSet.EventType.ATTACK, ctx.source_player_id)
			complete()

## 应用生命值变化（伤害或治疗）
static func _apply_health_change(player: Player, delta: int, ignore_cap: bool) -> void:
	var new_value: int = player.HP - delta
	if delta <= 0 and not ignore_cap:  # 治疗且需钳位
		new_value = min(new_value, player.get_attribute(&"HP_max"))
	player.HP = new_value

## 应用精神值变化（伤害或治疗）
static func _apply_mental_change(player: Player, delta: int, ignore_cap: bool) -> void:
	var new_value: int = player.MP - delta
	if delta > 0:  # 伤害：不低于0
		new_value = max(0, new_value)
	elif not ignore_cap:  # 治疗且需钳位
		new_value = min(new_value, player.get_attribute(&"MP_max"))
	player.MP = new_value
