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
			if area.area_name != "":
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
	item.area = area
	area.add_card_to_pool(item, area.items_pool.size())
	connect_card_to_area_signals(item, area)
	for face in item.get_children():
		if face is ItemFace:
			_init_preset_card_face(item, face)
	if item.get_child_count() == 0 and item.data != null:
		item.data_requested.emit()
##初始化预部署的牌面
func _init_preset_card_face(item: RenderItem, face: ItemFace) -> void:
	face.item = item
	connect_card_face_signals(item, face)
	face.data_update()

func create_card_face(item: RenderItem) -> void:
	var type_name = GlobalRegistry.get_constant_name(GlobalConstants.KEY_CARD_TYPE, item.data.type)
	var itemface: ItemFace = load(GlobalConfig.get_resource_path(&"cardface", type_name)).instantiate()
	if itemface:
		itemface.item = item
		item.add_child(itemface)
		connect_card_face_signals(item, itemface)
		itemface.data_update()

func connect_card_face_signals(item: RenderItem, itemface: ItemFace) -> void:
	if item.render_requested.is_connected(itemface.render_update):
		item.render_requested.disconnect(itemface.render_update)
	item.render_requested.connect(itemface.render_update)

func create_cards(items: Array[CardPack], area: RenderArea) -> void:
	var new_items: Array[RenderItem] = []
	new_items.resize(items.size())
	var array_position = area.items_pool.size()
	for i in range(items.size()):
		new_items[i] = create_single_card(items[i], area, array_position + i)
	area.items_added.emit(new_items)
	area.render_update()

func create_single_card(item_data: TransPack, area: RenderArea, pool_id: int) -> RenderItem:
	var new_item:RenderItem
	if not _item_pool.is_empty():
		new_item = _item_pool.pop_back()
		new_item._init(item_data)  # 重置卡牌状态
	else:
		new_item = RenderItem.new(item_data)  # 创建新对象
	new_item.area = area
	area.item_id_to_instance[new_item.get_id()] = new_item
	area.add_card_to_pool(new_item, pool_id)
	connect_card_to_area_signals(new_item, area)
	area.add_child(new_item)
	return new_item
	
func connect_card_to_area_signals(card: RenderItem, area: RenderArea) -> void:
	if area.render_requested.is_connected(card.render_update):
		area.render_requested.disconnect(card.render_update)
	if card.data_requested.is_connected(create_card_face):
		card.data_requested.disconnect(create_card_face)
	area.render_requested.connect(card.render_update)
	card.data_requested.connect(create_card_face.bind(card))

func connect_area_signals(area: RenderArea) -> void:
	if !area.items_add_requested.is_connected(create_cards):
		area.items_add_requested.connect(create_cards.bind(area))
	if !area.items_remove_requested.is_connected(remove_items):
		area.items_remove_requested.connect(remove_items.bind(area))
	if !area.item_move_requested.is_connected(_on_item_move_requested):
		area.item_move_requested.connect(_on_item_move_requested.bind(area))
# 新增：处理卡牌移动请求
func _on_item_move_requested(card: RenderItem, new_index: int, area: RenderArea) -> void:
	if card.is_inside_tree():
		area.move_child(card, new_index + area.init_child_count)

func remove_items(uids: PackedInt32Array, area: RenderArea) -> void:
	# 调用 RenderArea 内部方法移除卡牌
	var removed_items = area.remove_items_by_uids(uids)
	for item in removed_items:
		area.remove_child(item)
		_disconnect_item_from_area(item, area)
		_item_pool.append(item)
# 断开卡牌与区域的信号连接
func _disconnect_item_from_area(card: RenderItem, area: RenderArea) -> void:
	if area.render_requested.is_connected(card.render_update):
		area.render_requested.disconnect(card.render_update)
	if card.data_requested.is_connected(create_card_face):
		card.data_requested.disconnect(create_card_face)
