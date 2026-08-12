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
	var cached_health_damage: int
	var cached_mental_damage: int
	var ignore_cap: bool = false

	func modify_health_damage(new_value: int) -> void:
		if phase == PlayerAttributeCommand.Context.Phase.INIT:
			cached_health_damage = new_value

	func modify_mental_damage(new_value: int) -> void:
		if phase == PlayerAttributeCommand.Context.Phase.INIT:
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
	context_overriding.set_target_player(target_player)
	context_overriding.health_damage = health_dmg
	context_overriding.mental_damage = mental_dmg
	context_overriding.cached_health_damage = health_dmg
	context_overriding.cached_mental_damage = mental_dmg
	context_overriding.source_mechanism = mechanism
	context_overriding.source_player_id = source_id
	context_overriding.source_custom_name = source_custom
	context_overriding.damage_tags_mask = damage_tags_mask
	context_overriding.custom_damage_tags = custom_tags
	context_overriding.ignore_cap = ignore_cap
	super._init(target_player, name_overriding, context_overriding)

func get_update_event_type() -> RenderRequest.ItemSet.EventType:
	return RenderRequest.ItemSet.EventType.ATTACK

func _on_apply_phase(game_state: GameState, ctx: PlayerAttributeCommand.Context) -> void:
	if not ctx.target_player:
		ctx.phase = Context.Phase.DONE
		return
	if ctx.cached_health_damage != 0:
		_apply_health_change(ctx.target_player, ctx.cached_health_damage, ctx.ignore_cap)
	if ctx.cached_mental_damage != 0:
		_apply_mental_change(ctx.target_player, ctx.cached_mental_damage, ctx.ignore_cap)
	ctx.phase = Context.Phase.DONE

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
