## 玩家自己的角色面板，显示角色形象及伤害动画。
extends AreaFace

@onready var character_container: CharacterFace = $BackgoundCharacter/CharacterContainer
@onready var character: Sprite2D = $BackgoundCharacter/CharacterContainer/Character
@onready var background: ColorRect = $Backgound
@onready var background_character: ColorRect = $BackgoundCharacter
@onready var select_button: Button = $SelectButton

var character_position: Vector2

func _ready() -> void:
	request_area(RenderArea.DefaultArea.PLAYERS)
	_setup_character_pivot.call_deferred()
	character_container.resized.connect(_update_character_pivot)
	select_button.pressed.connect(_on_select_button_pressed)

func _into_area() -> void:
	super._into_area()
	if area:
		area.render_requested.emit(RenderEvent.new(RenderEvent.DefaultType.INTO_AREA))

func _outto_area() -> void:
	super._outto_area()
	if area:
		area.render_requested.emit(RenderEvent.new(RenderEvent.DefaultType.OUTTO_AREA))

func _setup_character_pivot() -> void:
	_update_character_pivot()

func _update_character_pivot() -> void:
	character_container.pivot_offset = Vector2(
		character_container.size.x / 2.0,
		character_container.size.y
	)

func _connect_to_area(target_area: RenderArea) -> void:
	super._connect_to_area(target_area)
	if target_area is not RenderAreaPlayers:
		return
	if target_area.local_player:
		_on_local_player_received(target_area.local_player)
	if not target_area.local_player_received.is_connected(_on_local_player_received):
		target_area.local_player_received.connect(_on_local_player_received)

func _disconnect_from_area(target_area: RenderArea) -> void:
	if target_area is RenderAreaPlayers:
		if target_area.local_player_received.is_connected(_on_local_player_received):
			target_area.local_player_received.disconnect(_on_local_player_received)
	super._disconnect_from_area(target_area)

## 本地玩家接收时设置卡片尺寸
func _on_local_player_received(local_player: RenderItem) -> void:
	local_player.set_item_size(background.size)

func render_update(_render_event: RenderEvent = RenderEvent.NULL_EVENT) -> void:
	character_position = position + background.position
	tween_update(_render_event)

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

func _on_select_button_pressed() -> void:
	if area is RenderAreaPlayers and area.local_player:
		area.local_player.request_selecting()
