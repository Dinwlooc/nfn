extends AreaFace

## 原始位置（未展开时的锚点）
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
## 重置动画时长（通常为 TWEEN_TIME 的一半）
const RESET_TIME: float = TWEEN_TIME / 2.0
## 选中卡牌的 Y 轴偏移量（向上抬起）
const SELECTED_Y_OFFSET: float = -5.0
## 中性缩放值
const SCALE_NEUTRAL: float = 1.0
## 中性旋转值
const ROTATION_NEUTRAL: float = 0.0

enum Mode { AUTO, MANUAL }
## 区域连接模式，AUTO自动请求守区，MANUAL手动
@export var mode: Mode = Mode.AUTO

# ==================== 预览功能相关变量 ====================
## 关联的玩家 RenderItem（当该玩家被选中时触发守区预览）
var associated_player: RenderItem = null
## 是否处于预览模式
var _preview_mode: bool = false
## 预览动画时长
const PREVIEW_ANIM_TIME: float = 0.45
## 预览时顶层卡牌的缩放倍数
const PREVIEW_TOP_SCALE: float = 1.0
## 预览时次顶层卡牌的缩放倍数
const PREVIEW_SECOND_SCALE: float = 1.0
## 预览水平线的竖直偏移（向下为正）
const PREVIEW_HORIZONTAL_LINE_Y_OFFSET: float = -20.0
## 预览水平线的长度缩放比（相对屏幕宽度）
const PREVIEW_HORIZONTAL_LINE_SCALE: float = 0.2

# 标记是否已通过 RenderContext 连接玩家区域（仅用于防止重复连接）
var _players_area_connection_active: bool = false

# ==================== 生命周期与初始化 ====================

func _ready() -> void:
	if mode == Mode.AUTO:
		request_area(RenderArea.DefaultArea.DEFENCE)
	original_position = position
	original_size = size
	area_target_position = original_position
	area_target_size = original_size
	_update_total_scale_factor()
	if mode == Mode.AUTO:
		call_deferred("_try_auto_connect_local_player")

func _connect_to_area(target_area: RenderArea) -> void:
	super._connect_to_area(target_area)
	if not (target_area is RenderAreaDefence):
		return
	GlobalConsole._print(["守区接入,", target_area])
	if mode == Mode.AUTO:
		_try_auto_connect_local_player()

func _exit_tree() -> void:
	_cleanup_preview_connections()
	if render_context and _area_requested:
		render_context.disconnect_renderarea(_requested_area_name, self._connect_to_area, _requested_player_id)
	_disconnect_from_current_area()

## 更新渲染目标位置
func render_update(render_event: RenderEvent = RenderEvent.NULL_EVENT) -> void:
	var event_type: StringName = render_event.get_type()
	if event_type == RenderEvent.DefaultType.CARD_ADD or event_type == RenderEvent.DefaultType.CARD_REMOVE:
		_update_total_scale_factor()
	target_position = UIAnimationUtils.generate_coordinates(
		area_target_position,
		area_target_size,
		area.items_pool.size()
	)
	tween_update(render_event)

## 触发卡牌移动动画
func tween_update(render_event: RenderEvent = RenderEvent.NULL_EVENT) -> void:
	card_move(render_event)

func _into_area() -> void:
	super._into_area()

func _outto_area() -> void:
	super._outto_area()

# ==================== 动画调度（单次遍历） ====================

## 核心动画：一次遍历完成所有卡牌的位置（局部/全局）、缩放、旋转
func card_move(_render_event: RenderEvent = RenderEvent.NULL_EVENT) -> void:
	if not area or area.items_pool.is_empty() or target_position.is_empty():
		return
	var pool_size :int= area.items_pool.size()
	var master_tween: Tween = create_tween()
	master_tween.set_parallel(true)
	for i in pool_size:
		var card: RenderItem = area.items_pool[i]
		if card.dragged:
			continue
		var card_local_target: Vector2 = target_position[i]
		var anim_time: float = TWEEN_TIME
		var scale_target: Vector2 = Vector2(total_scale_factor, total_scale_factor)
		var is_preview_top: bool = _preview_mode and (i == pool_size - 1)
		var is_preview_second: bool = _preview_mode and (i == pool_size - 2)
		if is_preview_top or is_preview_second:
			anim_time = PREVIEW_ANIM_TIME
			scale_target = Vector2.ONE * (PREVIEW_TOP_SCALE if is_preview_top else PREVIEW_SECOND_SCALE)
			var global_target: Vector2 = _get_preview_global_target(is_preview_top)
			if card.global_position != global_target:
				master_tween.tween_property(card, ^"global_position", global_target, anim_time) \
					.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		else:
			if card.selected:
				card_local_target.y += SELECTED_Y_OFFSET
			if card.position != card_local_target:
				master_tween.tween_property(card, ^"position", card_local_target, anim_time) \
					.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		if card.scale != scale_target:
			master_tween.tween_property(card, ^"scale", scale_target, anim_time) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		master_tween.tween_property(card, ^"rotation", ROTATION_NEUTRAL, RESET_TIME) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if current_card_tween:
		current_card_tween.kill()
	current_card_tween = master_tween

