extends Control

# 假设该节点已手动配置好上述泛光着色器的 ShaderMaterial
# 扫描范围参数
var range_min: float = -0.6   # 实际将映射到 threshold_min（会被钳位到 0~1）
var range_max: float = 0.0    # 映射到 threshold_max

func _process(_delta: float) -> void:
	pass

func _update_transition() -> void:
	# 范围滑动逻辑
	if range_min >= 1.0:
		range_min = -0.6
		range_max = 0.0
	range_max += 0.005
	range_min += 0.005
	var min_clamped = clamp(range_min, 0.0, 1.0)
	var max_clamped = clamp(range_max, 0.0, 1.0)
	if min_clamped > max_clamped:
		min_clamped = max_clamped
	ShaderEffectsUtils.set_bloom_range(self, min_clamped, max_clamped)
