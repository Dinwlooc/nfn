extends PlayerAttributeCommand
class_name ActionPointCommand

## @context
class Context extends PlayerAttributeCommand.Context:
	## 行动点变更方式
	enum Operation { ADD, SUB, SET }
	## 变更量
	var amount: int = 0
	## 准备阶段缓存的变更量（保证虚拟化时不丢值）
	var cached_amount: int = 0
	## 变更方式
	var operation: Operation = Operation.ADD
	## 事件名，用于渲染与日志标识
	var event_name: StringName = &""

	## 链式设置变更方式
	func set_operation(op: Operation) -> Context:
		operation = op
		return self

	## 链式设置变更量（同时写入缓存）
	func set_amount(val: int) -> Context:
		amount = val
		cached_amount = val
		return self

	## 链式设置事件名
	func set_event_name(name: StringName) -> Context:
		event_name = name
		return self

## @seam_override
func _init(
	target: Player,
	amount: int,
	operation: Context.Operation,
	event_name: StringName = &"",
	name_overriding: StringName = &"ActionPointChange",
	context_overriding: Context = Context.new()
) -> void:
	context_overriding.set_target_player(target).set_amount(amount).set_operation(operation).set_event_name(event_name)
	super._init(target, name_overriding, context_overriding)

## 静态应用：执行行动点变更
static func do_apply(context: Context, _game_state: GameState) -> void:
	if context.is_virtual:
		return
	if not context.target_player:
		return
	match context.operation:
		Context.Operation.ADD:
			context.target_player.add_ap(context.cached_amount)
		Context.Operation.SUB:
			context.target_player.sub_ap(context.cached_amount)
		Context.Operation.SET:
			context.target_player.set_ap(context.cached_amount)

## @hook
func _on_apply_phase(_game_state: GameState, context_overriding: PlayerAttributeCommand.Context = _context as Context) -> void:
	if context_overriding is not Context:
		return
	do_apply(context_overriding, _game_state)
