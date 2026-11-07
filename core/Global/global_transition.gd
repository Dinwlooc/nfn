## 全局转场：全屏黑幕的淡入淡出与带转场的场景切换，切换时以画面中心为基准做穿梭缩放。
extends Node

## 穿梭缩放的起始倍率，画面从该倍率收缩到 1.0
const ZOOM_SCALE: float = 10.0
## 入场淡入时长（秒）
const ENTER_DURATION: float = 2.0
## 切场淡出时长（秒）
const EXIT_DURATION: float = 1.0
## 淡出（到黑）时缩放补间的缓动类型
const EXIT_TRANS: Tween.TransitionType = Tween.TRANS_LINEAR
## 淡出（到黑）时缩放补间的缓动方向
const EXIT_EASE: Tween.EaseType = Tween.EASE_OUT
## 淡入（入场）时缩放补间的缓动类型
const ENTER_TRANS: Tween.TransitionType = Tween.TRANS_EXPO
## 淡入（入场）时缩放补间的缓动方向
const ENTER_EASE: Tween.EaseType = Tween.EASE_OUT
## 黑幕透明度补间的缓动类型
const ALPHA_TRANS: Tween.TransitionType = Tween.TRANS_LINEAR
## 黑幕透明度补间的缓动方向
const ALPHA_EASE: Tween.EaseType = Tween.EASE_IN_OUT

## 全屏遮罩矩形，_ready 时创建
var _transition_rect: ColorRect
## 当前淡入淡出补间，重新开始时先 kill 旧补间
var _tween: Tween
## 根视口画布当前的缩放倍率
var _canvas_scale: float = 1.0

## 淡入开始
## @emitter
signal fade_in_started
## 淡入完成
## @emitter
signal fade_in_completed
## 淡出开始
## @emitter
signal fade_out_started
## 淡出完成
## @emitter
signal fade_out_completed

## 创建全屏遮罩
func _ready() -> void:
	_setup_transition_rect()

## 创建全屏黑色遮罩并挂到本节点
## @side_effect
func _setup_transition_rect() -> void:
	_transition_rect = ColorRect.new()
	_transition_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_transition_rect.z_index = 100
	add_child(_transition_rect)
	var size = get_viewport().get_visible_rect().size
	_transition_rect.size = size
	_transition_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_transition_rect.color = Color.BLACK

## 播放遮罩透明度与画布缩放补间，并在起止时发出对应信号
## @side_effect @emitter
func play_fade_animation(target_alpha: float, duration: float, is_fade_in: bool, start_scale: float, end_scale: float) -> void:
	if _tween:
		_tween.kill()
		_tween = null
	if is_fade_in:
		fade_in_started.emit()
	else:
		fade_out_started.emit()
	if duration <= 0.0:
		_transition_rect.color = Color(0, 0, 0, target_alpha)
		_apply_canvas_scale(end_scale)
		_emit_fade_completed.call_deferred(is_fade_in)
		return
	# 黑幕透明度与缩放各用一组缓动，共用曲线会让黑幕瞬间消失
	var trans_type: Tween.TransitionType = EXIT_TRANS if is_fade_in else ENTER_TRANS
	var ease_type: Tween.EaseType = EXIT_EASE if is_fade_in else ENTER_EASE
	# 入场前把黑幕复位为不透明，避免从上次残留的透明态淡入导致入场没有黑色
	if not is_fade_in:
		_transition_rect.color = Color.BLACK
	_apply_canvas_scale(start_scale)
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(_transition_rect, ^"color",
						  Color(0, 0, 0, target_alpha),
						  duration).set_trans(ALPHA_TRANS).set_ease(ALPHA_EASE)
	_tween.tween_method(_apply_canvas_scale, start_scale, end_scale, duration).set_trans(trans_type).set_ease(ease_type)
	_tween.finished.connect(_emit_fade_completed.bind(is_fade_in))

## 以画面中心为基准缩放根视口画布，倍率为 1.0 时还原
## @side_effect
func _apply_canvas_scale(scale_value: float) -> void:
	_canvas_scale = scale_value
	if is_equal_approx(scale_value, 1.0):
		get_viewport().canvas_transform = Transform2D.IDENTITY
		return
	var center: Vector2 = _transition_rect.get_global_rect().get_center()
	get_viewport().canvas_transform = Transform2D(0.0,
			Vector2(scale_value, scale_value),
			0.0,
			center * (1.0 - scale_value))

## 淡入淡出补间是否仍在运行，用于阻止转场重入
## @pure
func _is_fading() -> bool:
	return _tween != null and _tween.is_running()

## 发出对应方向的淡入淡出完成信号
## @emitter
func _emit_fade_completed(is_fade_in: bool) -> void:
	if is_fade_in:
		fade_in_completed.emit()
		return
	fade_out_completed.emit()

## 淡出到全黑，同时把画面从当前倍率放大到穿梭起始倍率
## @delegates
## @emitter
func fade_in(duration: float = EXIT_DURATION) -> void:
	play_fade_animation(1.0, duration, true, _canvas_scale, ZOOM_SCALE)

## 从全黑淡入，同时把画面从穿梭起始倍率收缩回原始比例
## @delegates
## @emitter
func fade_out(duration: float = ENTER_DURATION) -> void:
	play_fade_animation(0.0, duration, false, ZOOM_SCALE, 1.0)

## 带转场保护的场景切换：淡入 → 换场景 → 淡出；转场中重复调用直接忽略
## @side_effect
func change_scene_with_transition(
	scene_path: String,
	fade_in_duration: float = EXIT_DURATION,
	fade_out_duration: float = ENTER_DURATION
	) -> void:
	if _is_fading():
		return
	fade_in(fade_in_duration)
	await fade_in_completed
	get_tree().change_scene_to_file(scene_path)
	fade_out(fade_out_duration)
	await fade_out_completed
