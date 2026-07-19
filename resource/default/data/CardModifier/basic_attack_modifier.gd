extends Modifier

func process(context: CommandContext, state: GameState, modifier_ctx: ModifierContext, creator: Item) -> ModifierContext:
	if RuleModifierRuntime.should_skip(modifier_ctx):
		return modifier_ctx
	if not RuleModifierTiming.is_settle_effect(context, creator):
		return modifier_ctx
	if not (creator is Card):
		return modifier_ctx.set_error(ModifierContext.ERR_INVALID_TARGET)
	var card: Card = creator as Card
	var sctx: SettleCommand.Context = context as SettleCommand.Context
	var transfer_cmd := CardTransferCommand.new(
		card.get_owner_id(),
		sctx.defensive_area,
		state.get_hand_area(card.get_owner_id()),
		CardTransferCommand.Context.MoveOutMode.BY_ID,
		PackedInt32Array([card.id])
	)
	_send_command(transfer_cmd, modifier_ctx)
	return modifier_ctx
