extends GameStateTrigger
class_name DefenseTrigger

func _init(game_state: GameState, command_bus: CommandBus) -> void:
	super._init(game_state, command_bus)
	game_state.area_registry.area_added.connect(_on_defense_area_created)
	game_state.area_registry.area_removed.connect(_on_defense_area_removed)
	game_state.stage_manager.stage_completed.connect(_on_stage_completed)
## @signal-listener 守区创建时连接其 card_added 信号
func _on_defense_area_created(defense: Area) -> void:
	if defense is not AreaDefence:
		return
	_connect_defense(defense)
## @signal-listener 守区移除时断开其 card_added 信号
func _on_defense_area_removed(defense: Area) -> void:
	if defense is not AreaDefence:
		return
	_disconnect_defense(defense)
##
func _connect_defense(defense: AreaDefence) -> void:
	defense.area_card_added.connect(_on_card_added)
##
func _disconnect_defense(defense: AreaDefence) -> void:
	defense.area_card_added.disconnect(_on_card_added)
## @signal-listener 敌方卡牌进入守区时触发战斗阶段
func _on_card_added(card: Card, area: AreaDefence) -> void:
	if _game_state.stage_manager.has_stage_with_name(&"DefenseBattle"):
		return
	if area.player == card.get_player():
		return
	var command := DefenseStageRequestCommand.new(area, card.player)
	_command_bus.queue_behavior(command)
## @signal-listener 主阶段结束时重置守区结算计数
func _on_stage_completed(new_stage: Stage) -> void:
	if not new_stage is StageMain:
		return
	for player in _game_state.player_manager.players:
		var defense: AreaDefence = _game_state.area_registry.get_defense_area(player.get_id())
		if defense:
			defense.reset_settle_count()
##
func disconnect_all() -> void:
	_game_state.area_registry.area_added.disconnect(_on_defense_area_created)
	_game_state.area_registry.area_removed.disconnect(_on_defense_area_removed)
	_game_state.stage_manager.stage_completed.disconnect(_on_stage_completed)
	for player in _game_state.player_manager.players:
		var defense: AreaDefence = _game_state.area_registry.get_defense_area(player.get_id())
		if defense:
			_disconnect_defense(defense)
