## 区域基类，所有具体区域（有序/无序）必须继承此类。
## 提供区域可见性、玩家归属、卡牌增删改查的抽象接口。
@abstract
extends RefCounted
class_name Area

#==枚举=======================================================================
## 区域可见性枚举
enum Visibility {
	PUBLIC,      ## 公共可见（所有玩家可见）
	PRIVATE,     ## 私有可见（仅所属玩家可见）
	INVISIBLE    ## 不可见（任何玩家都看不到，不传输任何变化）
}

#==属性=======================================================================
## 所属玩家（若为公共区域，则为 Player.PUBLIC_PLAYER）
var player: Player
## 区域名称（唯一标识）
var area_name: StringName
## 可见性，默认公开（实际派生类会覆写）
var visibility: Visibility = Visibility.PUBLIC

#==信号=======================================================================
## 卡牌添加时发射
## @emitter
signal area_card_added(new_cardpool: Card, area: Area)
## 卡牌移除时发射
## @emitter
signal area_card_removed(removed_cards: Card, area: Area)
## 卡牌批量移除完成后发射
## @emitter
signal after_cards_removed()

#==抽象方法===================================================================
## 添加卡牌
@abstract func cards_add(_new_cardpool: Array[Card]) -> void
## 按ID移除卡牌
@abstract func remove_cards_by_ids(_ids: PackedInt32Array) -> Array[Card]
## 卡牌总数
@abstract func card_count() -> int
## 按ID获取单张卡牌
## @nullable_pure
@abstract func get_card_by_id(_card_id: int) -> Card
## 获取所有卡牌
## @pure
@abstract func get_all_cards() -> Array[Card]
## 获取所有卡牌ID
## @pure
@abstract func get_card_ids() -> PackedInt32Array
## 按索引移除卡牌
@abstract func remove_cards_at_indices(_indices: PackedInt32Array) -> Array[Card]
## 移除顶部（或随机）N张卡牌
@abstract func remove_top_cards(_count: int) -> Array[Card]
## 按索引获取卡牌
@abstract func get_cards_at_indices(_indices: PackedInt32Array) -> Array[Card]
## 获取顶部（或随机）N张卡牌（不移除）
## @pure
@abstract func get_top_cards(_count: int) -> Array[Card]
## 判断区域是否为空
## @pure
@abstract func is_empty() -> bool

#==构造函数===================================================================
## @internal
func _init(_player: Player = Player.PUBLIC_PLAYER) -> void:
	player = _player
#==公开方法===================================================================
## 判断指定玩家是否可见此区域
## @pure
func is_visible_to(peer_id: int) -> bool:
	match visibility:
		Visibility.PUBLIC:
			# 公共区域对所有玩家可见（删除原冗余条件）
			return true
		Visibility.PRIVATE:
			return peer_id == player.peer_id
		Visibility.INVISIBLE:
			return false
	return false  # 不会到达
## 批量按ID获取卡牌（跳过不存在的）
## @pure
func get_cards_by_ids(ids: PackedInt32Array) -> Array[Card]:
	var result: Array[Card] = []
	for id in ids:
		var card = get_card_by_id(id)
		if card:
			result.append(card)
	return result
## 洗牌（默认空实现，子类按需重写）
## @internal
func shuffle_card_pool() -> void:
	pass
## 获取所属玩家
## @pure
func get_player() -> Player:
	return player
