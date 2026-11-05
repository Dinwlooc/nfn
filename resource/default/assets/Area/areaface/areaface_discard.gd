## 弃牌区面板：卡牌加入时弹射到画面外并回收。
extends AreaFace

#==vars==
## 关联的弃牌区
var _discard_area: RenderAreaDiscard = null

#==consts==
## 总动画时长
const ANIMATION_DURATION: float = 1.0
## 目标偏移
const TARGET_OFFSET: Vector2 = Vector2(-50, 50)
## 第二阶段缓动
const EASE_TYPE: Tween.EaseType = Tween.EASE_IN
## 第一阶段缓动
const EASE_OUT_TYPE: Tween.EaseType = Tween.EASE_OUT
## 中间矩形缩放
const CENTER_RECT_SCALE: float = 0.5
## 随机偏移范围
const RANDOM_OFFSET_RANGE: Vector2 = Vector2(300, 50)
## 第一阶段时长占比
const FIRST_STAGE_DURATION_RATIO: float = 0.4
## 中心矩形定位因子
const CENTER_RECT_POSITION_FACTOR: float = 0.5
## 过渡类型
const TRANS_TYPE: Tween.TransitionType = Tween.TRANS_EXPO
## 恢复缩放
const FINAL_SCALE: float = 0.8
## 最终缩放
const FINAL_SCALE_END: float = 0.2

#==lifecycle==
## 就绪：登记弃牌区
## @override
func _ready() -> void:
	request_area(RenderArea.DefaultArea.DISCARD)

#==hooks==
## 区域接入：缓存弃牌区引用并接管回收模式。
## @override @signal_listener
func _connect_to_area(target_area: RenderArea) -> void:
	super._connect_to_area(target_area)
	if not (target_area is RenderAreaDiscard):
		return
	_discard_area = target_area as RenderAreaDiscard
	_discard_area.recycle_mode = ItemCounterArea.RecycleMode.MANUAL
	if not _discard_area.items_added.is_connected(_on_item_added):
		_discard_area.items_added.connect(_on_item_added)
## 区域断开：取消加入监听后交给父类清理。
## @override @signal_listener
func _disconnect_from_area(target_area: RenderArea) -> void:
	if target_area is RenderAreaDiscard:
		if target_area.items_added.is_connected(_on_item_added):
			target_area.items_added.disconnect(_on_item_added)
		_discard_area = null
	super._disconnect_from_area(target_area)

#==tween==
## 弃牌弹射：把卡牌从当前位置弹射到画面外。
## 一次性演出：演出对象是卡牌本身且可并发，故不占面板槽位；补间随卡牌对象走，不做取消登记，
## 卡牌被提前回收或节点退出时补间随对象失效而中止（终态回调是唯一的回收写回点）。
## @atomic
func tween_discard_flight(render_item: RenderItem) -> void:
	var start_global_pos: Vector2 = render_item.global_position
	var viewport_rect: Rect2 = get_viewport().get_visible_rect()
	var target_global_pos: Vector2 = Vector2(viewport_rect.end.x + TARGET_OFFSET.x, viewport_rect.position.y + TARGET_OFFSET.y)
	# 计算中间点（按比例落点加随机偏移）
	var center_rect: Rect2 = Rect2(
		viewport_rect.position + viewport_rect.size * (1.0 - CENTER_RECT_SCALE) * CENTER_RECT_POSITION_FACTOR,
		viewport_rect.size * CENTER_RECT_SCALE
	)
	var sx: float = (start_global_pos.x - viewport_rect.position.x) / viewport_rect.size.x
	var sy: float = (start_global_pos.y - viewport_rect.position.y) / viewport_rect.size.y
	var mid_global_pos: Vector2 = Vector2(
		center_rect.position.x + sx * center_rect.size.x,
		center_rect.position.y + sy * center_rect.size.y
	)
	mid_global_pos += Vector2(
		randf_range(-RANDOM_OFFSET_RANGE.x, RANDOM_OFFSET_RANGE.x),
		randf_range(-RANDOM_OFFSET_RANGE.y, RANDOM_OFFSET_RANGE.y)
	)
	var tween: Tween = create_tween()
	do_discard_flight(tween, render_item, mid_global_pos, target_global_pos)
	tween.chain().tween_callback(func() -> void: _on_animation_finished(render_item))
## 弹射装配：先缩小飞向中间点，再飞向画面外并缩到极小。
## @atomic
static func do_discard_flight(tween: Tween, render_item: RenderItem, mid_global_pos: Vector2, target_global_pos: Vector2) -> void:
	var stage_duration: float = ANIMATION_DURATION * FIRST_STAGE_DURATION_RATIO
	tween.set_parallel(true)
	tween.tween_property(render_item, ^"scale", Vector2(FINAL_SCALE, FINAL_SCALE), stage_duration) \
		.set_trans(TRANS_TYPE).set_ease(EASE_OUT_TYPE)
	tween.tween_property(render_item, ^"global_position", mid_global_pos, stage_duration) \
		.set_trans(TRANS_TYPE).set_ease(EASE_OUT_TYPE)
	tween.chain()
	tween.tween_property(render_item, ^"global_position", target_global_pos, ANIMATION_DURATION) \
		.set_trans(TRANS_TYPE).set_ease(EASE_TYPE)
	tween.tween_property(render_item, ^"scale", Vector2(FINAL_SCALE_END, FINAL_SCALE_END), ANIMATION_DURATION) \
		.set_trans(TRANS_TYPE).set_ease(EASE_TYPE)

#==signals_in==
## 卡牌加入弃牌区：改挂到弃牌区并播放弹射动画
## @signal_listener
func _on_item_added(render_item: RenderItem) -> void:
	if not _discard_area or not is_instance_valid(render_item):
		return
	var discard_node: Node = _discard_area
	render_item.position -= _discard_area.global_position
	discard_node.add_child(render_item)
	tween_discard_flight(render_item)
## 动画完成：从区域移除并回收卡牌
## @internal
func _on_animation_finished(render_item: RenderItem) -> void:
	if not is_instance_valid(render_item):
		return
	area.remove_item(render_item)
	if render_item.get_parent():
		render_item.get_parent().remove_child(render_item)
	if _discard_area:
		_discard_area.recycle_item(render_item)
