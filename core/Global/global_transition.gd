## 全局转场：全屏黑幕的淡入淡出与带转场的场景切换。
extends Node

## 全屏遮罩矩形，_ready 时创建
var _transition_rect: ColorRect
## 当前淡入淡出补间，重新开始时先 kill 旧补间
var _tween: Tween
## 转场进行中标记，用于阻止重入
var _is_transitioning: bool = false  # 新增转场状态标记

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

## 播放遮罩透明度补间，并在起止时发出对应信号
## @side_effect @emitter
func play_fade_animation(target_alpha: float, duration: float, is_fade_in: bool):
	if _tween:
		_tween.kill()
		_tween = null
	if is_fade_in:
		fade_in_started.emit()
	else:
		fade_out_started.emit()
	_tween = create_tween()
	_tween.tween_property(_transition_rect, "color",
						  Color(0, 0, 0, target_alpha),
						  duration)
	_tween.finished.connect(func():
		if is_fade_in:
			fade_in_completed.emit()
		else:
			fade_out_completed.emit()
	)

## 淡入到全黑
## @delegates
func fade_in(duration: float = 1.5) -> void:
	play_fade_animation(1.0, duration, true)

## 从全黑淡出
## @delegates
func fade_out(duration: float = 1.5) -> void:
	play_fade_animation(0.0, duration, false)

# 添加了转场保护的场景切换方法
## 带转场保护的场景切换：淡入 → 换场景 → 淡出；转场中重复调用直接忽略
## @side_effect
func change_scene_with_transition(scene_path: String,
								 fade_in_duration: float = 0.4,
								 fade_out_duration: float = 2.5) -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	fade_in(fade_in_duration)
	await fade_in_completed
	get_tree().change_scene_to_file(scene_path)
	fade_out(fade_out_duration)
	await fade_out_completed
	_is_transitioning = false
