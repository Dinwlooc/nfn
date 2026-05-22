## 管理拖拽状态和阶段状态。
extends RefCounted
class_name RenderStateManager

class DragState:
	var area: RenderArea
	var card: RenderItem

const PUBLIC_PLAYER_ID: int = GlobalConstants.PUBLIC_PLAYER_ID

var card_on_drag: DragState = null

# 主阶段状态
var main_stage_name: StringName = &""
var main_stage_player_id: int = PUBLIC_PLAYER_ID

# 临时阶段状态
var temp_stage_name: StringName = &""
var temp_turn_player_id: int = PUBLIC_PLAYER_ID
var temp_stage_owner_id: int = PUBLIC_PLAYER_ID

## 拖拽信号
signal dragging_started(item: RenderItem)
signal dragging_canceled(item: RenderItem)

## 阶段通知信号（新）
signal main_stage_notified(stage_name: StringName, player_id: int, params: Dictionary)
signal temp_stage_notified(stage_name: StringName, turn_player_id: int, stage_owner_id: int, params: Dictionary)

## 保留旧信号（兼容，不再被 StageFace 使用）
signal stage_notified(stage_name: StringName, current_player_id: int, params: Dictionary)

# ================= 拖拽管理 =================
func set_card_on_drag(area: RenderArea, realcard: RenderItem) -> void:
	remove_card_on_drag()
	card_on_drag = DragState.new()
	card_on_drag.area = area
	card_on_drag.card = realcard
	card_on_drag.card.dragged = true
	card_on_drag.area.tween_update(RenderEvent.new(RenderEvent.DefaultType.CARD_START_DRAGGING))
	dragging_started.emit(realcard)

func remove_card_on_drag() -> void:
	if not card_on_drag:
		return
	var card = card_on_drag.card
	card_on_drag.card.dragged = false
	card_on_drag.area.tween_update(RenderEvent.new(RenderEvent.DefaultType.CARD_CANCEL_DRAGGING))
	dragging_canceled.emit(card)
	card_on_drag = null

func get_dragged_area() -> RenderArea:
	return card_on_drag.area if card_on_drag else null

func get_dragged_card() -> RenderItem:
	return card_on_drag.card if card_on_drag else null

# ================= 阶段管理 =================
## 通知主阶段：临时阶段立即失效，发射主阶段信号
func notify_main_stage(stage_name: StringName, player_id: int, params: Dictionary = {}) -> void:
	main_stage_name = stage_name
	main_stage_player_id = player_id
	# 主阶段到来时，临时阶段逻辑上结束（状态清除）
	temp_stage_name = &""
	temp_turn_player_id = PUBLIC_PLAYER_ID
	temp_stage_owner_id = PUBLIC_PLAYER_ID
	main_stage_notified.emit(stage_name, player_id, params)
## 通知临时阶段：保留主阶段不变，发射临时阶段信号
func notify_temp_stage(stage_name: StringName, turn_player_id: int, stage_owner_id: int, params: Dictionary = {}) -> void:
	temp_stage_name = stage_name
	temp_turn_player_id = turn_player_id
	temp_stage_owner_id = stage_owner_id
	temp_stage_notified.emit(stage_name, turn_player_id, stage_owner_id, params)
## 获取当前阶段名称（临时阶段优先）
var current_stage_name: StringName:
	get:
		return temp_stage_name if not temp_stage_name.is_empty() else main_stage_name
## 获取当前阶段所属玩家 ID（临时阶段优先）
func get_current_stage_name() -> StringName:
	return temp_stage_name if not temp_stage_name.is_empty() else main_stage_name

func get_current_stage_player_id() -> int:
	if not temp_stage_name.is_empty():
		return temp_stage_owner_id
	return main_stage_player_id
