extends Modifier

static func process(context: CommandContext, state: GameState, creator: Item) -> void:
	if not (creator is Card):
		return
	var card: Card = creator as Card
	if not RuleModifierTiming.is_settle_effect(context, card):
		return
	var sctx: SettleCommand.Context = context as SettleCommand.Context
	## 创建转移命令，将 creator 从守区移回其拥有者的手牌
	var transfer_cmd := CardTransferCommand.new(
		card.get_owner_id(),
		sctx.defensive_area,
		state.get_hand_area(card.get_owner_id()),
		CardTransferCommand.Context.MoveOutMode.BY_ID,
		PackedInt32Array([card.id])
	)
	state.queue_behavior(transfer_cmd)
