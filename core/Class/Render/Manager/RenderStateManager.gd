## 管理拖拽状态和阶段状态。
extends RefCounted
class_name RenderStateManager

## 拖拽状态快照
class DragState:
	## 拖拽起点区域
	var area: RenderArea
	## 被拖拽的卡牌
	var card: RenderItem

## 公共玩家 id
const PUBLIC_PLAYER_ID: int = GlobalConstants.PUBLIC_PLAYER_ID

## 当前拖拽中的卡牌状态
var card_on_drag: DragState = null

# 阶段状态
## 主阶段数据包（无则 null）
var main_stage: StagePack = null
## 临时阶段数据包栈：下标 0 为栈底，栈顶为当前临时阶段
var temp_stage_stack: Array[StagePack] = []

## 拖拽信号
signal dragging_started(item: RenderItem)
## 拖拽被取消
## @emitter
signal dragging_canceled(item: RenderItem)

## 阶段集合通知
## @emitter
signal stage_set_notified(stage_set: RenderRequest.StageSet)

# ================= 拖拽管理 =================
## 记录拖拽起点区域与卡牌
func set_card_on_drag(area: RenderArea, realcard: RenderItem) -> void:
	remove_card_on_drag()
	card_on_drag = DragState.new()
	card_on_drag.area = area
	card_on_drag.card = realcard
	card_on_drag.card.dragged = true
	card_on_drag.area.tween_update(RenderEvent.new(RenderEvent.DefaultType.CARD_START_DRAGGING))
	dragging_started.emit(realcard)

## 清除拖拽状态
func remove_card_on_drag() -> void:
	if not card_on_drag:
		return
	var card = card_on_drag.card
	card_on_drag.card.dragged = false
	card_on_drag.area.tween_update(RenderEvent.new(RenderEvent.DefaultType.CARD_CANCEL_DRAGGING))
	dragging_canceled.emit(card)
	card_on_drag = null

## 取拖拽起点区域
func get_dragged_area() -> RenderArea:
	return card_on_drag.area if card_on_drag else null

## 取被拖拽卡牌
func get_dragged_card() -> RenderItem:
	return card_on_drag.card if card_on_drag else null

# ================= 阶段管理 =================
## 通知阶段集合：按嵌套位点合并增量包，位于该位点之上的临时阶段视为已退出
## @side_effect @emitter
func notify_stage_set(stage_set: RenderRequest.StageSet) -> void:
	if not stage_set:
		return
	_merge_stage_pack(stage_set)
	stage_set_notified.emit(stage_set)

## 取当前阶段名（临时阶段优先，回退主阶段）
func get_current_stage_name() -> StringName:
	var top: StagePack = get_top_temp_stage()
	if top and not top.stage_name.is_empty():
		return top.stage_name
	return main_stage.stage_name if main_stage else &""

## 取当前阶段行动玩家 id（临时阶段取归属者，否则取主阶段玩家）
func get_current_stage_player_id() -> int:
	var top: StagePack = get_top_temp_stage()
	if top:
		return top.temporary_stage_player_id
	return main_stage.current_player_id if main_stage else PUBLIC_PLAYER_ID

## 取主阶段行动玩家 id
func get_main_stage_player_id() -> int:
	return main_stage.current_player_id if main_stage else PUBLIC_PLAYER_ID

## 取顶部临时阶段数据包（无则 null）
func get_top_temp_stage() -> StagePack:
	return temp_stage_stack[-1] if not temp_stage_stack.is_empty() else null

## 取指定临时阶段栈索引的数据包（越界返回 null）
func get_temp_stage(index: int) -> StagePack:
	if index < 0 or index >= temp_stage_stack.size():
		return null
	return temp_stage_stack[index]

## 取临时阶段归属玩家 id（无临时阶段时为 0）
func get_temp_stage_owner_id() -> int:
	var top: StagePack = get_top_temp_stage()
	return top.temporary_stage_player_id if top else 0

## 按嵌套位点合并阶段包
## @internal @side_effect
func _merge_stage_pack(stage_set: RenderRequest.StageSet) -> void:
	if RenderRequest.StageSet.is_main_site(stage_set.stage_site):
		main_stage = _merge_pack(main_stage, stage_set.pack)
		temp_stage_stack.clear()
		return
	var temp_index: int = RenderRequest.StageSet.temp_index_from_site(stage_set.stage_site)
	while temp_stage_stack.size() <= temp_index:
		temp_stage_stack.append(null)
	temp_stage_stack[temp_index] = _merge_pack(temp_stage_stack[temp_index], stage_set.pack)
	if temp_stage_stack.size() > temp_index + 1:
		temp_stage_stack.resize(temp_index + 1)

## 把更新包合并进缓存包（无缓存则新建）
## @internal
func _merge_pack(cached: StagePack, update_pack: StagePack) -> StagePack:
	var result: StagePack = cached if cached else StagePack.new()
	result.merge(update_pack)
	return result
