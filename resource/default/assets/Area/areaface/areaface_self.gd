extends AreaFace

var character_position:Vector2

func render_update(_render_event:RenderEvent = RenderEvent.NULL_EVENT):
	character_position = position + $BackgoundCharacter.position
	tween_update()

func tween_update(_render_event:RenderEvent = RenderEvent.NULL_EVENT):
	card_move()

func _into_area()->void:
	area.render_requested.emit(RenderEvent.new(RenderEvent.DefaultType.INTO_AREA))
	pass

func _outto_area()->void:
	area.render_requested.emit(RenderEvent.new(RenderEvent.DefaultType.OUTTO_AREA))

func card_move()-> void:
	if area.items_pool.size() == 0:
		return
	for i in range(0,area.items_pool.size()):
		var player:RenderItem = area.items_pool[i]
		if player.data.peer_id == multiplayer.get_unique_id():
			UIAnimationUtils.tween_animations(player,{^"position":character_position},0.1)
