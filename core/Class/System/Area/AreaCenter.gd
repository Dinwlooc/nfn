## 中央区（无序区域），存储待结算的卡牌，并记录技能目标玩家
extends UnorderedArea
class_name AreaCenter

#==属性=======================================================================
## 技能目标玩家列表（用于即将放入的技能卡牌） @context
var skill_target_players: Array[Player] = []

func _init(_player: Player = Player.PUBLIC_PLAYER) -> void:
	super._init(_player)
	area_name = GlobalConstants.DefaultArea.CENTER

#==公开方法===================================================================
## 设置技能目标玩家列表
## @internal
func set_skill_targets(players: Array[Player]) -> void:
	skill_target_players = players
## 清除技能目标
## @internal
func clear_skill_targets() -> void:
	skill_target_players = []
## 重写移除卡牌方法，当中心区变空时自动清除技能目标
## @override @internal
func remove_cards_by_ids(ids: PackedInt32Array) -> Array[Card]:
	var removed = super.remove_cards_by_ids(ids)
	if card_count() == 0:
		clear_skill_targets()
	return removed
