extends RefCounted
class_name RenderRequestHandler

func handle_request(request: RenderRequest) -> void:
	if request is RenderRequest.CardAdd:
			var render_area:RenderArea = GlobalRegistry._renderareas.get(request.target_area)
			render_area.cards_add(request.card_data)
	if request is RenderRequest.CardRemove:
			var render_area:RenderArea = GlobalRegistry._renderareas.get(request.target_area)
			render_area.cards_remove(request.uids_data)        
