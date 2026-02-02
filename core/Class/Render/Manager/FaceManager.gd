## FaceManager - 负责ItemFace的创建和管理
extends RefCounted
class_name FaceManager

func connect_to_item(item:RenderItem) -> void:
	item.request_face.connect(create_item_face)
	item.reset_requested.connect(_on_item_reset_requested)
# 创建ItemFace
func create_item_face(item: RenderItem) -> void:
	if not item or not item.data:
		return
	var type_name = item.data.get_class_name()
	var itemface: ItemFace = load(GlobalConfig.get_resource_path(&"cardface", type_name)).instantiate()
	if itemface:
		item.add_child(itemface)
		_connect_item_face_signals(item, itemface)
# 初始化预设的ItemFace
func _init_preset_item_face(item: RenderItem, face: ItemFace) -> void:
	face.item = item
	_connect_item_face_signals(item, face)
# 连接ItemFace信号
func _connect_item_face_signals(item: RenderItem, itemface: ItemFace) -> void:
	item.render_requested.connect(itemface.render_update)
	item.data_requested.connect(itemface.data_update)
# 新增：处理重置请求
func _on_item_reset_requested(item: RenderItem) -> void:
	for child in item.get_children():
		item.remove_child(child)
