extends ItemFace

## 选中图标节点
@onready var selected_icon: TextureRect = $SelectedIcon
## 角色容器节点（用于选中动画的位移/缩放）
@onready var character_container: Control = $CharacterPanel
## 角色动画节点（已封装受击动画）
@onready var character: CharacterFace = $CharacterPanel/Anchor/CharacterContainer
## 角色背景节点
@onready var character_background: ColorRect = $CharacterContainer/BackgoundCharacter
## 角色属性节点
@onready var properties: AreaFace = $AreaFaceSelf_Properties
## 防御区域节点
@onready var area_defence: AreaFace = $AreaFaceDenfence

## 选中动画时长（秒）
const SELECT_ANIMATION_DURATION: float = 0.2
## 选中动画缓动类型（先快后慢）
const SELECT_ANIMATION_EASE: int = Tween.EASE_OUT
## 选中动画过渡类型
const SELECT_ANIMATION_TRANS: int = Tween.TRANS_QUAD

## 选中时，属性节点向右平移的偏移量（像素）
const PROPERTIES_SHIFT_X: float = 120.0
## 选中时，属性节点的缩放倍数
const PROPERTIES_SCALE: float = 1
## 选中图标的浮动幅度（像素）
const FLOAT_AMPLITUDE: float = 10
## 选中图标的浮动频率（赫兹，即每秒周期数）
const FLOAT_FREQUENCY: float = 0.004

## 原始位置（用于还原）
var _icon_original_position: Vector2
## 原始大小（用于还原角色容器）
var _container_original_size: Vector2
## 原始位置（用于还原角色容器）
var _container_original_position: Vector2
## 属性节点的原始位置
var _properties_original_position: Vector2
## 属性节点的原始缩放
var _properties_original_scale: Vector2
## 当前选中状态（缓存，用于避免重复更新）
var _was_selected: bool = false
## 当前选中动画tween引用
var _current_tween: Tween = null

## 缓存的HP值（用于检测损失）
var _cached_hp: int = 0
## 缓存的MP值（用于检测损失）
var _cached_mp: int = 0
## 缓存的玩家ID（用于伤害事件）
var _cached_player_id: int = 0
## 缓存的属性计算结果（留作扩展）
var _cached_properties: Dictionary = {}

func _ready() -> void:
	# 记录原始状态
	_icon_original_position = selected_icon.position
	_container_original_size = character_container.size
	_container_original_position = character_container.position
	_properties_original_position = properties.position
	_properties_original_scale = properties.scale
	character.set_mirrored(true)

## 更新卡片数据（由外部调用）
func data_update(new_item: RenderItem) -> void:
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
	item.set_item_size(size)
	_init_cached_stats()  # 初始化缓存
	call_deferred(&"_refresh_ui")

## 处理同一物品的数据更新（数值变化）
func _handle_same_item_update(new_item: RenderItem) -> void:
	# 计算HP/MP损失（正数为减少），注意属性大写
	var hp_loss: int = _cached_hp - new_item.data.HP
	var mp_loss: int = _cached_mp - new_item.data.MP
	if hp_loss > 0 or mp_loss > 0:
		_send_damage_event(hp_loss, mp_loss)
	# 更新缓存
	_cached_hp = new_item.data.HP
	_cached_mp = new_item.data.MP

## 初始化或重置缓存值（根据当前item）
func _init_cached_stats() -> void:
	if not item:
		_cached_hp = 0
		_cached_mp = 0
		_cached_player_id = 0
		return
	_cached_hp = item.data.HP
	_cached_mp = item.data.MP
	_cached_player_id = item.data.get_id()  # 假设有 player_id 字段
	_cached_properties.clear()

## 生成伤害渲染事件并直接交给内部处理器
func _send_damage_event(hp_damage: int, mp_damage: int) -> void:
	var event: RenderEvent = RenderEvent.new()
	event.set_type(RenderEvent.DefaultType.DAMAGED)
	event.config[&"player_id"] = _cached_player_id
	event.config[&"hp_damage"] = hp_damage
	event.config[&"mp_damage"] = mp_damage
	_handle_damage_event(event)

## 刷新界面（根据数据重绘）
func _refresh_ui() -> void:
	if not item:
		return

