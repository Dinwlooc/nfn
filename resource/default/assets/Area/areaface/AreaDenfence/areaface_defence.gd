## 守区专用面板：按数量自适应缩放排布卡牌，并在预览条件下把顶层两张卡抬到屏幕中线。
extends AreaFace

#==vars==
## 区域工作模式：自动或手动
@export var mode: Mode = Mode.AUTO
## 原始局部坐标（用于重置）
var original_position: Vector2
## 原始尺寸（用于重置）
var original_size: Vector2
## 目标位置（区域计算后的期望位置）
var area_target_position: Vector2
## 目标尺寸（区域计算后的期望尺寸）
var area_target_size: Vector2
## 卡牌排布补间槽位（同一时刻只保留一条）
var layout_tween: Tween = null
## 所有卡牌的总缩放因子（根据数量自适应）
var total_scale_factor: float = 1.0
## 动画管理器
var _anim_manager: DefenceAnimationManager = null
## 预览管理器
var _preview_manager: DefencePreviewManager = null
## 浮动开始时间（秒）
var _float_start_time: float = 0.0
## 每张卡片的基准 Y 坐标缓存（键为 instance_id）
var _float_base_y: Dictionary[int, float] = {}
## 玩家区域引用
var _players_area: RenderAreaPlayers = null
## 本地玩家接收回调（用于绑定/解绑）
var _local_player_received_callback: Callable
## 选择限制变更回调（用于绑定/解绑）
var _select_limit_changed_callback: Callable

#==consts==
## 防御动画管理器脚本
const DefenceAnimationManager = preload("defence_animation_manager.gd")
## 防御预览管理器脚本
const DefencePreviewManager = preload("defence_preview_manager.gd")
## 补间动画时长（秒）
const TWEEN_TIME: float = 0.2

#==enums==
## 展示模式：自动/手动
enum Mode { AUTO, MANUAL }

#==lifecycle==
## 就绪：创建管理器、登记区域并记录原始几何。
## @override
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
## 每帧：驱动预览延迟计时，并在预览模式下更新浮动画。
## @override
func _process(delta: float) -> void:
	_preview_manager.update(delta)
	if _preview_manager.preview_mode and area and not area.items_pool.is_empty():
		_update_floating()

#==queries==
## 获取当前关联的玩家。
## @pure
func get_associated_player() -> RenderItem:
	return _preview_manager.get_player()

#==hooks==
## 设置关联玩家，并触发预览条件检查。
## @side_effect
func set_player(player: RenderItem) -> void:
	_preview_manager.set_player(player)
	_preview_manager.check_condition(render_context)
	_update_face_cache(_preview_manager.preview_mode)
## 检查当前预览条件，更新预览状态。
## @side_effect
func check_preview_condition() -> void:
	_preview_manager.check_condition(render_context)
	_update_face_cache(_preview_manager.preview_mode)
## 渲染更新：按卡牌数量重算缩放与排列坐标，并提交排布补间。
## @override
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
## 补间更新：提交卡牌排布。
## @override
func tween_update(render_event: RenderEvent = RenderEvent.NULL_EVENT) -> void:
	card_move(render_event)
## 区域接入：额外接管玩家区（自动模式）与预览管理器。
## @override @signal_listener
func _connect_to_area(target_area: RenderArea) -> void:
	super._connect_to_area(target_area)
	if target_area is RenderAreaDefence:
		if render_context:
			_preview_manager.set_render_context(render_context)
			if mode == Mode.AUTO:
				render_context.connect_renderarea(
					RenderAreaPlayers.get_area_name_static(),
					_on_players_area_connected,
					RenderContext.PUBLIC_PLAYER_ID
				)
## 区域断开：先清理玩家区与预览管理器，再交给父类断连。
## @override @signal_listener
func _disconnect_from_area(target_area: RenderArea) -> void:
	if target_area is not RenderAreaDefence:
		return
	if render_context and mode == Mode.AUTO:
		render_context.disconnect_renderarea(
			RenderAreaPlayers.get_area_name_static(),
			_on_players_area_connected,
			RenderContext.PUBLIC_PLAYER_ID
		)
	if _players_area:
		_players_area.local_player_received.disconnect(_local_player_received_callback)
		_players_area.select_limit_changed.disconnect(_select_limit_changed_callback)
		_players_area = null
	_preview_manager.preview_state_changed.disconnect(_on_preview_state_changed)
	_preview_manager.request_preview_start.disconnect(_on_preview_start_requested)
	_preview_manager.cleanup()
	_float_base_y.clear()
	if area:
		area.unregister_face_cache(&"nfn:preview_mode")
	super._disconnect_from_area(target_area)

