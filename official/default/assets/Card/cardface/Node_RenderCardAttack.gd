extends ItemFace

@onready var Nicon:Panel = $Backgound
@onready var NverticalName = $VerticalName
@onready var Ntexture = $CenterContainer/TextureRect
@onready var Ncost = $Cost
@onready var Ndamage = $Damage
@onready var Ndescription = $Description
@onready var Nname = $Name
@onready var Nsuit = $Suit

const TYPE = GlobalConstants.CardType.ATTACK
const TYPE_NAME = GlobalConstants.CARD_TYPES[TYPE]
const SELECT_COLOR:Color = Color(1,0.3,0.3,0.7)
const HOVERING_COLOR:Color = Color(1,0.7,0.6,0.7)
const NORMAL_COLOR:Color = Color(0.8,0.8,0.8,0.7)

var _current_color: Color
var _stylebox: StyleBoxFlat

func _ready() -> void:
	var button = get_node(^"Button")
	button.button_down.connect(item.request_select)
	button.button_down.connect(item.request_dragging)
	button.button_up.connect(item.request_dragging)
	_stylebox = Nicon.get_theme_stylebox(&"panel") as StyleBoxFlat
	_current_color = NORMAL_COLOR
	_stylebox.bg_color = _current_color

func _input(_event: InputEvent) -> void:
	if item.selected:
		_stylebox.bg_color = SELECT_COLOR
	elif item.hovering:
		_stylebox.bg_color = HOVERING_COLOR
	else:
		_stylebox.bg_color = NORMAL_COLOR
		
func data_update()-> void:
	var data:HandCardPack = item.data
	var texture = get_item_main_icon(data.name)
	Ntexture.texture = texture
	Ncost.text = "消耗"+str(data.modified_cost)
	Ndamage.text = "威力"+str(data.modified_power)
	Ndescription.text = get_description(data.name)
	Nname.text = get_real_name(data.name)
	NverticalName.text = get_real_name(data.name)
	Nsuit.frame = get_suit(data.suit)
	pass

func render_update(_render_event:RenderEvent = RenderEvent.new())->void:
	if item.area.items_pool.size()>12 && NverticalName.text.length() <= 4 :
		NverticalName.visible = true
	else:
		NverticalName.visible = false
	pass
