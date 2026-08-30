## 守区（有序区域），检测斗牌条件并发射信号
extends OrderedArea
class_name AreaDefence

#==属性=======================================================================
## 结算计数 @context
var settle_count: int = 0

#==信号=======================================================================
## 检测到斗牌时发射
## @emitter
signal battle_formation_detected(top_card: Card, second_card: Card)

#==构造函数===================================================================
func _init(_player: Player = Player.PUBLIC_PLAYER) -> void:
	super._init(_player)
	area_name = GlobalConstants.DefaultArea.DEFENCE
	# 连接自身信号监听 @signal_listener
	area_card_added.connect(_on_cards_changed)
	area_card_removed.connect(_on_cards_changed)

#==公开方法（重写）===========================================================
## 添加卡牌
## @override @internal
func cards_add(cards: Array[Card]) -> void:
	if cards.is_empty():
		return
	super.cards_add(cards)
## 检查斗牌条件
## @pure
func check_battle_formation() -> bool:
	var top: Card = get_top_card()
	var second: Card = get_second_card()
	return top != null and second != null and top.player != second.player
## 获取顶层牌
## @nullable_pure
func get_top_card() -> Card:
	var cards: Array[Card] = get_all_cards()
	return cards[-1] if not cards.is_empty() else null
## 获取次层牌（可能返回 null）
## @nullable_pure
func get_second_card() -> Card:
	var cards: Array[Card] = get_all_cards()
	return cards[-2] if cards.size() >= 2 else null
## 结算守区
## @internal
func settle_defense_area() -> void:
	settle_count += 1
## 仅重置结算次数
## @internal
func reset_settle_count() -> void:
	settle_count = 0
## 重置守区状态
## @internal
func reset() -> void:
	settle_count = 0

#==信号监听回调===============================================================
## 卡牌变化时检查斗牌
## @signal_listener
func _on_cards_changed(_card: Card, _area: Area) -> void:
	_check_and_emit_battle_formation()
## 检查并发射斗牌信号
## @emitter
func _check_and_emit_battle_formation() -> void:
	var top: Card = get_top_card()
	var second: Card = get_second_card()
	if top and second and top.player != second.player:
		battle_formation_detected.emit(top, second)
