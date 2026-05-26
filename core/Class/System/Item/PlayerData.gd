## 玩家数据蓝图，定义玩家的静态属性和默认行为。
extends ItemData
class_name PlayerData

func _init() -> void:
	attribute_defaults = {
		&"HP_max": 20,
		&"MP_max": 20,
		&"init_AP": 3,
		&"draw_cards_count": 2,
		&"speed": 1,
	}
	modifiers = []
	rule_overrides = {}
	pack_class = PlayerPack
