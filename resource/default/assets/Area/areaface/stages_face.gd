## StageFace 负责在阶段切换时，以冲击性滑动动画更新主/次显示标签。
## 标签文本包含阶段名称与回合所属玩家 ID，通过 RenderStateManager 信号驱动。
extends Control

# ==================== 常量 ====================
## 主标签正常位置（相对于控件原点）
const MAIN_POS: Vector2 = Vector2(0, 0)
## 次标签相对于主标签的偏移量
const SECONDARY_OFFSET: Vector2 = Vector2(160, 0)
## 新阶段滑入动画持续时间（秒）
const SLIDE_IN_DURATION: float = 0.3
## 旧阶段被顶开后，在滑出前的延迟时间（秒）
const DELAY_DURATION: float = 0.5
## 旧阶段滑出屏幕的持续时间（秒）
const SLIDE_OUT_DURATION: float = 0.3
## 阶段文本初始滑入时的额外左边距（防止紧贴边缘）
const SLIDE_IN_MARGIN: float = 30.0

# ==================== 导出变量 ====================
## 用于获取上下文的渲染控制节点（由场景配置）
@export var render_control: RenderControl = null

# ==================== 内部变量 ====================
## 主显示标签
var _main_label: Label = null
## 次显示标签（用于暂时持有旧阶段文本）
var _secondary_label: Label = null
## 动画 Tween 实例
var _tween: Tween = null
## 当前是否正在进行过渡动画
var _is_transitioning: bool = false
## 缓存的主标签位置
var _cached_main_pos: Vector2 = MAIN_POS
## 缓存的次标签位置
var _cached_secondary_pos: Vector2 = MAIN_POS + SECONDARY_OFFSET
## 当前显示的玩家 ID（用于文本格式化）
var _current_player_id: int = RenderContext.PUBLIC_PLAYER_ID

# ==================== 生命周期 ====================
func _ready() -> void:
	_setup_labels()
	if not render_control:
		return
	var ctx: RenderContext = render_control.render_context
	if not ctx or not ctx.state_manager:
		return
	# 连接阶段变更信号
	ctx.state_manager.stage_notified.connect(_on_stage_notified)
	# 立即设置当前阶段文本（若已存在）
	var initial_stage: StringName = ctx.state_manager.current_stage_name
	if not initial_stage.is_empty():
		_current_player_id = ctx.state_manager.current_stage_player_id
		_main_label.text = _format_stage_text(initial_stage, _current_player_id)

## 动态创建并配置两个标签子节点
func _setup_labels() -> void:
	_main_label = Label.new()
	_main_label.name = &"MainLabel"
	_main_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_main_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_main_label)
	_secondary_label = Label.new()
	_secondary_label.name = &"SecondaryLabel"
	_secondary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_secondary_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_secondary_label.visible = false
	add_child(_secondary_label)
	# 初始位置
	_main_label.position = _cached_main_pos
	_secondary_label.position = _cached_secondary_pos

# ==================== 信号回调 ====================
## 当阶段状态通知抵达时，生成包含玩家 ID 的显示文本并启动过渡动画
func _on_stage_notified(stage_name: StringName, current_player_id: int, _params: Dictionary) -> void:
	_current_player_id = current_player_id
	var display_text: String = _format_stage_text(stage_name, current_player_id)
	_start_transition(display_text)

# ==================== 格式化 ====================
## 将阶段名称与玩家 ID 组合为显示文本
func _format_stage_text(stage_name: StringName, player_id: int) -> String:
	return "%s [P%d]" % [stage_name, player_id]

# ==================== 过渡逻辑 ====================
## 启动阶段文本的滑入-顶出-延迟滑出动画，并处理快速切换的中断
func _start_transition(new_text: String) -> void:
	# 若已有动画进行中，立刻中断，以体现冲击感
	if _tween and _tween.is_valid():
		_tween.kill()
	_reset_to_idle_visuals()
	# 首次直接设置文本，无需动画
	if _main_label.text.is_empty():
		_main_label.text = new_text
		return
	# 保存旧文本，准备顶出
	var old_text: String = _main_label.text
	_main_label.text = new_text
	_secondary_label.text = old_text
	_secondary_label.visible = true
	# 计算滑入起始位置（标签在左侧屏幕外）
	_main_label.reset_size()  # 确保尺寸已更新
	var label_width: float = _main_label.size.x
	var start_main: Vector2 = Vector2(-label_width - SLIDE_IN_MARGIN, _cached_main_pos.y)
	# 创建动画
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(_main_label, ^"position", _cached_main_pos, SLIDE_IN_DURATION).from(start_main)
	_tween.tween_property(_secondary_label, ^"position", _cached_secondary_pos, SLIDE_IN_DURATION).from(_cached_main_pos)
	_tween.set_parallel(false)
	_tween.tween_interval(DELAY_DURATION)
	_tween.tween_property(_secondary_label, ^"position:x", -label_width - SLIDE_IN_MARGIN, SLIDE_OUT_DURATION)
	_tween.tween_callback(_on_slide_out_complete)
	_is_transitioning = true

## 动画完全结束后的清理
func _on_slide_out_complete() -> void:
	_secondary_label.visible = false
	_is_transitioning = false

## 将标签瞬间恢复到待命位置（隐藏次标签）
func _reset_to_idle_visuals() -> void:
	_main_label.position = _cached_main_pos
	_secondary_label.position = _cached_secondary_pos
	_secondary_label.visible = false
