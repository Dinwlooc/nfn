## 修饰器管理器，负责在命令处理前调用相关卡牌的修饰器。
class_name ModifierManager
extends RefCounted

## 处理命令上下文，遍历主修饰卡牌并应用其修饰器。
## @param context 命令上下文，应包含[method CommandContext.get_primary_modifier_cards]方法。
## @param game_state 当前游戏状态。
func process_modifiers(context: CommandContext, game_state: GameState) -> void:
	if not context:
		return
	var cards: Array[Card] = context.get_primary_modifier_cards()
	if cards.is_empty():
		return
	for card in cards:
		_apply_modifiers_on_card(card, context, game_state)

## 对单张卡牌应用其所有修饰器。
## @param card 目标卡牌。
## @param context 命令上下文。
## @param game_state 游戏状态。
func _apply_modifiers_on_card(card: Card, context: CommandContext, game_state: GameState) -> void:
	if not card or not card.modifiers:
		return
	for modifier in card.modifiers:
		modifier.process(context, game_state, card)
