extends Control

# 在控制脚本中维护这些变量
var current_seed = 0.0
var effect_enabled = true
 
func _process(_delta):
	if Engine.get_process_frames() % 2 == 0:
		randomize()
		# 更新种子（示例：每帧递增）
		current_seed = randi_range(1000,10000)/10000.0
		toggle_effect()
		material.set_shader_parameter("execute_effect", effect_enabled)
		material.set_shader_parameter("random_seed", current_seed)
 
func toggle_effect():
	effect_enabled = !effect_enabled
 
func set_random_seed(new_seed):
	current_seed = new_seed
