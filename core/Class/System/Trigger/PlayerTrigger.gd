## 玩家触发器：处理玩家添加、战意升级、特殊牌充能、死亡轮询。
extends SystemTrigger
class_name PlayerTrigger

var _system: System
var _operation_handler: OperationHandler
const UPGRADE_REQUIREMENTS: Array[int] = [7, 12, 15, 18]

func _init(system: System) -> void:
	super(system)
	_system = system
	_operation_handler = system.operation_handler
	system.game_state.player_manager.player_added.connect(_on_player_added)
	system.game_state.player_manager.player_added.connect(system.game_state.area_registry.create_areas_for_player)
	system.game_state.stage_manager.round_ended.connect(_on_round_ended)
	system.game_state.all_commands_completed.connect(_on_all_commands_completed)

func _on_player_added(player: Player) -> void:
	GlobalConsole._print(["System: 新玩家加入,id:", player.get_id(), "，peer_id:", player.peer_id])
	_operation_handler.update_verification_mapping(player.peer_id, player.get_id())
	player.morale_attack_increased.connect(_on_morale_attack_increased.bind(player))
	player.morale_defense_increased.connect(_on_morale_defense_increased.bind(player))

func _on_round_ended() -> void:
	for player in _system.game_state.player_manager.players:
		_try_upgrade_player(player)

func _try_upgrade_player(player: Player) -> void:
	var total_morale: int = player.morale_attack + player.morale_defense
	var current_level: int = player.morale_level
	if current_level >= UPGRADE_REQUIREMENTS.size():
		return
	var required: int = UPGRADE_REQUIREMENTS[current_level]
	if total_morale < required:
		return
	var new_level: int = current_level + 1
	player.set_morale_level(new_level)
	player.clear_morale()
	_apply_morale_bonus(player, new_level)
	_draw_one_card(player)
	_handle_ability_selection(player, new_level)
	RuleTrans.send_player_delta_updates([player])

func _apply_morale_bonus(player: Player, level: int) -> void:
	match level:
		1:
			player.attributeModifiers.add_modifier(&"init_AP", AttributeModifiers.TYPE_BASE_ADD, &"morale_ap_bonus", 1.0)
		2:
			player.attributeModifiers.add_modifier(&"hand_limit", AttributeModifiers.TYPE_FINAL_ADD, &"morale_hand_limit_bonus", 1.0)
		3:
			player.attributeModifiers.add_modifier(&"draw_cards_count", AttributeModifiers.TYPE_BASE_ADD, &"morale_draw_bonus", 1.0)
		4:
			pass
		_:
			pass

func _draw_one_card(player: Player) -> void:
	var draw_cmd := DrawCardsCommand.new(player.get_id(), 1)
	_system.game_state.queue_behavior(draw_cmd)

func _handle_ability_selection(_player: Player, _new_level: int) -> void:
	pass

func _on_morale_attack_increased(amount: int, player: Player) -> void:
	_charge_special_cards(player, &"attack", amount)

func _on_morale_defense_increased(amount: int, player: Player) -> void:
	_charge_special_cards(player, &"defense", amount)

## 特殊牌充能（待实现）
func _charge_special_cards(player: Player, morale_type: StringName, base_amount: int) -> void:
	var charge_amount: int = player.get_charge_amount(base_amount)
	# TODO: 获取玩家拥有的特殊牌列表，筛选类型匹配的牌，调用其充能方法。
	pass
## 所有命令完成后的回调：检查并进入濒死阶段
func _on_all_commands_completed(game_state:GameState) -> void:
	if _is_in_dying_stage(game_state):
		return
	var start_seat: int = _get_current_player_seat_index(game_state)
	if start_seat == -1:
		return
	var players: Array[Player] = game_state.player_manager.get_seated_players()
	var n: int = players.size()
	if n == 0:
		return
	for i in range(n):
		var idx: int = (start_seat + i) % n
		var player: Player = players[idx]
		if player.HP <= 0:
			_enter_dying_stage(game_state, player)
			return
## 检查当前阶段是否为濒死阶段
func _is_in_dying_stage(game_state: GameState) -> bool:
	var stage: Stage = game_state.stage_manager.current_stage
	return stage != null and stage.stage_name == &"Dying"
## 获取当前回合玩家的座位索引
func _get_current_player_seat_index(game_state: GameState) -> int:
	var cur_player_id: int = game_state.stage_manager.current_player_id
	if cur_player_id == 0:
		return -1
	var player: Player = game_state.player_manager.get_player_by_id(cur_player_id)
	return player.seat_index if player else -1
## 进入濒死阶段
func _enter_dying_stage(game_state: GameState, dying_player: Player) -> void:
	var dying_stage := StageDying.new(dying_player)
	game_state.stage_manager.start_temp_stage(dying_stage, game_state)
