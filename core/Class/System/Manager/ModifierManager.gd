class_name ModifierManager
extends RefCounted

## 处理命令上下文，遍历所有主修饰卡牌，应用其CommandModifiers中的生效脚本
func process_modifiers(context: CommandContext, game_state: GameState, command_bus: CommandBus, sequence: int) -> void:
	if not context:
		return
	var cards: Array[Card] = context.get_primary_modifier_cards()
	if cards.is_empty():
		return
	for card in cards:
		if card.command_modifiers:
			card.command_modifiers.process_modifiers(context, game_state, command_bus, card, sequence)
