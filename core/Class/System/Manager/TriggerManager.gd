## 触发器管理器。负责在游戏启动时实例化所有触发器，调用 [method Trigger.setup]，
## 并在游戏结束时调用 [method Trigger.teardown]。由 [System] 持有。
extends RefCounted
class_name TriggerManager

var system_triggers: Array[SystemTrigger] = []
var gamestate_triggers: Array[GameStateTrigger] = []
static var system_trigger_classes: Array[Script] = [
	PlayerTrigger,
	CommandTrigger,
	OperationTrigger,
	TimerTimeoutTrigger,
	StageTrigger,
]
static var gamestate_trigger_classes: Array[Script] = [
	DefenseBattleTrigger,
	SettleResetTrigger,
	CenterSkillTrigger,
	SyncTrigger,
	ShuffleWhenEmptyTrigger,
]

## 初始化所有触发器。传入的 [param system] 仅用于构造触发器实例，不会长期持有。
func initialize(system: System) -> void:
	system_triggers.resize(system_trigger_classes.size())
	for i in system_trigger_classes.size():
		var trigger_class: Script = system_trigger_classes[i]
		var trigger: SystemTrigger = _create_system_trigger(trigger_class, system)
		if trigger:
			system_triggers.set(i, trigger)
	# 新增：游戏状态触发器初始化
	gamestate_triggers.resize(gamestate_trigger_classes.size())
	for i in gamestate_trigger_classes.size():
		var trigger_class: Script = gamestate_trigger_classes[i]
		var trigger: GameStateTrigger = _create_gamestate_trigger(trigger_class, system.game_state)
		if trigger:
			gamestate_triggers.set(i, trigger)

## 清理所有触发器
func clear() -> void:
	pass

## 根据触发器类型构造实例。自动识别 [SystemTrigger] 与 [GameStateTrigger]。
func _create_system_trigger(trigger_class: Script, system: System) -> SystemTrigger:
	var obj: SystemTrigger = trigger_class.new(system)
	if obj is not SystemTrigger:
		return null
	return obj

## 创建游戏状态触发器实例
func _create_gamestate_trigger(trigger_class: Script, game_state: GameState) -> GameStateTrigger:
	var obj: GameStateTrigger = trigger_class.new(game_state)
	if obj is not GameStateTrigger:
		return null
	return obj
