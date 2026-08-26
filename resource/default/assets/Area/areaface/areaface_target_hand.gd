## 手牌表现脚本（手动配置挂件），用于卡牌移出/移入动画。
extends AreaFace

## 移动动画时长
const MOVE_DURATION: float = 0.3
## 缓动类型
const MOVE_EASE: Tween.EaseType = Tween.EASE_IN_OUT
## 过渡类型
const MOVE_TRANS: Tween.TransitionType = Tween.TRANS_QUAD

## 目标全局位置（动画终点）
var target_global_position: Vector2

func _ready() -> void:
	request_area(RenderArea.DefaultArea.HAND)
	target_global_position = global_position

func _connect_to_area(target_area: RenderArea) -> void:
	super._connect_to_area(target_area)
	if not target_area.item_created_for_removing.is_connected(_on_item_created_for_removing):
		target_area.item_created_for_removing.connect(_on_item_created_for_removing)
	if not target_area.items_added.is_connected(_on_item_added):
		target_area.items_added.connect(_on_item_added)

func _disconnect_from_area(target_area: RenderArea) -> void:
	if target_area.item_created_for_removing.is_connected(_on_item_created_for_removing):
		target_area.item_created_for_removing.disconnect(_on_item_created_for_removing)
	if target_area.items_added.is_connected(_on_item_added):
		target_area.items_added.disconnect(_on_item_added)
	super._disconnect_from_area(target_area)

## 创建移除卡牌时设置起始位置
func _on_item_created_for_removing(item: RenderItem) -> void:
	item.position = global_position

## 添加卡牌时播放移入动画
func _on_item_added(item: RenderItem) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(item, ^"position", position, MOVE_DURATION).set_trans(MOVE_TRANS).set_ease(MOVE_EASE)
	tween.finished.connect(_on_move_finished.bind(item), CONNECT_ONE_SHOT)

## 动画完成后回收临时卡牌
func _on_move_finished(item: RenderItem) -> void:
	if not area:
		return
	area.remove_item(item)
	if render_context:
		render_context.request_recycle_item(item)

## 禁用手牌区的默认渲染更新（由本类自定义）
func render_update(_render_event: RenderEvent = RenderEvent.NULL_EVENT) -> void:
	pass

func tween_update(_render_event: RenderEvent = RenderEvent.NULL_EVENT) -> void:
	pass
