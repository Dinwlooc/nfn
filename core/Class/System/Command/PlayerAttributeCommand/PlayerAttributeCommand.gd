## 玩家属性变更命令基类，提供三阶段执行流程：INIT → APPLY → DONE
## 每个阶段函数必须显式设置 ctx.phase 为下一阶段或 DONE
extends BehaviorCommand
class_name PlayerAttributeCommand

class Context extends CommandContext:
	enum Phase {
		INIT,
		APPLY,
		DONE
	}
	var target_player: Player = null

	func get_primary_modifier_players() -> Array[Player]:
		if target_player:
			return [target_player]
		return []

	func set_target_player(player: Player) -> void:
		target_player = player

func _init(player: Player, name_overriding: StringName = &"PlayerAttribute", context_overriding: Context = Context.new()) -> void:
	context_overriding.set_target_player(player)
	super._init(player.get_id(), name_overriding, context_overriding)

func execute(game_state: GameState) -> void:
	var ctx: Context = _context
	match ctx.phase:
		Context.Phase.INIT:
			_on_init_phase(game_state, ctx)
		Context.Phase.APPLY:
			_on_apply_phase(game_state, ctx)
		Context.Phase.DONE:
			_on_done_phase(game_state, ctx)

## 初始化阶段：默认切换到 APPLY，子类可重写并自行设置下一阶段
func _on_init_phase(game_state: GameState, ctx: Context) -> void:
	ctx.phase = Context.Phase.APPLY

## 应用阶段：子类必须重写，并最终设置 ctx.phase = Context.Phase.DONE
func _on_apply_phase(game_state: GameState, ctx: Context) -> void:
	push_error("子类必须实现 _on_apply_phase()")
	ctx.phase = Context.Phase.DONE

## 完成阶段：发送更新并结束
func _on_done_phase(game_state: GameState, ctx: Context) -> void:
	if ctx.target_player:
		_send_update(game_state, ctx)
	complete()

func get_update_event_type() -> RenderRequest.ItemSet.EventType:
	return RenderRequest.ItemSet.EventType.UPDATE

func _send_update(game_state: GameState, ctx: Context) -> void:
	if ctx.target_player:
		RuleTrans.send_player_delta_updates([ctx.target_player], get_update_event_type())
