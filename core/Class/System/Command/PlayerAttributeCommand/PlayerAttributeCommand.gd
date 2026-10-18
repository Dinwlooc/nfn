## 玩家属性变更命令基类，提供三阶段执行流程：INIT → APPLY → DONE
## 每个阶段函数必须显式设置 ctx.phase 为下一阶段或 DONE
extends BehaviorCommand
class_name PlayerAttributeCommand

## @context
class Context extends CommandContext:
	## 三阶段执行流程的状态
	enum Phase {
		INIT,
		APPLY,
		DONE
	}
	## 本次变更的目标玩家
	var target_player: Player = null

	## 把目标玩家作为主修饰玩家（第一优先）
	## @override @hook
	func get_primary_modifier_players() -> Array[Player]:
		if target_player:
			return [target_player]
		return []

	## 链式设置目标玩家
	func set_target_player(player: Player) -> Context:
		target_player = player
		return self

## @seam_override
func _init(player: Player, name_overriding: StringName = &"PlayerAttribute", context_overriding: Context = Context.new()) -> void:
	if not player:
		_context.phase = Context.Phase.DONE
		complete()
		return
	context_overriding.set_target_player(player)
	super._init(player.get_id(), name_overriding, context_overriding)

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

## @hook
func _on_init_phase(_game_state: GameState, context_overriding: Context = _context as Context) -> void:
	pass

## @hook
## 子类必须重写此方法，并在完成时设置 context_overriding.phase = Context.Phase.DONE
func _on_apply_phase(_game_state: GameState, context_overriding: Context = _context as Context) -> void:
	push_error("子类必须实现 _on_apply_phase()")
	context_overriding.phase = Context.Phase.DONE

## @hook
func _on_done_phase(game_state: GameState, context_overriding: Context = _context as Context) -> void:
	if not context_overriding.is_virtual and context_overriding.target_player:
		_send_update(game_state, context_overriding)
	complete()

## 本命令对应的渲染更新事件类型，子类按需覆盖
## @hook
func get_update_event_type() -> RenderRequest.ItemSet.EventType:
	return RenderRequest.ItemSet.EventType.UPDATE

## 向目标玩家发送增量数据包更新
## @delegates
func _send_update(game_state: GameState, ctx: Context) -> void:
	if ctx.target_player:
		RuleTrans.send_player_delta_updates([ctx.target_player], get_update_event_type())
