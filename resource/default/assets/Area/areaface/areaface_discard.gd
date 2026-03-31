extends AreaFace

# 常量定义
## 动画总时长（秒）
const ANIMATION_DURATION: float = 1.0
## 目标位置偏移
const TARGET_OFFSET: Vector2 = Vector2(-50, 50)
## 先慢后快缓动类型（用于第二阶段）
const EASE_TYPE: int = Tween.EASE_IN
## 先快后慢缓动类型（用于第一阶段）
const EASE_OUT_TYPE: int = Tween.EASE_OUT
## 中间矩形缩放系数
const CENTER_RECT_SCALE: float = 0.5
## 随机偏移范围（像素）
const RANDOM_OFFSET_RANGE: Vector2 = Vector2(300, 50)
## 第一阶段动画时长占 ANIMATION_DURATION 的比例
const FIRST_STAGE_DURATION_RATIO: float = 0.4
## 中心矩形定位系数（用于计算位置，值为0.5表示居中）
const CENTER_RECT_POSITION_FACTOR: float = 0.5
## 缓动过渡类型
const TRANS_TYPE: int = Tween.TRANS_EXPO
## 动画完成后的最终缩放（恢复缩放的目标值）
const FINAL_SCALE: float = 0.8

## 缓存的弃牌区域实例
var _discard_area: RenderAreaDiscard = null

func _ready() -> void:
	request_area(RenderArea.DefaultArea.DISCARD)

func _connect_to_area(target_area: RenderArea) -> void:
	super._connect_to_area(target_area)
	if not (target_area is RenderAreaDiscard):
		return
	_discard_area = target_area as RenderAreaDiscard
	_discard_area.recycle_mode = ItemCounterArea.RecycleMode.MANUAL
	_discard_area.items_added.connect(_on_item_added)

func _on_item_added(render_item: RenderItem) -> void:
	if not _discard_area or not is_instance_valid(render_item):
		return
	# 将卡片添加到弃牌区并调整坐标系
	var discard_node: Node = _discard_area
	render_item.position -= _discard_area.global_position
	discard_node.add_child(render_item)
	# 获取相关坐标与尺寸
	var start_global_pos: Vector2 = render_item.global_position
	var viewport_rect: Rect2 = get_viewport().get_visible_rect()
	# 目标右上角位置（最终位置）
	var target_global_pos: Vector2 = Vector2(
		viewport_rect.end.x + TARGET_OFFSET.x,
		viewport_rect.position.y + TARGET_OFFSET.y
	)
	# ----- 第一阶段：缩放恢复与移动到中间点 -----
	# 计算中间矩形（屏幕中心区域，缩放 CENTER_RECT_SCALE 倍）
	var center_rect: Rect2 = Rect2(
		viewport_rect.position + viewport_rect.size * (1.0 - CENTER_RECT_SCALE) * CENTER_RECT_POSITION_FACTOR,
		viewport_rect.size * CENTER_RECT_SCALE
	)
	# 将卡片原始位置按比例映射到中间矩形
	var sx: float = (start_global_pos.x - viewport_rect.position.x) / viewport_rect.size.x
	var sy: float = (start_global_pos.y - viewport_rect.position.y) / viewport_rect.size.y
	var mid_global_pos: Vector2 = Vector2(
		center_rect.position.x + sx * center_rect.size.x,
		center_rect.position.y + sy * center_rect.size.y
	)
	# 添加随机偏移
	var random_offset: Vector2 = Vector2(
		randf_range(-RANDOM_OFFSET_RANGE.x, RANDOM_OFFSET_RANGE.x),
		randf_range(-RANDOM_OFFSET_RANGE.y, RANDOM_OFFSET_RANGE.y)
	)
	mid_global_pos += random_offset
	# 创建动画序列
	var tween: Tween = create_tween()
	# 第一阶段：恢复缩放并移动到中间点（先快后慢）
	tween.set_parallel(true)
	tween.tween_property(render_item, ^"scale", Vector2(FINAL_SCALE, FINAL_SCALE), ANIMATION_DURATION * FIRST_STAGE_DURATION_RATIO)\
			.set_trans(TRANS_TYPE).set_ease(EASE_OUT_TYPE)
	tween.tween_property(render_item, ^"global_position", mid_global_pos, ANIMATION_DURATION * FIRST_STAGE_DURATION_RATIO)\
			.set_trans(TRANS_TYPE).set_ease(EASE_OUT_TYPE)
	tween.set_parallel(false)

	# 第二阶段：移动到右上角（先慢后快）
	tween.tween_property(render_item, ^"global_position", target_global_pos, ANIMATION_DURATION)\
			.set_trans(TRANS_TYPE).set_ease(EASE_TYPE)

	# 动画完成后回收卡片
	tween.finished.connect(_on_animation_finished.bind(render_item), CONNECT_ONE_SHOT)

func _on_animation_finished(render_item: RenderItem) -> void:
	if not is_instance_valid(render_item):
		return
	if render_item.get_parent():
		render_item.get_parent().remove_child(render_item)
	if _discard_area:
		_discard_area.recycle_item(render_item)
