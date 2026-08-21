## 闪电连接线的数据与动画类，负责存储曲线点集、执行电光闪烁动画。
extends RefCounted

## 曲线局部坐标点集
var points: PackedVector2Array = PackedVector2Array()
## 内线颜色
var inner_color: Color = Color.AQUA
## 外线起始颜色
var outer_start_color: Color = Color.WHITE
## 外线起始宽度
var outer_start_width: float = 8.0
## 外线结束宽度
var outer_end_width: float = 2.0
## 内线宽度
var inner_width: float = 2.0
## 外线动画时长
var outer_anim_time: float = 0.5
## 内线淡入时长
var inner_fadein_time: float = 0.1
## 当前外线颜色
var outer_color: Color = Color.WHITE
## 当前外线宽度
var outer_width: float = 8.0
## 当前内线透明度
var inner_alpha: float = 0.0

enum State { HIDDEN, ANIMATING, STABLE }
## 当前线状态
var state: State = State.HIDDEN

var _tween: Tween = null

## 启动电光闪烁动画，host 用于创建 Tween
func start_animation(host: Control) -> void:
	if state == State.ANIMATING:
		return
	outer_color = outer_start_color
	outer_width = outer_start_width
	inner_alpha = 0.0
	kill_tween()
	_tween = host.create_tween()
	state = State.ANIMATING
	_tween.set_parallel(true)
	_tween.tween_method(_set_outer_properties, 0.0, 1.0, outer_anim_time).set_ease(Tween.EASE_OUT)
	_tween.tween_method(_set_inner_alpha, 0.0, 1.0, inner_fadein_time).set_ease(Tween.EASE_IN)
	_tween.chain()
	_tween.tween_callback(_on_animation_finished)

## 停止动画并重置为隐藏状态，同时清除视觉属性
func kill_animation() -> void:
	kill_tween()
	state = State.HIDDEN
	outer_color.a = 0.0
	inner_alpha = 0.0

func kill_tween() -> void:
	if _tween:
		_tween.kill()
		_tween = null

func _set_outer_properties(progress: float) -> void:
	outer_color = outer_start_color.lerp(inner_color, progress)
	outer_width = lerpf(outer_start_width, outer_end_width, progress)

func _set_inner_alpha(alpha: float) -> void:
	inner_alpha = alpha

func _on_animation_finished() -> void:
	state = State.STABLE
	outer_color = inner_color
	outer_width = outer_end_width
	inner_alpha = 1.0
	_tween = null
