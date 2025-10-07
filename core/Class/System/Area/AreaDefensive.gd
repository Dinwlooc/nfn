extends Area
class_name AreaDefensive

signal battle_formed(top_card: Card, pending_card: Card)  # 斗牌形成时触发
var is_settled: bool = false  # 是否已结算
var pending_card: Card = null  # 缓冲槽中的斗牌

func _ready() -> void:
	# 监听卡牌移除事件以更新斗牌状态
	area_cards_remove.connect(_on_cards_removed)
# 卡牌移除时重新检查斗牌形成条件
func _on_cards_removed(_removed_cards: Array[Card]) -> void:
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
	var top = get_top_card()
	# 需满足：1) 顶层牌存在 2) 顶层牌是敌方牌 3) 缓冲卡未销毁
	if top and top.owner != pending_card.owner:
		emit_signal("battle_formed", top, pending_card)
# 获取顶层牌
func get_top_card() -> Card:
	var cards = get_all_cards()
	return cards[-1] if not cards.is_empty() else null
# 获取次层牌
func get_second_card() -> Card:
	var cards = get_all_cards()
	return cards[-2] if cards.size() >= 2 else null
# ================== 原子操作接口 ================== #
# 判断攻方能否出牌
func is_attackable(by_player: Player, card: Card) -> bool:
	if is_settled || by_player == player:
		return false
	var top = get_top_card()
	# 条件：1) 空置状态 2) 或顶层是己方防御牌
	if not top or (top.is_defense and top.owner == player):
		return card.is_attack or (card.is_skill and not card.is_mass)
	return false
# 判断守方能否出牌
func is_defendable(by_player: Player, card: Card) -> bool:
	if is_settled || by_player != player:
		return false
	var top = get_top_card()
	# 条件：顶层是敌方攻击牌
	return top and top.is_attack and top.owner != player and card.is_attack
# 判断是否可被攻击
func can_be_attacked() -> bool:
	return not is_settled
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