#==tween==
## 卡牌排布：按目标快照与预览几何提交排布补间；全拖或空池由卫语句拦住。
## @atomic
func card_move(_render_event: RenderEvent = RenderEvent.NULL_EVENT) -> void:
	if not area or area.items_pool.is_empty() or target_position.is_empty():
		return
	if count_draggable_cards() == 0:
		return
	var local_id: int = render_context.area_manager.local_player_id if render_context and render_context.area_manager else 0
	var preview: DefenceAnimationManager.PreviewParams = DefenceAnimationManager.compute_preview_params(
		area.items_pool,
		local_id,
		get_viewport(),
		_preview_manager.preview_mode
	)
	var master_tween: Tween = create_tween()
	DefenceAnimationManager.do_card_layout(master_tween, area.items_pool, target_position, total_scale_factor, preview)
	layout_tween = UIAnimationUtils.replace_tween(layout_tween, master_tween)
	master_tween.finished.connect(_on_tween_finished)

#==internal==
## 补间完成回调：记录顶层卡片的基准 Y 坐标。
## @internal
func _on_tween_finished() -> void:
	_float_base_y.clear()
	if not _preview_manager.preview_mode or not area or area.items_pool.is_empty():
		return
	var top_card: RenderItem = area.items_pool[area.items_pool.size() - 1]
	if top_card:
		_float_base_y[top_card.get_instance_id()] = top_card.global_position.y
## 更新浮动画效果（逐帧程序化通道，不占补间槽位）。
## @internal
func _update_floating() -> void:
	var elapsed: float = (Time.get_ticks_msec() / 1000.0) - _float_start_time
	var cards: Array[RenderItem] = area.items_pool
	var pool_size: int = cards.size()
	var top_card: RenderItem = cards[pool_size - 1]
	if (not top_card) or top_card.dragged:
		return
	var offset: float = _anim_manager.get_float_offset(pool_size - 1, elapsed)
	if not _float_base_y.has(top_card.get_instance_id()):
		_float_base_y[top_card.get_instance_id()] = top_card.global_position.y
	top_card.global_position.y = _float_base_y[top_card.get_instance_id()] + offset
## 更新总缩放因子（根据卡牌数量与区域尺寸）。
## @internal
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
## 更新区域缓存中的预览标志。
## @internal
func _update_face_cache(active: bool) -> void:
	if not area:
		return
	area.register_face_cache(&"nfn:preview_mode", active)

#==signals_in==
## 预览状态变更回调。
## @signal_listener
func _on_preview_state_changed(active: bool) -> void:
	if not active:
		_float_base_y.clear()
	_update_face_cache(active)
## 请求预览启动回调：重置浮动基准并重新排布。
## @signal_listener
func _on_preview_start_requested() -> void:
	_float_start_time = Time.get_ticks_msec() / 1000.0
	card_move()
	_update_face_cache(_preview_manager.preview_mode)
## 玩家区域连接回调。
## @signal_listener
func _on_players_area_connected(new_players: RenderArea, old_players: RenderArea) -> void:
	if not new_players is RenderAreaPlayers:
		return
	if old_players and old_players is RenderAreaPlayers:
		old_players.local_player_received.disconnect(_local_player_received_callback)
		old_players.select_limit_changed.disconnect(_select_limit_changed_callback)
	var pa: RenderAreaPlayers = new_players as RenderAreaPlayers
	pa.local_player_received.connect(_local_player_received_callback)
	pa.select_limit_changed.connect(_select_limit_changed_callback)
	_players_area = pa
	if pa.local_player:
		set_player(pa.local_player)
## 本地玩家接收回调。
## @signal_listener
func _on_local_player_received(player: RenderItem) -> void:
	set_player(player)
## 玩家区域选择限制变更回调。
## @signal_listener
func _on_player_area_limit_changed(_new_limit: int) -> void:
	_preview_manager.check_condition(render_context)
