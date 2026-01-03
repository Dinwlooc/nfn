extends RefCounted
class_name GameState

## 游戏状态数据容器
var area_center := AreaCenter.new()
var area_drawing := AreaDrawing.new()
var current_player_index := 0
var cardsmanager := CardsManager.new()
var player_manager := PlayersManager.new()
var timer: GameTimer
var network_manager:NetworkManager
var _process_active := false
var current_stage_stack: Array[StringName] = []
signal start_round(player_id:int)
signal new_behavior_with_callback(command:BehaviorCommand,callback:Callable)

func load_cards() -> void:
	area_drawing.cards_add(cardsmanager.load_all_cards())
	area_drawing.shuffle_card_pool()

func start_new_round(player_id:int):
	call_deferred(&"_start_round_emitter",player_id)

func _start_round_emitter(player_id:int):
	start_round.emit(player_id)

func queue_behavior_with_callback(command:BehaviorCommand,callback:Callable):
	new_behavior_with_callback.emit(command,callback)

## 获取当前主阶段名
func get_main_stage_name() -> StringName:
	if current_stage_stack.size() > 0:
		return current_stage_stack[0]
	return &""

## 获取所有临时阶段名
func get_temp_stage_names() -> Array[StringName]:
	if current_stage_stack.size() > 1:
		return current_stage_stack.slice(1)
	return []

## 获取当前活动阶段名（堆栈顶部）
func get_current_active_stage_name() -> StringName:
	if current_stage_stack.size() > 0:
		return current_stage_stack[current_stage_stack.size() - 1]
	return &""

## 切换主阶段，并清除所有临时阶段
func switch_main_stage(new_main_stage_name: StringName) -> void:
	current_stage_stack = [new_main_stage_name]
