## 渲染层管理器
##
## 负责卡牌和牌面的创建、信号连接及渲染逻辑管理。
## 作为核心渲染控制器，协调渲染层节点的交互。
extends RefCounted
class_name RenderManager

var _item_pool: Array[RenderItem] = []  # 存储可复用的卡牌对象

func render_tree_init(root_node: Node, context: RenderContext) -> void:
	var render_context = context  # 接收注入的上下文
	for area in root_node.get_children():
		if area is RenderArea:
			if area.area_name:
				render_context.register_render_area(area)
			else:
				push_error("RenderArea missing area_name: ", area.name)
			area.set_render_context(render_context)  # 向区域注入上下文
			area.context_ready.emit()
			connect_area_signals(area)
			for item in area.get_children():
				if item is RenderItem:
					_init_preset_card(item, area)
			area.render_update()
##：初始化预部署的卡牌节点
func _init_preset_card(item: RenderItem, area: RenderArea) -> void:
	item.area_name = area.area_name
	item.render_context = area.render_context
	area.set_item_to_pool(item, area.items_pool.size())
	connect_item_to_area_signals(item, area)
	item.data_requested.connect(create_item_face)
	for face in item.get_children():
		if face is ItemFace:
			_init_preset_card_face(item, face)
	if item.get_child_count() == 0 and item.data != null:
		item.data_requested.emit()
##初始化预部署的牌面
func _init_preset_card_face(item: RenderItem, face: ItemFace) -> void:
	face.item = item
	connect_item_face_signals(item, face)
	face.data_update()

func create_item_face(item: RenderItem) -> void:
	var type_name = GlobalRegistry.get_constant_name(GlobalConstants.KEY_CARD_TYPE, item.data.type)
	var itemface: ItemFace = load(GlobalConfig.get_resource_path(&"cardface", type_name)).instantiate()
	if itemface:
		itemface.item = item
		item.add_child(itemface)
		connect_item_face_signals(item, itemface)
		itemface.data_update()

func connect_item_face_signals(item: RenderItem, itemface: ItemFace) -> void:
	if item.render_requested.is_connected(itemface.render_update):
		item.render_requested.disconnect(itemface.render_update)
	item.render_requested.connect(itemface.render_update)

## 提取公共方法：连接信号、添加子节点、设置池位置
func _add_single_item_to_pool(item: RenderItem, area: RenderArea, pool_id: int) -> void:
	connect_item_to_area_signals(item, area)
	area.add_child(item)
	area.set_item_to_pool(item, pool_id)
## 移动项目到区域
func move_items_to_area(items: Array[RenderItem], area: RenderArea) -> void:
	var o_pos: int = area.items_pool.size()
	area.items_pool.resize(o_pos + items.size())
	for i in items.size():
		_add_single_item_to_pool(items[i], area, o_pos + i)
	area.render_update()
## 批量添加项目
func add_items_to_area(packs: Array[TransPack], area: RenderArea) -> void:
	var o_pos: int = area.items_pool.size()
	area.items_pool.resize(o_pos + packs.size())
	for i in packs.size():
		var item :RenderItem = create_single_item(packs[i])
		_add_single_item_to_pool(item, area, o_pos + i)
	area.render_update()

func create_single_item(item_data: TransPack) -> RenderItem:
	var new_item:RenderItem
	if not _item_pool.is_empty():
		new_item = _item_pool.pop_back()
		new_item._init(item_data)  # 重置卡牌状态
	else:
		new_item = RenderItem.new(item_data)
		new_item.data_requested.connect(create_item_face)
	return new_item

func connect_item_to_area_signals(item: RenderItem, area: RenderArea) -> void:
	area.render_requested.connect(item.render_update)
	item.request_drag.connect(area.on_drag)
	item.request_select.connect(area.on_select)
func connect_area_signals(area: RenderArea) -> void:
		area.items_add_requested.connect(add_items_to_area)
		area.items_remove_requested.connect(remove_items)
		area.item_move_requested.connect(_on_item_move_requested)
##：处理卡牌移动请求
func _on_item_move_requested(card: RenderItem, new_index: int, area: RenderArea) -> void:
	if card.is_inside_tree():
		area.move_child(card, new_index + area.init_child_count)
## 移除方法支持区域移动
func remove_items(uids: PackedInt32Array, target_area: StringName, area: RenderArea) -> void:
	var removed_items = area.remove_items_by_uids(uids)
	for item in removed_items:
		area.remove_child(item)
		disconnect_item_from_area_signals(item, area)
	area.render_update()
	if target_area != &"" && area.render_context:
		var target = area.render_context.get_render_area(target_area)
		if target:
			move_items_to_area(removed_items, target)
			return
	_item_pool.append_array(removed_items)
# 断开卡牌与区域的信号连接
func disconnect_item_from_area_signals(item: RenderItem, area: RenderArea) -> void:
	area.render_requested.disconnect(item.render_update)
	item.request_drag.disconnect(area.on_drag)
	item.request_select.disconnect(area.on_select)
