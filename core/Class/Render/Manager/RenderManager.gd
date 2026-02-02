## 渲染层管理器
## 负责卡牌和牌面的创建、信号连接及渲染逻辑管理。
## 作为核心渲染控制器，协调渲染层节点的交互。
extends RefCounted
class_name RenderManager

var _item_pool:Array[RenderItem] = []  # 复用池
var render_context: RenderContext  # 新增：RenderContext依赖

# 修改：添加render_context参数
func render_tree_init(root_node:Node, context:RenderContext) -> void:
	render_context = context
	for area in root_node.get_children():
		if area is RenderArea:
			_initialize_render_area(area, context)

func _initialize_render_area(area:RenderArea, context:RenderContext) -> void:
	if not area.area_name:
		push_error("RenderArea missing area_name: ", area.name)
		return
	context.register_render_area(area)
	area.set_render_context(context)
	_connect_area_signals(area)
	_initialize_preset_items(area)
	area.context_ready.emit()
	area.render_update()

func _initialize_preset_items(area:RenderArea) -> void:
	var item_index := 0
	for child in area.get_children():
		if child is RenderItem:
			_init_preset_item(child, area, item_index)
			item_index += 1

func _init_preset_item(item:RenderItem, area:RenderArea, pool_index:int) -> void:
	item.area_name = area.area_name
	item.render_context = area.render_context
	_connect_item_to_area(item, area)
	area.add_item(item, pool_index)
	item.data_requested.connect(_create_item_face)
	if item.data:
		var item_type = item.data.get_class_name()
		var item_id = item.data.get_id()
		if render_context:
			render_context.register_render_item(item_type, item_id, item)
	for face in item.get_children():
		if face is ItemFace:
			_init_preset_item_face(item, face)
	if item.get_child_count() == 0 and item.data != null:
		item.data_requested.emit()

func _init_preset_item_face(item:RenderItem, face:ItemFace) -> void:
	face.item = item
	_connect_item_face_signals(item, face)
	face.data_update()

func _create_item_face(item: RenderItem) -> void:
	var type_name =item.data.get_class_name()
	var itemface: ItemFace = load(GlobalConfig.get_resource_path(&"cardface", type_name)).instantiate()
	if itemface:
		itemface.item = item
		item.add_child(itemface)
		_connect_item_face_signals(item, itemface)
		itemface.data_update()

func _connect_item_face_signals(item:RenderItem, itemface:ItemFace) -> void:
	if item.render_requested.is_connected(itemface.render_update):
		item.render_requested.disconnect(itemface.render_update)
	item.render_requested.connect(itemface.render_update)

func _connect_item_to_area(item:RenderItem, area:RenderArea) -> void:
	if area.render_requested.is_connected(item.render_update):
		area.render_requested.disconnect(item.render_update)
	area.render_requested.connect(item.render_update)
	item.request_drag.connect(area.on_drag)
	item.request_select.connect(area.on_select)

# 修改：添加对ItemCounterArea的信号监听
func _connect_area_signals(area:RenderArea) -> void:
	if area is ItemRenderArea:
		if not area.item_add_requested.is_connected(_on_item_add_requested):
			area.item_add_requested.connect(_on_item_add_requested)
	if area is ItemCounterArea:
		if not area.items_added.is_connected(_on_item_counter_item_added):
			area.items_added.connect(_on_item_counter_item_added)

# 新增：ItemCounterArea的item添加信号处理
func _on_item_counter_item_added(item: RenderItem) -> void:
	call_deferred("_recycle_render_item", item)

# 新增：回收RenderItem
func _recycle_render_item(item: RenderItem) -> void:
	if render_context and item.data:
		var item_type = item.data.get_class_name()
		var item_id = item.data.get_id()
		render_context.unregister_render_item(item_type, item_id)
	if item.area_name:
		var current_area = render_context.get_render_area(item.area_name)
		if current_area:
			_disconnect_item_from_area(item, current_area)
	item.area_name = &""
	item.render_context = null
	item.pool_id = -1
	_item_pool.append(item)

func _on_item_add_requested(item:ItemPack, area:RenderArea) -> void:
	add_item_to_area(item, area)

# 添加项目到区域
func add_item_to_area(pack:ItemPack, area:RenderArea) -> void:
	var start_index = area.get_item_count()
	var item:RenderItem = _create_single_item(pack)
	_connect_item_to_area(item, area)
	if render_context:
		var item_type:StringName = pack.get_class_name()
		var item_id:int = pack.get_id()
		render_context.register_render_item(item_type, item_id, item)
	area.add_item(item)
	area.render_update()

func _create_single_item(item_data:TransPack) -> RenderItem:
	if not _item_pool.is_empty():
		var item:RenderItem = _item_pool.pop_back()
		item._init(item_data)  # 重置状态
		if not item.data_requested.is_connected(_create_item_face):
			item.data_requested.connect(_create_item_face)
		return item
	else:
		var item:RenderItem = RenderItem.new(item_data)
		item.data_requested.connect(_create_item_face)
		return item

func _disconnect_item_from_area(item:RenderItem, area:RenderArea) -> void:
	if area.render_requested.is_connected(item.render_update):
		area.render_requested.disconnect(item.render_update)
	item.request_drag.disconnect(area.on_drag)
	item.request_select.disconnect(area.on_select)
