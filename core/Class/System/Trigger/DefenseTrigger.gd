## 守区综合触发器。
## 1. 监听守区创建，当敌方卡牌进入时启动守区战斗阶段。
## 2. 监听主阶段进入，重置所有守区的结算计数。
extends GameStateTrigger
class_name DefenseTrigger

func _init(game_state: GameState, command_bus: CommandBus) -> void:
	_game_state = game_state
	_command_bus = command_bus
	game_state.area_registry.area_added.connect(_on_defense_area_created)
	game_state.area_registry.area_removed.connect(_on_defense_area_removed)
	game_state.stage_manager.stage_completed.connect(_on_stage_completed)

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
## ----- 守区攻防触发 -----
func _on_card_added(card: Card, area: AreaDefence) -> void:
	# 若已存在守区战斗阶段则不重复触发
	if _game_state.stage_manager.has_stage_with_name(&"DefenseBattle"):
		return
	# 仅当敌方卡牌进入时触发（卡牌所属玩家与守区玩家不同）
	if area.player == card.get_player():
		return
	var command := DefenseStageRequestCommand.new(area, card.player)
	_command_bus.queue_behavior(command)
## ----- 主阶段重置结算计数 -----
func _on_stage_completed(new_stage: Stage) -> void:
	if not new_stage is StageMain:
		return
	for player in _game_state.player_manager.players:
		var defense: AreaDefence = _game_state.area_registry.get_defense_area(player.get_id())
		if defense:
			defense.reset_settle_count()
