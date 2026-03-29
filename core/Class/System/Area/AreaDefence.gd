extends OrderedArea
class_name AreaDefence

var settle_count: int = 0
var pending_card: Card = null

func _init_expand() -> void:
	area_name = GlobalConstants.DefaultArea.DEFENCE
	is_private_visible = false

func cards_add(cards:Array[Card]) -> void:
	if not cards:
		return
	if cards.size() > 1:
		super.cards_add(cards)
		return
	if pending_card:
		commit_pending_card()
	add_pending_card(cards[0])
	area_card_added.emit(pending_card,self)
# 添加缓冲槽卡牌（攻防中即将置入的斗牌）
func add_pending_card(card: Card) -> void:
	if pending_card:
		commit_pending_card()
	pending_card = card
	check_battle_formation()
# 移除缓冲槽卡牌（如被摧毁时调用）
func remove_pending_card() -> Card:
	var card:Card = pending_card
	pending_card = null
	return card
# 提交缓冲槽卡牌到牌堆顶部
func commit_pending_card() -> void:
	if pending_card:
		super.cards_add([pending_card])  # 调用基类同步方法
		pending_card = null
# 检查斗牌形成条件
func check_battle_formation() -> bool:
	var top: Card
	var sub: Card
	if pending_card:
		top = pending_card
		sub = get_top_card()
	else:
		top = get_top_card()
		sub = get_second_card()
	if top and sub and top.player != sub.player:
		return true
	return false
# 获取顶层牌
func get_top_card() -> Card:
	var cards:Array[Card] = get_all_cards()
	return cards[-1] if not cards.is_empty() else null

# 获取次层牌
func get_second_card() -> Card:
	var cards:Array[Card] = get_all_cards()
	return cards[-2] if cards.size() >= 2 else null

# 结算守区
func settle_defense_area() -> Array[Card]:
	settle_count += 1
	return get_all_cards()
## 仅重置结算次数（保留缓冲槽卡牌）
func reset_settle_count() -> void:
	settle_count = 0
# 重置守区状态（新攻防开始时调用）
func reset() -> void:
	settle_count = 0
	commit_pending_card()

func is_empty() -> bool:
	return ( not pending_card and _ordered_pool.is_empty())
