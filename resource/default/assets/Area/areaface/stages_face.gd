## StageFace 负责在阶段切换时，以冲击性滑动动画分别更新主阶段与临时阶段显示。
## 主阶段文本居于中心，临时阶段文本位于其下方；两者各自独立拥有消息队列与动画。
## 主阶段切换时，临时阶段立即全部清除；主阶段间为顶开-延迟-上升回拉；
## 临时阶段间为顶开-延迟-下降回拉，不干扰主阶段。
## 只有最后进入的阶段（每行独立）放大显示；队列空时稳定消息加粗。
extends Control

# ==================== 常量 ====================
const MAIN_CENTER_POS := Vector2(0, 0)
const SLIDE_IN_DURATION := 0.3
const DELAY_DURATION := 0.5
const VERTICAL_DURATION := 0.15
const PULL_BACK_DURATION := 0.3
const SLIDE_IN_MARGIN := 30.0
const RIGHT_SPACING := 20.0
const FONT_SIZE_NORMAL := 14
const FONT_SIZE_EMPHASIZED := 28
const MAIN_TO_TEMP_GAP := 8.0

# ==================== 导出变量 ====================
@export var render_control: RenderControl = null

# ==================== 内部枚举 ====================
enum StageLine { MAIN = 0, TEMP = 1 }

class StageMessage:
	var text: String
	var display_player_id: int
	func _init(p_text: String, p_id: int) -> void:
		text = p_text
		display_player_id = p_id

# ==================== 内部变量 ====================
var _labels: Array[Label] = []
var _label_state: Array[StringName] = []
var _label_tweens: Array[Tween] = [null, null, null, null, null, null]
var _label_line: Array[int] = []

var _main_center_idx: int = -1
var _main_right_idx: int = -1
var _main_queue: Array[StageMessage] = []

var _temp_center_idx: int = -1
var _temp_right_idx: int = -1
var _temp_queue: Array[StageMessage] = []

var _temp_vertical_base: float = 0.0

# ==================== 生命周期 ====================
func _ready() -> void:
	_setup_labels()
	if not render_control:
		return
	var ctx: RenderContext = render_control.render_context
	if not ctx or not ctx.state_manager:
		return
	ctx.state_manager.main_stage_notified.connect(_on_main_stage_notified)
	ctx.state_manager.temp_stage_notified.connect(_on_temp_stage_notified)
	var initial_stage: StringName = ctx.state_manager.main_stage_name
	if not initial_stage.is_empty():
		var pid: int = ctx.state_manager.main_stage_player_id
		_show_initial_main(_format_stage_text(initial_stage, pid))

func _setup_labels() -> void:
	for i in 6:
		var label := Label.new()
		label.name = &"StageLabel%d" % i
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.visible = false
		add_child(label)
		_labels.append(label)
		_label_state.append(&"idle")
		_label_line.append(-1)
	_label_tweens.resize(6)
	_label_tweens.fill(null)

func _set_label_emphasized(label: Label, flag: bool) -> void:
	if not label: return
	if flag:
		label.add_theme_font_size_override(&"font_size", FONT_SIZE_EMPHASIZED)
	else:
		label.remove_theme_font_size_override(&"font_size")
	label.reset_size()

func _show_initial_main(text: String) -> void:
	var idx := _get_idle_label_index()
	if idx == -1: return
	_assign_label(idx, StageLine.MAIN, &"main_center")
	_labels[idx].text = text
	_set_label_emphasized(_labels[idx], true)
	_labels[idx].reset_size()
	_labels[idx].position = MAIN_CENTER_POS
	_labels[idx].visible = true
	_main_center_idx = idx

# ==================== 信号回调 ====================
func _on_main_stage_notified(stage_name: StringName, player_id: int, _params: Dictionary) -> void:
	var formatted :String = _format_stage_text(stage_name, player_id)
	_clear_temp_with_pull()
	if _main_center_idx != -1 and _labels[_main_center_idx].text == formatted:
		return
	var msg :StageMessage = StageMessage.new(formatted, player_id)
	_main_queue.append(msg)
	_process_main_queue()

