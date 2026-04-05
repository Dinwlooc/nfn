extends AreaFace
## 手牌表现脚本（手动配置挂件）
## 用于显示卡牌从手牌区移出/移入的视觉效果
## 需要手动挂载到场景中，并确保目标手牌区存在
## 动画时长（秒）
const MOVE_DURATION: float = 0.3
## 动画缓动类型
const MOVE_EASE: int = Tween.EASE_OUT
## 动画过渡类型
const MOVE_TRANS: int = Tween.TRANS_QUAD

## 目标全局位置（动画终点，默认为当前节点的全局位置）
var target_global_position: Vector2

func _ready() -> void:
	target_global_position = global_position

## 重写连接区域方法，额外连接手牌区特有信号
func _connect_to_area(target_area: RenderArea) -> void:
	super._connect_to_area(target_area)
	if not target_area.item_created_for_removing.is_connected(_on_item_created_for_removing):
		target_area.item_created_for_removing.connect(_on_item_created_for_removing)
	if not target_area.items_added.is_connected(_on_item_added):
		target_area.items_added.connect(_on_item_added)

## 重写断开连接方法，清理自定义信号
func _disconnect_from_current_area() -> void:
	if not area:
		return
	if area.item_created_for_removing.is_connected(_on_item_created_for_removing):
		area.item_created_for_removing.disconnect(_on_item_created_for_removing)
	if area.items_added.is_connected(_on_item_added):
		area.items_added.disconnect(_on_item_added)
	super._disconnect_from_current_area()

## 当手牌区创建用于移除的 RenderItem 时调用（移出动画起点）
func _on_item_created_for_removing(item: RenderItem) -> void:
	item.position = global_position

## 当手牌区添加新的 RenderItem 时调用（移入动画）
func _on_item_added(item: RenderItem) -> void:
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(item, ^"position", position, MOVE_DURATION)\
		.set_trans(MOVE_TRANS).set_ease(MOVE_EASE)
	# 动画完成后回收该 item（因为已经移动到目标区域，此临时 item 不再需要）
	tween.finished.connect(_on_move_finished.bind(item), CONNECT_ONE_SHOT)

## 动画完成时回收临时 RenderItem
func _on_move_finished(item: RenderItem) -> void:
	if render_context:
		render_context.request_recycle_item(item)

## 覆盖父类的 render_update 和 tween_update，避免干扰手牌区的默认行为
func render_update(render_event: RenderEvent = RenderEvent.NULL_EVENT) -> void:
	pass

func tween_update(render_event: RenderEvent = RenderEvent.NULL_EVENT) -> void:
	pass
