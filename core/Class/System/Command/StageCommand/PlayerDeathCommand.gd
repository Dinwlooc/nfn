extends BehaviorCommand
class_name PlayerDeathCommand

## @context
class Context extends CommandContext:
	enum Phase {
		TRANSFER_CARDS,
		REMOVE_PLAYER,
		DONE
	}
	var dying_player: Player

## @seam_override
func _init(
	dying_player: Player,
	name_overriding: StringName = &"PlayerDeath",
	context_overriding: Context = Context.new()
) -> void:
	context_overriding.dying_player = dying_player
	super._init(dying_player.get_id(), name_overriding, context_overriding)

## @template
func execute(game_state: GameState) -> void:
	if _context.is_cancelled:
		complete()
		return
	var ctx: Context = _context
	match ctx.phase:
		Context.Phase.TRANSFER_CARDS:
			ctx.phase = Context.Phase.REMOVE_PLAYER
			_on_transfer_phase(game_state, ctx)
		Context.Phase.REMOVE_PLAYER:
			ctx.phase = Context.Phase.DONE
			_on_remove_phase(game_state, ctx)
		Context.Phase.DONE:
			_on_done_phase(game_state, ctx)

## 静态转移手牌：创建 CardTransferCommand 将所有手牌移至弃牌堆
static func do_transfer(context: Context, game_state: GameState, command_owner: PlayerDeathCommand) -> void:
	if context.is_virtual:
		context.phase = Context.Phase.DONE
		return
	var hand_area: AreaHand = game_state.area_registry.get_hand_area(context.dying_player.get_id())
	if hand_area and hand_area.card_count() > 0:
		var transfer_cmd := CardTransferCommand.new(
			context.dying_player,
			hand_area,
			game_state.get_discard_area(),
			CardMoveCommand.Context.MoveOutMode.TOP,
			hand_area.card_count()
		)
		command_owner.append_companion_command(transfer_cmd)

## 静态移除玩家：从玩家管理器移除并发送更新
static func do_remove(context: Context, game_state: GameState) -> void:
	if context.is_virtual:
		context.phase = Context.Phase.DONE
		return
	var removed: Player = game_state.player_manager.remove_player_by_id(context.dying_player.get_id())
	if removed:
		RuleTrans.send_player_delta_updates([removed], RenderRequest.ItemSet.EventType.DEATH)

## @hook
func _on_transfer_phase(game_state: GameState, context_overriding: CommandContext = _context as Context) -> void:
	do_transfer(context_overriding as Context, game_state, self)

## @hook
func _on_remove_phase(game_state: GameState, context_overriding: CommandContext = _context as Context) -> void:
	do_remove(context_overriding as Context, game_state)

## @hook
func _on_done_phase(_game_state: GameState, _context: CommandContext = _context as Context) -> void:
	complete()