func _on_temp_stage_notified(stage_name: StringName, _turn_id: int, owner_id: int, _params: Dictionary) -> void:
	var msg := StageMessage.new(_format_stage_text(stage_name, owner_id), owner_id)
	_temp_queue.append(msg)
	_process_temp_queue()

func _format_stage_text(stage_name: StringName, player_id: int) -> String:
	return "%s [P%d]" % [stage_name, player_id]

# ==================== 队列处理 ====================
func _process_main_queue() -> void:
	while not _main_queue.is_empty() and _get_idle_label_index() != -1:
		var msg := _main_queue.pop_front() as StageMessage
		var stable := _main_queue.is_empty()
		_start_main_animation(msg.text, stable)

func _process_temp_queue() -> void:
	while not _temp_queue.is_empty() and _get_idle_label_index() != -1:
		var msg := _temp_queue.pop_front() as StageMessage
		var stable := _temp_queue.is_empty()
		_start_temp_animation(msg.text, stable)

# ==================== 主阶段动画 ====================
func _start_main_animation(new_text: String, is_stable: bool) -> void:
	if _main_center_idx == -1:
		_show_initial_main(new_text)
		return
	var new_idx := _get_idle_label_index()
	if new_idx == -1: return
	if _main_right_idx != -1:
		_interrupt_and_pull(_main_right_idx, StageLine.MAIN, true)
		_main_right_idx = -1

	var old_idx := _main_center_idx
	_label_state[old_idx] = &"main_right"
	_label_line[old_idx] = StageLine.MAIN
	_main_right_idx = old_idx
	_main_center_idx = new_idx
	_set_label_emphasized(_labels[old_idx], false)

	var new_label := _labels[new_idx]
	new_label.text = new_text
	_set_label_emphasized(new_label, is_stable)
	new_label.reset_size()
	var w := new_label.get_combined_minimum_size().x
	new_label.position = Vector2(-w - SLIDE_IN_MARGIN, MAIN_CENTER_POS.y)
	new_label.visible = true
	_assign_label(new_idx, StageLine.MAIN, &"main_center")

	var right_pos := MAIN_CENTER_POS + Vector2(w + RIGHT_SPACING, 0)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(new_label, ^"position", MAIN_CENTER_POS, SLIDE_IN_DURATION)
	tween.tween_property(_labels[old_idx], ^"position", right_pos, SLIDE_IN_DURATION)
	tween.set_parallel(false)

	var delay := create_tween()
	_label_tweens[old_idx] = delay
	delay.tween_interval(DELAY_DURATION)
	delay.tween_callback(_start_main_pull_back.bind(old_idx))

func _start_main_pull_back(index: int) -> void:
	if index < 0 or index >= _labels.size(): return
	var label := _labels[index]
	if not label.visible: return
	_label_state[index] = &"main_pulling"
	var h := label.get_combined_minimum_size().y
	if h <= 0: h = 30
	var up_pos := label.position + Vector2(0, -h)
	var w := label.get_combined_minimum_size().x
	var final_pos := Vector2(-w - SLIDE_IN_MARGIN, up_pos.y)

	var tw := create_tween()
	_label_tweens[index] = tw
	tw.tween_property(label, ^"position", up_pos, VERTICAL_DURATION)
	tw.tween_property(label, ^"position", final_pos, PULL_BACK_DURATION)
	tw.tween_callback(_on_pull_complete.bind(index, StageLine.MAIN))

