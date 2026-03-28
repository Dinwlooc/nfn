extends ItemFace

@onready var Nicon = $ColorRect
var Nicon_init_position:Vector2
const SELECT_COLOR:Color = Color(1,0.3,0.3)
const HOVERING_COLOR:Color = Color(1,0.7,0.6)
const NORMAL_COLOR:Color = Color(0.8,0.8,0.8)

func data_update(new_item:RenderItem)-> void:
	if new_item:
		var button = get_node(^"Button")
		if item != new_item:
			if item:
				button.button_down.disconnect(item.request_selecting)
				button.button_down.disconnect(item.request_dragging)
				button.button_up.disconnect(item.request_dragging)
			if new_item.data.peer_id == multiplayer.get_unique_id():
				queue_free()
				return
			item = new_item
			button.button_down.connect(item.request_selecting)
			button.button_down.connect(item.request_dragging)
			button.button_up.connect(item.request_dragging)
			$AreaFaceSelf_Properties.set_player(item)
			$AreaFaceSelf_Properties.set_render_context(item.render_context)
			$AreaFaceDenfence.request_area(RenderArea.DefaultArea.DEFENCE,item.data.get_id())
			$AreaFaceDenfence.set_render_context(item.render_context)
	item.set_item_size(size)
	Nicon_init_position = Nicon.position

func _physics_process(_delta: float) -> void:
	card_move_expand()

func card_move_expand()->void:
	if Nicon && Nicon.visible:
		Nicon.position.y += 0.3*sin((Time.get_ticks_msec())*0.004)

func _input(_event: InputEvent) -> void:
	if item.selected:
		Nicon.visible = true
	else:
		Nicon.visible = false
		Nicon.position = Nicon_init_position
	pass
