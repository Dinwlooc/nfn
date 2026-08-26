## 守区专用 AreaFace，负责卡牌布局、预览动画及玩家关联。
extends AreaFace

const DefenceAnimationManager = preload("defence_animation_manager.gd")
const DefencePreviewManager = preload("defence_preview_manager.gd")

enum Mode { AUTO, MANUAL }
@export var mode: Mode = Mode.AUTO

var original_position: Vector2
var original_size: Vector2
var area_target_position: Vector2
var area_target_size: Vector2
var current_card_tween: Tween = null
var total_scale_factor: float = 1.0
const TWEEN_TIME: float = 0.2

var _anim_manager: DefenceAnimationManager = null
var _preview_manager: DefencePreviewManager = null
var _float_start_time: float = 0.0
var _float_base_y: Dictionary[int, float] = {}

var _players_area: RenderAreaPlayers = null
var _local_player_received_callback: Callable
var _select_limit_changed_callback: Callable

func _ready() -> void:
	_anim_manager = DefenceAnimationManager.new()
	_preview_manager = DefencePreviewManager.new()
	_preview_manager.preview_state_changed.connect(_on_preview_state_changed)
	_preview_manager.request_preview_start.connect(_on_preview_start_requested)

	_local_player_received_callback = _on_local_player_received
	_select_limit_changed_callback = _on_player_area_limit_changed

	if mode == Mode.AUTO:
		request_area(RenderArea.DefaultArea.DEFENCE)

	original_position = position
	original_size = size
	area_target_position = original_position
	area_target_size = original_size
	_update_total_scale_factor()

func _connect_to_area(target_area: RenderArea) -> void:
	super._connect_to_area(target_area)
	if target_area is RenderAreaDefence:
		GlobalConsole._print(["守区接入,", target_area])
		if render_context:
			_preview_manager.set_render_context(render_context)
			if mode == Mode.AUTO:
				render_context.connect_renderarea(
					RenderAreaPlayers.get_area_name_static(),
					_on_players_area_connected,
					RenderContext.PUBLIC_PLAYER_ID
				)

func _disconnect_from_area(target_area: RenderArea) -> void:
	if target_area is RenderAreaDefence:
		if render_context and mode == Mode.AUTO:
			render_context.disconnect_renderarea(
				RenderAreaPlayers.get_area_name_static(),
				_on_players_area_connected,
				RenderContext.PUBLIC_PLAYER_ID
			)
		if _players_area:
			if _players_area.local_player_received.is_connected(_local_player_received_callback):
				_players_area.local_player_received.disconnect(_local_player_received_callback)
			if _players_area.select_limit_changed.is_connected(_select_limit_changed_callback):
				_players_area.select_limit_changed.disconnect(_select_limit_changed_callback)
			_players_area = null
		if _preview_manager.preview_state_changed.is_connected(_on_preview_state_changed):
			_preview_manager.preview_state_changed.disconnect(_on_preview_state_changed)
		if _preview_manager.request_preview_start.is_connected(_on_preview_start_requested):
			_preview_manager.request_preview_start.disconnect(_on_preview_start_requested)
		_preview_manager.cleanup()
		_float_base_y.clear()
		if area:
			area.unregister_face_cache(&"nfn:preview_mode")
	super._disconnect_from_area(target_area)

func _exit_tree() -> void:
	super._exit_tree()

func _process(_delta: float) -> void:
	_preview_manager.update(_delta)
	if _preview_manager.preview_mode and area and not area.items_pool.is_empty():
		_update_floating()

func render_update(render_event: RenderEvent = RenderEvent.NULL_EVENT) -> void:
	var event_type: StringName = render_event.get_type()
	if event_type == RenderEvent.DefaultType.CARD_ADD or event_type == RenderEvent.DefaultType.CARD_REMOVE:
		_update_total_scale_factor()
	if area:
		target_position = UIAnimationUtils.generate_coordinates(
			area_target_position,
			area_target_size,
			area.items_pool.size()
		)
	if event_type == RenderEvent.DefaultType.CARD_ADD and area and area.items_pool.size() == 1:
		_preview_manager.trigger_delayed_preview(render_context)
	tween_update(render_event)

func tween_update(render_event: RenderEvent = RenderEvent.NULL_EVENT) -> void:
	card_move(render_event)

func _into_area() -> void:
	super._into_area()

func _outto_area() -> void:
	super._outto_area()

func set_player(player: RenderItem) -> void:
	_preview_manager.set_player(player)
	_preview_manager.check_condition(render_context)
	_update_face_cache(_preview_manager.preview_mode)

func get_associated_player() -> RenderItem:
	return _preview_manager.get_player()

func check_preview_condition() -> void:
	_preview_manager.check_condition(render_context)
	_update_face_cache(_preview_manager.preview_mode)

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
	if not _preview_manager.preview_mode or not area or area.items_pool.is_empty():
		return
	var top_card: RenderItem = area.items_pool[area.items_pool.size() - 1]
	if top_card:
		_float_base_y[top_card.get_instance_id()] = top_card.global_position.y

func _update_floating() -> void:
	var elapsed: float = (Time.get_ticks_msec() / 1000.0) - _float_start_time
	var cards: Array[RenderItem] = area.items_pool
	var size: int = cards.size()
	var top_card: RenderItem = cards[size - 1]
	if top_card and not top_card.dragged:
		var offset: float = _anim_manager.get_float_offset(size - 1, elapsed)
		if not _float_base_y.has(top_card.get_instance_id()):
			_float_base_y[top_card.get_instance_id()] = top_card.global_position.y
		top_card.global_position.y = _float_base_y[top_card.get_instance_id()] + offset

func _on_preview_state_changed(active: bool) -> void:
	if not active:
		_float_base_y.clear()
	_update_face_cache(active)

func _on_preview_start_requested() -> void:
	_float_start_time = Time.get_ticks_msec() / 1000.0
	card_move()
	_update_face_cache(_preview_manager.preview_mode)

func _update_face_cache(active: bool) -> void:
	if not area:
		return
	area.register_face_cache(&"nfn:preview_mode", active)

func _on_players_area_connected(new_players: RenderArea, old_players: RenderArea) -> void:
	if not new_players is RenderAreaPlayers:
		return
	if old_players and old_players is RenderAreaPlayers:
		if old_players.local_player_received.is_connected(_local_player_received_callback):
			old_players.local_player_received.disconnect(_local_player_received_callback)
		if old_players.select_limit_changed.is_connected(_select_limit_changed_callback):
			old_players.select_limit_changed.disconnect(_select_limit_changed_callback)
		if _players_area == old_players:
			_players_area = null
	var pa: RenderAreaPlayers = new_players as RenderAreaPlayers
	if not pa.local_player_received.is_connected(_local_player_received_callback):
		pa.local_player_received.connect(_local_player_received_callback)
	if not pa.select_limit_changed.is_connected(_select_limit_changed_callback):
		pa.select_limit_changed.connect(_select_limit_changed_callback)
	_players_area = pa
	if pa.local_player:
		set_player(pa.local_player)

func _on_local_player_received(player: RenderItem) -> void:
	set_player(player)

func _on_player_area_limit_changed(_new_limit: int) -> void:
	_preview_manager.check_condition(render_context)

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
