extends ItemRenderArea
class_name RenderAreaPlayers

var local_player:RenderItem

func ready_expand()->void:
	area_name = DefaultArea.PLAYERS
	pack_type = PlayerPack.get_class_name_static()
	items_added.connect(_on_player_added)

func _on_player_added(new_player:RenderItem):
	if new_player.data.peer_id == multiplayer.get_unique_id():
		local_player = new_player
