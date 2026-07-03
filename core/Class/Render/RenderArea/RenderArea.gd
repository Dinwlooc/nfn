@abstract
extends Control
class_name RenderArea

signal render_requested(render_event:RenderEvent)
signal tween_requested(render_event:RenderEvent)
signal selected(item:RenderItem)
signal items_added(item:RenderItem)
signal items_removed(item:RenderItem)
signal context_ready()
signal item_created_for_removing(item: RenderItem)
signal select_limit_changed(new_limit: int)

var select_limit:int = 1
var render_context:RenderContext
var player_id:int
const DefaultArea = GlobalConstants.DefaultArea

@abstract func add_item(_item:RenderItem, _index:int = -1) -> void
@abstract func remove_item(_item:RenderItem) -> void
@abstract func remove_item_count(_count: int) -> void
## 响应ItemCountSet的数量增加方法
@abstract func add_item_count(_count: int) -> void
@abstract func get_item_count() -> int

func _init(new_player_id:int = RenderContext.PUBLIC_PLAYER_ID) -> void:
	player_id = new_player_id

func process_request(request: RenderRequest) -> void:
	if request is RenderRequest.ItemSet:
		_process_item_set(request as RenderRequest.ItemSet)
func on_drag(item:RenderItem) -> void:
	if not render_context:
		return
	render_context.set_card_on_drag(self, item)

func on_cancel_drag(item:RenderItem) -> void:
	if not render_context:
		return
	if render_context.get_dragged_card() == item:
		render_context.remove_card_on_drag()

func change_select_limit(new_limit)->void:
	select_limit = new_limit
	select_limit_changed.emit(select_limit)

func get_area_name()->StringName:
	return self.get_area_name_static()
## 渲染数据更新方法
func render_update(render_event:RenderEvent = RenderEvent.NULL_EVENT) -> void:
	render_requested.emit(render_event)
## 渲染动画更新方法
func tween_update(render_event:RenderEvent = RenderEvent.NULL_EVENT) -> void:
	tween_requested.emit(render_event)
##获取渲染上下文
func set_render_context(context:RenderContext) -> void:
	render_context = context
##更新ItemPack数据
func _update_item_data(render_item: RenderItem, item_pack: ItemPack) -> void:
	render_item.apply_pack(item_pack)
	tween_update(RenderEvent.new(RenderEvent.DefaultType.CARD_UPDATE))
## 处理ItemSet请求
func _process_item_set(_item_set: RenderRequest.ItemSet) -> void:
	pass
## 处理ItemCountSet 请求
func _process_item_count_set(_item_count_set: RenderRequest.ItemCountSet) -> void:
	pass
## 内部连接方法
func _connect_item_to_area(item:RenderItem) -> void:
	if render_requested.is_connected(item.render_update):
		render_requested.disconnect(item.render_update)
	render_requested.connect(item.render_update)
## 内部断开连接方法
func _disconnect_item_from_area(item:RenderItem) -> void:
	if render_requested.is_connected(item.render_update):
		render_requested.disconnect(item.render_update)
func _exit_tree() -> void:
	if render_context:
		render_context.unregister_render_area(get_area_name())


static func get_area_name_static()->StringName:
	return &""
