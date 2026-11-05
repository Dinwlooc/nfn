## 手牌表现挂件：卡牌移出/移入时播放一次性位移动画。
extends AreaFace

#==vars==
## 目标全局位置（动画终点）
var target_global_position: Vector2

#==consts==
## 移动动画时长
const MOVE_DURATION: float = 0.3
## 缓动类型
const MOVE_EASE: Tween.EaseType = Tween.EASE_IN_OUT
## 过渡类型
const MOVE_TRANS: Tween.TransitionType = Tween.TRANS_QUAD

#==lifecycle==
## 就绪：登记手牌区并记录动画目标位置
## @override
func _ready() -> void:
	request_area(RenderArea.DefaultArea.HAND)
	target_global_position = global_position

#==hooks==
## 区域接入：额外监听「移除时创建」与「添加」信号。
## @override @signal_listener
func _connect_to_area(target_area: RenderArea) -> void:
	super._connect_to_area(target_area)
	if not target_area.item_created_for_removing.is_connected(_on_item_created_for_removing):
		target_area.item_created_for_removing.connect(_on_item_created_for_removing)
	if not target_area.items_added.is_connected(_on_item_added):
		target_area.items_added.connect(_on_item_added)
## 区域断开：取消两条监听后交给父类清理。
## @override @signal_listener
func _disconnect_from_area(target_area: RenderArea) -> void:
	if target_area.item_created_for_removing.is_connected(_on_item_created_for_removing):
		target_area.item_created_for_removing.disconnect(_on_item_created_for_removing)
	if target_area.items_added.is_connected(_on_item_added):
		target_area.items_added.disconnect(_on_item_added)
	super._disconnect_from_area(target_area)

#==tween==
## 移入：把加入的卡牌补间到本挂件位置。
## 一次性演出：演出对象是卡牌本身且可并发，故不占面板槽位；补间随卡牌对象走，不做取消登记，
## 终态回调是唯一的回收写回点。
## @atomic
func tween_move_in(item: RenderItem) -> void:
	var tween: Tween = create_tween()
	do_move_in(tween, item, position)
	tween.chain().tween_callback(func() -> void: _on_move_finished(item))
## 移入装配：单卡位移到目标。
## @atomic
static func do_move_in(tween: Tween, item: RenderItem, target_position: Vector2) -> void:
	tween.tween_property(item, ^"position", target_position, MOVE_DURATION).set_trans(MOVE_TRANS).set_ease(MOVE_EASE)

#==signals_in==
## 创建移除卡牌时设置起始位置
## @signal_listener
func _on_item_created_for_removing(item: RenderItem) -> void:
	item.position = global_position
## 添加卡牌时播放移入动画
## @signal_listener
func _on_item_added(item: RenderItem) -> void:
	tween_move_in(item)
## 动画完成后回收临时卡牌
## @internal
func _on_move_finished(item: RenderItem) -> void:
	if not area:
		return
	area.remove_item(item)
	if render_context:
		render_context.request_recycle_item(item)
