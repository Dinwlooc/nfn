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

## 背景颜色定义（带透明度）
const TYPE_COLORS: Dictionary[StringName, Dictionary] = {
	GlobalConstants.DefaultCard.ATTACK: {
		&"normal": Color(1.0, 0.5, 0.5, 0.5),
		&"hover":  Color(1.0, 0.5, 0.5, 0.7),
		&"select": Color(1.0, 0.5, 0.5, 1.0)
	},
	GlobalConstants.DefaultCard.DEFENCE: {
		&"normal": Color(0.5, 0.8, 1.0, 0.5),
		&"hover":  Color(0.5, 0.8, 1.0, 0.7),
		&"select": Color(0.5, 0.8, 1.0, 1.0)
	},
	GlobalConstants.DefaultCard.SPELL: {
		&"normal": Color(0.3, 0.8, 0.3, 0.5),
		&"hover":  Color(0.3, 0.8, 0.3, 0.7),
		&"select": Color(0.3, 0.8, 0.3, 1.0)
	}
}
const DEFAULT_COLOR: Color = Color(0.8, 0.8, 0.8, 0.3)

var _stylebox: StyleBoxFlat
var _current_type: StringName

func _ready() -> void:
	_stylebox = background_panel.get_theme_stylebox(&"panel") as StyleBoxFlat
	_stylebox.bg_color = DEFAULT_COLOR
	# 内联信号：按钮连接到内部方法，避免动态连接/断开
	var button: Button = get_node(^"Button")
	button.button_down.connect(_on_button_down_selecting)
	button.button_down.connect(_on_button_down_dragging)
	button.button_up.connect(_on_button_up_cancel_dragging)

## 更新卡片数据（由外部调用，当 item 或其数据变化时）
func data_update(new_item: RenderItem,render_event:RenderEvent = RenderEvent.NULL_EVENT) -> void:
	if item == new_item:
		item.set_item_size(size)
		call_deferred(&"_refresh_ui")
		return
	item = new_item
	item.set_item_size(size)
	call_deferred(&"_refresh_ui")

## 刷新界面（根据当前 item 的数据重绘）
func _refresh_ui() -> void:
	if not item:
		return
	var data: HandCardPack = item.data
	_current_type = data.get_card_type()
	texture_rect.texture = get_item_main_icon(data.name)
	match _current_type:
		GlobalConstants.DefaultCard.DEFENCE:
			cost_label.text = "/"
			damage_label.text = "威力" + str(data.modified_power)
		GlobalConstants.DefaultCard.SPELL:
			cost_label.text = "消耗" + str(data.modified_cost)
			damage_label.text = "/"
		_:
			cost_label.text = "消耗" + str(data.modified_cost)
			damage_label.text = "威力" + str(data.modified_power)
	description_label.text = get_description(data.name)
	name_label.text = get_real_name(data.name)
	vertical_name_label.text = get_real_name(data.name)
	suit_sprite.frame = get_suit(data.suit)
	render_update()

## 渲染更新（由 render_context 触发）
func render_update(_render_event: RenderEvent = RenderEvent.NULL_EVENT) -> void:
	var area: ItemRenderArea
	if item and item.render_context:
		area = item.render_context.get_render_area(item.area_name)
	var show_vertical: bool = area and area.items_pool.size() > 12 and vertical_name_label.text.length() <= 4
	vertical_name_label.visible = show_vertical
	_update_background_color()

## 更新背景颜色（根据当前类型和交互状态）
func _update_background_color() -> void:
	if not _stylebox:
		return
	var color_map: Dictionary = _get_color_map()
	if color_map.is_empty():
		_stylebox.bg_color = DEFAULT_COLOR
		return
	var target_color: Color
	if item and item.selected:
		target_color = color_map[&"select"]
	elif item and item.hovering:
		target_color = color_map[&"hover"]
	else:
		target_color = color_map[&"normal"]
	_stylebox.bg_color = target_color

## 获取当前类型对应的颜色映射（纯函数）
func _get_color_map() -> Dictionary:
	return TYPE_COLORS.get(_current_type, {})

## 重置卡面到初始状态（用于回收复用）
func reset() -> void:
	item = null
	_current_type = &""
	texture_rect.texture = null
	cost_label.text = ""
	damage_label.text = ""
	description_label.text = ""
	name_label.text = ""
	vertical_name_label.text = ""
	suit_sprite.frame = 0
	if _stylebox:
		_stylebox.bg_color = DEFAULT_COLOR
	vertical_name_label.visible = false

## 按钮按下：请求选择（内部方法）
func _on_button_down_selecting() -> void:
	if item:
		item.request_selecting()

## 按钮按下：请求拖动（内部方法）
func _on_button_down_dragging() -> void:
	if item:
		item.request_dragging()

## 按钮抬起：取消拖动（内部方法）
func _on_button_up_cancel_dragging() -> void:
	if item:
		item.request_cancel_dragging()
