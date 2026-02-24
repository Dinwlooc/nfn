extends AreaFace

var original_position:Vector2
var original_size:Vector2
var area_target_position:Vector2
var area_target_size:Vector2
const TWEEN_TIME = 0.35

func _ready()->void:
	request_area(RenderArea.DefaultArea.PLAYERS)
	original_position = position
	original_size = size
	area_target_position = original_position
	area_target_size = original_size

func _on_context_ready()->void:
	render_update()
	area.render_context.connect_renderarea(RenderArea.DefaultArea.HAND,_on_render_area_registered)

func _on_render_area_registered(area:RenderArea)->void:
	area.selected.connect(quickly_select)

func render_update(_render_event:RenderEvent = RenderEvent.NULL_EVENT):
	target_position = UIAnimationUtils.generate_coordinates(area_target_position,area_target_size,area.items_pool.size() - 1)
	tween_update()

func tween_update(_render_event:RenderEvent = RenderEvent.NULL_EVENT):
	card_move()

func _into_area()->void:
	super._into_area()
	area.render_requested.emit(RenderEvent.new(RenderEvent.DefaultType.INTO_AREA))

func _outto_area()->void:
	super._outto_area()
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
		if player.position == _target_position:
			continue
		UIAnimationUtils.tween_animations(player,{^"position":_target_position},TWEEN_TIME)

func quickly_select(item: RenderItem) -> void:
	if area is not RenderAreaPlayers:
		return
	if area.items_pool.is_empty():
		return
	var card_type: StringName = item.data.get_card_type()
	var selected: Array[RenderItem] = area.get_selected_items()
	var local_player:RenderItem = area.local_player
	match card_type:
		&"attack":
			if selected.is_empty():
				for player in area.items_pool:
					if player != local_player:
						area.on_select(player)
						break
			elif selected[0] == local_player:
				area.on_select(selected[0])
				for player in area.items_pool:
					if player != local_player:
						area.on_select(player)
						break
		&"defence":
			var has_self :bool= false
			for s in selected:
				if s == local_player:
					has_self = true
					continue
				area.on_select(s)
			if not has_self:
				area.on_select(area.local_player)
