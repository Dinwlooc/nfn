extends RenderArea
class_name RenderAreaHand

func ready_expand()->void:
	area_name = DefaultArea.HAND

func process_request(request: RenderRequest) -> void:
	if request is RenderRequest.ItemAdd:
		items_add_requested.emit(request.item_data)
	elif request is RenderRequest.CardRemove:
		items_remove_requested.emit(request.uids_data)
