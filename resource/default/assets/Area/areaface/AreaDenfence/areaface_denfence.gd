extends AreaFace

const DefenceAnimationManager = preload("defence_animation_manager.gd")
const DefencePreviewManager = preload("defence_preview_manager.gd")

## 原始位置（局部坐标，用于参考）
var original_position: Vector2
## 原始尺寸
var original_size: Vector2
## 目标位置（动画过渡用）
var area_target_position: Vector2
## 目标尺寸
var area_target_size: Vector2
## 当前卡牌群组动画的 Tween 实例
var current_card_tween: Tween = null
## 卡牌缩放因子
var total_scale_factor: float = 1.0
## 常规补间动画时长
const TWEEN_TIME: float = 0.2

enum Mode { AUTO, MANUAL }
## 区域连接模式
@export var mode: Mode = Mode.AUTO

# ==================== 管理器实例 ====================
var _anim_manager: DefenceAnimationManager = null
var _preview_manager: DefencePreviewManager = null

# ==================== 浮动相关 ====================
var _float_start_time: float = 0.0
var _float_base_y: Dictionary = {}  # int -> float

# ==================== 生命周期与初始化 ====================

func _ready() -> void:
	_anim_manager = DefenceAnimationManager.new()
	_preview_manager = DefencePreviewManager.new()
	_preview_manager.preview_state_changed.connect(_on_preview_state_changed)
	_preview_manager.request_preview_start.connect(_on_preview_start_requested)

	if mode == Mode.AUTO:
		request_area(RenderArea.DefaultArea.DEFENCE)
	original_position = position
	original_size = size
	area_target_position = original_position
	area_target_size = original_size
	_update_total_scale_factor()
	# 注意：此时 render_context 可能为空，预览管理器需在 _connect_to_area 中注入

func _connect_to_area(target_area: RenderArea) -> void:
	super._connect_to_area(target_area)
	if not (target_area is RenderAreaDefence):
		return
	GlobalConsole._print(["守区接入,", target_area])
	# 注入渲染上下文到预览管理器（确保有效）
	if render_context:
		_preview_manager.set_render_context(render_context)
	if mode == Mode.AUTO:
		_try_auto_connect_local_player()

func _exit_tree() -> void:
	_cleanup_preview_connections()
	if render_context and _area_requested:
		render_context.disconnect_renderarea(_requested_area_name, self._connect_to_area, _requested_player_id)
	_disconnect_from_current_area()

func _process(_delta: float) -> void:
	_preview_manager.update(_delta)
	if _preview_manager.preview_mode and area and not area.items_pool.is_empty():
		_update_floating()

# ==================== 渲染更新 ====================

func render_update(render_event: RenderEvent = RenderEvent.NULL_EVENT) -> void:
	var event_type: StringName = render_event.get_type()
	if event_type == RenderEvent.DefaultType.CARD_ADD or event_type == RenderEvent.DefaultType.CARD_REMOVE:
		_update_total_scale_factor()
	target_position = UIAnimationUtils.generate_coordinates(
		area_target_position,
		area_target_size,
		area.items_pool.size()
	)
	if event_type == RenderEvent.DefaultType.CARD_ADD and area.items_pool.size() == 1:
		_preview_manager.trigger_delayed_preview(render_context)
	tween_update(render_event)

func tween_update(render_event: RenderEvent = RenderEvent.NULL_EVENT) -> void:
	card_move(render_event)

func _into_area() -> void:
	super._into_area()

func _outto_area() -> void:
	super._outto_area()

# ==================== 预览管理器回调 ====================

func _on_preview_state_changed(active: bool) -> void:
	if not active:
		_float_base_y.clear()
	_update_face_cache(active)

func _on_preview_start_requested() -> void:
	_float_start_time = Time.get_ticks_msec() / 1000.0
	card_move()
	_update_face_cache(_preview_manager.preview_mode)

# ==================== 缓存管理 ====================

func _update_face_cache(active: bool) -> void:
	if not area:
		return
	if active:
		var player: RenderItem = _preview_manager.get_player()
		var player_id: int = player.data.get_id() if player and player.data else 0
		area.register_face_cache(&"nfn:preview_mode", true)
		area.register_face_cache(&"nfn:associated_player_id", player_id)
	else:
		area.register_face_cache(&"nfn:preview_mode", false)

# ==================== 核心动画 ====================

func card_move(_render_event: RenderEvent = RenderEvent.NULL_EVENT) -> void:
	if not area or area.items_pool.is_empty() or target_position.is_empty():
		return
	var master_tween: Tween = create_tween()
	var local_id: int = render_context.area_manager.local_player_id if render_context and render_context.area_manager else 0
	_anim_manager.card_move(
		master_tween,
		area.items_pool,
		target_position,
		total_scale_factor,
		_preview_manager.preview_mode,
		local_id,
		get_viewport()
	)
	if current_card_tween:
		current_card_tween.kill()
	current_card_tween = master_tween
	master_tween.finished.connect(_on_tween_finished)

