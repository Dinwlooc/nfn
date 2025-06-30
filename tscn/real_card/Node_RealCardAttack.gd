extends RealCardFace

@onready var Nicon = $ColorRect
@onready var NverticalName = $VerticalName
@onready var Ntexture = $CenterContainer/TextureRect
@onready var Ncost = $Cost
@onready var Ndamage = $Damage
@onready var Ndescription = $Description
@onready var Nname = $Name
@onready var Nsuit = $Suit

const TYPE = "attack"
const SELECT_COLOR:Color = Color(1,0.3,0.3)
const HOVERING_COLOR:Color = Color(1,0.7,0.6)
const NORMAL_COLOR:Color = Color(0.8,0.8,0.8)



func _process(_delta):
	if get_parent_control().selected:
		Nicon.color = SELECT_COLOR
	elif get_parent_control().hovering:
		Nicon.color = HOVERING_COLOR
	else:
		Nicon.color = NORMAL_COLOR
	pass

func data_update()-> void:
	var texture = load(card.texture_path) as Texture
	Ntexture.texture = texture
	Ncost.text = "消耗"+str(card.basic_cost)
	Ndamage.text = "伤害"+str(card.basic_damage)
	Ndescription.text = card.description
	Nname.text = card.real_name
	NverticalName.text = card.real_name
	Nsuit.frame = get_suit(card.suit)
	pass	
	
func render_update()->void:
	if card.area.real_card_pool.size()>12:
		NverticalName.visible = true
	else:
		NverticalName.visible = false
	pass
