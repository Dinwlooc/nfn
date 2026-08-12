extends PlayerAttributeCommand
class_name MoraleCommand

class Context extends PlayerAttributeCommand.Context:
	var attack_delta: int = 0
	var defense_delta: int = 0
	var cached_attack_delta: int = 0
	var cached_defense_delta: int = 0
	var source_player_id: int = 0
	var event_name: StringName = &""

	func set_attack_delta(v: int) -> Context:
		attack_delta = max(0, v)
		cached_attack_delta = attack_delta
		return self

	func set_defense_delta(v: int) -> Context:
		defense_delta = max(0, v)
		cached_defense_delta = defense_delta
		return self

	func set_source_player_id(id: int) -> Context:
		source_player_id = id
		return self

	func set_event_name(name: StringName) -> Context:
		event_name = name
		return self

func _init(
	target: Player,
	attack_delta: int,
	defense_delta: int,
	source_id: int = 0,
	event_name: StringName = &"",
	name_overriding: StringName = &"MoraleChange",
	context_overriding: Context = Context.new()
) -> void:
	context_overriding.set_target_player(target)
	context_overriding.set_attack_delta(attack_delta)
	context_overriding.set_defense_delta(defense_delta)
	context_overriding.set_source_player_id(source_id)
	context_overriding.set_event_name(event_name)
	super._init(target, name_overriding, context_overriding)

func _on_apply_phase(game_state: GameState, ctx: PlayerAttributeCommand.Context) -> void:
	if not ctx.target_player:
		return
	if ctx.cached_attack_delta > 0:
		ctx.target_player.add_morale_attack(ctx.cached_attack_delta)
	if ctx.cached_defense_delta > 0:
		ctx.target_player.add_morale_defense(ctx.cached_defense_delta)
