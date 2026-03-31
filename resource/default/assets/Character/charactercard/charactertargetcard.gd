extends ItemFace

## 选中图标节点
@onready var selected_icon: TextureRect = $SelectedIcon
## 角色容器节点
@onready var character_container: Control = $CharacterContainer
## 角色背景节点
@onready var character_background: ColorRect = $CharacterContainer/BackgoundCharacter
## 角色属性节点
@onready var properties: AreaFace = $AreaFaceSelf_Properties
## 防御区域节点
@onready var area_defence: AreaFace = $AreaFaceDenfence
## 角色Sprite节点
@onready var character_sprite: Sprite2D = $CharacterContainer/Character

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

## 受击动画基准伤害（用于归一化因子）
const DAMAGE_REFERENCE: float = 20.0
## 受击最小/最大旋转弧度
const MIN_ANGLE: float = 0.0
const MAX_ANGLE: float = PI / 16
## 受击最小/最大后仰位移（像素）
const MIN_BACK_DIST: float = 20.0
const MAX_BACK_DIST: float = 100.0
## 受击最小/最大下压位移（像素）
const MIN_DOWN_DIST: float = 5.0
const MAX_DOWN_DIST: float = 25.0
## 受击最小/最大动画时长（秒）
const MIN_DURATION: float = 0.04
const MAX_DURATION: float = 0.2
## 恢复阶段时长系数（相对于T）
const RECOVER_X_FACTOR: float = 10.0
const RECOVER_Y_FACTOR: float = 7.0
const RECOVER_ROT_FACTOR: float = 5.0
## 总闪红时长系数（包含恢复）
const TOTAL_TIME_FACTOR: float = 1.0 + RECOVER_X_FACTOR

## 原始位置（用于还原）
var _icon_original_position: Vector2
## 原始大小（用于还原角色容器）
var _container_original_size: Vector2
## 原始位置（用于还原角色容器）
var _container_original_position: Vector2
## 背景原始位置
var _background_original_position: Vector2
## 背景原始大小
var _background_original_size: Vector2
## 属性节点的原始位置
var _properties_original_position: Vector2
## 属性节点的原始缩放
var _properties_original_scale: Vector2
## 角色Sprite的原始位置（相对容器）
var _character_original_position: Vector2
## 当前选中状态（缓存，用于避免重复更新）
var _was_selected: bool = false
## 当前选中动画tween引用
var _current_tween: Tween = null
## 受击动画当前伤害值（用于比较优先级）
var _current_hp_damage: int = 0
## 当前受击动画tween引用
var _current_tween_damage: Tween = null

## 缓存的HP值（用于检测损失）
var _cached_hp: int = 0
## 缓存的MP值（用于检测损失）
var _cached_mp: int = 0
## 缓存的玩家ID（用于伤害事件）
var _cached_player_id: int = 0
## 缓存的属性计算结果（留作扩展）
var _cached_properties: Dictionary = {}

func _ready() -> void:
	_icon_original_position = selected_icon.position
	_container_original_size = character_container.size
	_container_original_position = character_container.position
	_background_original_size = character_background.size
	_background_original_position = character_background.position
	_properties_original_position = properties.position
	_properties_original_scale = properties.scale
	_character_original_position = character_sprite.position

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
	# 创建伤害事件
	var event: RenderEvent = RenderEvent.new()
	event.set_type(RenderEvent.DefaultType.DAMAGED)
	event.config[&"player_id"] = _cached_player_id
	event.config[&"hp_damage"] = hp_damage
	event.config[&"mp_damage"] = mp_damage
	# 直接调用内部受击处理方法（不经过渲染上下文）
	_handle_damage_event(event)

## 刷新界面（根据数据重绘）
func _refresh_ui() -> void:
	if not item:
		return

