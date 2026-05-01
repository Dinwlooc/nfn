## 全局游戏状态，聚合所有逻辑层数据和子管理器。
## 区域注册表 [member area_registry] 内建于此。
extends RefCounted
class_name GameState

var area_center := AreaCenter.new()
var area_drawing := AreaDrawing.new()
var area_discard := AreaDiscard.new()
var cardsmanager := CardsManager.new()
var player_manager := PlayersManager.new()
var timer: GameTimer
var users: Dictionary[int, User]
var _process_active := false
var stage_manager: StageManager = StageManager.new()
## 区域注册表纯数据容器，由 [GameState] 内部创建
var area_registry: AreaManager = AreaManager.new()
const PUBLIC_PLAYER_ID:int = 1
signal start_round(player_id: int)
signal new_behavior_with_callback(command: BehaviorCommand, callback: Callable)
signal new_behavior(command: BehaviorCommand)
signal request_set_responsive_players(player_ids: PackedInt32Array)
signal all_commands_completed()

## 加载卡牌并将所有牌置入牌堆
func load_cards() -> void:
	area_drawing.cards_add(cardsmanager.load_all_cards())
	area_drawing.shuffle_card_pool()

## 开始新一轮
func start_new_round(player_id: int) -> void:
	call_deferred(&"_start_round_emitter", player_id)

func _start_round_emitter(player_id: int) -> void:
	start_round.emit(player_id)
	stage_manager.start_round(player_id, self)

## 入队带回调的命令
func queue_behavior_with_callback(command: BehaviorCommand, callback: Callable = Callable()) -> void:
	new_behavior_with_callback.emit(command, callback)

## 获取当前主阶段名
func get_main_stage_name() -> StringName:
	return stage_manager.current_main_stage_name

## 获取所有临时阶段
func get_temp_stage() -> Array[Stage]:
	var stages: Array[Stage] = []
	for stage in stage_manager.temp_stage_stack:
		stages.append(stage)
	var cur = stage_manager.current_stage
	if cur and cur.is_temporary:
		stages.append(cur)
	return stages

## 获取当前活动阶段名
func get_current_active_stage_name() -> StringName:
	var cur = stage_manager.current_stage
	if cur:
		return cur.stage_name
	return &""

## 设置可响应玩家
func set_responsive_players(player_ids: PackedInt32Array) -> void:
	request_set_responsive_players.emit(player_ids)

## 入队命令
func queue_behavior(command: BehaviorCommand) -> void:
	new_behavior.emit(command)

## 通过玩家ID获取玩家实例
func get_player_by_id(player_id: int) -> Player:
	if not player_manager:
		return null
	return player_manager.get_player_by_id(player_id)

## 通过卡牌ID获取卡牌实例
func get_card_by_id(card_id: int) -> Card:
	if not cardsmanager:
		return null
	return cardsmanager.get_card_by_id(card_id)

## 通过座位索引获取玩家实例
func get_player_by_seat(seat_index: int) -> Player:
	if not player_manager:
		return null
	return player_manager.get_player_by_seat(seat_index)

## 通过用户ID获取用户实例
func get_user_by_id(user_id: int) -> User:
	return users.get(user_id)

## 获取指定玩家的手牌区域（委托给 area_registry）
func get_hand_area(player_id: int) -> AreaHand:
	return area_registry.get_hand_area(player_id)

## 获取指定玩家的守备区域（委托给 area_registry）
func get_defense_area(player_id: int) -> AreaDefence:
	return area_registry.get_defense_area(player_id)

## 获取指定玩家的技能区域（委托给 area_registry）
func get_ability_area(player_id: int) -> AreaAbility:
	return area_registry.get_ability_area(player_id)
