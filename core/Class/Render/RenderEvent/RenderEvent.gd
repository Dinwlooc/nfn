extends RefCounted
class_name RenderEvent

# 配置字典，包含所有事件数据，包括类型
var config: Dictionary[StringName, Variant]
# 静态空事件（可保留，但需注意其 config 为空）
static var NULL_EVENT = RenderEvent.new()
# 官方事件类型常量（建议使用 StringName 避免字符串拷贝）
class DefaultType:
	const NULL = &"null"
	const INTO_AREA = &"into_area"
	const OUTTO_AREA = &"outto_area"
	const SELECT = &"select"
	const DAMAGED = &"damaged"
	const SWAP_CARD = &"swap_card"

# 构造函数：可传入初始 config 或直接指定类型（内部自动设置 config["type"]）
func _init(initial_data: Variant = null) -> void:
	config = {}
	if initial_data is Dictionary:
		config = initial_data.duplicate()
	elif initial_data is StringName:
		config[&"type"] = initial_data
# 获取事件类型（从 config 中读取）
func get_type() -> StringName:
	return config.get(&"type", DefaultType.NULL)
# 设置事件类型（链式调用）
func set_type(new_type: StringName) -> RenderEvent:
	config[&"type"] = new_type
	return self

func set_config(new_config:Dictionary[StringName,Variant])->RenderEvent:
	config = new_config
	return self
