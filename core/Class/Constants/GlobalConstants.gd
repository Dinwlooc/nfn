extends RefCounted
class_name GlobalConstants

## 区域类型序号
enum AreaType { DRAWING, HAND, PLAYERS, STAGE, DEFENCE, DISCARD, CENTER }
## 常量表键：区域类型
const KEY_AREA_TYPE := &"AreaType"
## 区域类型名表（下标与 AreaType 对应）
const AREA_TYPES: Array[StringName] = [&"drawing", &"hand", &"players", &"stage", &"defence", &"discard", &"center"]

## 卡牌类型序号
enum CardType { NULL, ATTACK, DEFENCE, SPELL }
## 卡牌类型名表（下标与 CardType 对应）
const CARD_TYPES: Array[StringName] = [&"null", &"attack", &"defence", &"spell"]
## 常量表键：物品类型
const KEY_ITEM_TYPE := &"ItemType"

## 公共玩家 id（非专有归属）
const PUBLIC_PLAYER_ID := 1

## 主阶段序号
enum GameStage { NULL, START, DRAW, MAIN, DISCARD, END }

## 默认区域名称常量类
class DefaultArea:
	## 手牌区
	const HAND: StringName = &"hand"
	## 玩家区
	const PLAYERS: StringName = &"players"
	## 守备区
	const DEFENCE: StringName = &"defence"
	## 阶段区
	const STAGE: StringName = &"stage"
	## 弃牌堆
	const DISCARD: StringName = &"discard"
	## 牌堆
	const DRAWING: StringName = &"drawing"
	## 中央区
	const CENTER: StringName = &"center"
	## 技能区
	const ABILITY: StringName = &"ability"

## 默认卡牌类型名称常量类
class DefaultCard:
	## 无类型
	const NULL: StringName = &"null"
	## 攻击牌
	const ATTACK: StringName = &"attack"
	## 防御牌
	const DEFENCE: StringName = &"defence"
	## 法术牌
	const SPELL: StringName = &"spell"

# 向动态常量集注册官方静态常量
## 把官方静态常量注册进动态常量表
## @side_effect
## @atomic
static func register_to(registry: GlobalRegistry) -> void:
	registry.register_constant(KEY_ITEM_TYPE, CARD_TYPES, CardType.size())
	registry.register_constant(KEY_AREA_TYPE, AREA_TYPES, AreaType.size())
