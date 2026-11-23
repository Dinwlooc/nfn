## StageFace 负责在阶段切换时，以冲击性滑动动画分别更新主阶段与临时阶段显示。
## 主阶段文本居于中心；临时阶段按阶段栈自上而下逐条列出，栈尾为当前临时阶段。
## 主阶段切换时，临时阶段立即全部清除；主阶段间为顶开-延迟-上升回拉；
## 临时阶段入栈时滑入，出栈时顶开-延迟-下降回拉。
## 每条阶段文本各自做分层随动与远离缩小：只有栈尾是最大重量，越靠前越轻。
extends Control

# ==================== 常量 ====================
## 主阶段文本的居中坐标
const MAIN_CENTER_POS := Vector2(0, 0)
## 滑入动画时长（秒）
const SLIDE_IN_DURATION := 0.3
## 顶开后到回拉的延迟（秒）
const DELAY_DURATION := 0.5
## 垂直顶开时长（秒）
const VERTICAL_DURATION := 0.15
## 回拉退出时长（秒）
const PULL_BACK_DURATION := 0.3
## 滑入起始位置相对左边缘的留白
const SLIDE_IN_MARGIN := 30.0
## 旧标签顶到右侧后的水平间距
const RIGHT_SPACING := 20.0
## 普通字号
const FONT_SIZE_NORMAL := 14
## 强调字号（最后进入的阶段）
const FONT_SIZE_EMPHASIZED := 28
## 主阶段与临时阶段之间的垂直间隔
const MAIN_TO_TEMP_GAP := 8.0
## 临时阶段行相邻标签的垂直间隔
const TEMP_ROW_GAP := 4.0
## 栈尾临时阶段的字号
const FONT_SIZE_TEMP_TAIL := 18
## 栈尾粗体的加重比例
const BOLD_EMBOLDEN := 0.6
## 初始标签数：主阶段居中与右侧各一
const INITIAL_LABEL_COUNT := 2
## 层视差换算工具
const LayerParallax = preload("res://core/Class/Face/Utils/LayerParallax.gd")
## 视差推离幅度（屏幕像素）
const PARALLAX_PUSH := 30.0
## 推离的深度混入量
const PARALLAX_PUSH_MIX := 0.15
## 视差吸向幅度（屏幕像素）
const PARALLAX_PULL := 3.0
## 吸向的深度指数
const PARALLAX_PULL_POWER := 2.5
## 指针死区
const PARALLAX_DEADZONE := 0.08
## 跟随平滑（每秒衰减率）
const PARALLAX_FOLLOW := 10.0
## 远离缩小的影响半径（屏幕像素）
const PARALLAX_RADIUS := 420.0
## 主阶段行在半径处的缩放下限
const PARALLAX_MAIN_MIN_SCALE := 0.88
## 临时阶段行在半径处的缩放下限（比主阶段缩得更明显）
const PARALLAX_TEMP_MIN_SCALE := 0.78
## 权重序列中最靠前的阶段文本的随动权重
const PARALLAX_MIN_WEIGHT := 0.35

# ==================== 枚举 ====================
## 单个阶段标签在动画链上的位置状态
enum LabelState {
	IDLE,
	MAIN_CENTER,
	MAIN_RIGHT,
	MAIN_PULLING,
	TEMP_CENTER,
	TEMP_RIGHT,
	TEMP_PULLING,
}

# ==================== 导出变量 ====================
## 关联的渲染根节点（用于取渲染上下文）
@export var render_control: RenderControl = null

# ==================== 内部枚举 ====================
## 阶段标签归属的行：主阶段行 / 临时阶段行
enum StageLine { MAIN = 0, TEMP = 1 }

## 一条阶段消息（文本 + 展示用玩家 id）
class StageMessage:
	## 已格式化的阶段文本
	var text: String
	## 展示用玩家 id
	var display_player_id: int
	## 构造：绑定文本与玩家 id
	func _init(p_text: String, p_id: int) -> void:
		text = p_text
		display_player_id = p_id

# ==================== 内部变量 ====================
## 文本标签池：按需求增长，数量随阶段栈长度变化
var _labels: Array[Label] = []
## 每个标签的随动持有点（位移与缩放的载体）
var _holders: Array[Control] = []
## 每个标签的状态
var _label_state: Array[LabelState] = []
## 每个标签当前挂载的补间（用于打断）
var _label_tweens: Array[Tween] = []
## 每个标签归属的行
var _label_line: Array[int] = []
## 每个标签平滑后的随动位移
var _parallax_offset: Array[Vector2] = []
## 每个标签平滑后的随动缩放
var _parallax_scale: Array[float] = []

