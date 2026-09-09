## 中心区技能触发规则，判断卡牌应触发技能、群体攻击还是无效果
@abstract
extends Rule
class_name RuleCenterSkill

## 验证器名称常量
## @deep_inherit
@abstract class Validator:
	const CENTER_SKILL_TRIGGER := &"center_skill_trigger"

## 触发类型枚举
enum TriggerType {
	NONE,           # 无效果
	SKILL,          # 触发技能
	GROUP_ATTACK,   # 触发群体攻击
}
## 默认规则：仅 SPELL 类型默认触发技能，其他类型默认无
static var _default_rules: Dictionary[StringName,Variant] = {
	GlobalConstants.DefaultCard.SPELL: { Validator.CENTER_SKILL_TRIGGER: TriggerType.SKILL },
}
## 获取卡牌的触发类型
## @param card 卡牌实例
## @return TriggerType 枚举值
static func get_trigger_type(card: Card) -> TriggerType:
	var card_type := card.type
	var base_value := TriggerType.NONE
	if _default_rules.has(card_type):
		base_value = _default_rules[card_type].get(Validator.CENTER_SKILL_TRIGGER, TriggerType.NONE)
	return Rule.get_rule_value(
		{ Validator.CENTER_SKILL_TRIGGER: base_value },
		card.get_rule_overrides() if card else {},
		{},
		Validator.CENTER_SKILL_TRIGGER,
		TriggerType.NONE
	) as TriggerType
