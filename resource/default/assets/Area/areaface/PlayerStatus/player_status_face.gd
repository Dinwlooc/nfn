## 玩家状态面板（HP/MP/AP/士气），支持自动绑定本地玩家。
extends AreaFace

## 绑定模式：自动绑定本地玩家 / 手动指定
enum Mode { AUTO, MANUAL }
## 当前绑定模式
@export var mode: Mode = Mode.AUTO

## 生命/战意块指示器脚本
const BlockIndicator = preload("block_indicator.gd")
## 法力点指示器脚本
const DotIndicator = preload("dot_indicator.gd")
## 行动点图标指示器脚本
const TextIconIndicator = preload("text_icon_indicator.gd")
## 呼吸动画脚本
const BreathAnimation = preload("breath_animation.gd")
## 颤动动画脚本
const TremorAnimation = preload("tremor_animation.gd")
## 粒子管理器脚本
const ParticleManager = preload("ParticleManager.gd")
## 状态数据脚本
const StatusData = preload("status_data.gd")
## UI 更新器脚本
const StatusUIUpdater = preload("status_ui_updater.gd")
## 常量配置脚本
const C = preload("status_constants.gd")

## 生命条指示器
@onready var hp_indicator: BlockIndicator = $HPBar
## 法力点指示器
@onready var mp_indicator: DotIndicator = $MPContainer
## 行动点指示器
@onready var ap_indicator: TextIconIndicator = $APContainer
## 战意条指示器
@onready var morale_indicator: BlockIndicator = $MoraleBar
## 战意等级标签
@onready var morale_level_label: Label = $MoraleBar/ValueLabel
## 战意数值标签
@onready var morale_value_label: RichTextLabel = $MoraleBar/MoraleValueLabel
## 粒子管理器
@onready var particle_manager: ParticleManager = $ParticleManager

## 状态数据（从 PlayerPack 同步）
var _data: StatusData
## UI 更新器
var _ui_updater: StatusUIUpdater
## 当前绑定的玩家卡实例
var _current_player: RenderItem = null
## 当前绑定玩家的 id（-1 表示未绑定）
var _cached_player_id: int = -1
## 是否已完成首次数据同步
var _initialized: bool = false
## 流血粒子发射计数
var _bleed_frame_counter: int = 0
## 当前流血发射间隔（帧）
var _bleed_interval: int = 0
## 是否处于流血状态
var _bleed_active: bool = false

## 就绪：登记玩家区，创建数据与 UI 更新器并接线
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

## 每帧：驱动 UI 更新器；满足间隔时从当前血量块发出流血粒子
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

## 接入区域：AUTO 模式下监听本地玩家出现事件
## @override
func _connect_to_area(target_area: RenderArea) -> void:
	super._connect_to_area(target_area)
	if not (target_area is RenderAreaPlayers):
		return
	if mode == Mode.AUTO:
		if not target_area.local_player_received.is_connected(_on_local_player_received):
			target_area.local_player_received.connect(_on_local_player_received)
		if target_area.local_player:
			_on_local_player_received(target_area.local_player)

## 断开区域连接
## @override
func _disconnect_from_area(target_area: RenderArea) -> void:
	if target_area is RenderAreaPlayers:
		if target_area.local_player_received.is_connected(_on_local_player_received):
			target_area.local_player_received.disconnect(_on_local_player_received)
	super._disconnect_from_area(target_area)

## 本地玩家出现：自动绑定
func _on_local_player_received(local_player: RenderItem) -> void:
	set_player(local_player)
## 设置当前绑定的玩家（自动监听数据更新）
func set_player(player: RenderItem) -> void:
	if _current_player == player:
		return
	if _current_player:
		_current_player.data_requested.disconnect(_on_player_data_requested)
		_current_player = null
		_cached_player_id = -1
	_current_player = player
	if not _current_player or _current_player.data is not PlayerPack:
		_clear_display()
		return
	_current_player.data_requested.connect(_on_player_data_requested)
	_cached_player_id = _current_player.get_id()
	_update_cached_stats(_current_player.data)

## 绑定玩家的数据更新回调：重新同步并计算增减
func _on_player_data_requested(player: RenderItem) -> void:
	if player == _current_player and player and player.data is PlayerPack:
		_update_cached_stats(player.data)
## 更新统计数据，计算伤害并触发事件
func _update_cached_stats(player_data: PlayerPack) -> void:
	var old_hp = _data.hp_current if _initialized else 0
	var old_mp = _data.mp_current if _initialized else 0
	_data.update_from_pack(player_data, not _initialized)
	_initialized = true
	var hp_damage = old_hp - _data.hp_current
	var mp_damage = old_mp - _data.mp_current
	if hp_damage != 0 or mp_damage != 0:
		_trigger_damage_event(hp_damage, mp_damage)
	_update_bleed_state()

## 清空显示与内部统计
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
	if _data.hp_max <= 0 or _data.hp_current <= 0:
		_bleed_active = false
		return
	var ratio: float = float(_data.hp_current) / float(_data.hp_max)
	if ratio > 0.5:
		_bleed_active = false
		return
	_bleed_active = true
	var t: float = ratio * 2.0
	_bleed_interval = int(lerp(float(C.BLEED_INTERVAL_AT_0), float(C.BLEED_INTERVAL_AT_50), t))
