extends UnorderedArea
class_name AreaCenter
## 中央区。
## 技能目标玩家ID列表（用于即将放入的技能卡牌）
var skill_target_player_ids: PackedInt32Array = PackedInt32Array()

func _init(_player: Player = Player.PUBLIC_PLAYER) -> void:
	super._init(_player)
	area_name = GlobalConstants.DefaultArea.CENTER

## 设置技能目标玩家ID列表
func set_skill_targets(ids: PackedInt32Array) -> void:
	skill_target_player_ids = ids

## 清除技能目标
func clear_skill_targets() -> void:
	skill_target_player_ids = PackedInt32Array()

## 重写移除卡牌方法，当中心区变空时自动清除技能目标
func remove_cards_by_ids(ids: PackedInt32Array) -> Array[Card]:
	var removed = super.remove_cards_by_ids(ids)
	if card_count() == 0:
		clear_skill_targets()
	return removed