## 返回预览卡牌的全局目标坐标（基于视口中心）
func _get_preview_global_target(is_top: bool) -> Vector2:
	var viewport: Viewport = get_viewport()
	if not viewport:
		return Vector2.ZERO
	var rect: Rect2 = viewport.get_visible_rect()
	var center: Vector2 = rect.size / 2.0
	var line_y: float = center.y + PREVIEW_HORIZONTAL_LINE_Y_OFFSET
	var half_line: float = rect.size.x * PREVIEW_HORIZONTAL_LINE_SCALE * 0.5
	var target_x: float = center.x + half_line if is_top else center.x - half_line
	return Vector2(target_x, line_y)

# ==================== 预览功能：回调连接接口（不持有区域引用） ====================

## 自动模式：通过 RenderContext.connect_renderarea 监听玩家区域（仅用于建立信号连接）
func _try_auto_connect_local_player() -> void:
	if not render_context or _players_area_connection_active:
		return
	_players_area_connection_active = true
	render_context.connect_renderarea(RenderAreaPlayers.get_area_name_static(), _on_players_area_connected, RenderContext.PUBLIC_PLAYER_ID)

## 当玩家区域注册或已存在时调用，仅建立信号连接，不持有区域引用
func _on_players_area_connected(area: RenderArea) -> void:
	if not area is RenderAreaPlayers:
		return
	var pa: RenderAreaPlayers = area as RenderAreaPlayers
	# 监听选择上限变化
	if not pa.select_limit_changed.is_connected(_on_player_area_limit_changed):
		pa.select_limit_changed.connect(_on_player_area_limit_changed)
	# 尝试获取本地玩家并关联
	if pa.local_player:
		set_player(pa.local_player)
	elif not pa.local_player_received.is_connected(_on_local_player_received):
		pa.local_player_received.connect(_on_local_player_received, CONNECT_ONE_SHOT)

## 本地玩家就绪回调（一次性连接）
func _on_local_player_received(player: RenderItem) -> void:
	set_player(player)

## 手动设置关联玩家（或由自动流程调用）
func set_player(player: RenderItem) -> void:
	if associated_player == player:
		return
	_disconnect_player_selection_signal()
	associated_player = player
	_connect_player_selection_signal()
	_check_preview_condition()

## 关联玩家选中状态变化回调
func _on_player_selection_changed(selected: bool) -> void:
	_check_preview_condition()

## 玩家区域选择上限变化回调
func _on_player_area_limit_changed(new_limit: int) -> void:
	_check_preview_condition()

## 统一预览条件判断：实时获取玩家区域检查选择上限
func _check_preview_condition() -> void:
	var should_preview: bool = false
	if associated_player and associated_player.selected and render_context:
		var players_area: RenderArea = render_context.get_render_area(RenderAreaPlayers.get_area_name_static(), RenderContext.PUBLIC_PLAYER_ID)
		if players_area:
			should_preview = players_area.select_limit == 1
	if should_preview and not _preview_mode:
		_preview_mode = true
	elif not should_preview and _preview_mode:
		_preview_mode = false
	card_move()

# ==================== 内部信号管理与清理 ====================

## 连接 associated_player 的 selected_changed 信号
func _connect_player_selection_signal() -> void:
	if not associated_player:
		return
	if not associated_player.selected_changed.is_connected(_on_player_selection_changed):
		associated_player.selected_changed.connect(_on_player_selection_changed)

## 断开 associated_player 的 selected_changed 信号
func _disconnect_player_selection_signal() -> void:
	if associated_player and associated_player.selected_changed.is_connected(_on_player_selection_changed):
		associated_player.selected_changed.disconnect(_on_player_selection_changed)

## 清理所有预览相关的信号连接（退出树时调用）
func _cleanup_preview_connections() -> void:
	_disconnect_player_selection_signal()
	# 断开与玩家区域的 select_limit_changed 连接（如果区域仍存在）
	if render_context:
		var players_area: RenderArea = render_context.get_render_area(RenderAreaPlayers.get_area_name_static(), RenderContext.PUBLIC_PLAYER_ID)
		if players_area:
			if players_area.select_limit_changed.is_connected(_on_player_area_limit_changed):
				players_area.select_limit_changed.disconnect(_on_player_area_limit_changed)
			if players_area is RenderAreaPlayers:
				var pa: RenderAreaPlayers = players_area as RenderAreaPlayers
				if pa.local_player_received.is_connected(_on_local_player_received):
					pa.local_player_received.disconnect(_on_local_player_received)
		# 移除 RenderContext 回调连接
		render_context.disconnect_renderarea(RenderAreaPlayers.get_area_name_static(), _on_players_area_connected, RenderContext.PUBLIC_PLAYER_ID)
	_players_area_connection_active = false

# ==================== 缩放更新 ====================

## 根据区域大小、卡牌数量和第一张卡牌尺寸更新缩放因子
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
