## 出牌阶段主逻辑实现
## 负责处理玩家出牌流程和守区攻防逻辑
extends Stage
class_name StageMain

var _current_attacker_id: int = -1  # 当前攻方玩家ID
var _current_attacker: Player = null  # 当前攻方玩家实例缓存

func _init(p_game_state: GameState) -> void:
	super._init(p_game_state)
	stage_name = &"Main"
	time_limit = 60.0

func enter_expand() -> void:
	_current_attacker = game_state.player_manager.get_player_by_seat(game_state.current_player_index)
	_current_attacker_id = _current_attacker.player_id
	game_state.request_set_responsive_players(PackedInt32Array([_current_attacker_id]))

func process_operation_request(request: OperationRequest) -> void:
	if is_ended or is_paused:
		return
	if request.get_class_name() == &"play_card":
		_process_play_card_request(request)
	else:
		GlobalConsole._print(["主阶段：收到不支持的操作类型", request.get_class_name_static()])

func _process_play_card_request(request: OperationRequest.PlayCard) -> void:
	if request.source_player_id != _current_attacker_id:
		GlobalConsole._print(["主阶段：非当前玩家操作，忽略"])
		request.cancel()
		return
	var rule_result = Rule.check_and_create_command(
		request._card_id,
		_current_attacker_id,
		request._target_id,
		request._is_to_center,
		game_state
	)
	if not rule_result.is_valid:
		GlobalConsole._print(["主阶段：", rule_result.message])
		request.cancel()
		return
	if not _check_defensive_restrictions(request._card_id, request._target_id, request._is_to_center):
		request.cancel()
		return
	game_state.queue_behavior(rule_result.command)
	if rule_result.should_respond:
		game_state.request_set_responsive_players(rule_result.responsive_players)
		GlobalConsole._print(["主阶段：技能牌使用成功，其他玩家获得响应机会"])
	else:
		GlobalConsole._print(["主阶段：卡牌使用成功,信息：",rule_result.message])
	request.complete()

func _check_defensive_restrictions(card_id: int, target_id: int, is_to_center: bool) -> bool:
	var card:Card = game_state.cardsmanager.get_card_by_id(card_id)
	if not card:
		GlobalConsole._print(["主阶段：卡牌不存在"])
		return false
	var card_type = card.type
	var target_player = game_state.player_manager.get_player_by_id(target_id) if target_id >= 0 else null
	match card_type:
		&"attack":
			if target_player and not target_player.area_defensive.is_empty():
				GlobalConsole._print(["主阶段：目标守区非空，不能攻击"])
				return false
			return true
		&"defense":
			if not _current_attacker.area_defensive.is_empty():
				GlobalConsole._print(["主阶段：自身守区非空，不能使用防御牌"])
				return false
			return true
		&"skill":
			return true
		_:
			return false

func run() -> void:
	pass

func end_stage_effect() -> void:
	_current_attacker = null  # 清理缓存
	game_state.request_set_responsive_players(PackedInt32Array())
	GlobalConsole._print(["主阶段结束"])
