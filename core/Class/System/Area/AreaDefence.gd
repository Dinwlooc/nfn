extends OrderedArea
class_name AreaDefence

signal battle_formed(top_card: Card, pending_card: Card)  # 斗牌形成时触发
var is_settled: bool = false  # 是否已结算
var pending_card: Card = null  # 缓冲槽中的斗牌

func _init_expand() -> void:
	area_name = GlobalConstants.DefaultArea.DEFENCE
	is_private_visible = false
	after_cards_removed.connect(_on_after_cards_removed)
# 卡牌移除时重新检查斗牌形成条件
func _on_after_cards_removed() -> void:
	check_battle_formation()
# 添加缓冲槽卡牌（攻防中即将置入的斗牌）
func add_pending_card(card: Card) -> void:
	if pending_card:
		push_warning("Pending card already exists, overwriting")
	pending_card = card
	check_battle_formation()
# 移除缓冲槽卡牌（如被摧毁时调用）
func remove_pending_card() -> Card:
	var card = pending_card
	pending_card = null
	return card
# 提交缓冲槽卡牌到牌堆顶部
func commit_pending_card() -> void:
	if pending_card:
		cards_add([pending_card])  # 调用基类同步方法
		pending_card = null
# 检查斗牌形成条件
func check_battle_formation() -> void:
	if not pending_card:
		return
	var top:Card = get_top_card()
	if top and top.owner != pending_card.owner:
		battle_formed.emit(top, pending_card)
# 获取顶层牌
func get_top_card() -> Card:
	var cards = get_all_cards()
	return cards[-1] if not cards.is_empty() else null
# 获取次层牌
func get_second_card() -> Card:
	var cards = get_all_cards()
	return cards[-2] if cards.size() >= 2 else null
# 结算完成标记
func mark_settled() -> void:
	is_settled = true
# 清空守区（结算结束时调用）
func clear_defense_area() -> Array[Card]:
	var ids = get_card_ids()
	return remove_cards_by_ids(ids)
# 重置守区状态
func reset() -> void:
	is_settled = false
	pending_card = null
func is_empty()->bool:
	return (!pending_card && _ordered_pool.is_empty())
