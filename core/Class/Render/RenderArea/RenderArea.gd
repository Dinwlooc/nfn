extends Control
class_name RenderArea

signal render_requested(render_event:RenderEvent)
signal tween_requested(render_event:RenderEvent)
signal selected(item:RenderItem)
signal items_added(item:RenderItem)
signal items_removed(item:RenderItem)
signal context_ready()

var select_limit:int = 1
var render_context:RenderContext

class DefaultArea:
	const HAND:StringName = GlobalConstants.AREA_TYPES[GlobalConstants.AreaType.HAND]
	const PLAYERS:StringName = GlobalConstants.AREA_TYPES[GlobalConstants.AreaType.PLAYERS]
	const STAGE:StringName = GlobalConstants.AREA_TYPES[GlobalConstants.AreaType.STAGE]

func _ready() -> void:
	ready_expand()

func ready_expand() -> void:
	pass

func process_request(request: RenderRequest) -> void:
	if request is RenderRequest.ItemSet:
		_process_item_set(request as RenderRequest.ItemSet)
# 新增：处理ItemSet请求
func _process_item_set(item_set: RenderRequest.ItemSet) -> void:
	pass
# 新增：更新ItemPack数据
func _update_item_data(render_item: RenderItem, item_pack: ItemPack) -> void:
	# "暂不实现"
	pass
# 新增：内部连接方法
func _connect_item_to_area(item:RenderItem) -> void:
	if render_requested.is_connected(item.render_update):
		render_requested.disconnect(item.render_update)
	render_requested.connect(item.render_update)

# 新增：内部断开连接方法
func _disconnect_item_from_area(item:RenderItem) -> void:
	if render_requested.is_connected(item.render_update):
		render_requested.disconnect(item.render_update)

func _exit_tree() -> void:
	if render_context:
		render_context.unregister_render_area(get_area_name())

func on_drag(item:RenderItem) -> void:
	if not render_context:
		return
	if Input.get_mouse_button_mask() == 1:
		render_context.set_card_on_drag(self, item)
	else:
		render_context.remove_card_on_drag()

# 渲染方法
func render_update(render_event:RenderEvent = RenderEvent.NULL_EVENT) -> void:
	render_requested.emit(render_event)

func tween_update(render_event:RenderEvent = RenderEvent.NULL_EVENT) -> void:
	tween_requested.emit(render_event)

# 上下文管理
func set_render_context(context:RenderContext) -> void:
	render_context = context
	if render_context.dragged_update.is_connected(tween_update.unbind(1)):
		render_context.dragged_update.disconnect(tween_update)
	render_context.dragged_update.connect(tween_update.unbind(1))

# 抽象方法 - 子类必须实现
func add_item(item:RenderItem, index:int = -1) -> void:
	push_error("add_item must be implemented in subclass")

func remove_item(item:RenderItem) -> void:
	push_error("remove_item must be implemented in subclass")

func get_item_count() -> int:
	push_error("get_item_count must be implemented in subclass")
	return 0

func get_area_name()->StringName:
	return self.get_area_name_static()

static func get_area_name_static()->StringName:
	return &""
