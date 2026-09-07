extends PlayerAttributeCommand
class_name MoraleCommand

## @context
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

## @seam_override
func _init(
	target: Player,
	attack_delta: int,
	defense_delta: int,
	source_id: int = 0,
	event_name: StringName = &"",
	name_overriding: StringName = &"MoraleChange",
	context_overriding: Context = Context.new()
) -> void:
	context_overriding.set_target_player(target).set_attack_delta(attack_delta).set_defense_delta(defense_delta).set_source_player_id(source_id).set_event_name(event_name)
	super._init(target, name_overriding, context_overriding)

## 静态应用：修改士气相关属性
static func do_apply(context: Context, _game_state: GameState) -> void:
	if context.is_virtual:
		return
	if not context.target_player:
		return
	if context.cached_attack_delta > 0:
		context.target_player.add_morale_attack(context.cached_attack_delta)
	if context.cached_defense_delta > 0:
		context.target_player.add_morale_defense(context.cached_defense_delta)

## @hook
func _on_apply_phase(_game_state: GameState, context_overriding: PlayerAttributeCommand.Context = _context as Context) -> void:
	var ctx := context_overriding as Context
	if not ctx:
		return
	do_apply(ctx, _game_state)
