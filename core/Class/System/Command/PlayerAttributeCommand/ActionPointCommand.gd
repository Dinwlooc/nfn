extends PlayerAttributeCommand
class_name ActionPointCommand

class Context extends PlayerAttributeCommand.Context:
	enum Operation { ADD, SUB, SET }
	var amount: int = 0
	var cached_amount: int = 0
	var operation: Operation = Operation.ADD
	var event_name: StringName = &""

	func set_operation(op: Operation) -> Context:
		operation = op
		return self

	func set_amount(val: int) -> Context:
		amount = val
		cached_amount = val
		return self

	func set_event_name(name: StringName) -> Context:
		event_name = name
		return self

func _init(
	target: Player,
	amount: int,
	operation: Context.Operation,
	event_name: StringName = &"",
	name_overriding: StringName = &"ActionPointChange",
	context_overriding: Context = Context.new()
) -> void:
	context_overriding.set_target_player(target)
	context_overriding.set_amount(amount)
	context_overriding.set_operation(operation)
	context_overriding.set_event_name(event_name)
	super._init(target, name_overriding, context_overriding)

func _on_apply_phase(game_state: GameState, ctx: PlayerAttributeCommand.Context) -> void:
	if not ctx.target_player:
		return
	match ctx.operation:
		Context.Operation.ADD:
			ctx.target_player.add_ap(ctx.cached_amount)
		Context.Operation.SUB:
			ctx.target_player.sub_ap(ctx.cached_amount)
		Context.Operation.SET:
			ctx.target_player.set_ap(ctx.cached_amount)
