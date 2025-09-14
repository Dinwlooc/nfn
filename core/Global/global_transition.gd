extends Node

var _transition_rect: ColorRect
var _tween: Tween
var _is_transitioning: bool = false  # 新增转场状态标记

signal fade_in_started
signal fade_in_completed
signal fade_out_started
signal fade_out_completed

func _ready() -> void:
	_setup_transition_rect()

func _setup_transition_rect() -> void:
	_transition_rect = ColorRect.new()
	_transition_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_transition_rect.z_index = 100
	add_child(_transition_rect)
	var size = get_viewport().get_visible_rect().size
	_transition_rect.size = size
	_transition_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_transition_rect.color = Color.BLACK

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

func fade_in(duration: float = 1.5) -> void:
	play_fade_animation(1.0, duration, true)

func fade_out(duration: float = 1.5) -> void:
	play_fade_animation(0.0, duration, false)

# 添加了转场保护的场景切换方法
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