## 渲染更新（由 render_context 触发）
func render_update(_render_event: RenderEvent = RenderEvent.NULL_EVENT) -> void:
	_update_selected_effects()
	if _render_event.get_type() == RenderEvent.DefaultType.DAMAGED:
		_handle_damage_event(_render_event)

## 更新选中时的视觉效果
func _update_selected_effects() -> void:
	if not is_instance_valid(item):
		return
	var is_selected: bool = item.selected
	if is_selected == _was_selected:
		return
	_was_selected = is_selected
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()
	if is_selected:
		_apply_selected_effects()
	else:
		_revert_selected_effects()

## 应用选中效果（带动画）
func _apply_selected_effects() -> void:
	_current_tween = create_tween()
	_current_tween.set_ease(SELECT_ANIMATION_EASE)
	_current_tween.set_trans(SELECT_ANIMATION_TRANS)
	_current_tween.parallel().tween_property(character_container, ^"position", Vector2.ZERO, SELECT_ANIMATION_DURATION)
	_current_tween.parallel().tween_property(character_container, ^"size", size , SELECT_ANIMATION_DURATION)
	_current_tween.parallel().tween_property(character_background, ^"position", Vector2.ZERO, SELECT_ANIMATION_DURATION)
	_current_tween.parallel().tween_property(character_background, ^"size", size , SELECT_ANIMATION_DURATION)
	_current_tween.parallel().tween_property(properties, ^"position", _properties_original_position + Vector2(PROPERTIES_SHIFT_X, 0), SELECT_ANIMATION_DURATION)
	_current_tween.parallel().tween_property(properties, ^"scale", _properties_original_scale * PROPERTIES_SCALE, SELECT_ANIMATION_DURATION)
	selected_icon.visible = true

## 还原选中效果（带动画）
func _revert_selected_effects() -> void:
	_current_tween = create_tween()
	_current_tween.set_ease(SELECT_ANIMATION_EASE)
	_current_tween.set_trans(SELECT_ANIMATION_TRANS)
	_current_tween.parallel().tween_property(character_container, ^"position", _container_original_position, SELECT_ANIMATION_DURATION)
	_current_tween.parallel().tween_property(character_container, ^"size", _container_original_size, SELECT_ANIMATION_DURATION)
	_current_tween.parallel().tween_property(properties, ^"position", _properties_original_position, SELECT_ANIMATION_DURATION)
	_current_tween.parallel().tween_property(properties, ^"scale", _properties_original_scale, SELECT_ANIMATION_DURATION)
	selected_icon.visible = false
	selected_icon.position = _icon_original_position

func _physics_process(_delta: float) -> void:
	if selected_icon.visible:
		_update_floating_icon()

## 更新选中图标的浮动效果
func _update_floating_icon() -> void:
	var offset: float = FLOAT_AMPLITUDE * sin(Time.get_ticks_msec() * FLOAT_FREQUENCY)
	selected_icon.position = _icon_original_position + Vector2(0, offset)

## 处理受击事件（转发给 CharacterFace）
func _handle_damage_event(event: RenderEvent) -> void:
	var player_id: int = event.config.get(&"player_id", 0)
	var hp_damage: int = event.config.get(&"hp_damage", 0)
	var mp_damage: int = event.config.get(&"mp_damage", 0)
	if hp_damage <= 0 and mp_damage <= 0:
		return
	if not item or not item.data:
		return
	if player_id != item.data.get_id():
		return
	if character:
		character.play_damage_animation(hp_damage, mp_damage)

## 重置卡面（用于回收复用）
func reset() -> void:
	super.reset()
	item = null
	_was_selected = false
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()
	if character and character.has_method(&"stop_damage_animation"):
		character.stop_damage_animation()
	_revert_selected_effects()
	# 确保最终状态与原始一致（动画可能未完成）
	character_container.position = _container_original_position
	character_container.size = _container_original_size
	properties.position = _properties_original_position
	properties.scale = _properties_original_scale
	selected_icon.visible = false
	selected_icon.position = _icon_original_position
	# 重置缓存变量
	_cached_hp = 0
	_cached_mp = 0
	_cached_player_id = 0
	_cached_properties.clear()
