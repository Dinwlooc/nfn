## MP 点指示器，继承 Control，内部包含一个 HBoxContainer 作为容器，
## 和一个 ValueLabel 作为平行子节点，用于显示数值。
extends Control

const DotUnit = preload("dot_unit.gd")

## 每个单位的点数（与 DotUnit 保持一致）。
const DOTS_PER_UNIT: int = 4
## 承载 DotUnit 的容器（HBoxContainer）。
@onready var container: HBoxContainer = $Container
## 单位模板（隐藏），类型应为 DotUnit。
@onready var template: Control = $Template
## 数值标签（可选）。
@onready var value_label: Label = $ValueLabel

var _units: Array[DotUnit] = []      ## 所有 DotUnit 实例
var _capacity: int = 0               ## 总点数容量
var _blink_duration: float = 0.2
var _fade_duration: float = 0.2

## 设置总点数容量，调整单位数量。
func set_capacity(new_max: int) -> void:
	if new_max < 0:
		return
	_capacity = new_max
	_adjust_units(new_max)
	_update_units_visibility()

## 设置单个全局点的颜色（可选动画）。
func set_dot_color(global_index: int, color: Color, animate: bool = false) -> void:
	var dot: ColorRect = _get_dot(global_index)
	if dot:
		if animate:
			UIAnimationUtils.blink_color(dot, dot.color, color, _blink_duration)
		else:
			dot.color = color

## 对全局点执行闪烁。
func blink_dot(global_index: int, from_color: Color, to_color: Color, duration: float) -> void:
	var dot: ColorRect = _get_dot(global_index)
	if dot:
		dot.color = from_color
		UIAnimationUtils.blink_color(dot, from_color, to_color, duration)

## 淡出全局点，完成后自动隐藏所在单位（若该单位无可见点）。
func fade_out_dot(global_index: int, duration: float) -> void:
	var unit_index: int = global_index / DOTS_PER_UNIT
	var local_index: int = global_index % DOTS_PER_UNIT
	if unit_index < 0 or unit_index >= _units.size():
		return
	var unit: DotUnit = _units[unit_index]
	unit.fade_out_dot(local_index, duration)

## 清除所有点（释放单位）。
func clear_dots() -> void:
	for unit in _units:
		unit.queue_free()
	_units.clear()
	_capacity = 0

## 更新数值标签（如果存在）。
func update_label_text(current: int, max: int) -> void:
	if value_label:
		value_label.text = "%d / %d" % [current, max]

## 调整单位数量。
func _adjust_units(target_dots: int) -> void:
	var needed_units: int = ceili(float(target_dots) / float(DOTS_PER_UNIT))
	while _units.size() < needed_units:
		var unit: DotUnit = template.duplicate() as DotUnit
		unit.visible = true
		container.add_child(unit)   # 添加到容器中
		_units.append(unit)
	while _units.size() > needed_units:
		var unit: DotUnit = _units.pop_back()
		unit.queue_free()

## 根据容量隐藏多余点（通过设置可见性）。
func _update_units_visibility() -> void:
	var dot_index: int = 0
	for unit in _units:
		for i in range(DOTS_PER_UNIT):
			var dot: ColorRect = unit.get_dot(i)
			if dot:
				dot.visible = dot_index < _capacity
			dot_index += 1
		# 如果单位内所有点都不可见，则隐藏单位本身
		var any_visible: bool = false
		for i in range(DOTS_PER_UNIT):
			var d: ColorRect = unit.get_dot(i)
			if d and d.visible:
				any_visible = true
				break
		unit.visible = any_visible

## 获取全局点索引对应的点。
func _get_dot(global_index: int) -> ColorRect:
	if global_index < 0 or global_index >= _capacity:
		return null
	var unit_index: int = global_index / DOTS_PER_UNIT
	var local_index: int = global_index % DOTS_PER_UNIT
	if unit_index >= _units.size():
		return null
	return _units[unit_index].get_dot(local_index)
