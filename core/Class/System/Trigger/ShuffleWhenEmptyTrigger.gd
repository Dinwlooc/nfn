## 当命令队列完全清空（闲置期）且抽牌区为空时，自动生成洗牌命令。
extends GameStateTrigger
class_name ShuffleWhenEmptyTrigger

func _init(game_state: GameState, command_bus: CommandBus) -> void:
	_game_state = game_state
	_command_bus = command_bus
	game_state.all_commands_completed.connect(_on_idle)

func _on_idle(game_state: GameState) -> void:
	if not _game_state:
		return
	var drawing: AreaDrawing = _game_state.get_drawing_area()
	var discard: AreaDiscard = _game_state.get_discard_area()
	if drawing and drawing.is_empty() and discard and not discard.is_empty():
		_command_bus.queue_behavior(ShuffleCommand.new())
