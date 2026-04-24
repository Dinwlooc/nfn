extends RefCounted
class_name AreaManager

var _game_state: GameState
var _hands: Dictionary[int, AreaHand] = {}
var _defenses: Dictionary[int, AreaDefence] = {}
var _abilities: Dictionary[int, AreaAbility] = {}

func _init(game_state: GameState) -> void:
	_game_state = game_state
	_game_state.stage_manager.stage_entered.connect(_on_stage_changed)

## 为新玩家创建所有区域（由 System 在 player_added 时调用）
func create_areas_for_player(player: Player) -> void:
	var id: int = player.player_id
	if _hands.has(id):
		return
	_hands[id] = AreaHand.new(player)
	_defenses[id] = AreaDefence.new(player)
	_abilities[id] = AreaAbility.new(player)
	connect_area_defence(_defenses[id])
	GlobalConsole._print(["AreaManager: 为玩家", id, "创建区域"])

## 获取手牌区域
func get_hand_area(player_id: int) -> AreaHand:
	return _hands.get(player_id)

## 获取守备区域
func get_defense_area(player_id: int) -> AreaDefence:
	return _defenses.get(player_id)

## 获取技能区域
func get_ability_area(player_id: int) -> AreaAbility:
	return _abilities.get(player_id)

## 连接守区的卡牌增加信号
func connect_area_defence(area: AreaDefence) -> void:
	area.area_card_added.connect(_on_card_added_to_defense)
	GlobalConsole._print(["AreaManager:连接至守区卡牌增加信号"])

## 卡牌增加到守区时，尝试开启攻防阶段
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
		var defense_area: AreaDefence = get_defense_area(player.player_id)
		if defense_area:
			defense_area.reset_settle_count()
