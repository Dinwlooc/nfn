## 角色目标卡：把玩家的 HP/MP 变化转成受击演出，并驱动选中态的位移/缩放与图标浮动。
extends ItemFace

#==vars==
## 选中图标节点
@onready var selected_icon: TextureRect = $SelectedIcon
## 角色容器节点（用于选中动画的位移/缩放）
@onready var character_container: Control = $CharacterPanel
## 角色动画节点（已封装受击动画）
@onready var character: CharacterFace = $CharacterPanel/Anchor/CharacterContainer
## 角色属性节点
@onready var properties: AreaFace = $AreaFaceSelf_Properties
## 防御区域节点
@onready var area_defence: AreaFace = $AreaFaceDenfence
## 手牌表现节点
@onready var area_hand: AreaFace = $AreaFaceHand
## 选中态补间槽位（同一时刻只保留一条）
var selection_tween: Tween = null
## 原始位置（用于还原图标）
var _icon_original_position: Vector2
## 原始大小（用于还原角色容器）
var _container_original_size: Vector2
## 原始位置（用于还原角色容器）
var _container_original_position: Vector2
## 属性节点的原始位置
var _properties_original_position: Vector2
## 属性节点的原始缩放
var _properties_original_scale: Vector2
## 已提交的选中状态（用于差量判定）
var _was_selected: bool = false
## 缓存的HP值（用于检测变化）
var _cached_hp: int = 0
## 缓存的MP值（用于检测变化）
var _cached_mp: int = 0
## 缓存的玩家ID（用于伤害事件）
var _cached_player_id: int = 0
## 缓存的属性计算结果（留作扩展）
var _cached_properties: Dictionary = {}

#==consts==
## 选中动画时长（秒）
const SELECT_ANIMATION_DURATION: float = 0.2
## 选中动画缓动类型（先快后慢）
const SELECT_ANIMATION_EASE: Tween.EaseType = Tween.EASE_OUT
## 选中动画过渡类型
const SELECT_ANIMATION_TRANS: Tween.TransitionType = Tween.TRANS_QUAD
## 选中时，属性节点向右平移的偏移量（像素）
const PROPERTIES_SHIFT_X: float = 120.0
## 选中时，属性节点的缩放倍数
const PROPERTIES_SCALE: float = 1.0
## 选中图标的浮动幅度（像素）
const FLOAT_AMPLITUDE: float = 10.0
## 选中图标的浮动频率（赫兹，即每秒周期数）
const FLOAT_FREQUENCY: float = 0.004
## 选中时角色容器的缩放系数
const CONTAINER_SELECTED_SCALE: float = 0.95

#==record==
## 选中态目标位姿（四项总是成组使用）。
## @record
class SelectionPose:
	## 角色容器目标位置
	var container_position: Vector2
	## 角色容器目标尺寸
	var container_size: Vector2
	## 属性节点目标位置
	var properties_position: Vector2
	## 属性节点目标缩放
	var properties_scale: Vector2

	## 构造：记录四项目标位姿
	func _init(p_container_position: Vector2, p_container_size: Vector2, p_properties_position: Vector2, p_properties_scale: Vector2) -> void:
		container_position = p_container_position
		container_size = p_container_size
		properties_position = p_properties_position
		properties_scale = p_properties_scale

#==lifecycle==
## 就绪：记录原始位姿并让角色朝外。
## @override
func _ready() -> void:
	_icon_original_position = selected_icon.position
	_container_original_size = character_container.size
	_container_original_position = character_container.position
	_properties_original_position = properties.position
	_properties_original_scale = properties.scale
	character.set_mirrored(true)
## 物理帧：选中图标可见时驱动浮动。
## @override
func _physics_process(_delta: float) -> void:
	if selected_icon.visible:
		_update_floating_icon()

#==hooks==
## 数据更新：绑定新卡牌、接线子区域，并在同一张卡上比较 HP/MP 变化。
## @override
func data_update(new_item: RenderItem, render_item: RenderEvent = RenderEvent.NULL_EVENT) -> void:
	if not new_item:
		return
	var button: Button = get_node(^"Button")
	if item == new_item:
		_handle_same_item_update(new_item)
		call_deferred(&"_refresh_ui")
		return
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
	properties.set_player(item)
	properties.set_render_context(item.render_context)
	area_defence.request_area(RenderArea.DefaultArea.DEFENCE, item.data.get_id())
	area_defence.set_render_context(item.render_context)
	area_defence.set_player(item)
	area_hand.request_area(RenderArea.DefaultArea.HAND, item.data.get_id())
	area_hand.set_render_context(item.render_context)
	item.set_item_size(size)
	_init_cached_stats()
	call_deferred(&"_refresh_ui")
## 补间更新：先提交选中态差量，再把伤害事件转给受击演出。
## @override
func tween_update(render_event: RenderEvent = RenderEvent.NULL_EVENT) -> void:
	_update_selected_effects()
	if render_event.get_type() == RenderEvent.DefaultType.DAMAGED:
		_handle_damage_event(render_event)
