extends Resource
class_name Card

@export var name:StringName
@export var type:StringName
var player:Player
var id:int
var area_name:StringName
var attributeModifiers:AttributeModifiers = AttributeModifiers.new()
var last_pack: CardPack = null

func get_attribute(attribute:StringName) -> int:
	return attributeModifiers.get_final_value(attribute)

func get_pack() -> CardPack:
	if last_pack == null:
		last_pack = _create_card_pack()
		last_pack.update_merge_mask()
	else:
		last_pack._update_and_calculate_delta(self)  # 传入 Card 实例
	return last_pack

func get_full_pack() -> CardPack:
	return _create_card_pack()

func _create_card_pack() -> CardPack:
	return CardPack.init_from_card(self)
## 当卡牌移动到牌堆里时使用它，以释放增量更新缓存的巨大占用
func clear_pack_cache() -> void:
	last_pack = null

func set_player(p_player:Player)->void:
	player = p_player

func get_player()->Player:
	return player

func clear_player()->void:
	player = Player.NULL_PLAYER
