## 守区预览控制器：管理预览状态与延迟计时，并监听关联玩家选中变化。
extends RefCounted

const PREVIEW_DELAY_MS: int = 500

signal preview_state_changed(active: bool)
signal request_preview_start()

# ==================== 公开属性 ====================

var preview_mode: bool = false

# ==================== 私有成员 ====================

var _associated_player: RenderItem = null
var _preview_delay_start_ms: int = 0
var _is_processing: bool = false
var _render_context: RenderContext = null

# ==================== 公开方法 ====================

## 设置渲染上下文（由主类注入）
func set_render_context(context: RenderContext) -> void:
	_render_context = context
	if _associated_player and _render_context:
		check_condition(_render_context)

## 设置关联玩家，自动连接/断开选中信号
func set_player(player: RenderItem) -> void:
	if _associated_player == player:
		return
	# 断开旧追踪目标的信号
	_disconnect_player_selection_signal()
	_associated_player = player
	# 连接新目标的信号
	_connect_player_selection_signal()
	if _render_context:
		check_condition(_render_context)

## 获取关联玩家
func get_player() -> RenderItem:
	return _associated_player

## 设置 _process 状态（由主类调用）
func set_processing_active(active: bool) -> void:
	_is_processing = active

## 每帧更新（由主类 _process 调用），处理延迟启动预览
func update(_delta: float) -> void:
	if _preview_delay_start_ms <= 0:
		return
	if Time.get_ticks_msec() - _preview_delay_start_ms >= PREVIEW_DELAY_MS:
		_preview_delay_start_ms = 0
		if not preview_mode:
			_activate_preview()

## 由主类调用，传入 render_context 进行条件判断，决定激活/取消预览
func check_condition(render_context: RenderContext) -> void:
	var should_preview: bool = _should_preview(render_context)
	if should_preview and not preview_mode:
		if not _is_processing:
			_activate_preview()
	elif not should_preview and preview_mode:
		_deactivate_preview()

## 延迟进入预览（当首张卡牌加入时调用）
func trigger_delayed_preview(render_context: RenderContext) -> void:
	if not _should_preview(render_context):
		return
	if preview_mode:
		return
	preview_mode = false
	_preview_delay_start_ms = Time.get_ticks_msec()
	_is_processing = true
	request_preview_start.emit()

## 清理所有状态与信号
func cleanup() -> void:
	_disconnect_player_selection_signal()
	preview_mode = false
	_preview_delay_start_ms = 0
	_is_processing = false
	_render_context = null

# ==================== 私有方法 ====================

## 判断是否满足预览条件（玩家选中且 players 区域选择数为1）
func _should_preview(render_context: RenderContext) -> bool:
	if not _associated_player or not _associated_player.selected or not render_context:
		return false
	var players_area: RenderArea = render_context.get_render_area(
		RenderAreaPlayers.get_area_name_static(),
		RenderContext.PUBLIC_PLAYER_ID
	)
	if not players_area:
		return false
	return players_area.select_limit == 1

## 激活预览（发射信号）
func _activate_preview() -> void:
	preview_mode = true
	preview_state_changed.emit(true)
	request_preview_start.emit()

## 取消预览（发射信号）
func _deactivate_preview() -> void:
	preview_mode = false
	_preview_delay_start_ms = 0
	_is_processing = false
	preview_state_changed.emit(false)
	request_preview_start.emit()

## 连接玩家选中信号（追踪范式）
func _connect_player_selection_signal() -> void:
	if not _associated_player:
		return
	_associated_player.selected_changed.connect(_on_player_selection_changed)

## 断开玩家选中信号（追踪范式）
func _disconnect_player_selection_signal() -> void:
	if _associated_player:
		if _associated_player.selected_changed.is_connected(_on_player_selection_changed):
			_associated_player.selected_changed.disconnect(_on_player_selection_changed)

## 玩家选中状态变更回调（转发到 check_condition）
func _on_player_selection_changed(_selected: bool) -> void:
	if _render_context:
		check_condition(_render_context)
