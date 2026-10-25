## 系统权威节点：接线网络，驱动命令堆栈，并承接调试指令。
extends Node
class_name System

## 全局游戏状态，聚合所有逻辑层数据与子管理器
var game_state := GameState.new()
## 命令堆栈处理器，按帧节流驱动
var command_processor := CommandProcessor.new(game_state)
## 命令总线：命令入队与响应权切换
var command_bus := CommandBus.new()
## 操作请求处理器
var operation_handler := OperationHandler.new()
## 触发器管理器，_ready 时统一接线
var trigger_manager := TriggerManager.new()
## 传输层（全局 autoload）
var transport: Transport = GlobalTransport
## 修饰器管理器
var modifier_manager := ModifierManager.new()

## 注册全局常量
func _init() -> void:
	GlobalConstants.register_to(GlobalRegistry)

## 初始化触发器与调试指令接入，加载卡牌后延迟启动服务器
## 计时器由 TimerTimeoutTrigger 从注册表取得并注入；Agent 由 AgentTrigger 部署
func _ready() -> void:
	trigger_manager.initialize(self)
	signal_connect_test()
	game_state.load_cards()
	GlobalConsole.c_close.connect(signal_disconnect_test)
	call_deferred(&"start_server")

## 启动服务器并接管用户表
## @side_effect
func start_server() -> void:
	transport.start_server()
	game_state.users = transport.network_manager.users

## 按 4 帧节流驱动命令堆栈（帧控制节奏由架构裁定保留）
func _process(_delta: float) -> void:
	if Engine.get_process_frames() % 4 != 0:
		return
	if not game_state._process_active:
		return
	command_processor.process()

## 控制台：开始一局游戏；已开始时拒绝
## @delegates
func _start_game() -> void:
	if game_state.stage_manager.get_current_stage_enum() != -1:
		GlobalConsole._print("System:Error:c_start未生效。游戏已开始。")
		return
	var start_event = GameStartCommand.new(command_bus)
	command_bus.queue_behavior(start_event)
	GlobalConsole._print("System:游戏开始事件已创建")

## 控制台：为当前玩家调试抽牌；处理中或未开局时拒绝
## @delegates
func _draw_cards_test() -> void:
	if game_state._process_active:
		GlobalConsole._print("System:Error:c_draw未生效。无法插入事件至处理中的堆栈。")
		return
	if game_state.stage_manager.get_current_stage_enum() == -1:
		GlobalConsole._print("System:Error:c_draw未生效。游戏未开始。")
		return
	if game_state.player_manager.players.is_empty():
		GlobalConsole._print("System:Error:c_draw未生效。无存活玩家。")
		return
	var draw_event = DrawCardsCommand.new(
		game_state.get_player_by_id(game_state.stage_manager.current_player_id),
		2
	)
	command_bus.queue_behavior(draw_event)
	GlobalConsole._print("System:调试抽卡，（玩家 %s）" % game_state.stage_manager.current_player_id)

## 控制台：对指定玩家造成生命/法力伤害；处理中或未开局时拒绝
## @delegates
func _damage(hp_damage: int = 1, mp_damage: int = 1, player_id: int = 2) -> void:
	if game_state._process_active:
		GlobalConsole._print("System:Error:c_damage未生效。无法插入事件至处理中的堆栈。")
		return
	if game_state.stage_manager.get_current_stage_enum() == -1:
		GlobalConsole._print("System:Error:c_damage未生效。游戏未开始。")
		return
	if game_state.player_manager.players.is_empty():
		GlobalConsole._print("System:Error:c_damage未生效。无存活玩家。")
		return
	command_bus.queue_behavior(DamageCommand.new(game_state.player_manager.get_player_by_id(player_id), hp_damage, mp_damage))

## 接入控制台调试指令
func signal_connect_test():
	GlobalConsole.c_start.connect(_start_game)
	GlobalConsole.c_draw.connect(_draw_cards_test)
	GlobalConsole.c_damage.connect(_damage)
	GlobalConsole._print("System:调试模式已接入系统")

## 断开控制台调试指令
func signal_disconnect_test():
	GlobalConsole.c_start.disconnect(_start_game)
	GlobalConsole.c_draw.disconnect(_draw_cards_test)
	GlobalConsole._print("System:调试模式已断离系统")
