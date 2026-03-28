extends AreaFace

# 常量定义
## 动画时长（秒）
const ANIMATION_DURATION: float = 1.0
## 目标位置偏移
const TARGET_OFFSET: Vector2 = Vector2(-50, 50)
## 先慢后快缓动类型
const EASE_TYPE: int = Tween.EASE_IN
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
	var discard_node: Node = _discard_area
	render_item.position -= _discard_area.global_position
	discard_node.add_child(render_item)
	var start_global_pos: Vector2 = render_item.global_position
	var viewport_rect: Rect2 = get_viewport().get_visible_rect()
	var target_global_pos: Vector2 = Vector2(viewport_rect.end.x + TARGET_OFFSET.x, viewport_rect.position.y + TARGET_OFFSET.y)
	# 创建动画
	var tween: Tween = create_tween()
	tween.tween_property(render_item, ^"global_position", target_global_pos, ANIMATION_DURATION).set_trans(Tween.TRANS_EXPO).set_ease(EASE_TYPE)
	# 动画完成后回收
	tween.finished.connect(_on_animation_finished.bind(render_item), CONNECT_ONE_SHOT)

func _on_animation_finished(render_item: RenderItem) -> void:
	if not is_instance_valid(render_item):
		return
	if render_item.get_parent():
		render_item.get_parent().remove_child(render_item)
	if _discard_area:
		_discard_area.recycle_item(render_item)
