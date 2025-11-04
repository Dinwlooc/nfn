## 渲染层管理器
##
## 负责卡牌和牌面的创建、信号连接及渲染逻辑管理。
## 作为核心渲染控制器，协调渲染层节点的交互。
extends RefCounted
class_name RenderManager

var _card_pool: Array[RenderCard] = []  # 存储可复用的卡牌对象
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
			for card in area.get_children():
				if card is RenderCard:
					_init_preset_card(card, area)
			area.render_update()
##：初始化预部署的卡牌节点
func _init_preset_card(card: RenderCard, area: RenderArea) -> void:
	card.area = area
	area.add_card_to_pool(card, area.card_pool.size())
	connect_card_to_area_signals(card, area)
	for face in card.get_children():
		if face is RenderCardFace:
			_init_preset_card_face(card, face)
	if card.get_child_count() == 0 and card.data != null:
		card.data_requested.emit()
##初始化预部署的牌面
func _init_preset_card_face(card: RenderCard, face: RenderCardFace) -> void:
	face.card = card
	connect_card_face_signals(card, face)
	face.data_update()

func create_card_face(card: RenderCard) -> void:
	var type_name = GlobalRegistry.get_constant_name(GlobalConstants.KEY_CARD_TYPE, card.data.type)
	var cardface: RenderCardFace = load(GlobalConfig.get_resource_path(&"cardface", type_name)).instantiate()
	if cardface:
		cardface.card = card
		card.add_child(cardface)
		connect_card_face_signals(card, cardface)
		cardface.data_update()

func connect_card_face_signals(card: RenderCard, cardface: RenderCardFace) -> void:
	if card.render_requested.is_connected(cardface.render_update):
		card.render_requested.disconnect(cardface.render_update)
	card.render_requested.connect(cardface.render_update)

func create_cards(cards: Array[CardPack], area: RenderArea) -> void:
	var new_cards: Array[RenderCard] = []
	new_cards.resize(cards.size())
	var array_position = area.card_pool.size()
	for i in range(cards.size()):
		new_cards[i] = create_single_card(cards[i], area, array_position + i)
	area.cards_added.emit(new_cards)
	area.render_update()

func create_single_card(card_data: CardPack, area: RenderArea, pool_id: int) -> RenderCard:
	var new_card:RenderCard
	if not _card_pool.is_empty():
		new_card = _card_pool.pop_back()
		new_card._init(card_data)  # 重置卡牌状态
	else:
		new_card = RenderCard.new(card_data)  # 创建新对象
	new_card.area = area
	area.card_id_to_instance[new_card.get_id()] = new_card
	area.add_card_to_pool(new_card, pool_id)
	connect_card_to_area_signals(new_card, area)
	area.add_child(new_card)
	return new_card

func connect_card_to_area_signals(card: RenderCard, area: RenderArea) -> void:
	if area.render_requested.is_connected(card.render_update):
		area.render_requested.disconnect(card.render_update)
	if card.data_requested.is_connected(create_card_face):
		card.data_requested.disconnect(create_card_face)
	area.render_requested.connect(card.render_update)
	card.data_requested.connect(create_card_face.bind(card))

func connect_area_signals(area: RenderArea) -> void:
	if !area.cards_add_requested.is_connected(create_cards):
		area.cards_add_requested.connect(create_cards.bind(area))
	if !area.cards_remove_requested.is_connected(remove_cards):
		area.cards_remove_requested.connect(remove_cards.bind(area))
	if !area.card_move_requested.is_connected(_on_card_move_requested):
		area.card_move_requested.connect(_on_card_move_requested.bind(area))
# 新增：处理卡牌移动请求
func _on_card_move_requested(card: RenderCard, new_index: int, area: RenderArea) -> void:
	if card.is_inside_tree():
		area.move_child(card, new_index + area.init_child_count)

func remove_cards(uids: PackedInt32Array, area: RenderArea) -> void:
	# 调用 RenderArea 内部方法移除卡牌
	var removed_cards = area.remove_cards_by_uids(uids)
	for card in removed_cards:
		area.remove_child(card)
		_disconnect_card_from_area(card, area)
		_card_pool.append(card)
# 断开卡牌与区域的信号连接
func _disconnect_card_from_area(card: RenderCard, area: RenderArea) -> void:
	if area.render_requested.is_connected(card.render_update):
		area.render_requested.disconnect(card.render_update)
	if card.data_requested.is_connected(create_card_face):
		card.data_requested.disconnect(create_card_face)