## 重置卡面到初始状态（用于回收复用）：清槽位、瞬时归位、清缓存。
## @override
func reset() -> void:
	super.reset()
	item = null
	_was_selected = false
	selection_tween = UIAnimationUtils.clear_tween(selection_tween)
	character.stop_damage_animation()
	_restore_original_pose()
	_cached_hp = 0
	_cached_mp = 0
	_cached_player_id = 0
	_cached_properties.clear()

#==tween==
## 选中态：按目标态装配并提交补间（单槽位提交）。
## @atomic
func tween_selected(selected: bool) -> void:
	_was_selected = selected
	var tween: Tween = create_tween()
	do_selected(tween, character_container, properties, _build_selection_pose(selected))
	selection_tween = UIAnimationUtils.replace_tween(selection_tween, tween)
	selected_icon.visible = selected
	if not selected:
		selected_icon.position = _icon_original_position
## 选中态装配：角色容器与属性节点并行位移、缩放。
## @atomic
static func do_selected(tween: Tween, container: Control, properties: Control, pose: SelectionPose) -> void:
	tween.set_ease(SELECT_ANIMATION_EASE)
	tween.set_trans(SELECT_ANIMATION_TRANS)
	tween.parallel().tween_property(container, ^"position", pose.container_position, SELECT_ANIMATION_DURATION)
	tween.parallel().tween_property(container, ^"size", pose.container_size, SELECT_ANIMATION_DURATION)
	tween.parallel().tween_property(properties, ^"position", pose.properties_position, SELECT_ANIMATION_DURATION)
	tween.parallel().tween_property(properties, ^"scale", pose.properties_scale, SELECT_ANIMATION_DURATION)

#==internal==
## 处理同一物品的数据更新（数值变化）
## @internal
func _handle_same_item_update(new_item: RenderItem) -> void:
	var hp_change: int = _cached_hp - new_item.data.HP
	var mp_change: int = _cached_mp - new_item.data.MP
	if hp_change != 0 or mp_change != 0:
		_send_damage_event(hp_change, mp_change)
	_cached_hp = new_item.data.HP
	_cached_mp = new_item.data.MP
## 初始化或重置缓存值（根据当前item）
## @internal
func _init_cached_stats() -> void:
	if not item:
		_cached_hp = 0
		_cached_mp = 0
		_cached_player_id = 0
		return
	_cached_hp = item.data.HP
	_cached_mp = item.data.MP
	_cached_player_id = item.data.get_id()
	_cached_properties.clear()
## 生成伤害渲染事件并直接交给内部处理器
## @internal
func _send_damage_event(hp_change: int, mp_change: int) -> void:
	var event: RenderEvent = RenderEvent.new()
	event.set_type(RenderEvent.DefaultType.DAMAGED)
	event.config[&"player_id"] = _cached_player_id
	event.config[&"hp_damage"] = hp_change
	event.config[&"mp_damage"] = mp_change
	_handle_damage_event(event)
## 刷新界面（根据数据重绘）
## @internal
func _refresh_ui() -> void:
	if not item:
		return
## 按目标选中态构造位姿记录。
## @internal
func _build_selection_pose(selected: bool) -> SelectionPose:
	var container_position: Vector2 = Vector2.ZERO if selected else _container_original_position
	var container_size: Vector2 = size * CONTAINER_SELECTED_SCALE if selected else _container_original_size
	var properties_position: Vector2 = _properties_original_position + Vector2(PROPERTIES_SHIFT_X, 0) if selected else _properties_original_position
	var properties_scale: Vector2 = _properties_original_scale * PROPERTIES_SCALE if selected else _properties_original_scale
	return SelectionPose.new(container_position, container_size, properties_position, properties_scale)
## 选中态差量提交：状态未变则早退。
## @internal
func _update_selected_effects() -> void:
	if not is_instance_valid(item):
		return
	var is_selected: bool = item.selected
	if is_selected == _was_selected:
		return
	tween_selected(is_selected)
## 瞬时写回未选中位姿（回收路径禁止建补间）。
## @internal
func _restore_original_pose() -> void:
	character_container.position = _container_original_position
	character_container.size = _container_original_size
	properties.position = _properties_original_position
	properties.scale = _properties_original_scale
	selected_icon.visible = false
	selected_icon.position = _icon_original_position
## 更新选中图标的浮动效果（逐帧程序化通道，不占补间槽位）
## @internal
func _update_floating_icon() -> void:
	var offset: float = FLOAT_AMPLITUDE * sin(Time.get_ticks_msec() * FLOAT_FREQUENCY)
	selected_icon.position = _icon_original_position + Vector2(0, offset)
## 处理受击事件（转发给 CharacterFace）
## @external
func _handle_damage_event(event: RenderEvent) -> void:
	var player_id: int = event.config.get(&"player_id", 0)
	var hp_damage: int = event.config.get(&"hp_damage", 0)
	var mp_damage: int = event.config.get(&"mp_damage", 0)
	if hp_damage == 0 and mp_damage == 0:
		return
	if not item or not item.data:
		return
	if player_id != item.data.get_id():
		return
	if not character:
		return
	var data: PlayerPack = item.data as PlayerPack
	var current_hp: int = data.HP
	var max_hp: int = data.modified_HP_max
	var remaining_ratio: float = float(current_hp) / float(max_hp) if max_hp > 0 else 1.0
	character.play_damage_animation(hp_damage, mp_damage, remaining_ratio)
