## 手牌拖拽交换管理器：管理冷却、缓存和交换执行。
extends RefCounted

## 上次成功交换的毫秒时间戳
var last_swap_time_ms: int = 0
## 是否有等待中的交换请求（冷却期间缓存）
var pending_swap: bool = false

## 交换冷却持续时间（毫秒）
const SWAP_COOLDOWN_DURATION_MS: int = 300
## 允许缓存请求的延迟窗口（毫秒）
const SWAP_DELTA_MS: int = 70

## 判断是否可以立即交换（纯函数）
func can_swap_immediately(current_time_ms: int) -> bool:
	return current_time_ms - last_swap_time_ms >= SWAP_COOLDOWN_DURATION_MS

## 判断是否应该缓存交换请求（纯函数）
func should_cache_request(current_time_ms: int) -> bool:
	var time_since_last_ms: int = current_time_ms - last_swap_time_ms
	return time_since_last_ms > SWAP_DELTA_MS and time_since_last_ms < SWAP_COOLDOWN_DURATION_MS

## 尝试交换拖拽卡牌与悬停卡牌。返回是否成功交换。
func try_swap(drag_card: RenderItem, hovering_card: RenderItem, area: RenderArea, current_time_ms: int) -> bool:
	if not can_swap_immediately(current_time_ms):
		if should_cache_request(current_time_ms):
			pending_swap = true
		return false
	if not hovering_card:
		return false
	hovering_card.set_hovering(false)
	area.move_item_to_index(drag_card.pool_id, hovering_card.pool_id, RenderEvent.new(RenderEvent.DefaultType.SWAP_CARD))
	# 交换成功后重置悬停状态（由调用者负责清空hovering_card）
	last_swap_time_ms = current_time_ms
	return true

## 清除缓存请求（在成功执行缓存交换后调用）
func clear_pending() -> void:
	pending_swap = false
