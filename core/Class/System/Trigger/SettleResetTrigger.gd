## 主阶段开始时，重置所有守区的结算计数。
extends GameStateTrigger
class_name SettleResetTrigger

var _game_state:GameState
## 构造时接收 [GameState]，不持有长期引用。
func _init(game_state: GameState) -> void:
	_game_state = game_state
	game_state.stage_manager.stage_entered.connect(_on_stage_entered)

func _on_stage_entered(new_stage: Stage) -> void:
	if not new_stage is StageMain:
		return
	for player in _game_state.player_manager.players:
		var defense := _game_state.area_registry.get_defense_area(player.player_id)
		if defense:
			defense.reset_settle_count()
