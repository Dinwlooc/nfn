## 激光修饰器：压制时对被压制牌造成「摧毁4」并摧毁自身。
extends Modifier

const ComponentDestroyX:Script = preload("res://resource/default/data/Component/ComponentDestroyX.gd")
const destroy_x:int = 4
## 修饰器处理入口，由上层系统自动调用。
## @param ctx:     当前命令上下文
## @param state:   全局游戏状态
## @param creator: 修饰器附着的主体对象（Card 实例）
static func process(ctx: CommandContext, state: GameState, creator: Item) -> void:
	if not (creator is Card):
		return
	var source_card: Card = creator as Card
	if not RuleModifierTiming.is_suppressing(ctx, source_card):
		return
	var bctx: BattleCommand.Context = ctx as BattleCommand.Context
	_apply_suppress(source_card, bctx.second_card, bctx.defensive_area, state)
## 执行压制效果：摧毁目标牌，然后摧毁自身
static func _apply_suppress(source_card: Card, target_card: Card, src_area: AreaDefence, state: GameState) -> void:
	var owner: Player = source_card.get_player()
	var self_destroy_cmd := DestroyCardsCommand.new(
		owner.get_id() if owner else 0,
		src_area,
		source_card.get_id(),
		owner,
		source_card
	)
	state.queue_behavior(self_destroy_cmd)
	if not ComponentDestroyX:
		return
	var cmd: BehaviorCommand = ComponentDestroyX.generate_command(owner, source_card, target_card, src_area, destroy_x, state)
	state.queue_behavior(cmd)
