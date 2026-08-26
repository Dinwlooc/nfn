## 触发器管理器。
extends RefCounted
class_name TriggerManager

var system_triggers: Array[SystemTrigger] = []
var gamestate_triggers: Array[GameStateTrigger] = []

static var system_trigger_classes: Array[Script] = [
	CommandTrigger,
	OperationTrigger,
	TimerTimeoutTrigger,
	StageTrigger,
]
static var gamestate_trigger_classes: Array[Script] = [
	PlayerTrigger,
	DefenseTrigger,
	CenterSkillTrigger,
	SyncTrigger,
	ShuffleWhenEmptyTrigger,
]

## 初始化所有触发器。
func initialize(system: System) -> void:
	system_triggers.resize(system_trigger_classes.size())
	for i in system_trigger_classes.size():
		var trigger_class: Script = system_trigger_classes[i]
		var trigger: SystemTrigger = _create_system_trigger(trigger_class, system)
		if trigger:
			system_triggers.set(i, trigger)
	gamestate_triggers.resize(gamestate_trigger_classes.size())
	for i in gamestate_trigger_classes.size():
		var trigger_class: Script = gamestate_trigger_classes[i]
		var trigger: GameStateTrigger = _create_gamestate_trigger(trigger_class, system.game_state, system.command_bus)
		if trigger:
			gamestate_triggers.set(i, trigger)
## 清理所有触发器。
func clear() -> void:
	for trigger in system_triggers:
		if trigger:
			trigger.disconnect_all()
	for trigger in gamestate_triggers:
		if trigger:
			trigger.disconnect_all()
	system_triggers.clear()
	gamestate_triggers.clear()
##
func _create_system_trigger(trigger_class: Script, system: System) -> SystemTrigger:
	var obj: SystemTrigger = trigger_class.new(system)
	if obj is not SystemTrigger:
		return null
	return obj
##
func _create_gamestate_trigger(trigger_class: Script, game_state: GameState, command_bus: CommandBus) -> GameStateTrigger:
	var obj: GameStateTrigger = trigger_class.new(game_state, command_bus)
	if obj is not GameStateTrigger:
		return null
	return obj
