extends Node

var _transition_rect: ColorRect
signal fade_in_started
signal fade_in_completed
signal fade_out_started
signal fade_out_completed
var fade_in_tween:Tween
var fade_out_tween:Tween
func _ready() -> void:
	_setup_transition_rect()
	
func _setup_transition_rect() -> void:
	_transition_rect = ColorRect.new()
	_transition_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_transition_rect.z_index = 100
	add_child(_transition_rect)
	# 确保覆盖整个屏幕
	var size = get_viewport().get_visible_rect().size
	_transition_rect.size = size
	_transition_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_transition_rect.color = Color.BLACK
# 播放淡入效果
func fade_in(duration:float = 1.5) -> void:
	if fade_in_tween:
		fade_in_tween.kill()
	fade_in_started.emit()
	fade_in_tween = UIAnimationUtils.tween_animations(_transition_rect, {^"color": Color.BLACK}, duration)
	fade_in_tween.finished.connect(emit_signal.bind(&"fade_in_completed"))
# 播放淡出效果
func fade_out(duration:float = 1.5) -> void:
	if fade_out_tween:
		fade_out_tween.kill()
	fade_out_started.emit()
	fade_out_tween = UIAnimationUtils.tween_animations(_transition_rect, {^"color": Color(Color.BLACK, 0)},duration)
	fade_out_tween.finished.connect(emit_signal.bind(&"fade_out_completed"))

# 带转场的场景切换
func change_scene_with_transition(scene_path: String, fade_in_duration:float = 0.4, fade_out_duration:float = 2.5) -> void:
	fade_in(fade_in_duration)
	await fade_in_completed
	get_tree().change_scene_to_file(scene_path)
	fade_out(fade_out_duration)
