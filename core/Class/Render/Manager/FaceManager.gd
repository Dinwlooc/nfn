extends RefCounted
class_name FaceManager
## ItemFace回收池，按类型存储
var _face_pool: Dictionary[StringName, Array] = {}
## 最大缓存数量
const MAX_POOL_SIZE: int = 6

# 初始化
func _init() -> void:
	_face_pool = {}

# 连接到RenderItem
func connect_to_item(item: RenderItem) -> void:
	item.request_face.connect(create_item_face)
	item.reset_requested.connect(_on_item_reset_requested)
# 创建ItemFace（使用回收池）
func create_item_face(item: RenderItem) -> void:
	if not item or not item.data:
		return
	var type_name: StringName = item.data.get_class_name()
	var itemface: ItemFace = null
	itemface = _get_from_pool(type_name)
	if not itemface:
		var resource_path: String = GlobalConfig.get_resource_path(&"cardface", type_name)
		var resource: Resource = load(resource_path)
		if resource:
			itemface = resource.instantiate() as ItemFace
			if itemface:
				itemface.item_type = type_name
	if itemface:
		item.add_child(itemface)
		_init_item_face(item, itemface)
		itemface.position = Vector2.ZERO

# 从回收池获取ItemFace
func _get_from_pool(type_name: StringName) -> ItemFace:
	if not _face_pool.has(type_name):
		return null
	var pool_array: Array = _face_pool[type_name]
	if pool_array.is_empty():
		return null
	return pool_array.pop_back() as ItemFace

# 将ItemFace放入回收池
func _add_to_pool(itemface: ItemFace) -> void:
	if not itemface:
		return
	var type_name: StringName = itemface.item_type
	# 先重置状态，再移除父节点
	_cleanup_item_face(itemface)
	itemface.reset()
	if not _face_pool.has(type_name):
		_face_pool[type_name] = []
	var pool_array: Array = _face_pool[type_name]
	if pool_array.size() < MAX_POOL_SIZE:
		pool_array.append(itemface)
	else:
		itemface.queue_free()

# 清理ItemFace状态（仅断开信号和移除父节点，不重置内容）
func _cleanup_item_face(itemface: ItemFace) -> void:
	if not itemface:
		return
	if itemface.item:
		itemface.item.render_requested.disconnect(itemface.render_update)
		itemface.item.data_requested.disconnect(itemface.data_update)
	if itemface.get_parent():
		itemface.get_parent().remove_child(itemface)

# 初始化ItemFace
func _init_item_face(item: RenderItem, itemface: ItemFace) -> void:
	itemface.item_type = item.data.get_class_name()
	itemface.data_update(item)
	_connect_item_face_signals(item, itemface)

# 连接ItemFace信号
func _connect_item_face_signals(item: RenderItem, itemface: ItemFace) -> void:
	item.render_requested.connect(itemface.render_update)
	item.data_requested.connect(itemface.data_update)

# 处理重置请求
func _on_item_reset_requested(item: RenderItem) -> void:
	for child in item.get_children():
		item.remove_child(child)
		if child is ItemFace:
			_add_to_pool(child as ItemFace)
