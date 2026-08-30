## 手牌区（无序区域），卡牌进入时设置所属玩家
extends UnorderedArea
class_name AreaHand

func _init(_player: Player = Player.PUBLIC_PLAYER) -> void:
	super._init(_player)
	area_name = GlobalConstants.DefaultArea.HAND
	visibility = Visibility.PRIVATE
	area_card_added.connect(_on_area_card_added)

## 回调：当卡牌添加时，设置所属玩家
## @signal_listener @external
func _on_area_card_added(card: Card, _area: Area) -> void:
	card.set_player(player)
