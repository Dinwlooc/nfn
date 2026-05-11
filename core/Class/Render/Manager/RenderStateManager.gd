## 管理拖拽状态和阶段状态。
extends RefCounted
class_name RenderStateManager

class DragState:
	var area: RenderArea
	var card: RenderItem
const PUBLIC_PLAYER_ID: int = RenderContext.PUBLIC_PLAYER_ID
var card_on_drag: DragState = null
var current_stage_name: StringName = &""
var current_stage_player_id: int = PUBLIC_PLAYER_ID

## 拖拽开始/取消信号
signal dragging_started(item: RenderItem)
signal dragging_canceled(item: RenderItem)
## 阶段通知信号
signal stage_notified(stage_name: StringName, current_player_id: int, params: Dictionary)


## 拖拽管理
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

## 阶段管理
func notify_stage(stage_name: StringName, current_player_id: int, params: Dictionary = {}) -> void:
	current_stage_name = stage_name
	current_stage_player_id = current_player_id
	stage_notified.emit(stage_name, current_player_id, params)

func get_current_stage_name() -> StringName:
	return current_stage_name

func get_current_stage_player_id() -> int:
	return current_stage_player_id
