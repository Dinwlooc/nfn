class_name ModifierManager
extends RefCounted

## 处理命令上下文，遍历所有主修饰卡牌，应用其CommandModifiers中的生效脚本
func process_modifiers(context: CommandContext, game_state: GameState, command_bus: CommandBus) -> void:
	if not context:
		return
	var cards: Array[Card] = context.get_primary_modifier_cards()
	if cards.is_empty():
		return
	for card in cards:
		_apply_modifiers_on_card(card, context, game_state, command_bus)

func _apply_modifiers_on_card(card: Card, context: CommandContext, game_state: GameState, command_bus: CommandBus) -> void:
	if not card or not card.command_modifiers:
		return
	for modifier in card.command_modifiers.get_modifiers():
		# 调用修饰器并忽略返回值（后续可根据需要扩展）
		modifier.process(context, game_state, command_bus, card)
