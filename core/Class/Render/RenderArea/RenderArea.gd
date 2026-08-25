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
var _face_cache: Dictionary[StringName, Variant] = {}
const DefaultArea = GlobalConstants.DefaultArea


@abstract func add_item(_item:RenderItem, _index:int = -1) -> void
@abstract func remove_item(_item:RenderItem) -> void
@abstract func remove_item_count(_count: int) -> void
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

func render_update(render_event:RenderEvent = RenderEvent.NULL_EVENT) -> void:
	render_requested.emit(render_event)

func tween_update(render_event:RenderEvent = RenderEvent.NULL_EVENT) -> void:
	tween_requested.emit(render_event)

func set_render_context(context:RenderContext) -> void:
	render_context = context

func _update_item_data(render_item: RenderItem, item_pack: ItemPack) -> void:
	render_item.apply_pack(item_pack)
	render_update(RenderEvent.new(RenderEvent.DefaultType.CARD_UPDATE))

func _process_item_set(_item_set: RenderRequest.ItemSet) -> void:
	pass

func _process_item_count_set(_item_count_set: RenderRequest.ItemCountSet) -> void:
	pass

func _connect_item_to_area(item:RenderItem) -> void:
	if render_requested.is_connected(item.render_update):
		render_requested.disconnect(item.render_update)
	render_requested.connect(item.render_update)

func _disconnect_item_from_area(item:RenderItem) -> void:
	if render_requested.is_connected(item.render_update):
		render_requested.disconnect(item.render_update)

func _exit_tree() -> void:
	if render_context:
		render_context.unregister_render_area(get_area_name())
	clear_face_cache()
# ==================== Face 缓存中心 ====================
## 注册缓存，键需使用命名空间，例如 "nfn:preview_mode"
func register_face_cache(key: StringName, value: Variant) -> void:
	_face_cache[key] = value
## 注销缓存
func unregister_face_cache(key: StringName) -> void:
	_face_cache.erase(key)
## 获取缓存，若不存在返回 null
func get_face_cache(key: StringName) -> Variant:
	return _face_cache.get(key, null)
## 清空所有缓存（退出时调用）
func clear_face_cache() -> void:
	_face_cache.clear()

static func get_area_name_static()->StringName:
	return &""
