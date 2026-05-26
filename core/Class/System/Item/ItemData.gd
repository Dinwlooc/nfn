## 物品数据蓝图，作为共享只读资源，定义物品的静态属性和默认行为。
extends Resource
class_name ItemData

## 预置修饰器脚本列表，在物品初始化时加载并应用到 CommandModifiers
@export var modifiers: Array[Script] = []
## 属性默认值字典，键为属性名（StringName），值为基础数值（int）
@export var attribute_defaults: Dictionary[StringName, int] = {}
## 规则覆盖字典，用于覆盖游戏规则类的默认行为
@export var rule_overrides: Dictionary = {}
## 指定对应的 ItemPack 子类（用于序列化）
@export var pack_class: Script