func _on_tween_finished() -> void:
	_float_base_y.clear()
	if _preview_manager.preview_mode and area and not area.items_pool.is_empty():
		var top_card: RenderItem = area.items_pool[area.items_pool.size() - 1]
		if top_card:
			_float_base_y[top_card.get_instance_id()] = top_card.global_position.y

# ==================== 浮动更新 ====================

func _update_floating() -> void:
	var elapsed: float = (Time.get_ticks_msec() / 1000.0) - _float_start_time
	var cards: Array = area.items_pool
	var size: int = cards.size()
	var top_card: RenderItem = cards[size - 1]
	if top_card and not top_card.dragged:
		var offset: float = _anim_manager.get_float_offset(size - 1, elapsed)
		if not _float_base_y.has(top_card.get_instance_id()):
			_float_base_y[top_card.get_instance_id()] = top_card.global_position.y
		top_card.global_position.y = _float_base_y[top_card.get_instance_id()] + offset

# ==================== 预览功能：回调连接（完全保留原逻辑） ====================

var _players_area_connection_active: bool = false

func _try_auto_connect_local_player() -> void:
	if not render_context or _players_area_connection_active:
		return
	_players_area_connection_active = true
	render_context.connect_renderarea(
		RenderAreaPlayers.get_area_name_static(),
		_on_players_area_connected,
		RenderContext.PUBLIC_PLAYER_ID
	)

func _on_players_area_connected(area: RenderArea) -> void:
	if not area is RenderAreaPlayers:
		return
	var pa: RenderAreaPlayers = area as RenderAreaPlayers
	if not pa.select_limit_changed.is_connected(_on_player_area_limit_changed):
		pa.select_limit_changed.connect(_on_player_area_limit_changed)
	if pa.local_player:
		set_player(pa.local_player)
	elif not pa.local_player_received.is_connected(_on_local_player_received):
		pa.local_player_received.connect(_on_local_player_received, CONNECT_ONE_SHOT)

func _on_local_player_received(player: RenderItem) -> void:
	set_player(player)

func _on_player_selection_changed(selected: bool) -> void:
	_preview_manager.check_condition(render_context)

func _on_player_area_limit_changed(new_limit: int) -> void:
	_preview_manager.check_condition(render_context)

# ==================== 公开接口 ====================

func set_player(player: RenderItem) -> void:
	_preview_manager.set_player(player)
	_preview_manager.check_condition(render_context)
	_update_face_cache(_preview_manager.preview_mode)

func get_associated_player() -> RenderItem:
	return _preview_manager.get_player()

func check_preview_condition() -> void:
	_preview_manager.check_condition(render_context)
	_update_face_cache(_preview_manager.preview_mode)

# ==================== 清理 ====================

func _cleanup_preview_connections() -> void:
	if area:
		area.unregister_face_cache(&"nfn:preview_mode")
		area.unregister_face_cache(&"nfn:associated_player_id")
	if render_context:
		var players_area: RenderArea = render_context.get_render_area(
			RenderAreaPlayers.get_area_name_static(),
			RenderContext.PUBLIC_PLAYER_ID
		)
		if players_area:
			if players_area.select_limit_changed.is_connected(_on_player_area_limit_changed):
				players_area.select_limit_changed.disconnect(_on_player_area_limit_changed)
			if players_area is RenderAreaPlayers:
				var pa: RenderAreaPlayers = players_area as RenderAreaPlayers
				if pa.local_player_received.is_connected(_on_local_player_received):
					pa.local_player_received.disconnect(_on_local_player_received)
		render_context.disconnect_renderarea(
			RenderAreaPlayers.get_area_name_static(),
			_on_players_area_connected,
			RenderContext.PUBLIC_PLAYER_ID
		)
	_players_area_connection_active = false
	_preview_manager.cleanup()
	_float_base_y.clear()

# ==================== 缩放更新 ====================

func _update_total_scale_factor() -> void:
	if not area or area.items_pool.is_empty():
		total_scale_factor = 1.0
		return
	var first_card: RenderItem = area.items_pool[0]
	var area_width: float = size.x
	var area_height: float = size.y
	var n: int = area.items_pool.size()
	var s_width: float = area_width / (n * first_card.size.x)
	var s_height: float = area_height / first_card.size.y
	total_scale_factor = min(s_width, s_height)
	total_scale_factor = clamp(total_scale_factor, 0.2, 1.0)
