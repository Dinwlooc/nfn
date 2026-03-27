extends RefCounted
class_name GameState

## 游戏状态数据容器
var area_center := AreaCenter.new()
var area_drawing := AreaDrawing.new()
var area_discard := AreaDiscard.new()
var current_player_index := 0
var cardsmanager := CardsManager.new()
var player_manager := PlayersManager.new()
var timer: GameTimer
var users: Dictionary[int, User]
var _process_active := false
var stage_context: StageContext

signal start_round(player_id: int)
signal new_behavior_with_callback(command: BehaviorCommand, callback: Callable)
signal new_behavior(command: BehaviorCommand)
signal request_set_responsive_players(player_ids: PackedInt32Array)
signal request_temp_stage(temp_stage: Stage)
signal all_commands_completed()

func load_cards() -> void:
	area_drawing.cards_add(cardsmanager.load_all_cards())
	area_drawing.shuffle_card_pool()

func start_new_round(player_id: int) -> void:
	call_deferred(&"_start_round_emitter", player_id)

func _start_round_emitter(player_id: int) -> void:
	start_round.emit(player_id)

func queue_behavior_with_callback(command: BehaviorCommand, callback: Callable = Callable()) -> void:
	new_behavior_with_callback.emit(command, callback)

## 获取当前主阶段名
func get_main_stage_name() -> StringName:
	if stage_context:
		return stage_context.current_main_stage_name
	return &""

## 获取所有临时阶段（包括当前临时阶段，不包括主阶段）
func get_temp_stage() -> Array[Stage]:
	if not stage_context:
		return []
	var stages: Array[Stage] = []
	# 被暂停的父阶段
	for stage in stage_context.temp_stage_stack:
		stages.append(stage)
	# 如果当前阶段是临时阶段，则加入
	var cur:Stage = stage_context.current_stage
	if cur and cur.is_temporary:
		stages.append(cur)
	return stages

## 获取当前活动阶段名（栈顶阶段名）
func get_current_active_stage_name() -> StringName:
	if not stage_context:
		return &""
	var cur = stage_context.current_stage
	if cur:
		return cur.stage_name
	return &""

## 请求设置可响应玩家
func set_responsive_players(player_ids: PackedInt32Array) -> void:
	request_set_responsive_players.emit(player_ids)

func queue_behavior(command: BehaviorCommand) -> void:
	new_behavior.emit(command)
