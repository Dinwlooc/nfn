## 背景：视差随鼠标移动；泛光强度与扩散随鼠标到中心的距离变化，该效果由本场景独立实现。
extends Control

#==consts==
## 背景中心（场景局部坐标）
const CENTER := Vector2(800.0, 450.0)
## 全景尺寸
const VIEW_SIZE := Vector2(1600.0, 900.0)
## 泛光强度下限：开局前 / 开局后
const INTENSITY_MIN_PRE_GAME := 0.0
const INTENSITY_MIN_IN_GAME := 0.87
## 扩散下限：开局前 / 开局后
const SPREAD_MIN_PRE_GAME := 9.0
const SPREAD_MIN_IN_GAME := 0.0
## 距离效果补间时长（秒）
const EFFECT_SMOOTH_TIME := 0.2
## 视差补间时长（秒）
const PARALLAX_TIME := 3.0

#==nodes==
## 背景图：着色器参数的作用对象
@onready var color_rect: TextureRect = $ColorRect

#==vars==
## 视差目标偏移
var target_position := Vector2.ZERO
## 当前视差补间
var tween: Tween
## 距离效果补间槽位
var effect_tween: Tween = null
## 泛光强度上限（取场景实例参数）
var _intensity_max: float = 1.739
## 扩散上限（取场景实例参数）
var _spread_max: float = 19.054
## 游戏是否已开局
var _game_started: bool = false
## 是否启用距离效果（场景实例参数齐备时启用）
var _distance_effect_enabled: bool = false

#==lifecycle==
## 就绪：关闭逐帧处理、忽略鼠标，取着色器上限并接入开局标志
## @override
func _ready() -> void:
	set_process(false)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_read_shader_limits()
	_bind_game_start()

## 接入开局标志：已注册则立即读取，否则等注册信号
## @signal_listener
func _bind_game_start() -> void:
	if GlobalRegistry.has_singleton(GlobalRegistry.RENDER_CONTROL_TYPE):
		_on_render_control_registered(GlobalRegistry.get_singleton(GlobalRegistry.RENDER_CONTROL_TYPE))
		return
	if not GlobalRegistry.singleton_registered.is_connected(_on_singleton_registered):
		GlobalRegistry.singleton_registered.connect(_on_singleton_registered)
## 单例注册：只处理渲染根
## @signal_listener
func _on_singleton_registered(type: String, instance: Node) -> void:
	if type != String(GlobalRegistry.RENDER_CONTROL_TYPE):
		return
	_on_render_control_registered(instance)

#==hooks==
## 鼠标移动：更新距离效果并按缩放反算视差目标
## @override
func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseMotion):
		return
	_apply_distance_effect()
	_update_parallax()
## 按缩放反算视差目标并启动补间
## @internal
func _update_parallax() -> void:
	if scale.x <= 1.0:
		return
	var mouse_pos: Vector2 = get_global_mouse_position()
	mouse_pos.x = clamp(mouse_pos.x, 0.0, VIEW_SIZE.x)
	mouse_pos.y = clamp(mouse_pos.y, 0.0, VIEW_SIZE.y)
	target_position = -mouse_pos * (scale.x - 1.0)
	start_tween()

#==tween==
## 启动视差补间（指数缓出）
## @atomic
func start_tween() -> void:
	tween = UIAnimationUtils.replace_tween(tween, create_tween())
	tween.set_trans(Tween.TRANS_EXPO)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, ^"position", target_position, PARALLAX_TIME)
## 距离效果：开局前立即写入；开局后按补间过渡，旧补间未结束不在实时移动里新建
## @atomic
func _apply_distance_effect() -> void:
	if not _distance_effect_enabled:
		return
	var mouse_pos: Vector2 = get_global_mouse_position().clamp(Vector2.ZERO, VIEW_SIZE)
	var ratio: float = clamp(mouse_pos.distance_to(CENTER) / CENTER.length(), 0.0, 1.0)
	var intensity_min: float = INTENSITY_MIN_IN_GAME if _game_started else INTENSITY_MIN_PRE_GAME
	var intensity: float = lerp(_intensity_max, intensity_min, ratio)
	var spread: float = _spread_for(ratio)
	if not _game_started:
		color_rect.set_instance_shader_parameter(&"bloom_intensity", intensity)
		color_rect.set_instance_shader_parameter(&"spread", spread)
		return
	if effect_tween and effect_tween.is_valid():
		return
	var next: Tween = create_tween().set_parallel(true)
	next.tween_method(_set_shader_parameter.bind(&"bloom_intensity"), _read_parameter(&"bloom_intensity", _intensity_max), intensity, EFFECT_SMOOTH_TIME)
	next.tween_method(_set_shader_parameter.bind(&"spread"), _read_parameter(&"spread", _spread_max), spread, EFFECT_SMOOTH_TIME)
	effect_tween = next

#==internal==
## 扩散取值：开局前越靠近中心越大，开局后随距离增大
## @internal
func _spread_for(ratio: float) -> float:
	if _game_started:
		return lerp(SPREAD_MIN_IN_GAME, _spread_max, ratio)
	return lerp(_spread_max, SPREAD_MIN_PRE_GAME, ratio)
## 取场景里的着色器上限；缺失时不启用距离效果
## @internal
func _read_shader_limits() -> void:
	var intensity: Variant = color_rect.get_instance_shader_parameter(&"bloom_intensity")
	var spread: Variant = color_rect.get_instance_shader_parameter(&"spread")
	if intensity == null or spread == null:
		return
	_intensity_max = float(intensity)
	_spread_max = float(spread)
	_distance_effect_enabled = true
## 取当前实例参数；缺失时回退给定值
## @internal
func _read_parameter(key: StringName, fallback: float) -> float:
	var value: Variant = color_rect.get_instance_shader_parameter(key)
	return float(value) if value != null else fallback
## 写入单个着色器实例参数
## @internal
func _set_shader_parameter(value: float, key: StringName) -> void:
	color_rect.set_instance_shader_parameter(key, value)
## 渲染根注册：取开局标志并订阅一次性开局通知
## @signal_listener
func _on_render_control_registered(instance: Node) -> void:
	var render_control: RenderControl = instance as RenderControl
	if not render_control:
		return
	var state: RenderStateManager = render_control.render_context.state_manager
	_game_started = state.game_started
	if _game_started:
		_apply_distance_effect()
		return
	state.game_started_notified.connect(_on_game_started, CONNECT_ONE_SHOT)
## 开局：切换下限并立即重算距离效果
## @signal_listener
func _on_game_started() -> void:
	_game_started = true
	_apply_distance_effect()
