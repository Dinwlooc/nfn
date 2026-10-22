extends BehaviorCommand
class_name BuffCommand

## @context
class Context extends CommandContext:
	## Buff 命令的三阶段状态
	enum Phase {
		INIT,
		APPLY,
		DONE
	}
	## Buff 操作模式
	enum BuffMode {
		APPLY, OVERRIDE, REMOVE, DISPEL
	}
	## 目标玩家的 Buff 修饰器集合
	var buff_modifiers: BuffModifiers = null
	## 要操作的 Buff 实例
	var buff: Buff = null
	## 操作模式
	var mode: BuffMode = BuffMode.APPLY
	## 层数：叠加/移除时的本次增减量，覆盖时为目标层数
	var stack_count: int = 1
	## 来源卡牌
	var source_card: Card = null
	## 来源玩家
	var source_player: Player = null

	## 链式设置目标 Buff 修饰器集合
	func set_buff_modifiers(p_modifiers: BuffModifiers) -> Context:
		buff_modifiers = p_modifiers
		return self
	## 链式设置要操作的 Buff
	func set_buff(p_buff: Buff) -> Context:
		buff = p_buff
		return self
	## 链式设置操作模式
	func set_mode(p_mode: BuffMode) -> Context:
		mode = p_mode
		return self
	## 链式设置层数
	func set_stack_count(p_count: int) -> Context:
		stack_count = p_count
		return self
	## 链式设置来源卡牌
	func set_source_card(p_card: Card) -> Context:
		source_card = p_card
		return self
	## 链式设置来源玩家
	func set_source_player(p_player: Player) -> Context:
		source_player = p_player
		return self

## @internal @seam_override
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

## @facade @template
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

## 叠加模式：已有同 Buff 则累加层数并回调，否则首次附加
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

## 覆盖模式：移除同名旧 Buff 后附加新的
## @atomic
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

## 移除模式：扣减层数，归零则移除
## @atomic
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

## 驱散模式：直接移除整个 Buff
## @atomic
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
## @hook @operation(do_apply)
func _on_apply_phase(game_state: GameState, context_overriding: CommandContext = _context as Context) -> void:
	BuffCommand.do_apply(context_overriding as Context, game_state)
## @hook @operation(do_send_update) @delegates(complete)
func _on_done_phase(game_state: GameState, context_overriding: CommandContext = _context as Context) -> void:
	BuffCommand.do_send_update(context_overriding as Context, game_state)
	complete()