# ==================== 临时阶段动画 ====================
func _start_temp_animation(new_text: String, is_stable: bool) -> void:
	var base_y := MAIN_CENTER_POS.y
	if _main_center_idx != -1:
		var main_label := _labels[_main_center_idx]
		base_y = main_label.position.y + main_label.get_combined_minimum_size().y + MAIN_TO_TEMP_GAP
	_temp_vertical_base = base_y
	var temp_center := Vector2(MAIN_CENTER_POS.x, base_y)

	if _temp_center_idx == -1:
		var idx := _get_idle_label_index()
		if idx == -1: return
		var label := _labels[idx]
		label.text = new_text
		_set_label_emphasized(label, is_stable)
		label.reset_size()
		var w := label.get_combined_minimum_size().x
		label.position = Vector2(-w - SLIDE_IN_MARGIN, temp_center.y)
		label.visible = true
		_assign_label(idx, StageLine.TEMP, &"temp_center")
		_temp_center_idx = idx
		var tw := create_tween()
		_label_tweens[idx] = tw
		tw.tween_property(label, ^"position", temp_center, SLIDE_IN_DURATION)
		tw.tween_callback(_process_temp_queue)
		return

	var new_idx := _get_idle_label_index()
	if new_idx == -1: return
	if _temp_right_idx != -1:
		_interrupt_and_pull(_temp_right_idx, StageLine.TEMP, false)
		_temp_right_idx = -1

	var old_idx := _temp_center_idx
	_label_state[old_idx] = &"temp_right"
	_label_line[old_idx] = StageLine.TEMP
	_temp_right_idx = old_idx
	_temp_center_idx = new_idx
	_set_label_emphasized(_labels[old_idx], false)

	var new_label := _labels[new_idx]
	new_label.text = new_text
	_set_label_emphasized(new_label, is_stable)
	new_label.reset_size()
	var w := new_label.get_combined_minimum_size().x
	new_label.position = Vector2(-w - SLIDE_IN_MARGIN, temp_center.y)
	new_label.visible = true
	_assign_label(new_idx, StageLine.TEMP, &"temp_center")

	var right_pos := temp_center + Vector2(w + RIGHT_SPACING, 0)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(new_label, ^"position", temp_center, SLIDE_IN_DURATION)
	tween.tween_property(_labels[old_idx], ^"position", right_pos, SLIDE_IN_DURATION)
	tween.set_parallel(false)

	var delay := create_tween()
	_label_tweens[old_idx] = delay
	delay.tween_interval(DELAY_DURATION)
	delay.tween_callback(_start_temp_pull_back.bind(old_idx))

func _start_temp_pull_back(index: int) -> void:
	if index < 0 or index >= _labels.size(): return
	var label := _labels[index]
	if not label.visible: return
	_label_state[index] = &"temp_pulling"
	var h := label.get_combined_minimum_size().y
	if h <= 0: h = 30
	var down_pos := label.position + Vector2(0, h)
	var w := label.get_combined_minimum_size().x
	var final_pos := Vector2(-w - SLIDE_IN_MARGIN, down_pos.y)

	var tw := create_tween()
	_label_tweens[index] = tw
	tw.tween_property(label, ^"position", down_pos, VERTICAL_DURATION)
	tw.tween_property(label, ^"position", final_pos, PULL_BACK_DURATION)
	tw.tween_callback(_on_pull_complete.bind(index, StageLine.TEMP))

# ==================== 通用清理 ====================
func _interrupt_and_pull(index: int, line: StageLine, is_main: bool) -> void:
	_kill_tween(index)
	if is_main:
		_start_main_pull_back(index)
	else:
		_start_temp_pull_back(index)

func _on_pull_complete(index: int, line: StageLine) -> void:
	_labels[index].visible = false
	_label_state[index] = &"idle"
	_label_line[index] = -1
	_label_tweens[index] = null
	if line == StageLine.MAIN and _main_right_idx == index:
		_main_right_idx = -1
	elif line == StageLine.TEMP and _temp_right_idx == index:
		_temp_right_idx = -1
	if line == StageLine.MAIN:
		_process_main_queue()
	else:
		_process_temp_queue()

## 清除所有临时阶段（带动画回拉）
func _clear_temp_with_pull() -> void:
	_temp_queue.clear()
	# 启动 center 和 right 的回拉动画
	if _temp_center_idx != -1:
		_interrupt_and_pull(_temp_center_idx, StageLine.TEMP, false)
		_temp_center_idx = -1
	if _temp_right_idx != -1:
		_interrupt_and_pull(_temp_right_idx, StageLine.TEMP, false)
		_temp_right_idx = -1

# ==================== 辅助 ====================
func _get_idle_label_index() -> int:
	for i in _labels.size():
		if _label_state[i] == &"idle":
			return i
	return -1

func _assign_label(idx: int, line: StageLine, state: StringName) -> void:
	_label_line[idx] = line
	_label_state[idx] = state

func _kill_tween(index: int) -> void:
	var tw := _label_tweens[index]
	if tw and tw.is_valid():
		tw.kill()
	_label_tweens[index] = null
