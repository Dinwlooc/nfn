class_name SkillCommand
extends BehaviorCommand

class Context extends CommandContext:
	enum Phase { INIT, SKILL, DONE }
	var skill_card: Card
	var target_area: Area
	var target_players: Array[Player] = []

	func get_primary_modifier_cards() -> Array[Card]:
		if skill_card:
			return [skill_card]
		return []

	func get_primary_modifier_players() -> Array[Player]:
		var players: Array[Player] = []
		if skill_card and skill_card.player:
			players.append(skill_card.player)
		for p in target_players:
			if p and not players.has(p):
				players.append(p)
		return players

func _init(
	card: Card,
	target_area: Area,
	target_players: Array[Player] = [],
	name_overriding: StringName = &"Skill",
	context_overriding: Context = Context.new()
) -> void:
	context_overriding.skill_card = card
	context_overriding.target_area = target_area
	context_overriding.target_players = target_players
	super._init(card.get_owner_id(), name_overriding, context_overriding)

func execute(game_state: GameState) -> void:
	var ctx = _context as Context
	match ctx.phase:
		Context.Phase.INIT:
			_on_init_phase(game_state, ctx)
		Context.Phase.SKILL:
			_on_skill_phase(game_state, ctx)
		Context.Phase.DONE:
			_on_done_phase(game_state, ctx)

func _on_init_phase(_game_state: GameState, ctx: Context) -> void:
	ctx.phase = Context.Phase.SKILL

func _on_skill_phase(_game_state: GameState, ctx: Context) -> void:
	ctx.phase = Context.Phase.DONE

func _on_done_phase(_game_state: GameState, _ctx: Context) -> void:
	complete()
