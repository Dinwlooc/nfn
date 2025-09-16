extends RefCounted
class_name GlobalConstants

enum AreaType { HAND }
const AREA_TYPES = [&"HAND"]
enum CardType { NULL, CHARACTER, ATTACK } # 官方内置类型枚举
const CARD_TYPES = [&"null", &"character", &"attack"]

# 移除静态变量和映射方法，改为注册函数
static func register_to(registry: GlobalRegistry) -> void:
	# 注册CardType常量
	registry.register_constant(&"CardType", 
		CARD_TYPES, 
		CardType.size()
	)
	# 注册AreaType常量
	registry.register_constant(&"AreaType", 
		AREA_TYPES, 
		AreaType.size()
	)
