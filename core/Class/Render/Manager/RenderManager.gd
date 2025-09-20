## 渲染层管理器
##
## 负责卡牌和牌面的创建、信号连接及渲染逻辑管理。
## 作为核心渲染控制器，协调渲染层节点的交互。
extends RefCounted
class_name RenderManager

func render_tree_init(root_node: Node) -> void:
	for area in root_node.get_children():
		if area is RenderArea:
			connect_area_signals(area)
			for card in area.get_children():
				if card is RenderCard:
					_init_preset_card(card, area)
			area.render_update()
##：初始化预部署的卡牌节点
func _init_preset_card(card: RenderCard, area: RenderArea) -> void:
	card.area = area
	card.pool_id = area.card_pool.size()
	area.card_pool.append(card)
	if card.data != null:
		area.card_id_to_pool_id[card.data.id] = card.pool_id
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
## 为指定渲染卡牌创建对应的牌面实例
## 根据卡牌类型加载对应的[RenderCardFace]资源，建立父子关系并连接信号。[br]
## 完成后触发牌面的初始数据更新。
func create_card_face(card: RenderCard) -> void:
	var type_name = GlobalRegistry.get_constant_name(GlobalConstants.KEY_CARD_TYPE, card.data.type)
	var cardface: RenderCardFace = load(GlobalConfig.get_resource_path(&"cardface", type_name)).instantiate()
	if cardface:
		cardface.card = card
		card.add_child(cardface)
		connect_card_face_signals(card, cardface)
		cardface.data_update()
## 连接卡牌与牌面的信号通道
## 确保[RenderCard]的[code]render_requested[/code]信号触发时，[br]
## 对应的[RenderCardFace]能正确响应渲染更新。
func connect_card_face_signals(card: RenderCard, cardface: RenderCardFace) -> void:
	if card.render_requested.is_connected(cardface.render_update):
		card.render_requested.disconnect(cardface.render_update)
	card.render_requested.connect(cardface.render_update)
## 批量创建卡牌实例并添加到指定区域
## 根据传入的[CardPack]数组生成对应的[RenderCard]实例，[br]
## 将其添加到[RenderArea]的卡牌池中并触发区域渲染更新。
func create_cards(cards: Array[CardPack], area: RenderArea) -> void:
	var new_cards: Array[RenderCard] = []
	new_cards.resize(cards.size())
	var array_position = area.card_pool.size()
	for i in range(cards.size()):
		new_cards[i] = create_single_card(cards[i], area, array_position + i)
	area.cards_added.emit(new_cards)
	area.card_pool.append_array(new_cards)
	area.render_update()
## 创建单张卡牌实例。
## 初始化卡牌的渲染区域关联和池ID，建立信号连接，[br]
## 并在区域索引中注册卡牌ID映射关系。
func create_single_card(card_data: CardPack, area: RenderArea, pool_id: int) -> RenderCard:
	var new_card := RenderCard.new()
	new_card.area = area
	new_card.pool_id = pool_id
	area.add_child(new_card)
	connect_card_to_area_signals(new_card, area)
	new_card.data_update(card_data)
	area.card_id_to_pool_id[card_data.id] = pool_id
	return new_card
## 建立卡牌与区域的信号连接。
## 绑定区域渲染请求到卡牌的渲染更新方法，[br]
## 同时连接卡牌的数据请求信号到牌面创建流程。
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
	# area.cards_remove_requested.connect(remove_cards.bind(area))
