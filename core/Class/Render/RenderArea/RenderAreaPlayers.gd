extends ItemRenderArea
class_name RenderAreaPlayers

var local_player:RenderItem
signal local_player_received(local_player:RenderItem)

func ready_expand()->void:
	items_added.connect(_on_player_added)

func _on_player_added(new_player:RenderItem)->void:
	if new_player.data.get_class_name() != PlayerPack.get_class_name_static():
		return
	if new_player.data.peer_id == multiplayer.get_unique_id():
		local_player = new_player
		render_context.loacal_player_id = local_player.data.get_id()
		local_player_received.emit(local_player)
		return
	render_context.create_render_area(DefaultArea.HAND,new_player.data.get_id())

static func get_area_name_static()->StringName:
	return DefaultArea.PLAYERS
