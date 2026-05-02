## 中心区技能触发规则，判断卡牌应触发技能、群体攻击还是无效果
extends RefCounted
class_name RuleCenterSkill
## 触发类型枚举
enum TriggerType {
	NONE,           # 无效果
	SKILL,          # 触发技能
	GROUP_ATTACK,   # 触发群体攻击
}
## 默认规则：仅 SPELL 类型默认触发技能，其他类型默认无
static var _default_rules: Dictionary = {
	GlobalConstants.DefaultCard.SPELL: { &"trigger": TriggerType.SKILL },
}
## 获取卡牌的触发类型
## @param card 卡牌实例
## @return TriggerType 枚举值
static func get_trigger_type(card: Card) -> TriggerType:
	var overrides: Dictionary = card.get_rule_overrides()
	if overrides.has(&"center_skill_trigger"):
		var val = overrides[&"center_skill_trigger"]
		if val is int:
			return val as TriggerType
	var card_type: StringName = card.type
	if _default_rules.has(card_type):
		return _default_rules[card_type].get(&"trigger", TriggerType.NONE)
	return TriggerType.NONE
