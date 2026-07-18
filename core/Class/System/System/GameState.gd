## 全局游戏状态，聚合所有逻辑层数据和子管理器。
extends RefCounted
class_name GameState

var cardsmanager := CardsManager.new()
var player_manager := PlayersManager.new()
var timer: GameTimer
var users: Dictionary[int, User]
var _process_active := false
var stage_manager: StageManager = StageManager.new()
## 区域注册表统一管理器
var area_registry: AreaManager = AreaManager.new()
## 命令上下文堆栈。命令可以在其他命令的执行中途入栈，故尾部仅代表在当前的修饰下，下一轮调用时将被执行的命令。
var command_context_stack: Array[CommandContext] = []
const PUBLIC_PLAYER_ID: int = 1
# signal request_set_responsive_players 已移至 CommandBus
signal new_behavior_with_callback(command: BehaviorCommand, callback: Callable)
signal new_behavior(command: BehaviorCommand)
signal all_commands_completed(game_state:GameState)

## 加载卡牌并将所有牌置入牌堆
func load_cards() -> void:
	var drawing: AreaDrawing = area_registry.get_drawing_area()
	drawing.cards_add(cardsmanager.load_all_cards())
	drawing.shuffle_card_pool()

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
	if cur and cur.is_temporary():
		stages.append(cur)
	return stages

## 获取当前活动阶段名
func get_current_active_stage_name() -> StringName:
	var cur = stage_manager.current_stage
	if cur:
		return cur.stage_name
	return &""

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

## 获取公共中央区（便捷方法）
func get_center_area() -> AreaCenter:
	return area_registry.get_center_area()

## 获取公共牌堆区（便捷方法）
func get_drawing_area() -> AreaDrawing:
	return area_registry.get_drawing_area()

## 获取公共弃牌堆区（便捷方法）
func get_discard_area() -> AreaDiscard:
	return area_registry.get_discard_area()

## 压入命令上下文到堆栈尾部
func push_command_context(context: CommandContext) -> void:
	command_context_stack.push_back(context)

## 弹出命令上下文从堆栈尾部（不做检查）
func pop_command_context() -> void:
	if not command_context_stack.is_empty():
		command_context_stack.pop_back()
