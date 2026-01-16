## 渲染层管理器
##
## 负责卡牌和牌面的创建、信号连接及渲染逻辑管理。
## 作为核心渲染控制器，协调渲染层节点的交互。
extends RefCounted
class_name RenderManager

var _item_pool:Array[RenderItem] = []  # 复用池

func render_tree_init(root_node:Node, context:RenderContext) -> void:
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
	var type_name = GlobalRegistry.get_constant_name(GlobalConstants.KEY_CARD_TYPE, item.data.type)
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

func _connect_area_signals(area:RenderArea) -> void:
	if not area.items_add_requested.is_connected(_on_items_add_requested):
		area.items_add_requested.connect(_on_items_add_requested)
	if not area.items_remove_requested.is_connected(_on_items_remove_requested):
		area.items_remove_requested.connect(_on_items_remove_requested)

func _on_items_add_requested(items:Array[TransPack], area:RenderArea) -> void:
	add_items_to_area(items, area)

func _on_items_remove_requested(uids:PackedInt32Array, target_area:StringName, area:RenderArea) -> void:
	remove_items(uids, target_area, area)

# 添加项目到区域
func add_items_to_area(packs:Array[TransPack], area:RenderArea) -> void:
	var start_index = area.items_pool.size()
	for i in range(packs.size()):
		var item:RenderItem = _create_single_item(packs[i])
		var pool_index:int = start_index + i
		_connect_item_to_area(item, area)
		area.add_item(item, pool_index)
	area.render_update()

func _create_single_item(item_data:TransPack) -> RenderItem:
	if not _item_pool.is_empty():
		var item:RenderItem = _item_pool.pop_back()
		item._init(item_data)  # 重置状态
		return item
	else:
		var item:RenderItem = RenderItem.new(item_data)
		item.data_requested.connect(_create_item_face)
		return item

# 移除项目
func remove_items(uids:PackedInt32Array, target_area:StringName, area:RenderArea) -> void:
	var removed_items = area.remove_items_by_uids(uids)
	for item in removed_items:
		_disconnect_item_from_area(item, area)
	if target_area != &"" and area.render_context:
		var target = area.render_context.get_render_area(target_area)
		if target:
			move_items_to_area(removed_items, target)
			return
	_item_pool.append_array(removed_items)

func _disconnect_item_from_area(item:RenderItem, area:RenderArea) -> void:
	if area.render_requested.is_connected(item.render_update):
		area.render_requested.disconnect(item.render_update)
	item.request_drag.disconnect(area.on_drag)
	item.request_select.disconnect(area.on_select)

# 移动项目到另一个区域
func move_items_to_area(items:Array[RenderItem], target_area:RenderArea) -> void:
	var start_index = target_area.items_pool.size()
	for i in range(items.size()):
		var item = items[i]
		var pool_index = start_index + i
		if item.area_name and target_area.render_context:
			var source_area = target_area.render_context.get_render_area(item.area_name)
			if source_area:
				_disconnect_item_from_area(item, source_area)
		_connect_item_to_area(item, target_area)
		target_area.add_item(item, pool_index)
	target_area.render_update()
