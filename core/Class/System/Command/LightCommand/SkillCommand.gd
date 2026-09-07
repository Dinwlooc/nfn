extends BehaviorCommand
class_name SkillCommand

## @context
class Context extends CommandContext:
	enum Phase { INIT, SKILL, DONE }
	var skill_card: Card
	var target_area: Area
	var target_players: Array[Player] = []

	func set_skill_card(card: Card) -> Context:
		skill_card = card
		return self
	func set_target_area(area: Area) -> Context:
		target_area = area
		return self
	func set_target_players(players: Array[Player]) -> Context:
		target_players = players
		return self

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

## @seam_override
func _init(
	card: Card,
	target_area: Area,
	target_players: Array[Player] = [],
	name_overriding: StringName = &"Skill",
	context_overriding: Context = Context.new()
) -> void:
	context_overriding.set_skill_card(card).set_target_area(target_area).set_target_players(target_players)
	super._init(card.get_owner_id(), name_overriding, context_overriding)

## @template
func execute(game_state: GameState) -> void:
	var ctx: Context = _context
	match ctx.phase:
		Context.Phase.INIT:
			ctx.phase = Context.Phase.SKILL
			_on_init_phase(game_state, ctx)
		Context.Phase.SKILL:
			ctx.phase = Context.Phase.DONE
			_on_skill_phase(game_state, ctx)
		Context.Phase.DONE:
			_on_done_phase(game_state, ctx)
## 技能命令本身不产生任何逻辑，仅作为修饰占位。设计如此。
## @hook
func _on_init_phase(_game_state: GameState, _context: Context) -> void:
	pass
## 技能命令本身不产生任何逻辑，仅作为修饰占位。设计如此。
## @hook
func _on_skill_phase(_game_state: GameState, context_overriding: CommandContext = _context as Context) -> void:
	# 无操作
	pass
## @hook
func _on_done_phase(_game_state: GameState, _context: CommandContext = _context as Context) -> void:
	complete()
