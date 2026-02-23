extends AreaFace

var character_position: Vector2
var _current_hp_damage: int = 0          # 当前正在播放的物理受击伤害值
var _current_tween: Tween = null         # 当前物理受击的 Tween 实例
@onready var backgound = $Backgound
@onready var backgound_character = $BackgoundCharacter
@onready var character_container = $BackgoundCharacter/CharacterContainer
@onready var character = $BackgoundCharacter/CharacterContainer/Character
func _ready() -> void:
	request_area(RenderArea.DefaultArea.PLAYERS)
	_setup_character_pivot.call_deferred()
	character_container.resized.connect(_update_character_pivot)

func _setup_character_pivot() -> void:
	_update_character_pivot()

func _update_character_pivot() -> void:
	character_container.pivot_offset = Vector2(
		character_container.size.x / 2.0,
		character_container.size.y
	)

func _connect_to_area(target_area: RenderArea) -> void:
	super._connect_to_area(target_area)
	if target_area is RenderAreaPlayers:
		target_area.local_player_received.connect(_on_local_player_received)

func _on_local_player_received(local_player: RenderItem) -> void:
	local_player.set_item_size($Backgound.size)

func render_update(_render_event: RenderEvent = RenderEvent.NULL_EVENT):
	character_position = position + $Backgound.position
	tween_update(_render_event)

func tween_update(_render_event: RenderEvent = RenderEvent.NULL_EVENT):
	if _render_event != RenderEvent.NULL_EVENT and _render_event.get_type() == RenderEvent.DefaultType.DAMAGED:
		_handle_damage_event(_render_event)
	card_move()

func _handle_damage_event(event: RenderEvent) -> void:
	const DAMAGE_REFERENCE: float = 20.0
	const MIN_ANGLE: float = 0.0
	const MAX_ANGLE: float = PI/16
	const MIN_DURATION: float = 0.04
	const MAX_DURATION: float = 0.2
	const MIN_BACK_DIST: float = 20.0
	const MAX_BACK_DIST: float = 100.0
	const MIN_DOWN_DIST: float = 5.0
	const MAX_DOWN_DIST: float = 25.0
	const RECOVER_X_FACTOR: float = 10.0
	const RECOVER_Y_FACTOR: float = 7.0
	const RECOVER_ROT_FACTOR: float = 5.0
	const TOTAL_TIME_FACTOR: float = 1.0 + RECOVER_X_FACTOR
	var player_id: int = event.config.get(&"player_id", 0)
	var hp_damage: int = event.config.get(&"hp_damage", 0)
	var mp_damage: int = event.config.get(&"mp_damage", 0)
	if area is not RenderAreaPlayers:
		return
	if area.local_player == null or player_id != area.local_player.get_id():
		return
	if hp_damage <= 0 and mp_damage <= 0:
		return
	var factor: float = clampf(hp_damage / DAMAGE_REFERENCE, 0.0, 1.0)
	var T: float = MIN_DURATION + (MAX_DURATION - MIN_DURATION) * factor
	var flash_duration: float = TOTAL_TIME_FACTOR * T
	if hp_damage > 0:
		if _current_tween != null and hp_damage >= _current_hp_damage:
			_current_tween.kill()
			_current_tween = null
			_current_hp_damage = 0
		if _current_tween == null:
			_current_hp_damage = hp_damage
			var angle: float = MIN_ANGLE + (MAX_ANGLE - MIN_ANGLE) * factor
			var back_dist: float = MIN_BACK_DIST + (MAX_BACK_DIST - MIN_BACK_DIST) * factor
			var down_dist: float = MIN_DOWN_DIST + (MAX_DOWN_DIST - MIN_DOWN_DIST) * factor
			_current_tween = create_tween()
			_current_tween.set_parallel(true)
			if character is Sprite2D:
				character.frame = 1  # 切换到受击帧
			_current_tween.tween_property(character_container, ^"position:x", back_dist, T).set_ease(Tween.EASE_OUT)
			_current_tween.tween_property(character_container, ^"position:y", down_dist, T).set_ease(Tween.EASE_IN_OUT)
			_current_tween.tween_property(character_container, ^"rotation", angle, T).set_ease(Tween.EASE_OUT)
			_current_tween.chain().tween_property(character_container, ^"position:x", 0.0, RECOVER_X_FACTOR * T).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_BACK)
			_current_tween.tween_property(character_container, ^"position:y", 0.0, RECOVER_Y_FACTOR * T).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_BACK)
			_current_tween.tween_property(character_container, ^"rotation", 0.0, RECOVER_ROT_FACTOR * T).set_ease(Tween.EASE_IN)
			_current_tween.chain().tween_callback(_on_physical_anim_finished)
		if character and character.material is ShaderMaterial:
			ShaderEffectsUtils.flash_color(character, Color.RED, flash_duration, 1.0)
	elif mp_damage > 0 and character and character.material is ShaderMaterial:
		ShaderEffectsUtils.flash_color(character, Color.BLUE, flash_duration, 1.0)
		if character is Sprite2D:
			character.frame = 1
		create_tween().tween_callback(func():
			if is_instance_valid(character) and character is Sprite2D:
				ShaderEffectsUtils.crossfade_sprite_frame(character, 0, 0.2)
		).set_delay(flash_duration)

func _on_physical_anim_finished() -> void:
	if character is Sprite2D:
		ShaderEffectsUtils.crossfade_sprite_frame(character, 0, 0.2)
	_current_hp_damage = 0
	_current_tween = null

func _into_area() -> void:
	area.render_requested.emit(RenderEvent.new(RenderEvent.DefaultType.INTO_AREA))
	pass

func _outto_area() -> void:
	area.render_requested.emit(RenderEvent.new(RenderEvent.DefaultType.OUTTO_AREA))

func card_move() -> void:
	if area.items_pool.size() == 0:
		return
	for i in range(0, area.items_pool.size()):
		var player: RenderItem = area.items_pool[i]
		if player.data.peer_id == multiplayer.get_unique_id():
			UIAnimationUtils.tween_animations(player, { ^"position": character_position }, 0.1)
