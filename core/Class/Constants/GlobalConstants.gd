extends RefCounted
class_name GlobalConstants

enum AreaType {DRAWING , HAND , PLAYERS ,STAGE ,DEFENCE,DISCARD}
const KEY_AREA_TYPE = &"AreaType"
const AREA_TYPES:Array[StringName] = [&"drawing",&"hand",&"players",&"stage",&"defence",&"discard"]
enum CardType { NULL, ATTACK ,DEFENCE,SPELL} # 官方内置类型枚举
const CARD_TYPES:Array[StringName] = [&"null",&"attack",&"defence",&"spell"]
const KEY_ITEM_TYPE = &"ItemType"
enum GameStage { NULL, START, DRAW, MAIN, DISCARD, END }

class DefaultArea:
	const HAND:StringName = &"hand"
	const PLAYERS:StringName = &"players"
	const DEFENCE:StringName =  &"defence"
	const STAGE:StringName = &"stage"
	const DISCARD:StringName = &"discard"

const OP_PLAY_CARD: StringName = &"play_card"
const OP_END_TURN: StringName = &"end_turn"
const OP_USE_SKILL: StringName = &"use_skill"
const OP_DISCARD: StringName = &"discard"
const OP_CONFIRM: StringName = &"confirm"

# 向动态常量集注册官方静态常量
static func register_to(registry: GlobalRegistry) -> void:
	registry.register_constant(KEY_ITEM_TYPE,
		CARD_TYPES,
		CardType.size()
	)
	registry.register_constant(KEY_AREA_TYPE,
		AREA_TYPES,
		AreaType.size()
	)
