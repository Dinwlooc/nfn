extends Control
class_name RenderControl
## 渲染请求队列处理器（先进先出，每帧处理一个）
class RenderRequestQueue:
	extends RefCounted
	var _queue: Array[RenderRequest] = []
	var _owner: RenderControl
	func _init(owner: RenderControl) -> void:
		_owner = owner
	## 入队请求
	func enqueue(request: RenderRequest) -> void:
		_queue.append(request)
	## 每帧处理一个请求
	func process_one() -> void:
		if _queue.is_empty():
			return
		var request = _queue.pop_front()
		_owner._handle_request_immediate(request)

var render_context: RenderContext = RenderContext.new()
var face_manager: FaceManager = FaceManager.new()
var transport: Transport = GlobalTransport
var operation_manager: OperationManager = OperationManager.new(transport, render_context)
## 渲染请求队列
var _request_queue: RenderRequestQueue

func _ready() -> void:
	GlobalRegistry.register_singleton(GlobalRegistry.RENDER_CONTROL_TYPE, self)
	render_context.set_operation_manager(operation_manager)
	_request_queue = RenderRequestQueue.new(self)
	transport.render_request_received.connect(_request_queue.enqueue)
	for child in get_children():
		if child is RenderArea:
			render_context.register_render_area(child)
			_initialize_render_area(child)
	GlobalConsole.c_select_hand_card.connect(_on_select_hand_card)
	GlobalConsole.c_select_target.connect(_on_select_target)
	GlobalConsole.c_play_selected_card.connect(_on_play_a_card)
	GlobalConsole.c_discard_cards.connect(_on_discard_cards)
	GlobalConsole.c_abandon_response.connect(_on_abandon_response)
	render_context.item_manager.item_created.connect(face_manager.connect_to_item)
	render_context.area_manager.area_created.connect(_on_render_context_area_created)

func _process(_delta: float) -> void:
	if not Engine.get_process_frames() % 10 == 0:
		return
	_request_queue.process_one()

func _initialize_render_area(area: RenderArea) -> void:
	area.set_render_context(render_context)
	_initialize_preset_items(area)
	area.context_ready.emit()
	area.render_update()

func _initialize_preset_items(area: RenderArea) -> void:
	var item_index := 0
	for child in area.get_children():
		if child is RenderItem:
			_init_preset_item(child, area, item_index)
			item_index += 1
		if child is AreaFace:
			child.set_render_context(render_context)

func _init_preset_item(item: RenderItem, area: RenderArea, pool_index: int) -> void:
	item.area_name = area.get_area_name()
	item.render_context = render_context
	area._connect_item_to_area(item)
	area.add_item(item, pool_index)
	if item.data:
		var item_type = item.data.get_class_name()
		var item_id = item.data.get_id()
		render_context.register_render_item(item_type, item_id, item)
	if not item.data_requested.is_connected(face_manager.create_item_face):
		item.data_requested.connect(face_manager.create_item_face.bind(item))
	for face in item.get_children():
		if face is ItemFace:
			face_manager._init_preset_item_face(item, face)
	if item.get_child_count() == 0 and item.data != null:
		item.data_requested.emit()

## 控制台指令：追加选择渲染位次对应的手牌。
## @delegates(on_select)
func _on_select_hand_card(card_index: int) -> void:
	var hand_area: ItemRenderArea = render_context.get_render_area(RenderArea.DefaultArea.HAND) as ItemRenderArea
	if not hand_area:
		print_request_error(&"c_select_hand_card", OperationManager.RequestError.HAND_AREA_MISSING)
		return
	var card_item: RenderItem = hand_area.get_item_by_index(card_index)
	if not card_item:
		print_request_error(&"c_select_hand_card", OperationManager.RequestError.INVALID_CARD_INDEX)
		return
	hand_area.on_select(card_item)
## 控制台指令：追加选择玩家 id 对应的目标。
## @delegates(on_select)
func _on_select_target(target_player_id: int) -> void:
	var players_area: ItemRenderArea = render_context.get_render_area(RenderArea.DefaultArea.PLAYERS) as ItemRenderArea
	if not players_area:
		print_request_error(&"c_select_target", OperationManager.RequestError.PLAYERS_AREA_MISSING)
		return
	var target_item: RenderItem = render_context.get_render_item_by_id(PlayerPack.get_class_name_static(), target_player_id)
	if not target_item:
		print_request_error(&"c_select_target", OperationManager.RequestError.INVALID_TARGET_ID)
		return
	players_area.on_select(target_item)
## 控制台指令：打出卡牌。不传参走已选牌与已选目标，传索引时交给业务方法按索引出牌。
## @delegates(play_card_by_index)
func _on_play_a_card(card_index: int = -1, target_player_id: int = 0) -> void:
	if card_index < 0:
		operation_manager.upload_play_card()
		return
	var error:OperationManager.RequestError = operation_manager.play_card_by_index(card_index, target_player_id)
	print_request_error(&"c_play_a_card", error)
## 控制台指令：弃牌。不传参走已选手牌，传索引时交给业务方法按索引弃置。
## @delegates(discard_card_by_index)
func _on_discard_cards(card_index: int = -1) -> void:
	if card_index < 0:
		operation_manager.upload_discard_cards()
		return
	var error:OperationManager.RequestError = operation_manager.discard_card_by_index(card_index)
	print_request_error(&"c_discard_cards", error)
## 控制台指令：放弃响应。
## @delegates(upload_abandon_response)
func _on_abandon_response() -> void:
	operation_manager.upload_abandon_response()
## 向游戏内控制台播报请求错误。
## @operation
func print_request_error(source: StringName, error: OperationManager.RequestError) -> void:
	GlobalConsole._print("%s：%s" % [source, OperationManager.ERROR_MESSAGES.get(error, "未知错误")])

## 立即处理渲染请求（由队列调用，不对外暴露）
func _handle_request_immediate(request: RenderRequest) -> void:
	var target_area: StringName = request.target_area
	var target_area_player_id: int = request.target_area_player_id
	if target_area == RenderArea.DefaultArea.PLAYERS:
		target_area_player_id = RenderContext.PUBLIC_PLAYER_ID
	var render_area: RenderArea = render_context.get_render_area(target_area, target_area_player_id)
	GlobalConsole._print(["接收到RenderRequest：", request.get_class_name(), ",目标：", request.target_area, ",属于：玩家", request.target_area_player_id])
	if render_area:
		render_area.process_request(request)
	else:
		push_error("RenderArea not found for target: " + str(target_area) + ",player:" + str(request.target_area_player_id))
		render_context.get_render_area(&"discard").process_request(request)

func _on_render_context_area_created(area: RenderArea, player_id: int) -> void:
	_initialize_render_area(area)
