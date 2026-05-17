extends RefCounted
class_name GlobalConstants

enum AreaType { DRAWING, HAND, PLAYERS, STAGE, DEFENCE, DISCARD, CENTER }
const KEY_AREA_TYPE := &"AreaType"
const AREA_TYPES: Array[StringName] = [&"drawing", &"hand", &"players", &"stage", &"defence", &"discard", &"center"]

enum CardType { NULL, ATTACK, DEFENCE, SPELL }
const CARD_TYPES: Array[StringName] = [&"null", &"attack", &"defence", &"spell"]
const KEY_ITEM_TYPE := &"ItemType"

const PUBLIC_PLAYER_ID := 1

enum GameStage { NULL, START, DRAW, MAIN, DISCARD, END }

## 默认区域名称常量类
class DefaultArea:
	const HAND: StringName = &"hand"
	const PLAYERS: StringName = &"players"
	const DEFENCE: StringName = &"defence"
	const STAGE: StringName = &"stage"
	const DISCARD: StringName = &"discard"
	const DRAWING: StringName = &"drawing"
	const CENTER: StringName = &"center"
	const ABILITY: StringName = &"ability"

## 默认卡牌类型名称常量类
class DefaultCard:
	const NULL: StringName = &"null"
	const ATTACK: StringName = &"attack"
	const DEFENCE: StringName = &"defence"
	const SPELL: StringName = &"spell"

# 向动态常量集注册官方静态常量
static func register_to(registry: GlobalRegistry) -> void:
	registry.register_constant(KEY_ITEM_TYPE, CARD_TYPES, CardType.size())
	registry.register_constant(KEY_AREA_TYPE, AREA_TYPES, AreaType.size())