## 渲染更新（由 render_context 触发）
func render_update(_render_event: RenderEvent = RenderEvent.NULL_EVENT) -> void:
	_update_selected_effects()
	if _render_event != RenderEvent.NULL_EVENT and _render_event.get_type() == RenderEvent.DefaultType.DAMAGED:
		_handle_damage_event(_render_event)
	super.render_update(_render_event)

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
	# 若受击动画正在播放，立即终止并清除状态，确保选中动画不受干扰
	if _current_tween_damage and _current_tween_damage.is_valid():
		_current_tween_damage.kill()
		_current_tween_damage = null
		_current_hp_damage = 0
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
	_current_tween.parallel().tween_property(character_container, ^"size", size / character_container.scale.x, SELECT_ANIMATION_DURATION)
	_current_tween.parallel().tween_property(character_background, ^"position", Vector2.ZERO, SELECT_ANIMATION_DURATION)
	_current_tween.parallel().tween_property(character_background, ^"size", size / character_background.scale.x, SELECT_ANIMATION_DURATION)
	_current_tween.parallel().tween_property(properties, ^"position", _properties_original_position + Vector2(PROPERTIES_SHIFT_X, 0), SELECT_ANIMATION_DURATION)
	_current_tween.parallel().tween_property(properties, ^"scale", _properties_original_scale * PROPERTIES_SCALE, SELECT_ANIMATION_DURATION)
	var final_container_size: Vector2 = size / character_container.scale.x
	var target_sprite_pos: Vector2 = Vector2(final_container_size.x * 0.5,final_container_size.y * 0.7)
	_current_tween.parallel().tween_property(character_sprite, ^"position", target_sprite_pos, SELECT_ANIMATION_DURATION)
	# 选中时确保 Sprite 旋转归零（若受击动画被打断可能残留旋转）
	_current_tween.parallel().tween_property(character_sprite, ^"rotation", 0.0, SELECT_ANIMATION_DURATION)
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
	_current_tween.parallel().tween_property(character_sprite, ^"position", _character_original_position, SELECT_ANIMATION_DURATION)
	# 取消选中时同样确保旋转归零
	_current_tween.parallel().tween_property(character_sprite, ^"rotation", 0.0, SELECT_ANIMATION_DURATION)
	selected_icon.visible = false
	selected_icon.position = _icon_original_position

func _physics_process(_delta: float) -> void:
	if selected_icon.visible:
		_update_floating_icon()

## 更新选中图标的浮动效果
func _update_floating_icon() -> void:
	var offset: float = FLOAT_AMPLITUDE * sin(Time.get_ticks_msec() * FLOAT_FREQUENCY)
	selected_icon.position = _icon_original_position + Vector2(0, offset)