## 主阶段居中标签下标（-1 表示无）
var _main_center_idx: int = -1
## 主阶段右侧「被顶开」标签下标
var _main_right_idx: int = -1
## 主阶段待播消息队列
var _main_queue: Array[StageMessage] = []

## 临时阶段行：按下标顺序是栈底到栈尾的标签下标
var _temp_entries: Array[int] = []
## 临时阶段行每条对应的阶段名
var _temp_names: Array[StringName] = []

## 栈尾粗体变体（内置字体加粗）
var _bold_font: FontVariation = null

# ==================== 生命周期 ====================
## 就绪：建标签池、建粗体变体并接入阶段通知信号
func _ready() -> void:
	_setup_labels()
	_ensure_bold_font()
	if not render_control:
		return
	var ctx: RenderContext = render_control.render_context
	if not ctx or not ctx.state_manager:
		return
	ctx.state_manager.stage_set_notified.connect(_on_stage_set_notified)
	var initial_stage: StagePack = ctx.state_manager.main_stage
	if initial_stage and not initial_stage.stage_name.is_empty():
		_show_initial_main(_format_stage_text(initial_stage.stage_name, initial_stage.current_player_id))

## 每帧：按指针刷新每条阶段文本的分层随动
## @override
func _process(delta: float) -> void:
	_update_parallax(delta)

## 创建初始标签
func _setup_labels() -> void:
	for i in INITIAL_LABEL_COUNT:
		_create_label()

## 建栈尾用的粗体变体
func _ensure_bold_font() -> void:
	_bold_font = FontVariation.new()
	_bold_font.base_font = ThemeDB.fallback_font
	_bold_font.variation_embolden = BOLD_EMBOLDEN

## 切换标签的强调字号
func _set_label_emphasized(label: Label, flag: bool) -> void:
	if not label: return
	if flag:
		label.add_theme_font_size_override(&"font_size", FONT_SIZE_EMPHASIZED)
		label.reset_size()
		return
	label.remove_theme_font_size_override(&"font_size")
	label.reset_size()

## 直接显示初始主阶段文本
func _show_initial_main(text: String) -> void:
	var idx := _acquire_label()
	_assign_label(idx, StageLine.MAIN, LabelState.MAIN_CENTER)
	_labels[idx].text = text
	_set_label_emphasized(_labels[idx], true)
	_labels[idx].reset_size()
	_labels[idx].position = MAIN_CENTER_POS
	_labels[idx].visible = true
	_main_center_idx = idx

# ==================== 信号回调 ====================
## 阶段集合通知：主阶段位点走主阶段行，临时阶段位点按整份栈刷新临时行
## 增量包只携带变化字段，展示必须取合并后的位点缓存，不能读包体本身
## @signal_listener
func _on_stage_set_notified(stage_set: RenderRequest.StageSet) -> void:
	var ctx: RenderContext = render_control.render_context if render_control else null
	if not ctx or not ctx.state_manager:
		return
	if RenderRequest.StageSet.is_main_site(stage_set.stage_site):
		var main_pack: StagePack = ctx.state_manager.get_main_stage()
		if main_pack:
			_on_main_stage(main_pack.stage_name, main_pack.current_player_id)
		return
	_sync_temp_stack(ctx.state_manager.temp_stage_stack)

## 主阶段通知：清空临时行并入队主阶段消息
func _on_main_stage(stage_name: StringName, player_id: int) -> void:
	var formatted :String = _format_stage_text(stage_name, player_id)
	_clear_temp_with_pull()
	if _main_center_idx != -1 and _labels[_main_center_idx].text == formatted:
		return
	var msg :StageMessage = StageMessage.new(formatted, player_id)
	_main_queue.append(msg)
	_process_main_queue()

## 格式化阶段文本为「阶段名 [P玩家id]」；阶段名按翻译键 nfn:stage_* 取值，键缺失时回退为键本身
func _format_stage_text(stage_name: StringName, player_id: int) -> String:
	var stage_key: StringName = StringName("nfn:stage_" + String(stage_name))
	return "%s [P%d]" % [GlobalConfig.get_translation(stage_key), player_id]

