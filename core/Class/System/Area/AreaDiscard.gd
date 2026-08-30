## 弃牌区（无序区域），卡牌进入时清除所属玩家和物品状态
extends UnorderedArea
class_name AreaDiscard

func _init(_player: Player = Player.PUBLIC_PLAYER) -> void:
	super._init(_player)
	area_name = GlobalConstants.DefaultArea.DISCARD
	visibility = Visibility.INVISIBLE
	area_card_added.connect(_on_area_card_added)
## 回调：当卡牌添加时，清除其玩家和物品引用
## @signal-listener @exo
func _on_area_card_added(card: Card, _area: Area) -> void:
	card.clear_player()
	card.reset_item()
