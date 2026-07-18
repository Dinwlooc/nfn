extends Modifier

func process(context: CommandContext, state: GameState, command_bus: CommandBus, creator: Item) -> int:
	if not (creator is Card):
		return 0  # PASS
	var card: Card = creator as Card
	if not RuleModifierTiming.is_settle_effect(context, card):
		return 0
	var sctx: SettleCommand.Context = context as SettleCommand.Context
	var transfer_cmd := CardTransferCommand.new(
		card.get_owner_id(),
		sctx.defensive_area,
		state.get_hand_area(card.get_owner_id()),
		CardTransferCommand.Context.MoveOutMode.BY_ID,
		PackedInt32Array([card.id])
	)
	command_bus.queue_behavior(transfer_cmd)
	return Modifier.COMMAND_SENT  # 发送了命令
