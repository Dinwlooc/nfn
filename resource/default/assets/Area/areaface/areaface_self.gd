## 玩家自己的角色面板：把角色卡对位到角色立绘位置，并把伤害事件转给角色受击动画。
extends AreaFace

#==vars==
## 角色形象容器
@onready var character_container: CharacterFace = $BackgoundCharacter/CharacterContainer
## 角色立绘
@onready var character: Sprite2D = $BackgoundCharacter/CharacterContainer/Character
## 角色背板
@onready var background: ColorRect = $Backgound
## 角色背板容器
@onready var background_character: ColorRect = $BackgoundCharacter
## 选择按钮
@onready var select_button: Button = $SelectButton
## 角色卡应处的全局位置
var character_position: Vector2
## 角色卡对位补间槽位
var layout_tween: Tween = null

#==consts==
## 角色卡对位补间时长（秒）
const CARD_MOVE_TIME: float = 0.1

#==lifecycle==
## 就绪：登记玩家区并接线尺寸/按钮回调。
## @override
func _ready() -> void:
	request_area(RenderArea.DefaultArea.PLAYERS)
	_setup_character_pivot.call_deferred()
	character_container.resized.connect(_update_character_pivot)
	select_button.pressed.connect(_on_select_button_pressed)

#==hooks==
## 进入区域：向区域广播一次入区渲染请求。
## @override
func on_into_area() -> void:
	if area:
		area.render_requested.emit(RenderEvent.new(RenderEvent.DefaultType.INTO_AREA))
## 离开区域：向区域广播一次出区渲染请求。
## @override
func on_outto_area() -> void:
	if area:
		area.render_requested.emit(RenderEvent.new(RenderEvent.DefaultType.OUTTO_AREA))
## 渲染更新：重算角色卡应处位置。
## @override
func render_update(render_event: RenderEvent = RenderEvent.NULL_EVENT) -> void:
	character_position = position + background.position
	tween_update(render_event)
## 补间更新：处理伤害事件并提交角色卡对位。
## @override
func tween_update(render_event: RenderEvent = RenderEvent.NULL_EVENT) -> void:
	if render_event.get_type() == RenderEvent.DefaultType.DAMAGED:
		_handle_damage_event(render_event)
	card_move()
## 区域接入：额外订阅本地玩家出现事件。
## @override @signal_listener
func _connect_to_area(target_area: RenderArea) -> void:
	super._connect_to_area(target_area)
	if target_area is not RenderAreaPlayers:
		return
	if target_area.local_player:
		_on_local_player_received(target_area.local_player)
	if not target_area.local_player_received.is_connected(_on_local_player_received):
		target_area.local_player_received.connect(_on_local_player_received)
## 区域断开：取消本地玩家监听后交给父类清理。
## @override @signal_listener
func _disconnect_from_area(target_area: RenderArea) -> void:
	if target_area is RenderAreaPlayers:
		if target_area.local_player_received.is_connected(_on_local_player_received):
			target_area.local_player_received.disconnect(_on_local_player_received)
	super._disconnect_from_area(target_area)

#==tween==
## 角色卡对位：把本地玩家卡补间到角色立绘位置；已在位时由卫语句拦住。
## @atomic
func card_move(_render_event: RenderEvent = RenderEvent.NULL_EVENT) -> void:
	if not area or area.items_pool.is_empty() or not area.local_player:
		return
	if area.local_player.position == character_position:
		return
	var tween: Tween = create_tween()
	do_card_align(tween, area.local_player, character_position)
	layout_tween = UIAnimationUtils.replace_tween(layout_tween, tween)
## 对位装配：单卡位移到目标。
## @atomic
static func do_card_align(tween: Tween, card: RenderItem, target_position: Vector2) -> void:
	tween.tween_property(card, ^"position", target_position, CARD_MOVE_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

#==internal==
## 延迟设置角色枢轴（等待容器尺寸就绪）
## @internal
func _setup_character_pivot() -> void:
	_update_character_pivot()
## 把枢轴设到容器底部中心（便于缩放与受击动画）
## @internal
func _update_character_pivot() -> void:
	character_container.pivot_offset = Vector2(
		character_container.size.x / 2.0,
		character_container.size.y
	)
## 本地玩家接收：设置卡片尺寸
## @signal_listener
func _on_local_player_received(local_player: RenderItem) -> void:
	local_player.set_item_size(background.size)
## 处理伤害事件（触发角色受击动画）
## @external
func _handle_damage_event(event: RenderEvent) -> void:
	var player_id: int = event.config.get(&"player_id", 0)
	var hp_damage: int = event.config.get(&"hp_damage", 0)
	var mp_damage: int = event.config.get(&"mp_damage", 0)
	if not area or not (area is RenderAreaPlayers) or area.local_player == null:
		return
	if player_id != area.local_player.get_id():
		return
	var player_data: PlayerPack = area.render_context.get_render_item_by_id(PlayerPack.get_class_name_static(), player_id).data
	var remaining_hp_ratio: float = float(player_data.HP) / float(player_data.modified_HP_max)
	if character_container:
		character_container.play_damage_animation(hp_damage, mp_damage, remaining_hp_ratio)
## 选择按钮：请求选中本地玩家
## @signal_listener
func _on_select_button_pressed() -> void:
	if area is RenderAreaPlayers and area.local_player:
		area.local_player.request_selecting()
