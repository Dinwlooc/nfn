extends RefCounted
class_name Stage

enum StageType {
	MAIN,          # 主阶段
	INTERRUPT      # 插入阶段
}
signal stage_ended
var system:System
var type: int = StageType.MAIN
var stage_name: String = "Unnamed Stage"
var time_limit: float = 30.0

func _init()->void:
	system = GlobalConsole.system
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

func exit():
	end_stage()
	GlobalConsole.timer.timeout.disconnect(on_timeout)
	GlobalConsole.timer.timer_stop()
	stage_ended.emit()

func handle_operation(op_data: Dictionary):
	pass

func on_timeout()->void:
	exit()
	
func end_stage()->void:
	pass

# 游戏功能函数
func draw_cards(draw_count:int)-> void:
	system.draw_cards(draw_count,system.current_player_index)
