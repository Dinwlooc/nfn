## RenderControl - 根节点，负责初始化
extends Control
class_name RenderControl

var render_context: RenderContext = RenderContext.new()
var face_manager: FaceManager = FaceManager.new()
var transport: Transport = GlobalTransport
var operation_manager: OperationManager = OperationManager.new(transport, render_context)

func _ready() -> void:
	GlobalRegistry.register_singleton(GlobalRegistry.RENDER_CONTROL_TYPE, self)
	for child in get_children():
		if child is RenderArea:
			render_context.register_render_area(child)
			_initialize_render_area(child)
	GlobalConsole.c_play_selected_card.connect(_on_play_a_card)
	transport.render_request_received.connect(handle_request)
	render_context._item_pool.item_created.connect(face_manager.connect_to_item)
	render_context.area_created.connect(_on_render_context_area_created)

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

func _on_play_a_card() -> void:
	operation_manager.upload_play_card()

func handle_request(request: RenderRequest) -> void:
	var target_area: StringName = request.target_area
	var render_area: RenderArea = render_context.get_render_area(target_area)
	GlobalConsole._print(["接收到RenderRequest：", request.get_class_name(), ",目标：", request.target_area])
	if render_area:
		render_area.process_request(request)
	else:
		push_error("RenderArea not found for target: " + str(target_area))
		# 调试效果，尝试使用discard区域
		render_context.get_render_area(&"discard").process_request(request)

func _on_render_context_area_created(area: RenderArea, player_id: int) -> void:
	add_child(area)
	_initialize_render_area(area)
