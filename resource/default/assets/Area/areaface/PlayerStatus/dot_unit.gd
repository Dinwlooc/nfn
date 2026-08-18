## 单个 MP 单位，包含固定数量的点（ColorRect），按行排列。
## 继承 Control，内部包含一个 HBoxContainer 作为点的容器。
extends Control
## 每个单位的点数量（固定为4）。
const DOTS_PER_UNIT: int = 4
## 点的容器（HBoxContainer）。
@onready var dot_container: GridContainer = $DotContainer
var _dots: Array[ColorRect] = []  ## 当前单位内的所有点。
func _ready() -> void:
	# 收集所有点（假设点直接作为 dot_container 的子节点）
	for child in dot_container.get_children():
		if child is ColorRect:
			_dots.append(child as ColorRect)
	# 确保数量匹配
	assert(_dots.size() == DOTS_PER_UNIT, "DotUnit must have exactly %d ColorRect children." % DOTS_PER_UNIT)
## 设置单位内指定索引点的颜色（可选动画）。
func set_dot_color(local_index: int, color: Color, animate: bool = false) -> void:
	if local_index < 0 or local_index >= _dots.size():
		return
	var dot: ColorRect = _dots[local_index]
	if animate:
		UIAnimationUtils.blink_color(dot, dot.color, color, 0.2)  # 使用默认时长，可传入
	else:
		dot.color = color
## 对指定点执行从起始颜色到目标颜色的闪烁。
func blink_dot(local_index: int, from_color: Color, to_color: Color, duration: float) -> void:
	if local_index < 0 or local_index >= _dots.size():
		return
	var dot: ColorRect = _dots[local_index]
	dot.color = from_color
	UIAnimationUtils.blink_color(dot, from_color, to_color, duration)
## 淡出指定点（透明度过渡到0），完成后检查是否所有点均不可见，若是则隐藏整个单位。
func fade_out_dot(local_index: int, duration: float) -> void:
	if local_index < 0 or local_index >= _dots.size():
		return
	var dot: ColorRect = _dots[local_index]
	var tween: Tween = create_tween()
	tween.tween_property(dot, ^"color", Color.TRANSPARENT, duration)
	tween.finished.connect(_on_dot_fade_out_finished.bind(dot), CONNECT_ONE_SHOT)
## 检查单位是否还有可见点（透明度 > 0.01）。
func has_visible_dots() -> bool:
	for dot in _dots:
		if dot.color.a > 0.01:
			return true
	return false
## 获取指定点的引用。
func get_dot(local_index: int) -> ColorRect:
	if local_index < 0 or local_index >= _dots.size():
		return null
	return _dots[local_index]
## 淡出完成回调：如果单位无可见点则隐藏自身。
func _on_dot_fade_out_finished(dot: ColorRect) -> void:
	if not has_visible_dots():
		visible = false
