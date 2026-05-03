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
## 预览模式的专用 Tween（避免与群组动画冲突）
var preview_tween: Tween = null
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

# ==================== 生命周期与初始化 ====================

func _ready() -> void:
	if mode == Mode.AUTO:
		request_area(RenderArea.DefaultArea.DEFENCE)
	original_position = position
	original_size = size
	area_target_position = original_position
	area_target_size = original_size
	_update_total_scale_factor()
	# 自动模式下尝试关联本地玩家
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
	if render_context and _area_requested:
		render_context.disconnect_renderarea(_requested_area_name, self._connect_to_area, _requested_player_id)
	_disconnect_from_current_area()

## 更新渲染目标位置（基于当前卡牌数量计算每个卡牌应在的局部坐标）
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

## 触发卡牌移动动画，预览模式下会先刷新预览卡牌
func tween_update(render_event: RenderEvent = RenderEvent.NULL_EVENT) -> void:
	_sync_preview_mode()
	if _preview_mode:
		_refresh_preview()
	card_move(render_event)

func _into_area() -> void:
	super._into_area()

func _outto_area() -> void:
	super._outto_area()

# ==================== 动画调度 ====================

## 核心动画调度函数，创建主 Tween 并添加基础移动和重置动画
func card_move(_render_event: RenderEvent = RenderEvent.NULL_EVENT) -> void:
	if area.items_pool.is_empty() or target_position.is_empty():
		return
	if _preview_mode and area.items_pool.size()<=2:
		return
	var master_tween: Tween = create_tween()
	master_tween.set_parallel(true)
	_add_base_movement_tweens(master_tween)
	master_tween.chain()
	_add_reset_tweens(master_tween)
	if current_card_tween:
		current_card_tween.kill()
	current_card_tween = master_tween

## 为所有非拖拽卡牌添加基础位置移动动画（含总数缩放动画）
func _add_base_movement_tweens(master_tween: Tween) -> void:
	for i in area.items_pool.size():
		var card: RenderItem = area.items_pool[i]
		if card.dragged:
			continue
		# 预览模式下跳过顶层和次顶层
		if _preview_mode and _is_preview_card(card):
			continue
		var card_target_pos: Vector2 = target_position[i]
		if card.selected:
			card_target_pos.y += SELECTED_Y_OFFSET
		if card.position != card_target_pos:
			master_tween.tween_property(card, ^"position", card_target_pos, TWEEN_TIME) \
				.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_OUT)
		var target_scale: Vector2 = Vector2(total_scale_factor, total_scale_factor)
		if card.scale != target_scale:
			master_tween.tween_property(card, ^"scale", target_scale, TWEEN_TIME) \
				.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_OUT)

## 恢复所有卡牌的默认旋转和缩放（恢复到总数因子）
func _add_reset_tweens(master_tween: Tween) -> void:
	for card in area.items_pool:
		if card.dragged:
			continue
		# 预览模式下跳过顶层和次顶层
		if _preview_mode and _is_preview_card(card):
			continue
		master_tween.tween_property(card, ^"rotation", ROTATION_NEUTRAL, RESET_TIME) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		var target_scale: Vector2 = Vector2(total_scale_factor, total_scale_factor)
		master_tween.tween_property(card, ^"scale", target_scale, RESET_TIME) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

# ==================== 预览功能：关联玩家与模式 ====================

## 设置关联的玩家（手动模式调用）
## @param player 玩家 RenderItem 实例
func set_player(player: RenderItem) -> void:
	if associated_player == player:
		return
	if associated_player and associated_player.request_select.is_connected(_on_associated_player_selected):
		associated_player.request_select.disconnect(_on_associated_player_selected)
	associated_player = player
	if associated_player:
		if not associated_player.request_select.is_connected(_on_associated_player_selected):
			associated_player.request_select.connect(_on_associated_player_selected)
		if associated_player.selected:
			_enter_preview_mode()

