extends RefCounted
class_name AreaManager

var _game_state: GameState

func _init(game_state: GameState) -> void:
	_game_state = game_state
	_game_state.stage_manager.stage_entered.connect(_on_stage_changed)

## 连接守区的卡牌增加信号
func connect_area_denfence(area: AreaDefence) -> void:
	area.area_card_added.connect(_on_card_added_to_defense)
	GlobalConsole._print(["AreaManager:连接至守区卡牌增加信号"])

## 卡牌增加到守区时，尝试开启攻防阶段（不检查斗牌条件）
func _on_card_added_to_defense(attack_card: Card, area: AreaDefence) -> void:
	if _game_state.stage_manager.has_stage_with_name(&"DefenseBattle"):
		return
	if area.player == attack_card.get_player():
		return
	var command := StartDefenseBattleStageCommand.new(area, attack_card.player)
	_game_state.queue_behavior(command)
	GlobalConsole._print(["AreaManager:守区增加卡牌，尝试开启守区攻防阶段"])

## 主阶段开始时重置所有守区的结算次数
func _on_stage_changed(new_stage: Stage) -> void:
	if not new_stage is StageMain:
		return
	for player in _game_state.player_manager.players:
		var defense_area: AreaDefence = player.area_defensive
		if defense_area:
			defense_area.reset_settle_count()
