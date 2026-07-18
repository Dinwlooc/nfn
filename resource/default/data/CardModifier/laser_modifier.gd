## 激光修饰器：压制时对被压制牌造成「摧毁4」并摧毁自身。
extends Modifier

const ComponentDestroyX: Script = preload("res://resource/default/data/Component/ComponentDestroyX.gd")
@export var destroy_x: int = 4

## 修饰器处理入口
func process(ctx: CommandContext, state: GameState, command_bus: CommandBus, creator: Item) -> ModifierResult:
	if not (creator is Card):
		return ModifierResult.PASS
	var source_card: Card = creator as Card
	if not RuleModifierTiming.is_suppressing(ctx, source_card):
		return ModifierResult.PASS
	var bctx: BattleCommand.Context = ctx as BattleCommand.Context
	_apply_suppress(source_card, bctx.second_card, bctx.defensive_area, state, command_bus)
	return ModifierResult.WORK

func _apply_suppress(source_card: Card, target_card: Card, src_area: AreaDefence, state: GameState, command_bus: CommandBus) -> void:
	var owner: Player = source_card.get_player()
	var self_destroy_cmd := DestroyCardsCommand.new(
		owner.get_id() if owner else 0,
		src_area,
		source_card.get_id(),
		owner,
		source_card
	)
	command_bus.queue_behavior(self_destroy_cmd)
	if not ComponentDestroyX:
		return
	var cmd: BehaviorCommand = ComponentDestroyX.generate_command(owner, source_card, target_card, src_area, destroy_x, state)
	command_bus.queue_behavior(cmd)
