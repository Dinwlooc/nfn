extends Control

## 着色器渐变区间下界
var range_min:float = -0.6
## 着色器渐变区间上界
var range_max:float = 0
## 着色器时间参数
var time

## 每帧推进着色器时间参数
func _process(_delta):
	#update_transition()
	time = Time.get_ticks_msec()*0.001
	material.set_shader_parameter("time",time)
## 推进渐变区间（越界回绕并对上界封顶 0.95）
func update_transition() -> void:
	if range_min >= 1:
		range_min = -0.6
		range_max = 0
	range_max = range_max + 0.005
	range_min = range_min + 0.005
	material.set_shader_parameter("range_min",range_min)
	if range_max < 0.95:
		material.set_shader_parameter("range_max",range_max)
	else :
		material.set_shader_parameter("range_max",0.95)
	pass
