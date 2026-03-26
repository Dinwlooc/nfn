extends RefCounted
class_name AreaManager

var _game_state: GameState

func _init(game_state: GameState) -> void:
	_game_state = game_state

## 连接区域，监听其请求命令入栈信号
func connect_area_denfence(area: AreaDefence) -> void:
	area.area_card_added.connect(_start_defense_battle_stage)
	GlobalConsole._print(["AreaManager:连接至守区"])

func _start_defense_battle_stage(card: Card,area:AreaDefence) -> void:
	var _command := StartDefenseBattleStageCommand.new(area,card.player)
	_game_state.queue_behavior(_command)
	GlobalConsole._print(["AreaManager:尝试开启守区攻防阶段"])
