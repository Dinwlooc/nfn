extends RefCounted
class_name GlobalConstants

enum AreaType { HAND , PLAYERS }
const KEY_AREA_TYPE = &"AreaType"
const AREA_TYPES:Array[StringName] = [&"hand",&"players"]
enum CardType { NULL, CHARACTER, ATTACK } # 官方内置类型枚举
const CARD_TYPES:Array[StringName] = [&"null", &"character", &"attack"]
const KEY_CARD_TYPE = &"CardType"

# 移除静态变量和映射方法，改为注册函数
static func register_to(registry: GlobalRegistry) -> void:
	# 注册CardType常量
	registry.register_constant(KEY_CARD_TYPE, 
		CARD_TYPES, 
		CardType.size()
	)
	# 注册AreaType常量
	registry.register_constant(KEY_AREA_TYPE, 
		AREA_TYPES, 
		AreaType.size()
	)
