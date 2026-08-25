## 守区预览控制器：管理预览状态与延迟计时，并监听关联玩家选中变化。
extends RefCounted

const PREVIEW_DELAY_MS: int = 500

signal preview_state_changed(active: bool)
signal request_preview_start()


var preview_mode: bool = false
var _associated_player: RenderItem = null
var _preview_delay_start_ms: int = 0
var _is_processing: bool = false
var _render_context: RenderContext = null

## 设置渲染上下文（由主类注入）
func set_render_context(context: RenderContext) -> void:
	_render_context = context
	# 若已有关联玩家且上下文已存在，立即触发条件检查
	if _associated_player and _render_context:
		check_condition(_render_context)

## 设置关联玩家，自动连接/断开选中信号
func set_player(player: RenderItem) -> void:
	if _associated_player == player:
		return
	_disconnect_player_selection_signal()
	_associated_player = player
	_connect_player_selection_signal()
	# 立即触发检查（若有上下文）
	if _render_context:
		check_condition(_render_context)

## 获取关联玩家
func get_player() -> RenderItem:
	return _associated_player

## 设置 _process 状态
func set_processing_active(active: bool) -> void:
	_is_processing = active

## 每帧更新（由主类 _process 调用）
func update(delta: float) -> void:
	if _preview_delay_start_ms > 0:
		if Time.get_ticks_msec() - _preview_delay_start_ms >= PREVIEW_DELAY_MS:
			_preview_delay_start_ms = 0
			if not preview_mode:
				_activate_preview()
			return

## 由主类调用，传入 render_context 进行条件判断
func check_condition(render_context: RenderContext) -> void:
	var should_preview: bool = _should_preview(render_context)
	if should_preview and not preview_mode:
		if not _is_processing:
			_activate_preview()
	elif not should_preview and preview_mode:
		_deactivate_preview()

## 延迟进入预览
func trigger_delayed_preview(render_context: RenderContext) -> void:
	if not _should_preview(render_context):
		return
	if preview_mode:
		return
	preview_mode = false
	_preview_delay_start_ms = Time.get_ticks_msec()
	_is_processing = true
	request_preview_start.emit()

## 清理
func cleanup() -> void:
	_disconnect_player_selection_signal()
	preview_mode = false
	_preview_delay_start_ms = 0
	_is_processing = false
	_render_context = null

## 判断是否应该预览
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

func _activate_preview() -> void:
	preview_mode = true
	preview_state_changed.emit(true)
	request_preview_start.emit()

func _deactivate_preview() -> void:
	preview_mode = false
	_preview_delay_start_ms = 0
	_is_processing = false
	preview_state_changed.emit(false)
	request_preview_start.emit()

# ==================== 信号连接管理 ====================

func _connect_player_selection_signal() -> void:
	if not _associated_player:
		return
	if not _associated_player.selected_changed.is_connected(_on_player_selection_changed):
		_associated_player.selected_changed.connect(_on_player_selection_changed)

func _disconnect_player_selection_signal() -> void:
	if _associated_player and _associated_player.selected_changed.is_connected(_on_player_selection_changed):
		_associated_player.selected_changed.disconnect(_on_player_selection_changed)

func _on_player_selection_changed(selected: bool) -> void:
	if _render_context:
		check_condition(_render_context)
