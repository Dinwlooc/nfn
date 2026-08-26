## 玩家状态面板（HP/MP/AP/士气），支持自动绑定本地玩家。
extends AreaFace

enum Mode { AUTO, MANUAL }
@export var mode: Mode = Mode.AUTO

const BlockIndicator = preload("block_indicator.gd")
const DotIndicator = preload("dot_indicator.gd")
const TextIconIndicator = preload("text_icon_indicator.gd")
const BreathAnimation = preload("breath_animation.gd")
const TremorAnimation = preload("tremor_animation.gd")
const ParticleManager = preload("ParticleManager.gd")
const StatusData = preload("status_data.gd")
const StatusUIUpdater = preload("status_ui_updater.gd")
const C = preload("status_constants.gd")

@onready var hp_indicator: BlockIndicator = $HPBar
@onready var mp_indicator: DotIndicator = $MPContainer
@onready var ap_indicator: TextIconIndicator = $APContainer
@onready var morale_indicator: BlockIndicator = $MoraleBar
@onready var morale_level_label: Label = $MoraleBar/ValueLabel
@onready var morale_value_label: RichTextLabel = $MoraleBar/MoraleValueLabel
@onready var particle_manager: ParticleManager = $ParticleManager

var _data: StatusData
var _ui_updater: StatusUIUpdater
var _current_player: RenderItem = null
var _cached_player_id: int = -1
var _initialized: bool = false
var _bleed_frame_counter: int = 0
var _bleed_interval: int = 0
var _bleed_active: bool = false

func _ready() -> void:
	request_area(RenderArea.DefaultArea.PLAYERS)
	_data = StatusData.new()
	_ui_updater = StatusUIUpdater.new(
		hp_indicator,
		mp_indicator,
		ap_indicator,
		morale_indicator,
		morale_level_label,
		morale_value_label,
		particle_manager
	)
	_data.hp_changed.connect(_ui_updater.on_hp_changed)
	_data.mp_changed.connect(_ui_updater.on_mp_changed)
	_data.ap_changed.connect(_ui_updater.on_ap_changed)
	_data.morale_changed.connect(_ui_updater.on_morale_changed)

func _process(delta: float) -> void:
	if not visible:
		return
	_ui_updater.process(delta)
	if not _bleed_active or _data.hp_current <= 0:
		_bleed_frame_counter = 0
		return
	_bleed_frame_counter += 1
	if _bleed_frame_counter % _bleed_interval != 0:
		return
	# 触发流血粒子效果
	var available: int = _data.hp_current
	var idx: int = randi_range(0, available - 1)
	var block: Panel = hp_indicator.blocks[idx]
	var dir: int = 1 if randf() > 0.5 else -1
	var pos_x: float = block.global_position.x + (block.size.x if dir == 1 else 0.0)
	var pos: Vector2 = Vector2(pos_x, block.global_position.y + block.size.y * 0.5)
	var ratio: float = float(_data.hp_current) / float(_data.hp_max) if _data.hp_max > 0 else 0.0
	particle_manager.emit_blood_bleed_single(pos, dir, ratio)

func _connect_to_area(target_area: RenderArea) -> void:
	super._connect_to_area(target_area)
	if not (target_area is RenderAreaPlayers):
		return
	if mode == Mode.AUTO:
		if not target_area.local_player_received.is_connected(_on_local_player_received):
			target_area.local_player_received.connect(_on_local_player_received)
		if target_area.local_player:
			_on_local_player_received(target_area.local_player)

func _disconnect_from_area(target_area: RenderArea) -> void:
	if target_area is RenderAreaPlayers:
		if target_area.local_player_received.is_connected(_on_local_player_received):
			target_area.local_player_received.disconnect(_on_local_player_received)
	super._disconnect_from_area(target_area)

func _on_local_player_received(local_player: RenderItem) -> void:
	set_player(local_player)

## 设置当前绑定的玩家（自动监听数据更新）
func set_player(player: RenderItem) -> void:
	if _current_player == player:
		return
	if _current_player:
		if _current_player.data_requested.is_connected(_on_player_data_requested):
			_current_player.data_requested.disconnect(_on_player_data_requested)
		_current_player = null
		_cached_player_id = -1
	_current_player = player
	if _current_player and _current_player.data is PlayerPack:
		if not _current_player.data_requested.is_connected(_on_player_data_requested):
			_current_player.data_requested.connect(_on_player_data_requested)
		_cached_player_id = _current_player.get_id()
		_update_cached_stats(_current_player.data)
	else:
		_clear_display()

func _on_player_data_requested(player: RenderItem) -> void:
	if player == _current_player and player and player.data is PlayerPack:
		_update_cached_stats(player.data)

## 更新统计数据，计算伤害并触发事件
func _update_cached_stats(player_data: PlayerPack) -> void:
	var old_hp = _data.hp_current if _initialized else 0
	var old_mp = _data.mp_current if _initialized else 0
	if not _initialized:
		_initialized = true
		_data.update_from_pack(player_data, true)
	else:
		_data.update_from_pack(player_data, false)
	if _initialized:
		var hp_damage = old_hp - _data.hp_current
		var mp_damage = old_mp - _data.mp_current
		if hp_damage != 0 or mp_damage != 0:
			_trigger_damage_event(hp_damage, mp_damage)
	_update_bleed_state()

func _clear_display() -> void:
	_ui_updater.on_clear_display()
	_initialized = false
	_bleed_active = false
	_data.hp_max = 0
	_data.hp_current = 0
	_data.mp_max = 0
	_data.mp_current = 0
	_data.ap_current = 0
	_data.ap_init_max = 0
	_data.morale_level = 0
	_data.morale_attack = 0
	_data.morale_defense = 0
	_data.morale_required = 0

## 向守区发送伤害事件（用于视觉反馈）
func _trigger_damage_event(hp_damage: int, mp_damage: int) -> void:
	if _cached_player_id == -1 or not render_context or not area:
		return
	var event: RenderEvent = RenderEvent.new().set_type(RenderEvent.DefaultType.DAMAGED)
	event.config[&"player_id"] = _cached_player_id
	event.config[&"hp_damage"] = hp_damage
	event.config[&"mp_damage"] = mp_damage
	area.tween_update(event)

## 根据血量比更新流血状态
func _update_bleed_state() -> void:
	if _data.hp_max <= 0:
		_bleed_active = false
		return
	var ratio: float = float(_data.hp_current) / float(_data.hp_max)
	if _data.hp_current > 0 and ratio <= 0.5:
		_bleed_active = true
		var t: float = ratio * 2.0
		_bleed_interval = int(lerp(float(C.BLEED_INTERVAL_AT_0), float(C.BLEED_INTERVAL_AT_50), t))
	else:
		_bleed_active = false
