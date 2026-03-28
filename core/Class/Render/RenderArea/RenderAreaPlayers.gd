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
		render_context.local_player_id = local_player.data.get_id()
		local_player_received.emit(local_player)
		return
	var hand_area:RenderAreaHand = render_context.create_render_area(DefaultArea.HAND,new_player.data.get_id())
	var defence_area:RenderAreaDefence = render_context.create_render_area(DefaultArea.DEFENCE,new_player.data.get_id())
	new_player.add_child(hand_area)
	new_player.add_child(defence_area)

static func get_area_name_static()->StringName:
	return DefaultArea.PLAYERS
