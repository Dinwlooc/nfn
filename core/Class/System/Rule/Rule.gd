## 规则基类，提供通用的规则合并和查询逻辑。
## 支持所有 Item 子类（含 Card、Player 等）的规则覆盖。
@abstract
extends Object
class_name Rule

# ## 子类需要定义该内部类。
# ## @deep_inherit
# @abstract class Validator

## 合并多个规则字典，按优先级合并（优先级：extra > item_overrides > base）。
## 仅保留 allowed_keys 列表中的键，其他键忽略。
## @param base 基础规则字典
## @param item_overrides 物品自身的覆盖规则（来自 Item.get_rule_overrides()）
## @param extra_overrides 额外覆盖（如调用方传入）
## @param allowed_keys 允许合并的键列表，空数组表示不过滤（保留所有键）
## @return 合并后的新字典
static func merge_rules(
	base: Dictionary[StringName, Variant],
	item_overrides: Dictionary[StringName, Variant],
	extra_overrides: Dictionary[StringName, Variant],
	allowed_keys: Array[StringName] = []
) -> Dictionary[StringName, Variant]:
	var merged: Dictionary[StringName, Variant] = base.duplicate()
	if allowed_keys.is_empty():
		# 不过滤，直接覆盖
		for key in item_overrides:
			merged[key] = item_overrides[key]
		for key in extra_overrides:
			merged[key] = extra_overrides[key]
	else:
		for key in item_overrides:
			if key in allowed_keys:
				merged[key] = item_overrides[key]
		for key in extra_overrides:
			if key in allowed_keys:
				merged[key] = extra_overrides[key]
	return merged

## 获取单个规则键的最终值，按优先级查询。
## 适用于只需要一个键的场景，避免构建完整字典。
## @param base 基础规则字典
## @param item_overrides 物品自身的覆盖规则
## @param extra_overrides 额外覆盖
## @param key 要查询的键
## @param default 当所有字典均无该键时返回的默认值
## @return 最终值
static func get_rule_value(
	base: Dictionary[StringName, Variant],
	item_overrides: Dictionary[StringName, Variant],
	extra_overrides: Dictionary[StringName, Variant],
	key: StringName,
	default_value: Variant = null
) -> Variant:
	if key in extra_overrides:
		return extra_overrides[key]
	if key in item_overrides:
		return item_overrides[key]
	return base.get(key, default_value)

## 获取完整的规则配置字典（便捷方法，常用于多键场景）。
## 自动从 Item 获取覆盖，并与基础规则、额外覆盖合并。
## @param item 任意 Item 子类实例（如 Card、Player），可为 null
## @param base_rules 基础规则字典
## @param allowed_keys 允许合并的键列表，空表示不过滤
## @param extra_overrides 额外覆盖字典（优先级最高）
## @return 合并后的最终规则字典
static func get_rule_config(
	item: Item,
	base_rules: Dictionary[StringName, Variant],
	allowed_keys: Array[StringName] = [],
	extra_overrides: Dictionary[StringName, Variant] = {}
) -> Dictionary[StringName, Variant]:
	var item_overrides := item.get_rule_overrides() if item else {}
	return merge_rules(base_rules, item_overrides, extra_overrides, allowed_keys)
