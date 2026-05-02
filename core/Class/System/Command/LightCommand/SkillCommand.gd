class_name SkillCommand
extends BehaviorCommand

class Context extends CommandContext:
	enum Phase {
		INIT, SKILL, DONE
	}
	var skill_card: Card
	var target_area: Area
	var target_player_ids: PackedInt32Array   # 新增

	func get_primary_modifier_cards() -> Array[Card]:
		if skill_card:
			return [skill_card]
		return []

	func get_primary_modifier_player_ids() -> PackedInt32Array:
		var ids: PackedInt32Array = []
		if skill_card and skill_card.player:
			ids.append(skill_card.player.player_id)
		for pid in target_player_ids:
			if pid != 0 and not ids.has(pid):
				ids.append(pid)
		return ids

func _init(card: Card, target_area: Area, target_player_ids: PackedInt32Array = PackedInt32Array(), name_overriding: StringName = &"Skill") -> void:
	var ctx = Context.new()
	ctx.skill_card = card
	ctx.target_area = target_area
	ctx.target_player_ids = target_player_ids
	super._init(card.get_owner_id(), name_overriding, ctx)

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
