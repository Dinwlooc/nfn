extends RenderArea
class_name RenderAreaHand

func ready_expand()->void:
	area_name = DefaultArea.HAND

func process_request(request: RenderRequest) -> void:
	if request is RenderRequest.ItemAdd:
		items_add_requested.emit(request.items)
	elif request is RenderRequest.ItemRemove:
		items_remove_requested.emit(request.uids_data)
