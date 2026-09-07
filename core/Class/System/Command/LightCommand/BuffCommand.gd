extends BehaviorCommand
class_name BuffCommand

## @context
class Context extends CommandContext:
	enum Phase {
		INIT,
		APPLY,
		DONE
	}
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

## @seam_override
func _init(
	modifiers: BuffModifiers,
	buff: Buff,
	mode: Context.BuffMode = Context.BuffMode.APPLY,
	stack_count: int = 1,
	source_card: Card = null,
	source_player: Player = Player.PUBLIC_PLAYER,
	name_overriding: StringName = &"Buff",
	context_overriding: Context = Context.new()
) -> void:
	context_overriding.set_buff_modifiers(modifiers).set_buff(buff).set_mode(mode).set_stack_count(stack_count).set_source_card(source_card).set_source_player(source_player)
	super._init(source_player.get_id(), name_overriding, context_overriding)

## @template
func execute(game_state: GameState) -> void:
	var ctx: Context = _context
	match ctx.phase:
		Context.Phase.INIT:
			ctx.phase = Context.Phase.APPLY
			_on_init_phase(game_state, ctx)
		Context.Phase.APPLY:
			ctx.phase = Context.Phase.DONE
			_on_apply_phase(game_state, ctx)
		Context.Phase.DONE:
			_on_done_phase(game_state, ctx)

## 静态应用：执行 Buff 增删改逻辑
static func do_apply(context: Context, _game_state: GameState) -> void:
	if context.is_virtual:
		return
	if not context.buff_modifiers or not context.buff:
		return
	match context.mode:
		Context.BuffMode.APPLY:
			_do_apply_apply(context)
		Context.BuffMode.OVERRIDE:
			_do_apply_override(context)
		Context.BuffMode.REMOVE:
			_do_apply_remove(context)
		Context.BuffMode.DISPEL:
			_do_apply_dispel(context)

static func _do_apply_apply(context: Context) -> void:
	var bm := context.buff_modifiers
	var buff_name: StringName = context.buff.buff_name
	if bm.buffs.has(buff_name):
		var existing: Buff = bm.buffs[buff_name]
		if existing.locked:
			return
		var target_stack = existing.stack_count + context.stack_count
		var old = existing.stack_count
		existing.stack_count = target_stack
		existing.on_stack_changed(old, target_stack)
	else:
		context.buff.stack_count = context.stack_count
		bm.buffs[buff_name] = context.buff
		context.buff.on_apply()

static func _do_apply_override(context: Context) -> void:
	var bm := context.buff_modifiers
	var buff_name: StringName = context.buff.buff_name
	if bm.buffs.has(buff_name):
		var existing: Buff = bm.buffs[buff_name]
		if existing.locked:
			return
		bm.buffs.erase(buff_name)
		existing.on_remove()
	context.buff.stack_count = context.stack_count
	bm.buffs[buff_name] = context.buff
	context.buff.on_apply()

static func _do_apply_remove(context: Context) -> void:
	var bm := context.buff_modifiers
	var buff_name: StringName = context.buff.buff_name
	if bm.buffs.has(buff_name):
		var existing: Buff = bm.buffs[buff_name]
		if existing.locked:
			return
		var new_stack = existing.stack_count - context.stack_count
		if new_stack > 0:
			var old = existing.stack_count
			existing.stack_count = new_stack
			existing.on_stack_changed(old, new_stack)
		else:
			bm.buffs.erase(buff_name)
			existing.on_remove()

static func _do_apply_dispel(context: Context) -> void:
	var bm := context.buff_modifiers
	var buff_name: StringName = context.buff.buff_name
	if bm.buffs.has(buff_name):
		var existing: Buff = bm.buffs[buff_name]
		if existing.locked:
			return
		bm.buffs.erase(buff_name)
		existing.on_remove()

## 静态发送更新
static func do_send_update(context: Context, game_state: GameState) -> void:
	if context.is_virtual:
		return
	RuleTrans.send_buff_modifiers_update(game_state, context.buff_modifiers, RenderRequest.ItemSet.EventType.UPDATE)

## @hook
func _on_init_phase(_game_state: GameState, _context: Context) -> void:
	pass

## @hook
func _on_apply_phase(game_state: GameState, context_overriding: CommandContext = _context as Context) -> void:
	do_apply(context_overriding as Context, game_state)

## @hook
func _on_done_phase(game_state: GameState, context_overriding: CommandContext = _context as Context) -> void:
	do_send_update(context_overriding as Context, game_state)
	complete()