# ==================== 临时阶段栈 ====================
## 按整份阶段栈同步临时行：栈底在上、栈尾在下，节点数随栈长增减
## @side_effect
func _sync_temp_stack(stack: Array[StagePack]) -> void:
	var packs: Array[StagePack] = []
	for pack in stack:
		if pack:
			packs.append(pack)
	while _temp_entries.size() > packs.size():
		var leaving: int = _temp_entries.pop_back()
		_temp_names.pop_back()
		_interrupt_and_pull(leaving, StageLine.TEMP, false)
	while _temp_entries.size() < packs.size():
		var enter_index: int = _temp_entries.size()
		var idx: int = _acquire_label()
		_temp_entries.append(idx)
		_temp_names.append(&"")
		_play_temp_enter(idx, enter_index, packs[enter_index])
	for i in _temp_entries.size():
		var label: Label = _labels[_temp_entries[i]]
		var pack: StagePack = packs[i]
		var text: String = _format_stage_text(pack.stage_name, pack.temporary_stage_player_id)
		_temp_names[i] = pack.stage_name
		if label.text != text:
			label.text = text
			label.reset_size()
		_set_temp_style(label, i == _temp_entries.size() - 1)
	_place_temp_labels()

## 临时阶段入栈：从左侧滑入到所在行
## @side_effect
func _play_temp_enter(index: int, row: int, pack: StagePack) -> void:
	var label: Label = _labels[index]
	label.text = _format_stage_text(pack.stage_name, pack.temporary_stage_player_id)
	label.reset_size()
	var target := Vector2(MAIN_CENTER_POS.x, _temp_row_y(row))
	var w := label.get_combined_minimum_size().x
	label.position = Vector2(-w - SLIDE_IN_MARGIN, target.y)
	label.visible = true
	_assign_label(index, StageLine.TEMP, LabelState.TEMP_CENTER)
	var tw := create_tween()
	_label_tweens[index] = tw
	tw.tween_property(label, ^"position", target, SLIDE_IN_DURATION)

## 重排临时行：仅摆放未在动画中的标签
## @side_effect
func _place_temp_labels() -> void:
	for i in _temp_entries.size():
		var index: int = _temp_entries[i]
		var tw := _label_tweens[index]
		if tw and tw.is_valid() and tw.is_running():
			continue
		_labels[index].position = Vector2(MAIN_CENTER_POS.x, _temp_row_y(i))

## 临时行第 index 条的纵向基准：主阶段文本下缘加间隔，逐条累加各行高度
## @internal
func _temp_row_y(index: int) -> float:
	var y: float = MAIN_CENTER_POS.y
	if _main_center_idx != -1:
		var main_label := _labels[_main_center_idx]
		y = main_label.position.y + main_label.get_combined_minimum_size().y + MAIN_TO_TEMP_GAP
	for j in index:
		y += _labels[_temp_entries[j]].get_combined_minimum_size().y + TEMP_ROW_GAP
	return y

## 临时阶段文本样式：栈尾略大并加粗，其余按普通字号
## @side_effect
func _set_temp_style(label: Label, is_tail: bool) -> void:
	if is_tail:
		label.add_theme_font_size_override(&"font_size", FONT_SIZE_TEMP_TAIL)
		label.add_theme_font_override(&"font", _bold_font)
		label.reset_size()
		return
	label.add_theme_font_size_override(&"font_size", FONT_SIZE_NORMAL)
	label.remove_theme_font_override(&"font")
	label.reset_size()

# ==================== 队列处理 ====================
## 消费主阶段队列，直到无空闲标签
func _process_main_queue() -> void:
	while not _main_queue.is_empty() and _get_idle_label_index() != -1:
		var msg := _main_queue.pop_front() as StageMessage
		var stable := _main_queue.is_empty()
		_start_main_animation(msg.text, stable)

# ==================== 主阶段动画 ====================
## 主阶段切换：新标签滑入、旧标签顶到右侧，延迟后回拉
func _start_main_animation(new_text: String, is_stable: bool) -> void:
	if _main_center_idx == -1:
		_show_initial_main(new_text)
		return
	var new_idx := _acquire_label()
	if _main_right_idx != -1:
		_interrupt_and_pull(_main_right_idx, StageLine.MAIN, true)
		_main_right_idx = -1

	var old_idx := _main_center_idx
	_label_state[old_idx] = LabelState.MAIN_RIGHT
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
	_assign_label(new_idx, StageLine.MAIN, LabelState.MAIN_CENTER)

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

## 主阶段回拉：先向上顶开，再向左滑出
func _start_main_pull_back(index: int) -> void:
	if index < 0 or index >= _labels.size(): return
	var label := _labels[index]
	if not label.visible: return
	_label_state[index] = LabelState.MAIN_PULLING
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
## 临时阶段出栈：先向下顶开，再向左滑出
func _start_temp_pull_back(index: int) -> void:
	if index < 0 or index >= _labels.size(): return
	var label := _labels[index]
	if not label.visible: return
	_label_state[index] = LabelState.TEMP_PULLING
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
## 打断标签动画并立即回拉
func _interrupt_and_pull(index: int, line: StageLine, is_main: bool) -> void:
	_kill_tween(index)
	if is_main:
		_start_main_pull_back(index)
		return
	_start_temp_pull_back(index)

