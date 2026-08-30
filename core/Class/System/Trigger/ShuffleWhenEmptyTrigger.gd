extends GameStateTrigger
class_name ShuffleWhenEmptyTrigger

func _init(game_state: GameState, command_bus: CommandBus) -> void:
	super._init(game_state, command_bus)
	game_state.all_commands_completed.connect(_on_idle)
## @signal_listener 命令队列空闲时检查抽牌区
func _on_idle(game_state: GameState) -> void:
	if not _game_state:
		return
	var drawing: AreaDrawing = _game_state.get_drawing_area()
	var discard: AreaDiscard = _game_state.get_discard_area()
	if drawing and drawing.is_empty() and discard and not discard.is_empty():
		_command_bus.queue_behavior(ShuffleCommand.new())
##
func disconnect_all() -> void:
	_game_state.all_commands_completed.disconnect(_on_idle)
