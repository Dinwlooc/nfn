extends RefCounted
class_name Stage

enum StageType {
	MAIN,          # 主阶段
	INTERRUPT      # 插入阶段
}
signal stage_enter
signal stage_ended
var system: System
var type: int = StageType.MAIN
var stage_name: String = "Unnamed Stage"
var time_limit: float = 30.0

func _init(system_ref: System)->void:
	stage_enter.connect(enter)
	system = system_ref
	_init_expand()

func  _init_expand()->void:
	pass

func enter()->void:
	if type == StageType.MAIN:
		GlobalConsole.timer.timer_create(time_limit)
		GlobalConsole.timer.timeout.connect(on_timeout)
	enter_expand()

func enter_expand()->void:
	pass

# 由system调用的阶段结束方法，不建议覆盖。
func exit():
	GlobalConsole.timer.timeout.disconnect(on_timeout)
	GlobalConsole.timer.timer_stop()

func handle_operation(op_data: Dictionary):
	pass

func on_timeout():
	end_stage()
	
# 由自身调用的阶段结束方法，由子类覆盖。
func end_stage():
	pass
	emit_signal("stage_ended")
# 游戏功能函数

func draw_cards(draw_count:int)-> void:
	system.draw_cards(draw_count,system.current_player_index)