## 回拉完成：回收标签并继续消费主阶段队列
func _on_pull_complete(index: int, line: StageLine) -> void:
	_labels[index].visible = false
	_label_state[index] = LabelState.IDLE
	_label_line[index] = -1
	_label_tweens[index] = null
	if line != StageLine.MAIN:
		return
	if _main_right_idx == index:
		_main_right_idx = -1
	_process_main_queue()

## 清除所有临时阶段（带动画回拉）
func _clear_temp_with_pull() -> void:
	for index in _temp_entries:
		_interrupt_and_pull(index, StageLine.TEMP, false)
	_temp_entries.clear()
	_temp_names.clear()

# ==================== 分层随动 ====================
## 刷新每条可见阶段文本的随动位移与缩放：权重按显示序列递减，栈尾为满权重
## @side_effect
func _update_parallax(delta: float) -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var mouse_position: Vector2 = get_viewport().get_mouse_position()
	var pointer: Vector2 = LayerParallax.normalize_pointer(mouse_position, viewport_size, PARALLAX_DEADZONE)
	var self_transform: Transform2D = get_global_transform()
	var item_scale: float = self_transform.get_scale().x
	var follow: float = 1.0 - exp(-PARALLAX_FOLLOW * delta)
	var total: float = float(_temp_entries.size() + 1)
	for i in _labels.size():
		if not _labels[i].visible:
			continue
		var weight: float = _weight_of(i, total)
		var min_scale: float = PARALLAX_MAIN_MIN_SCALE if _label_line[i] == StageLine.MAIN else PARALLAX_TEMP_MIN_SCALE
		var base_center: Vector2 = _labels[i].position + _labels[i].get_combined_minimum_size() * 0.5
		var center_global: Vector2 = self_transform * base_center
		var push: Vector2 = LayerParallax.push_vector(pointer, weight, PARALLAX_PUSH, PARALLAX_PUSH_MIX)
		var pull: Vector2 = LayerParallax.pull_vector(center_global, mouse_position, weight, PARALLAX_PULL, PARALLAX_PULL_POWER)
		var target_offset: Vector2 = LayerParallax.offset_for(push + pull, item_scale)
		var target_scale: float = LayerParallax.scale_for(center_global, mouse_position, PARALLAX_RADIUS, min_scale)
		_parallax_offset[i] = _parallax_offset[i].lerp(target_offset, follow)
		_parallax_scale[i] = lerpf(_parallax_scale[i], target_scale, follow)
		_holders[i].position = _parallax_offset[i]
		_holders[i].pivot_offset = base_center
		_holders[i].scale = Vector2(_parallax_scale[i], _parallax_scale[i])

## 该标签在显示序列中的随动权重：序列为主阶段在首、栈尾在末
## @pure
func _weight_of(index: int, total: float) -> float:
	var order: float = 0.0
	var position: int = _temp_entries.find(index)
	if position != -1:
		order = float(position + 1)
	return lerpf(PARALLAX_MIN_WEIGHT, 1.0, order / maxf(total - 1.0, 1.0))

# ==================== 辅助 ====================
## 取一个空闲标签下标（无则 -1）
func _get_idle_label_index() -> int:
	for i in _labels.size():
		if _label_state[i] == LabelState.IDLE:
			return i
	return -1

## 取一个空闲标签，没有空闲时新建，节点数随需求增长
## @side_effect
func _acquire_label() -> int:
	var idx := _get_idle_label_index()
	if idx != -1:
		return idx
	return _create_label()

## 新建一个标签：外层持有随动位移与缩放，内层文本由动画写 position
## @side_effect
func _create_label() -> int:
	var index: int = _labels.size()
	var holder := Control.new()
	holder.name = &"StageLayer%d" % index
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	var label := Label.new()
	label.name = &"StageLabel%d" % index
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.visible = false
	holder.add_child(label)
	_labels.append(label)
	_holders.append(holder)
	_label_state.append(LabelState.IDLE)
	_label_line.append(-1)
	_label_tweens.append(null)
	_parallax_offset.append(Vector2.ZERO)
	_parallax_scale.append(1.0)
	return index

## 登记标签归属行与状态
func _assign_label(idx: int, line: StageLine, state: LabelState) -> void:
	_label_line[idx] = line
	_label_state[idx] = state

## 终止标签上挂载的补间
func _kill_tween(index: int) -> void:
	var tw := _label_tweens[index]
	if tw and tw.is_valid():
		tw.kill()
	_label_tweens[index] = null
