## 卡牌卡面：把卡牌数据归约为文字/贴图/底色，并把弃牌区闪烁做成单槽位补间。
extends ItemFace

#==vars==
## 卡面底板
@onready var background_panel: Panel = $Backgound
## 竖排名称标签
@onready var vertical_name_label: Label = $VerticalName
## 主图标
@onready var texture_rect: TextureRect = $CenterContainer/TextureRect
## 消耗标签
@onready var cost_label: Label = $Cost
## 伤害数值标签
@onready var damage_label: Label = $Damage
## 描述标签
@onready var description_label: Label = $Description
## 卡名标签
@onready var name_label: Label = $Name
## 花色精灵
@onready var suit_sprite: Sprite2D = $Suit
## 颜色块容器
@onready var color_rect_parent: Node = $ColorRectParent
## 弃牌区闪烁补间槽位（同一时刻只保留一条）
var blink_tween: Tween = null
## 当前卡面样式
var _stylebox: StyleBoxFlat
## 当前卡牌类型
var _current_type: StringName
## 已提交的竖排名可见性（用于差量判定）
var _applied_vertical_name_visible: bool = false
## 已提交的弃牌闪烁状态（用于差量判定）
var _applied_discard_blink: bool = false

#==consts==
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
## 默认底色
const DEFAULT_COLOR: Color = Color(0.8, 0.8, 0.8, 0.3)
## 弃牌区闪烁单程时长（秒）
const DISCARD_BLINK_HALF_TIME: float = 0.3

#==lifecycle==
## 就绪：缓存样式并接线按钮。
## @override
func _ready() -> void:
	_stylebox = background_panel.get_theme_stylebox(&"panel") as StyleBoxFlat
	_stylebox.bg_color = DEFAULT_COLOR
	# 竖排名默认隐藏：场景里该节点默认可见，已提交状态若也写成 false，差量判定会跳过「隐藏」而让它一直显示
	vertical_name_label.visible = false
	_applied_vertical_name_visible = false
	var button: Button = get_node(^"Button")
	button.button_down.connect(_on_button_down_selecting)
	button.button_down.connect(_on_button_down_dragging)
	button.button_up.connect(_on_button_up_cancel_dragging)

#==hooks==
## 数据更新：绑定新卡牌并重绘静态表现。
## @override
func data_update(new_item: RenderItem, _render_event: RenderEvent = RenderEvent.NULL_EVENT) -> void:
	if item == new_item:
		item.set_item_size(size)
		call_deferred(&"_refresh_ui")
		return
	item = new_item
	item.set_item_size(size)
	call_deferred(&"_refresh_ui")
## 渲染更新：只做数据归约与静态表现（底色、竖排名），不做动画判定。
## @override
func render_update(render_event: RenderEvent = RenderEvent.NULL_EVENT) -> void:
	if not item:
		return
	_update_background_color()
	_update_vertical_name_visibility()
	if item.area_name == RenderArea.DefaultArea.HAND and item.render_context:
		return
	tween_update(render_event)
## 补间更新：按事件类型判定弃牌闪烁的目标状态，有差量才提交槽位。
## @override
func tween_update(render_event: RenderEvent = RenderEvent.NULL_EVENT) -> void:
	if not item:
		return
	if render_event.get_type() != RenderEvent.DefaultType.CARD_ADD:
		return
	var active: bool = item.area_name == RenderArea.DefaultArea.DISCARD
	if active == _applied_discard_blink:
		return
	tween_discard_blink(active)
	if not active:
		_update_background_color()
## 重置卡面到初始状态（用于回收复用）：清空槽位与已提交状态。
## @override
func reset() -> void:
	tween_discard_blink(false)
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
	_applied_vertical_name_visible = false
	_applied_discard_blink = false

#==tween==
## 弃牌区闪烁：按目标状态开启循环闪烁，或关闭并清槽位（单槽位提交）。
## @atomic
func tween_discard_blink(active: bool) -> void:
	_applied_discard_blink = active
	if not active:
		blink_tween = UIAnimationUtils.clear_tween(blink_tween)
		return
	var tween: Tween = create_tween()
	do_discard_blink(tween, _stylebox, _stylebox.bg_color)
	blink_tween = UIAnimationUtils.replace_tween(blink_tween, tween)
## 闪烁装配：让底板在白色与给定底色之间循环往复。
## @atomic
static func do_discard_blink(tween: Tween, stylebox: StyleBoxFlat, base_color: Color) -> void:
	tween.set_loops()
	tween.tween_property(stylebox, ^"bg_color", Color.WHITE, DISCARD_BLINK_HALF_TIME).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(stylebox, ^"bg_color", base_color, DISCARD_BLINK_HALF_TIME).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_LINEAR)

#==internal==
## 刷新界面（根据当前 item 的数据重绘静态表现）
## @internal
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
	_update_background_color()
	render_update()
## 手牌区现算竖排名可见性（数据驱动，非动画）。
## @internal
func _update_vertical_name_visibility() -> void:
	if not item or item.area_name != RenderArea.DefaultArea.HAND or not item.render_context:
		return
	var hand_area: RenderArea = item.render_context.get_render_area(item.area_name)
	var show_vertical: bool = hand_area and hand_area.items_pool.size() > 12 and vertical_name_label.text.length() <= 4
	_set_vertical_name_visible(show_vertical)
## 按差量设置竖排名可见性。
## @internal
func _set_vertical_name_visible(visible_flag: bool) -> void:
	if visible_flag == _applied_vertical_name_visible:
		return
	_applied_vertical_name_visible = visible_flag
	vertical_name_label.visible = visible_flag
## 更新背景颜色（瞬时赋值：类型 + 选中/悬停）
## @internal
func _update_background_color() -> void:
	if not _stylebox:
		return
	var color_map: Dictionary = _get_color_map()
	if color_map.is_empty():
		_stylebox.bg_color = DEFAULT_COLOR
		return
	if item and item.selected:
		_stylebox.bg_color = color_map[&"select"]
		return
	if item and item.hovering:
		_stylebox.bg_color = color_map[&"hover"]
		return
	_stylebox.bg_color = color_map[&"normal"]
## 获取当前类型对应的颜色映射
## @pure
func _get_color_map() -> Dictionary:
	return TYPE_COLORS.get(_current_type, {})

#==signals_in==
## 按钮按下：请求选择
## @signal_listener
func _on_button_down_selecting() -> void:
	if item:
		item.request_selecting()
## 按钮按下：请求拖动
## @signal_listener
func _on_button_down_dragging() -> void:
	if item:
		item.request_dragging()
## 按钮抬起：取消拖动
## @signal_listener
func _on_button_up_cancel_dragging() -> void:
	if item:
		item.request_cancel_dragging()
