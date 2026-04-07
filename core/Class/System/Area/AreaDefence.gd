extends OrderedArea
class_name AreaDefence

var settle_count: int = 0
signal battle_formation_detected(top_card: Card, second_card: Card)

## 初始化扩展
func _init_expand() -> void:
	area_name = GlobalConstants.DefaultArea.DEFENCE
	area_card_added.connect(_on_cards_changed)
	area_card_removed.connect(_on_cards_changed)

## 添加卡牌（直接调用基类，不再使用缓冲槽）
func cards_add(cards: Array[Card]) -> void:
	if cards.is_empty():
		return
	super.cards_add(cards)

## 移除卡牌（基类已发出信号，无需重写，但为了检测需保留信号连接）

## 检查并发出斗牌信号
func _check_and_emit_battle_formation() -> void:
	var top: Card = get_top_card()
	var second: Card = get_second_card()
	if top and second and top.player != second.player:
		battle_formation_detected.emit(top, second)

## 卡牌变化时的回调
func _on_cards_changed(_card: Card, _area: Area) -> void:
	_check_and_emit_battle_formation()

## 检查斗牌条件（供外部调用）
func check_battle_formation() -> bool:
	var top: Card = get_top_card()
	var second: Card = get_second_card()
	return top != null and second != null and top.player != second.player

## 获取顶层牌
func get_top_card() -> Card:
	var cards: Array[Card] = get_all_cards()
	return cards[-1] if not cards.is_empty() else null

## 获取次层牌
func get_second_card() -> Card:
	var cards: Array[Card] = get_all_cards()
	return cards[-2] if cards.size() >= 2 else null

## 结算守区
func settle_defense_area() -> void:
	settle_count += 1

## 仅重置结算次数
func reset_settle_count() -> void:
	settle_count = 0

## 重置守区状态
func reset() -> void:
	settle_count = 0
