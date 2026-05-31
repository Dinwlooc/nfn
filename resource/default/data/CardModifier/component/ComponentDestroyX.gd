## 摧毁-x 修饰器组件：返回命令实例而非直接执行。
extends RefCounted

## 返回组件名称（同时用作属性修饰器名）
static func get_component_name() -> StringName:
	return &"DestroyX"
const  buff_name: StringName = &"DestroyX_Debuff"
## 生成「摧毁 x」效果的命令。
## 若 x >= 目标牌威力，返回一个 DestroyCardsCommand；否则返回一个 BuffCommand。
## @return 命令数组（每次只有一条命令，便于统一处理）
static func generate_command(
	source_player: Player,
	source_card: Card,
	target_card: Card,
	target_area: AreaDefence,
	x: int,
	game_state: GameState
) -> BehaviorCommand:
	var command: BehaviorCommand
	if x >= target_card.get_attribute(&"power"):
			command = DestroyCardsCommand.new(
				source_player.get_id() if source_player else target_card.get_owner_id(),
				target_area ,
				target_card.get_id(),
				source_player,
				source_card
			)
	else:
		var buff := SimpleAttributeBuffBuilder.create_attribute_buff(
			buff_name,
			target_card.attributeModifiers,
			&"power",
			AttributeModifiers.TYPE_BASE_ADD,
			false,
			float(-x),
			0
		)
		command = BuffCommand.new(
			target_card.buff_modifiers,
			buff,
			BuffCommand.Context.BuffMode.APPLY,
			source_card.attributeModifiers.compute_with_temporary_bonus(buff_name,x),
			source_card,
			source_player
		)
	return command
