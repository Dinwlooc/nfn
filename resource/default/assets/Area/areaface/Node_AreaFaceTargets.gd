extends AreaFace

var original_position:Vector2
var original_size:Vector2
var area_target_position:Vector2
var area_target_size:Vector2
const TWEEN_TIME = 0.35

func _ready()->void:
	super._ready()
	original_position = position
	original_size = size
	area_target_position = original_position
	area_target_size = original_size

func _on_context_ready()->void:
	render_update()
	area.render_context.connect_renderarea(RenderArea.DefaultArea.HAND,_on_render_area_registered)

func _on_render_area_registered(area:RenderArea)->void:
	area.selected.connect(quickly_select)

func render_update(_render_event:RenderEvent = RenderEvent.new()):
	target_position = UIAnimationUtils.generate_coordinates(area_target_position,area_target_size,area.items_pool.size() - 1)
	tween_update()

func tween_update(_render_event:RenderEvent = RenderEvent.new()):
	card_move()

func _into_area()->void:
	area.render_requested.emit(RenderEvent.new(RenderEvent.DefaultType.INTO_AREA))
	pass

func _outto_area()->void:
	area.render_requested.emit(RenderEvent.new(RenderEvent.DefaultType.OUTTO_AREA))

func card_move()-> void:
	if area.items_pool.size() == 0||target_position.size()==0:
		return
	var skipped_local_players_count:int = 0
	for i in range(0,area.items_pool.size()):
		var player:RenderItem = area.items_pool[i]
		if player.data.peer_id == multiplayer.get_unique_id():
			skipped_local_players_count += 1
			continue
		var _target_position = target_position[i - skipped_local_players_count]
		UIAnimationUtils.tween_animations(player,{^"position":_target_position},TWEEN_TIME)

func quickly_select()->void:
	if area.items_pool.size() <= 0 || area.get_selected_items().size() > 0:
		return
	for player in area.items_pool:
		if player.data.peer_id == multiplayer.get_unique_id():
			continue
		area.on_select(player)
		break