## 自动模式：尝试从玩家区域获取本地玩家并关联
func _try_auto_connect_local_player() -> void:
	if not render_context:
		return
	var players_area: RenderArea = render_context.get_render_area(RenderAreaPlayers.get_area_name_static(), RenderContext.PUBLIC_PLAYER_ID)
	if not players_area:
		return
	if players_area is RenderAreaPlayers:
		var pa: RenderAreaPlayers = players_area as RenderAreaPlayers
		if pa.local_player:
			set_player(pa.local_player)
		elif not pa.local_player_received.is_connected(_on_local_player_received):
			pa.local_player_received.connect(_on_local_player_received)

## 本地玩家就绪回调
func _on_local_player_received(player: RenderItem) -> void:
	set_player(player)

## 关联玩家选中状态变化时触发（即时开启/关闭预览）
func _on_associated_player_selected(player: RenderItem) -> void:
	if player.selected:
		_enter_preview_mode()
	else:
		_exit_preview_mode()

## 同步预览模式与玩家选中状态（每次渲染更新时调用）
func _sync_preview_mode() -> void:
	if not associated_player:
		if _preview_mode:
			_exit_preview_mode()
		return
	if associated_player.selected and not _preview_mode:
		_enter_preview_mode()
	elif not associated_player.selected and _preview_mode:
		_exit_preview_mode()

# ==================== 预览模式核心 ====================

## 进入预览模式：设置标志并立即刷新动画
func _enter_preview_mode() -> void:
	if _preview_mode:
		return
	if not area or area.items_pool.size() < 2:
		return
	_preview_mode = true
	# 清理已有的动画，避免冲突
	if preview_tween:
		preview_tween.kill()
	if current_card_tween:
		current_card_tween.kill()
	_refresh_preview()

## 退出预览模式：重置标志，清理预览 Tween，并触发正常布局
func _exit_preview_mode() -> void:
	if not _preview_mode:
		return
	_preview_mode = false
	if preview_tween:
		preview_tween.kill()
		preview_tween = null
	# 触发整个区域的补间更新，所有卡牌回到正确位置
	if area:
		area.tween_update(RenderEvent.NULL_EVENT)

## 刷新预览卡牌的位置与缩放动画（从池中动态获取顶层/次顶层）
func _refresh_preview() -> void:
	if not area or area.items_pool.is_empty():
		_exit_preview_mode()
		return
	var pool_size: int = area.items_pool.size()
	if pool_size < 2:
		_exit_preview_mode()
		return
	var top_card: RenderItem = area.items_pool[pool_size - 1]
	var second_card: RenderItem = area.items_pool[pool_size - 2]
	if preview_tween:
		preview_tween.kill()
	preview_tween = create_tween()
	preview_tween.set_parallel(true)
	_preview_animate_card(preview_tween, top_card, PREVIEW_TOP_SCALE, PREVIEW_ANIM_TIME, true)
	_preview_animate_card(preview_tween, second_card, PREVIEW_SECOND_SCALE, PREVIEW_ANIM_TIME, false)

## 为指定卡牌添加预览补间属性
func _preview_animate_card(tween: Tween, card: RenderItem, scale_mult: float, duration: float, is_top: bool) -> void:
	var viewport: Viewport = get_viewport()
	var rect: Rect2 = viewport.get_visible_rect()
	var center: Vector2 = rect.size / 2.0
	var line_y: float = center.y + PREVIEW_HORIZONTAL_LINE_Y_OFFSET
	var half_line: float = rect.size.x * PREVIEW_HORIZONTAL_LINE_SCALE * 0.5
	var target_x: float = center.x + half_line if is_top else center.x - half_line
	var target_global: Vector2 = Vector2(target_x, line_y)
	tween.tween_property(card, ^"global_position", target_global, duration) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, ^"scale", Vector2.ONE * scale_mult, duration) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

## 判断一张卡是否为预览模式下的顶层或次顶层卡
func _is_preview_card(card: RenderItem) -> bool:
	if not area or area.items_pool.is_empty():
		return false
	var pool_size: int = area.items_pool.size()
	return card.pool_id == pool_size - 1 or (pool_size >= 2 and card.pool_id == pool_size - 2)

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
