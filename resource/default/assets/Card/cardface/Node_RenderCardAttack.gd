extends ItemFace

@onready var background_panel: Panel = $Backgound
@onready var vertical_name_label: Label = $VerticalName
@onready var texture_rect: TextureRect = $CenterContainer/TextureRect
@onready var cost_label: Label = $Cost
@onready var damage_label: Label = $Damage
@onready var description_label: Label = $Description
@onready var name_label: Label = $Name
@onready var suit_sprite: Sprite2D = $Suit
@onready var color_rect_parent: Node = $ColorRectParent

# 背景颜色定义（带透明度）
const TYPE_COLORS = {
	&"attack": {
		&"normal": Color(1.0, 0.5, 0.5, 0.5),
		&"hover":  Color(1.0, 0.5, 0.5, 0.7),
		&"select": Color(1.0, 0.5, 0.5, 1.0)
	},
	&"defence": {
		&"normal": Color(0.5, 0.8, 1.0, 0.5),
		&"hover":  Color(0.5, 0.8, 1.0, 0.7),
		&"select": Color(0.5, 0.8, 1.0, 1.0)
	},
	&"spell": {
		&"normal": Color(0.3, 0.8, 0.3, 0.5),
		&"hover":  Color(0.3, 0.8, 0.3, 0.7),
		&"select": Color(0.3, 0.8, 0.3, 1.0)
	}
}
const DEFAULT_COLOR = Color(0.8, 0.8, 0.8, 0.3)
var _stylebox: StyleBoxFlat
var _current_type: StringName

func _ready() -> void:
	_stylebox = background_panel.get_theme_stylebox(&"panel") as StyleBoxFlat
	_stylebox.bg_color = DEFAULT_COLOR

func data_update(new_item: RenderItem) -> void:
	if item != new_item:
		var button = get_node(^"Button")
		if item:
			button.button_down.disconnect(item.request_selecting)
			button.button_down.disconnect(item.request_dragging)
			button.button_up.disconnect(item.request_dragging)
		item = new_item
		button.button_down.connect(item.request_selecting)
		button.button_down.connect(item.request_dragging)
		button.button_up.connect(item.request_dragging)
	var data: HandCardPack = item.data
	_current_type = data.get_card_type()
	texture_rect.texture = get_item_main_icon(data.name)
	if _current_type == &"defence":
		cost_label.text = "/"
		damage_label.text = "威力" + str(data.modified_power)
	elif _current_type == &"spell":
		cost_label.text = "消耗" + str(data.modified_cost)
		damage_label.text = "/"
	else:
		cost_label.text = "消耗" + str(data.modified_cost)
		damage_label.text = "威力" + str(data.modified_power)
	description_label.text = get_description(data.name)
	name_label.text = get_real_name(data.name)
	vertical_name_label.text = get_real_name(data.name)
	suit_sprite.frame = get_suit(data.suit)
	render_update()

func render_update(_render_event: RenderEvent = RenderEvent.NULL_EVENT) -> void:
	var area: RenderAreaHand
	if item.render_context:
		area = item.render_context.get_render_area(item.area_name)
	if area && area.items_pool.size() > 12 && vertical_name_label.text.length() <= 4:
		vertical_name_label.visible = true
	else:
		vertical_name_label.visible = false
	_update_background_color()

func _update_background_color() -> void:
	var color_map = TYPE_COLORS.get(_current_type, {})
	if color_map.is_empty():
		_stylebox.bg_color = DEFAULT_COLOR
		return
	var target_color: Color
	if item.selected:
		target_color = color_map[&"select"]
	elif item.hovering:
		target_color = color_map[&"hover"]
	else:
		target_color = color_map[&"normal"]
	_stylebox.bg_color = target_color
