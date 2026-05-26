## 行动点变动命令
extends BehaviorCommand
class_name ActionPointCommand

## 行动点变动上下文类
class Context extends CommandContext:
	## 影响类型：add（增加）、sub（减少）、set（设置）
	enum Operation {
		ADD,
		SUB,
		SET
	}
	var player: Player = null          ## 被影响的玩家对象
	var amount: int = 0                ## 影响值（正数）
	var operation: Operation = Operation.ADD  ## 操作类型
	var event_name: StringName = &""   ## 关联的事件名（如 &"play_card"）

	## 设置增加操作（链式调用）
	func set_add(value: int) -> Context:
		operation = Operation.ADD
		amount = value
		return self

	## 设置减少操作（链式调用）
	func set_sub(value: int) -> Context:
		operation = Operation.SUB
		amount = value
		return self

	## 设置设置操作（链式调用）
	func set_set(value: int) -> Context:
		operation = Operation.SET
		amount = value
		return self

	## 设置事件名
	func set_event_name(name: StringName) -> Context:
		event_name = name
		return self

	## 设置被影响的玩家
	func set_player(p_player: Player) -> Context:
		player = p_player
		return self

	## 获取主修饰玩家ID（被影响的玩家）
	func get_primary_modifier_player_ids() -> PackedInt32Array:
		if not player:
			return PackedInt32Array()
		return PackedInt32Array([player.get_id()])

## 构造函数
func _init(p_player: Player, p_amount: int, p_operation: Context.Operation, p_event_name: StringName = &"", name_overriding: StringName = &"ActionPointChange", context_overriding: Context = Context.new()) -> void:
	context_overriding.set_player(p_player)
	match p_operation:
		Context.Operation.ADD:
			context_overriding.set_add(p_amount)
		Context.Operation.SUB:
			context_overriding.set_sub(p_amount)
		Context.Operation.SET:
			context_overriding.set_set(p_amount)
	context_overriding.set_event_name(p_event_name)
	super._init(p_player.get_id(), name_overriding, context_overriding)

## 执行命令
func execute(game_state: GameState) -> void:
	var ctx: Context = _context
	if not ctx.player:
		push_error("ActionPointCommand: 未设置被影响的玩家")
		complete()
		return
	var modified: bool = false
	match ctx.operation:
		Context.Operation.ADD:
			if ctx.amount != 0:
				ctx.player.add_ap(ctx.amount)
				modified = true
		Context.Operation.SUB:
			if ctx.amount != 0:
				ctx.player.sub_ap(ctx.amount)
				modified = true
		Context.Operation.SET:
			ctx.player.set_ap(ctx.amount)
			modified = true
	if modified:
		RuleTrans.send_player_delta_updates([ctx.player])
	complete()
