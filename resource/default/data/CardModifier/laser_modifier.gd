## 激光修饰器：压制时对被压制牌造成「摧毁4」并摧毁自身。
class_name LaserModifier
extends Modifier

## 初始化：为源卡牌设置组件层数「DestroyX」= 4
static func init(source: Object) -> void:
	if source is Card:
		var card: Card = source as Card
		SimpleAttributeBuffBuilder.set_component_stack(
			card.attributeModifiers,
			DestroyXModifier.get_component_name(),
			4
		)

## 修饰器处理入口，由上层系统自动调用。
## @param ctx:     当前命令上下文（通常为 BattleCommand.Context）
## @param state:   全局游戏状态
## @param creator: 修饰器附着的主体对象（Card 实例）
static func process(ctx: CommandContext, state: GameState, creator: Object) -> void:
	if not (ctx is BattleCommand.Context):
		return
	var bctx: BattleCommand.Context = ctx as BattleCommand.Context
	if not (creator is Card):
		return
	var source_card: Card = creator as Card
	match bctx.phase:
		BattleCommand.Context.Phase.INIT:
			if source_card != bctx.top_card:
				return
			_apply_suppress(source_card, bctx.second_card, bctx.defensive_area, state)

## 执行压制效果：摧毁目标牌，然后摧毁自身
static func _apply_suppress(source_card: Card, target_card: Card, src_area: AreaDefence, state: GameState) -> void:
	var x: int = int(source_card.attributeModifiers.get_final_value(DestroyXModifier.get_component_name()))
	if x <= 0:
		return
	var owner: Player = source_card.get_player()
	var self_destroy_cmd := DestroyCardsCommand.new(
		owner.player_id if owner else -1,
		src_area,
		source_card.id,
		owner,
		source_card
	)
	state.queue_behavior(self_destroy_cmd)
	var cmd: BehaviorCommand = DestroyXModifier.generate_command(owner, source_card, target_card,src_area, x, state)
	state.queue_behavior(cmd)