## 处理受击事件（直接作用于 Sprite2D，并保留交叉渐变切换效果）
func _handle_damage_event(event: RenderEvent) -> void:
	# 卫语句：提取并验证事件参数
	var player_id: int = event.config.get(&"player_id", 0)
	var hp_damage: int = event.config.get(&"hp_damage", 0)
	var mp_damage: int = event.config.get(&"mp_damage", 0)
	if hp_damage <= 0 and mp_damage <= 0:
		return
	if not item or not item.data:
		return
	if player_id != item.data.get_id():
		return

	# 计算动画参数
	var factor: float = clampf(hp_damage / DAMAGE_REFERENCE, 0.0, 1.0)
	var T: float = MIN_DURATION + (MAX_DURATION - MIN_DURATION) * factor
	var flash_duration: float = TOTAL_TIME_FACTOR * T
	# HP 伤害处理（物理受击）
	if hp_damage > 0:
		# 若已有更严重的伤害正在播放，则跳过本次低优先级伤害
		if _current_tween_damage != null and hp_damage >= _current_hp_damage:
			_current_tween_damage.kill()
			_current_tween_damage = null
			_current_hp_damage = 0
		if _current_tween_damage == null:
			_current_hp_damage = hp_damage
			# 记录当前基准位置和旋转（受击开始时的状态）
			var base_pos: Vector2 = character_sprite.position
			var base_rot: float = 0
			# 根据伤害因子计算偏移量和旋转角
			var angle: float = MIN_ANGLE + (MAX_ANGLE - MIN_ANGLE) * factor
			var back_dist: float = MIN_BACK_DIST + (MAX_BACK_DIST - MIN_BACK_DIST) * factor
			var down_dist: float = MIN_DOWN_DIST + (MAX_DOWN_DIST - MIN_DOWN_DIST) * factor
			_current_tween_damage = create_tween()
			_current_tween_damage.set_parallel(true)
			# 受击帧切换
			if character_sprite is Sprite2D:
				character_sprite.frame = 1
			# 动画作用于 Sprite2D 自身（位移 + 旋转），基于基准值
			_current_tween_damage.tween_property(character_sprite, ^"position:x", base_pos.x + back_dist, T).set_ease(Tween.EASE_OUT)
			_current_tween_damage.tween_property(character_sprite, ^"position:y", base_pos.y + down_dist, T).set_ease(Tween.EASE_IN_OUT)
			_current_tween_damage.tween_property(character_sprite, ^"rotation", base_rot + angle, T).set_ease(Tween.EASE_OUT)
			# 恢复阶段（回到基准位置与旋转），并行执行
			_current_tween_damage.chain()
			_current_tween_damage.parallel().tween_property(character_sprite, ^"position:x", base_pos.x, RECOVER_X_FACTOR * T).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_BACK)
			_current_tween_damage.parallel().tween_property(character_sprite, ^"position:y", base_pos.y, RECOVER_Y_FACTOR * T).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_BACK)
			_current_tween_damage.parallel().tween_property(character_sprite, ^"rotation", base_rot, RECOVER_ROT_FACTOR * T).set_ease(Tween.EASE_IN)
			_current_tween_damage.chain().tween_callback(_on_physical_anim_finished)
		# 闪红效果（材质闪红）
		if character_sprite and character_sprite.material is ShaderMaterial:
			ShaderEffectsUtils.flash_color(character_sprite, Color.RED, flash_duration, 1.0)
	# MP 伤害处理（仅闪蓝，无位移旋转）
	elif mp_damage > 0 and character_sprite and character_sprite.material is ShaderMaterial:
		ShaderEffectsUtils.flash_color(character_sprite, Color.BLUE, flash_duration, 1.0)
		if character_sprite is Sprite2D:
			character_sprite.frame = 1
		create_tween().tween_callback(func():
			if is_instance_valid(character_sprite) and character_sprite is Sprite2D:
				ShaderEffectsUtils.crossfade_sprite_frame(character_sprite, 0, 0.2)
		).set_delay(flash_duration)

## 物理受击动画结束回调（交叉渐变切回正常帧）
func _on_physical_anim_finished() -> void:
	ShaderEffectsUtils.crossfade_sprite_frame(character_sprite, 0, 0.2)
	_current_hp_damage = 0
	_current_tween_damage = null

## 重置卡面（用于回收复用）
func reset() -> void:
	super.reset()
	item = null
	_was_selected = false
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()
	if _current_tween_damage and _current_tween_damage.is_valid():
		_current_tween_damage.kill()
	_revert_selected_effects()
	# 确保最终状态与原始一致（动画可能未完成）
	character_container.position = _container_original_position
	character_container.size = _container_original_size
	character_background.position = _background_original_position
	character_background.size = _background_original_size
	properties.position = _properties_original_position
	properties.scale = _properties_original_scale
	character_sprite.position = _character_original_position
	character_sprite.rotation = 0.0   # 重置旋转
	selected_icon.visible = false
	selected_icon.position = _icon_original_position
	_current_hp_damage = 0
	_current_tween_damage = null
	# 重置缓存变量
	_cached_hp = 0
	_cached_mp = 0
	_cached_player_id = 0
	_cached_properties.clear()
