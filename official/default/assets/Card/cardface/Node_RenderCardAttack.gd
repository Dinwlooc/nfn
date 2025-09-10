extends RenderCardFace

@onready var Nicon = $ColorRect
@onready var NverticalName = $VerticalName
@onready var Ntexture = $CenterContainer/TextureRect
@onready var Ncost = $Cost
@onready var Ndamage = $Damage
@onready var Ndescription = $Description
@onready var Nname = $Name
@onready var Nsuit = $Suit

const TYPE = &"attack"
const SELECT_COLOR:Color = Color(1,0.3,0.3)
const HOVERING_COLOR:Color = Color(1,0.7,0.6)
const NORMAL_COLOR:Color = Color(0.8,0.8,0.8)

func _ready() -> void:
	var button = get_node(^"Button")
	button.button_down.connect(card.request_select)
	button.button_down.connect(card.request_dragging)
	button.button_up.connect(card.request_dragging)

func _input(event: InputEvent) -> void:
	if card.selected:
		Nicon.color = SELECT_COLOR
	elif card.hovering:
		Nicon.color = HOVERING_COLOR
	else:
		Nicon.color = NORMAL_COLOR
	pass

func data_update()-> void:
	var data:HandCardPack = card.data
	var texture = get_card_main_icon(data.name)
	Ntexture.texture = texture
	Ncost.text = "消耗"+str(data.modified_cost)
	Ndamage.text = "威力"+str(data.modified_power)
	Ndescription.text = get_description(data.name)
	Nname.text = get_real_name(data.name)
	NverticalName.text = get_real_name(data.name)
	Nsuit.frame = get_suit(data.suit)
	pass	
	
func render_update(render_event:RenderEvent = RenderEvent.new())->void:
	if card.area.card_pool.size()>12 && NverticalName.text.length() <= 4 :
		NverticalName.visible = true
	else:
		NverticalName.visible = false
	pass
