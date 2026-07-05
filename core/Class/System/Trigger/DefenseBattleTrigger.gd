## 守区攻防阶段触发器。当敌方卡牌进入守区时，自动启动 [StageDefense] 临时阶段。
extends GameStateTrigger
class_name DefenseBattleTrigger

func _init(game_state: GameState, command_bus: CommandBus) -> void:
	_game_state = game_state
	_command_bus = command_bus
	game_state.area_registry.area_added.connect(_on_defense_area_created)
	game_state.area_registry.area_removed.connect(_on_defense_area_removed)

func _on_defense_area_created(defense: Area) -> void:
	if defense is not AreaDefence:
		return
	_connect_defense(defense)

func _on_defense_area_removed(defense: Area) -> void:
	if defense is not AreaDefence:
		return
	_disconnect_defense(defense)

func _connect_defense(defense: AreaDefence) -> void:
	if not defense.area_card_added.is_connected(_on_card_added):
		defense.area_card_added.connect(_on_card_added)

func _disconnect_defense(defense: AreaDefence) -> void:
	if defense.area_card_added.is_connected(_on_card_added):
		defense.area_card_added.disconnect(_on_card_added)

func _on_card_added(card: Card, area: AreaDefence) -> void:
	if _game_state.stage_manager.has_stage_with_name(&"DefenseBattle"):
		return
	if area.player == card.get_player():
		return
	var command := StartDefenseBattleStageCommand.new(area, card.player)
	_command_bus.queue_behavior(command)
