## 当命令队列完全清空（闲置期）且抽牌区为空时，自动生成洗牌命令。
extends GameStateTrigger
class_name ShuffleWhenEmptyTrigger

func _init(game_state: GameState) -> void:
	super._init(game_state)
	if game_state:
		game_state.all_commands_completed.connect(_on_idle)

func _on_idle() -> void:
	if not _game_state:
		return
	var drawing: AreaDrawing = _game_state.get_drawing_area()
	var discard: AreaDiscard = _game_state.get_discard_area()
	if drawing and drawing.is_empty() and discard and not discard.is_empty():
		_game_state.queue_behavior(ShuffleCommand.new())
