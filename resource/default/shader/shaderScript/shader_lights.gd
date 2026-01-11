extends Control

var range_min:float = -0.6
var range_max:float = 0
var time

func _process(_delta):
	#update_transition()
	time = Time.get_ticks_msec()*0.001
	material.set_shader_parameter(&"time",time)
func update_transition() -> void:
	if range_min >= 1:
		range_min = -0.6
		range_max = 0
	range_max = range_max + 0.005
	range_min = range_min + 0.005
	material.set_shader_parameter(&"range_min",range_min)
	if range_max < 0.95:
		material.set_shader_parameter(&"range_max",range_max)
	else :
		material.set_shader_parameter(&"range_max",0.95)
	pass
