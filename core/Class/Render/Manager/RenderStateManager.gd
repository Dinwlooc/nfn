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

# 主阶段状态
## 当前主阶段名
var main_stage_name: StringName = &""
## 主阶段归属玩家 id
var main_stage_player_id: int = PUBLIC_PLAYER_ID

# 临时阶段状态
## 当前临时阶段名
var temp_stage_name: StringName = &""
## 临时阶段行动玩家 id
var temp_turn_player_id: int = PUBLIC_PLAYER_ID
## 临时阶段归属玩家 id
var temp_stage_owner_id: int = PUBLIC_PLAYER_ID

## 拖拽信号
signal dragging_started(item: RenderItem)
## 拖拽被取消
## @emitter
signal dragging_canceled(item: RenderItem)

## 阶段通知信号（新）
signal main_stage_notified(stage_name: StringName, player_id: int, params: Dictionary)
## 临时阶段变更通知
## @emitter
signal temp_stage_notified(stage_name: StringName, turn_player_id: int, stage_owner_id: int, params: Dictionary)
## 群体攻击阶段通知（目标 / 待表态 / 威力 / 时机）
## @emitter
signal group_attack_notified(notify: RenderRequest.GroupAttackNotify)

## 群体攻击阶段状态快照（未处于该阶段时为 null）
var group_attack_state: RenderRequest.GroupAttackNotify = null

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
## 通知主阶段：临时阶段立即失效，发射主阶段信号
func notify_main_stage(stage_name: StringName, player_id: int, params: Dictionary = {}) -> void:
	main_stage_name = stage_name
	main_stage_player_id = player_id
	# 主阶段到来时，临时阶段逻辑上结束（状态清除）
	temp_stage_name = &""
	temp_turn_player_id = PUBLIC_PLAYER_ID
	temp_stage_owner_id = PUBLIC_PLAYER_ID
	# 群体攻击属于临时阶段，主阶段切换即失效
	group_attack_state = null
	main_stage_notified.emit(stage_name, player_id, params)
## 通知临时阶段：保留主阶段不变，发射临时阶段信号
func notify_temp_stage(stage_name: StringName, turn_player_id: int, stage_owner_id: int, params: Dictionary = {}) -> void:
	temp_stage_name = stage_name
	temp_turn_player_id = turn_player_id
	temp_stage_owner_id = stage_owner_id
	temp_stage_notified.emit(stage_name, turn_player_id, stage_owner_id, params)
## 通知群体攻击阶段：保存状态快照并广播；FINISHED 时清空快照（前端据信号收起展示）
func notify_group_attack(notify: RenderRequest.GroupAttackNotify) -> void:
	if not notify:
		return
	if notify.state == RenderRequest.GroupAttackNotify.State.FINISHED:
		group_attack_state = null
	else:
		group_attack_state = notify
	group_attack_notified.emit(notify)

## 取群体攻击阶段状态快照（未处于该阶段时返回 null）
func get_group_attack_state() -> RenderRequest.GroupAttackNotify:
	return group_attack_state

## 获取当前阶段所属玩家 ID（临时阶段优先）
func get_current_stage_name() -> StringName:
	return temp_stage_name if not temp_stage_name.is_empty() else main_stage_name

## 取当前阶段行动玩家 id（临时阶段优先）
func get_current_stage_player_id() -> int:
	if not temp_stage_name.is_empty():
		return temp_stage_owner_id
	return main_stage_player_id
