extends RefCounted
class_name RenderRequestHandler

func handle_request(request: RenderRequest) -> void:
	if request is RenderRequest.CardOperation:
		var card_request: RenderRequest.CardOperation = request
		var render_area:RenderArea = GlobalRegistry._renderareas.get(card_request.target_area)
		if not render_area:
			push_error("Render area not found: " + str(card_request.target_area))
			return
		match request.request_type:
			RenderRequest.REQUEST_TYPE.CARD_ADD:
				var add_request: RenderRequest.CardADD = request
				render_area.cards_add(add_request.card_data)
			RenderRequest.REQUEST_TYPE.CARD_REMOVE:
				var remove_request: RenderRequest.CardRemove = request
				render_area.cards_remove(remove_request.uids_data)        
			_:
				push_error("Unsupported card operation type: " + str(request.request_type))
	else:
		push_error("Unsupported request type: " + str(request.request_type))
