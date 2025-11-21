extends ItemFace

@onready var Nicon = $ColorRect
var Nicon_init_position:Vector2
const TYPE = GlobalConstants.CARD_TYPES[GlobalConstants.CardType.CHARACTER]
const SELECT_COLOR:Color = Color(1,0.3,0.3)
const HOVERING_COLOR:Color = Color(1,0.7,0.6)
const NORMAL_COLOR:Color = Color(0.8,0.8,0.8)

func _ready() -> void:
	Nicon_init_position = Nicon.position
	var button = get_node(^"Button")
	button.button_down.connect(item.request_select)
	button.button_down.connect(item.request_dragging)
	button.button_up.connect(item.request_dragging)
	item.set_item_size(size)

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
