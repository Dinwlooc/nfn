## 玩家自己的角色面板，显示角色形象及伤害动画。
extends AreaFace

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

## 就绪：登记玩家区并接线尺寸/按钮回调
func _ready() -> void:
	request_area(RenderArea.DefaultArea.PLAYERS)
	_setup_character_pivot.call_deferred()
	character_container.resized.connect(_update_character_pivot)
	select_button.pressed.connect(_on_select_button_pressed)

## 进入区域：额外广播一次入区渲染请求
## @override
func _into_area() -> void:
	super._into_area()
	if area:
		area.render_requested.emit(RenderEvent.new(RenderEvent.DefaultType.INTO_AREA))

## 离开区域：额外广播一次出区渲染请求
## @override
func _outto_area() -> void:
	super._outto_area()
	if area:
		area.render_requested.emit(RenderEvent.new(RenderEvent.DefaultType.OUTTO_AREA))

## 延迟设置角色枢轴（等待容器尺寸就绪）
func _setup_character_pivot() -> void:
	_update_character_pivot()

## 把枢轴设到容器底部中心（便于缩放与受击动画）
func _update_character_pivot() -> void:
	character_container.pivot_offset = Vector2(
		character_container.size.x / 2.0,
		character_container.size.y
	)

## 接入区域：订阅本地玩家出现事件
## @override
func _connect_to_area(target_area: RenderArea) -> void:
	super._connect_to_area(target_area)
	if target_area is not RenderAreaPlayers:
		return
	if target_area.local_player:
		_on_local_player_received(target_area.local_player)
	if not target_area.local_player_received.is_connected(_on_local_player_received):
		target_area.local_player_received.connect(_on_local_player_received)

## 断开区域连接
## @override
func _disconnect_from_area(target_area: RenderArea) -> void:
	if target_area is RenderAreaPlayers:
		if target_area.local_player_received.is_connected(_on_local_player_received):
			target_area.local_player_received.disconnect(_on_local_player_received)
	super._disconnect_from_area(target_area)

## 本地玩家接收时设置卡片尺寸
func _on_local_player_received(local_player: RenderItem) -> void:
	local_player.set_item_size(background.size)

## 渲染更新：重算角色卡应处位置
## @override
func render_update(_render_event: RenderEvent = RenderEvent.NULL_EVENT) -> void:
	character_position = position + background.position
	tween_update(_render_event)

## 补间更新：处理伤害事件并移动角色卡
## @override
func tween_update(_render_event: RenderEvent = RenderEvent.NULL_EVENT) -> void:
	if _render_event.get_type() == RenderEvent.DefaultType.DAMAGED:
		_handle_damage_event(_render_event)
	card_move()

## 处理伤害事件（触发角色伤害动画）
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

## 将本地玩家卡片移动到角色位置
func card_move() -> void:
	if not area or area.items_pool.is_empty() or not area.local_player:
		return
	if area.local_player.position == character_position:
		return
	UIAnimationUtils.tween_animations(area.local_player, {^"position": character_position}, 0.1)

## 选择按钮：请求选中本地玩家
func _on_select_button_pressed() -> void:
	if area is RenderAreaPlayers and area.local_player:
		area.local_player.request_selecting()
