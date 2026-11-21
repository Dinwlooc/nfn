## 预设列表：把一组预设标签渲染成按钮列，点选后回调调用方；选中项高亮。
## 交互与无头共用同一份预设标识，本组件只负责呈现与转发，不持有预设语义。
extends VBoxContainer
class_name LabPresetList

#==字段==
## 回调：被点选的预设下标
var _on_pick: Callable = Callable()
## 当前高亮的预设下标；-1 表示无
var _selected: int = -1

#==列表呈现==
## 重建列表：labels 的下标即预设下标
## @side_effect
func fill(labels: PackedStringArray, on_pick: Callable) -> void:
	_on_pick = on_pick
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	add_theme_constant_override(&"separation", 4)
	for index: int in labels.size():
		var button: Button = Button.new()
		button.text = labels[index]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(0.0, 34.0)
		button.pressed.connect(_on_pressed.bind(index))
		add_child(button)
	mark_selected(_selected)

## 高亮一条预设；越界时清除高亮
## @side_effect
func mark_selected(index: int) -> void:
	_selected = index
	for position: int in get_child_count():
		var button: Button = get_child(position) as Button
		if button == null:
			continue
		button.add_theme_color_override(&"font_color", Color(0.35, 0.95, 0.9) if position == index else Color(1, 1, 1, 1))

#==按钮回调==
## 按钮回调：转发下标
## @internal
func _on_pressed(index: int) -> void:
	mark_selected(index)
	if _on_pick.is_valid():
		_on_pick.call(index)
