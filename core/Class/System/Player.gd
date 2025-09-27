extends RefCounted
class_name Player

var peer_id: int = 0       # 对等体ID (0=AI)
var player_id: int = 0     # 玩家ID (唯一标识)
var seat_index: int = -1
var HP_max: int#玩家生命上限
var HP: int #玩家当前生命
var AP: int #玩家当前的行动点
var init_AP:int = 3
var draw_cards_count = 2
var area_hand:AreaHand = AreaHand.new(self)
var area_ability:AreaAbility = AreaAbility.new(self)
var area_defensive:AreaDefensive = AreaDefensive.new(self)
var attributeModifiers:AttributeModifiers = AttributeModifiers.new()
