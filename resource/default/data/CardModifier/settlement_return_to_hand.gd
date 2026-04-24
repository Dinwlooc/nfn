extends Modifier

static func process(context: CommandContext, state: GameState, creator: Object) -> void:
	if creator is not Card:
		return
	if context is not SettleCommand.Context:
		return
	creator = creator as Card
	context = context as SettleCommand.Context
	if not context.phase == SettleCommand.Context.Phase.EFFECT:
		return
	if not context.get_settle_card() == creator:
		return
	## 创建转移命令，将 creator 从守区移回其拥有者的手牌
	var transfer_cmd := CardTransferCommand.new(
		creator.get_owner_id(),
		context.defensive_area,
		state.get_hand_area(creator.get_owner_id()),
		CardTransferCommand.Context.MoveOutMode.BY_ID,
		PackedInt32Array([creator.id])
	)
	state.queue_behavior(transfer_cmd)
