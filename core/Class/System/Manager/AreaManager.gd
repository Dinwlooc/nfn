extends RefCounted
class_name AreaManager

var _game_state: GameState

func _init(game_state: GameState) -> void:
	_game_state = game_state
	_game_state.stage_manager.stage_entered.connect(_on_stage_changed)

## 连接区域，监听其请求命令入栈信号
func connect_area_denfence(area: AreaDefence) -> void:
	area.area_pending_card_added.connect(_start_defense_battle_stage)
	GlobalConsole._print(["AreaManager:连接至守区"])

func _start_defense_battle_stage(card: Card, area: AreaDefence) -> void:
	if not _game_state.stage_manager.has_stage_with_name(&"DefenseBattle"):
		var _command := StartDefenseBattleStageCommand.new(area, card.player)
		_game_state.queue_behavior(_command)
		GlobalConsole._print(["AreaManager:尝试开启守区攻防阶段"])

## 当主阶段开始时（非恢复），重置所有守区的结算次数
func _on_stage_changed(new_stage: Stage) -> void:
	if not new_stage is StageMain:
		return
	for player in _game_state.player_manager.players:
		var defense_area: AreaDefence = player.area_defensive
		if defense_area:
			defense_area.reset_settle_count()
