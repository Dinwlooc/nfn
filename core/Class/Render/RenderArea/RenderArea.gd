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
var player_id:int
const DefaultArea = GlobalConstants.DefaultArea

func _init(new_player_id:int = -1) -> void:
	player_id = new_player_id

func _ready() -> void:
	ready_expand()

func ready_expand() -> void:
	pass

func process_request(request: RenderRequest) -> void:
	if request is RenderRequest.ItemSet:
		_process_item_set(request as RenderRequest.ItemSet)
# 新增：处理ItemSet请求
func _process_item_set(_item_set: RenderRequest.ItemSet) -> void:
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
	render_context.set_card_on_drag(self, item)

func on_cancel_drag(item:RenderItem) -> void:
	if not render_context:
		return
	if render_context.get_dragged_card() == item:
		render_context.remove_card_on_drag()

# 渲染方法
func render_update(render_event:RenderEvent = RenderEvent.NULL_EVENT) -> void:
	render_requested.emit(render_event)

func tween_update(render_event:RenderEvent = RenderEvent.NULL_EVENT) -> void:
	tween_requested.emit(render_event)

# 上下文管理
func set_render_context(context:RenderContext) -> void:
	render_context = context

## 抽象方法 - 子类必须实现
func add_item(_item:RenderItem, _index:int = -1) -> void:
	push_error("add_item must be implemented in subclass")
##更新ItemPack数据
func _update_item_data(render_item: RenderItem, item_pack: ItemPack) -> void:
	render_item.apply_pack(item_pack)

func remove_item(_item:RenderItem) -> void:
	push_error("remove_item must be implemented in subclass")

func get_item_count() -> int:
	push_error("get_item_count must be implemented in subclass")
	return 0

func get_area_name()->StringName:
	return self.get_area_name_static()

static func get_area_name_static()->StringName:
	return &""
