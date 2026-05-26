extends BehaviorCommand
class_name BuffCommand

class Context extends CommandContext:
	enum BuffMode {
		APPLY, OVERRIDE, REMOVE, DISPEL
	}
	var buff_modifiers: BuffModifiers = null
	var buff: Buff = null
	var mode: BuffMode = BuffMode.APPLY
	var stack_count: int = 1
	var source_card: Card = null
	var source_player: Player = null

	func set_buff_modifiers(p_modifiers: BuffModifiers) -> Context:
		buff_modifiers = p_modifiers
		return self
	func set_buff(p_buff: Buff) -> Context:
		buff = p_buff
		return self
	func set_mode(p_mode: BuffMode) -> Context:
		mode = p_mode
		return self
	func set_stack_count(p_count: int) -> Context:
		stack_count = p_count
		return self
	func set_source_card(p_card: Card) -> Context:
		source_card = p_card
		return self
	func set_source_player(p_player: Player) -> Context:
		source_player = p_player
		return self

static func create(
	modifiers: BuffModifiers,
	buff: Buff,
	mode: Context.BuffMode = Context.BuffMode.APPLY,
	stack_count: int = 1,
	source_card: Card = null,
	source_player: Player = null
) -> BuffCommand:
	var cmd: BuffCommand = BuffCommand.new(modifiers, buff, mode, stack_count, source_card, source_player)
	return cmd

func _init(
	modifiers: BuffModifiers,
	buff: Buff,
	mode: Context.BuffMode = Context.BuffMode.APPLY,
	stack_count: int = 1,
	source_card: Card = null,
	source_player: Player = Player.NULL_PLAYER,
	name_overriding: StringName = &"Buff",
	context_overriding: Context = Context.new()
) -> void:
	super._init(source_player.get_id(), name_overriding, context_overriding)
	_context.set_buff_modifiers(modifiers)
	_context.set_buff(buff)
	_context.set_mode(mode)
	_context.set_stack_count(stack_count)
	_context.set_source_card(source_card)
	_context.set_source_player(source_player)

func execute(game_state: GameState) -> void:
	var ctx: Context = _context as Context
	if not ctx.buff_modifiers or not ctx.buff:
		push_error("BuffCommand: 缺少目标 BuffModifiers 或 Buff")
		complete()
		return

	var bm := ctx.buff_modifiers
	var buff_name: StringName = ctx.buff.buff_name

	match ctx.mode:
		Context.BuffMode.APPLY:
			if bm.buffs.has(buff_name):
				var existing: Buff = bm.buffs[buff_name]
				if existing.locked:
					complete()
					return
				var target_stack = existing.stack_count + ctx.stack_count
				var old = existing.stack_count
				existing.stack_count = target_stack
				existing.on_stack_changed(old, target_stack)
			else:
				ctx.buff.stack_count = ctx.stack_count
				bm.buffs[buff_name] = ctx.buff
				ctx.buff.on_apply()
		Context.BuffMode.OVERRIDE:
			if bm.buffs.has(buff_name):
				var existing: Buff = bm.buffs[buff_name]
				if existing.locked:
					complete()
					return
				bm.buffs.erase(buff_name)
				existing.on_remove()
			ctx.buff.stack_count = ctx.stack_count
			bm.buffs[buff_name] = ctx.buff
			ctx.buff.on_apply()
		Context.BuffMode.REMOVE:
			if bm.buffs.has(buff_name):
				var existing: Buff = bm.buffs[buff_name]
				if existing.locked:
					complete()
					return
				var new_stack = existing.stack_count - ctx.stack_count
				if new_stack > 0:
					var old = existing.stack_count
					existing.stack_count = new_stack
					existing.on_stack_changed(old, new_stack)
				else:
					bm.buffs.erase(buff_name)
					existing.on_remove()
		Context.BuffMode.DISPEL:
			if bm.buffs.has(buff_name):
				var existing: Buff = bm.buffs[buff_name]
				if existing.locked:
					complete()
					return
				bm.buffs.erase(buff_name)
				existing.on_remove()
	_send_update(game_state, ctx)
	complete()

func _send_update(game_state: GameState, ctx: Context) -> void:
	RuleTrans.send_buff_modifiers_update(game_state, ctx.buff_modifiers, RenderRequest.ItemSet.EventType.UPDATE)
