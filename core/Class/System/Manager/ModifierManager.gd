## 修饰器管理器，负责按优先级轮询卡牌和玩家的命令修饰器。
extends RefCounted
class_name ModifierManager

## 处理命令上下文，依次应用：
## 1. 主修饰卡牌（相关卡牌，第一优先）
## 2. 主修饰玩家（相关玩家，第二优先）
## 3. 其他在座玩家（从当前回合玩家开始，第三优先）
## 每个玩家仅处理一次，跳过已处理过的对象。
func process_modifiers(context: CommandContext, game_state: GameState, command_bus: CommandBus, sequence: int) -> void:
	if not context:
		return
	var processed_player_ids := {}
	_process_card_modifiers(context, game_state, command_bus, sequence)
	_process_primary_player_modifiers(context, game_state, command_bus, sequence, processed_player_ids)
	_process_other_player_modifiers(context, game_state, command_bus, sequence, processed_player_ids)

## 处理主修饰卡牌（第一优先）
func _process_card_modifiers(context: CommandContext, game_state: GameState, command_bus: CommandBus, sequence: int) -> void:
	var cards: Array[Card] = context.get_primary_modifier_cards()
	for card in cards:
		if card.command_modifiers:
			card.command_modifiers.process_modifiers(context, game_state, command_bus, card, sequence)

## 处理主修饰玩家（第二优先）
func _process_primary_player_modifiers(context: CommandContext, game_state: GameState, command_bus: CommandBus, sequence: int, processed: Dictionary) -> void:
	var players: Array[Player] = context.get_primary_modifier_players()
	for player in players:
		if player and player.command_modifiers:
			player.command_modifiers.process_modifiers(context, game_state, command_bus, player, sequence)
			processed[player.get_id()] = true

## 处理其他在座玩家（第三优先，从当前回合玩家开始轮询）
func _process_other_player_modifiers(context: CommandContext, game_state: GameState, command_bus: CommandBus, sequence: int, processed: Dictionary) -> void:
	var current_turn_player_id: int = game_state.stage_manager.current_player_id if game_state.stage_manager else 0
	var all_players: Array[Player] = game_state.player_manager.get_seated_players()
	var start_index: int = game_state.player_manager.get_seat_index_by_player_id(current_turn_player_id)
	if start_index == -1:
		start_index = 0
	var total: int = all_players.size()
	for offset in total:
		var idx: int = (start_index + offset) % total
		var player: Player = all_players[idx]
		var pid: int = player.get_id()
		if processed.has(pid):
			continue
		if player.command_modifiers:
			player.command_modifiers.process_modifiers(context, game_state, command_bus, player, sequence)
			processed[pid] = true
