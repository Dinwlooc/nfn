extends Control
class_name RenderControl

var render_manager: RenderManager = RenderManager.new()
var render_context: RenderContext = RenderContext.new()
var transport:Transport = GlobalTransport
var operation_manager: OperationManager = OperationManager.new(transport,render_context)


func _ready() -> void:
	GlobalRegistry.register_singleton(GlobalRegistry.RENDER_CONTROL_TYPE, self)
	render_manager.render_tree_init(self, render_context)
	GlobalConsole.c_play_selected_card.connect(_on_play_a_card)
	transport.render_request_received.connect(handle_request)

func _on_play_a_card() -> void:
	operation_manager.upload_play_card()

func handle_request(request: RenderRequest) -> void:
	var target_area:StringName = request.target_area
	var render_area: RenderArea = render_context.get_render_area(target_area)
	GlobalConsole._print(["接收到RenderRequest：",request.get_class_name(),",目标：",request.target_area])
	if render_area:
		render_area.process_request(request)
	else:
		push_error("RenderArea not found for target: " + str(target_area))
		render_context.get_render_area(&"discard").process_request(request) #调试效果
