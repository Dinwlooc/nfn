## 激光修饰器：压制时对被压制牌造成「摧毁4」并摧毁自身。
extends Modifier

const ComponentDestroyX: Script = preload("res://resource/default/data/Component/ComponentDestroyX.gd")
@export var destroy_x: int = 4

func process(ctx: CommandContext, state: GameState, modifier_ctx: ModifierContext, creator: Item) -> ModifierContext:
	if RuleModifierRuntime.should_skip(modifier_ctx):
		return modifier_ctx
	if not RuleModifierTiming.is_suppressing(ctx, creator):
		return modifier_ctx
	if not (creator is Card):
		return modifier_ctx.set_error(ModifierContext.ERR_INVALID_TARGET)
	var source_card: Card = creator as Card
	var bctx: BattleCommand.Context = ctx as BattleCommand.Context
	_apply_suppress(source_card, bctx.second_card, bctx.defensive_area, state, modifier_ctx)
	return modifier_ctx

func _apply_suppress(source_card: Card, target_card: Card, src_area: AreaDefence, state: GameState, modifier_ctx: ModifierContext) -> void:
	var owner: Player = source_card.get_player()
	var self_destroy_cmd := DestroyCardsCommand.new(
		owner.get_id() if owner else 0,
		src_area,
		source_card.get_id(),
		owner,
		source_card
	)
	_send_command(self_destroy_cmd, modifier_ctx)
	if not ComponentDestroyX:
		return
	var cmd: BehaviorCommand = ComponentDestroyX.generate_command(owner, source_card, target_card, src_area, destroy_x, state)
	_send_command(cmd, modifier_ctx)
