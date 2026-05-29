## 属性修饰器配置项，用于 ItemData 中定义基础属性。
extends Resource
class_name AttributeData

## 属性名称（如 &"power"、&"HP_max"）
@export var attribute: StringName = &""
## 修饰值（浮点数，支持比例值如 1.5）
@export var value: float = 0.0
## 算术类型，对应 AttributeModifiers 中的常量：
## 0=TYPE_BASE_ADD, 1=TYPE_BASE_MULTIPLY, 2=TYPE_FINAL_ADD, 3=TYPE_FINAL_MULTIPLY
@export var arithmetic_type: int = 0
## 修饰器名称，默认为 &"base_value"
@export var modifier_name: StringName = &"base_value"
