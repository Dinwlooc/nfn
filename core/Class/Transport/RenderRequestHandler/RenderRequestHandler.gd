extends RefCounted
class_name RenderRequestHandler

func handle_request(request: RenderRequest) -> void:
	var target_area:StringName = request.target_area
	var render_area:RenderArea = GlobalRegistry.get_renderarea(target_area)
	if render_area:
		render_area.process_request(request)
