## 卡牌类，继承自 Item，整合原 Card 和 Card 的所有逻辑。
extends Item
class_name Card

signal area_changed(card: Card)
enum Suit {
	HEART,
	DIAMOND,
	SPADE,
	CLUB,
	VOID,
}
## 运行时可变的卡牌类型
var type: StringName
## 卡牌所在区域名称
var area_name: StringName
## 区域所属玩家 ID
var area_player_id: int
## 持有者玩家引用
var player: Player
## 花色（仅运行时分配，不由数据蓝图管理）
var suit: int = 0
## 构造函数，接收 CardData 蓝图
func _init(card_data: CardData = CardData.new()) -> void:
	super._init(card_data)
	type = card_data.type
## 链式设置花色
func set_suit(value: int) -> Card:
	suit = value
	return self
## 链式设置玩家
func set_player(p_player: Player) -> Card:
	player = p_player
	return self
## 链式清除玩家
func clear_player() -> Card:
	player = Player.NULL_PLAYER
	return self
## 获取卡牌名称（从蓝图读取，运行时不可变）
func get_name() -> StringName:
	return data.name
## 获取卡牌类型
func get_type() -> StringName:
	return type
## 设置卡牌类型（运行时可变）
func set_type(new_type: StringName) -> void:
	type = new_type
## 获取持有者玩家
func get_player() -> Player:
	return player
## 获取持有者 ID
func get_owner_id() -> int:
	if not player or player == Player.NULL_PLAYER:
		return 0
	return player.get_id()
## 获取花色
func get_suit() -> int:
	return suit
## 获取原始威力（从蓝图中的默认修饰器读取）
func get_base_power() -> int:
	return _get_base_attribute_value(&"power", 3)
## 获取原始消耗
func get_base_cost() -> int:
	return _get_base_attribute_value(&"cost", 1)
## 获取原始攻击范围
func get_base_attack_range() -> int:
	return _get_base_attribute_value(&"attack_range", 1)
## 获取原始结算伤害加成
func get_base_settlement_damage_bonus() -> int:
	return _get_base_attribute_value(&"settlement_damage_bonus", 0)
## 内部辅助：从 attribute_defaults 数组中提取指定属性且 modifier_name == "base_value" 的原始值
func _get_base_attribute_value(attr: StringName, fallback: int) -> int:
	for attr_data: AttributeData in data.attribute_defaults:
		if attr_data.attribute == attr and attr_data.modifier_name == &"base_value":
			return int(round(attr_data.value))
	return fallback
## 获取最终威力（包含所有修饰）
func get_power() -> int:
	return get_attribute(&"power")
## 获取最终消耗
func get_cost() -> int:
	return get_attribute(&"cost")
## 获取最终攻击范围
func get_attack_range() -> int:
	return get_attribute(&"attack_range")
## 计算最终结算伤害（复合修饰链）
func get_settlement_damage(damage_base: int = -1) -> int:
	if damage_base == -1:
		damage_base = get_power()
	var settlement_damage: int = attributeModifiers.compute_with_temporary_bonus(&"settlement_damage_bonus", float(damage_base))
	return settlement_damage
## 设置卡牌所在区域，仅当区域数据发生变化时才更新并发射 area_changed 信号
func set_area(area: Area) -> void:
	var new_area_name: StringName = area.area_name
	var new_area_player_id: int = area.get_player().get_id()
	if area_name == new_area_name and area_player_id == new_area_player_id:
		return
	area_name = new_area_name
	area_player_id = new_area_player_id
	area_changed.emit(self)
## 清除区域缓存（用于强制重建数据包）
func clear_area_cache() -> void:
	area_name = &""
	area_player_id = 0
## 供 CardsManager 在分配 ID 后调用，设置 BuffModifiers 所有者
func set_card_id(new_id: int) -> void:
	set_id(new_id)
## 返回物品类型标识
static func get_item_type() -> StringName:
	return &"card"
