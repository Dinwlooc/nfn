## 守区攻防阶段触发器。当敌方卡牌进入守区时，自动启动 [StageDefense] 临时阶段。
extends GameStateTrigger
class_name DefenseBattleTrigger

var _game_state:GameState
## 构造时接收 [GameState]，不持有长期引用。
func _init(game_state: GameState) -> void:
	_game_state = game_state
	game_state.area_registry.defense_area_added.connect(_on_defense_area_created)
	game_state.area_registry.defense_area_removed.connect(_on_defense_area_removed)

func _on_defense_area_created(defense: AreaDefence, _pid: int) -> void:
	_connect_defense(defense)

func _on_defense_area_removed(defense: AreaDefence, _pid: int) -> void:
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
	_game_state.queue_behavior(command)
