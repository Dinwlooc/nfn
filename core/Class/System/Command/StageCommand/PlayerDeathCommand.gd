## 玩家死亡命令：分阶段转移手牌、移出座位
extends BehaviorCommand
class_name PlayerDeathCommand

class Context extends CommandContext:
	enum Phase { TRANSFER_CARDS, REMOVE_PLAYER, DONE }
	var dying_player: Player
## 构造函数
func _init(p_dying_player: Player, name_overriding: StringName = &"PlayerDeath", context_overriding: Context = Context.new()) -> void:
	super._init(p_dying_player.get_id(), name_overriding, context_overriding)
	_context.dying_player = p_dying_player

func execute(game_state: GameState) -> void:
	var ctx: Context = _context
	match ctx.phase:
		Context.Phase.TRANSFER_CARDS:
			_on_transfer_phase(game_state, ctx)
		Context.Phase.REMOVE_PLAYER:
			_on_remove_phase(game_state, ctx)
		Context.Phase.DONE:
			_on_done_phase(game_state, ctx)
## 第一阶段：将所有手牌转移到弃牌堆
func _on_transfer_phase(game_state: GameState, ctx: Context) -> void:
	var hand_area: AreaHand = game_state.area_registry.get_hand_area(ctx.dying_player.get_id())
	if hand_area and hand_area.card_count() > 0:
		var transfer_cmd := CardTransferCommand.new(
			ctx.dying_player.get_id(),
			hand_area,
			game_state.get_discard_area(),
			CardMoveCommand.Context.MoveOutMode.TOP,
			hand_area.card_count()
		)
		append_companion_command(transfer_cmd)
	ctx.phase = Context.Phase.REMOVE_PLAYER
## 第二阶段：将玩家移出座位
func _on_remove_phase(game_state: GameState, ctx: Context) -> void:
	var removed: Player = game_state.player_manager.remove_player_by_id(ctx.dying_player.get_id())
	if removed:
		RuleTrans.send_player_delta_updates([removed], RenderRequest.ItemSet.EventType.DEATH)
	ctx.phase = Context.Phase.DONE
## 完成阶段
func _on_done_phase(_game_state: GameState, _ctx: Context) -> void:
	complete()
