extends RefCounted
class_name RuleModifierTiming

## 结算效果阶段：守卫区结算效果阶段，且当前卡牌为结算牌
## @param ctx 命令上下文（应为 SettleCommand.Context）
## @param card 当前修饰器附着的卡牌
static func is_settle_effect(ctx: CommandContext, card: Card) -> bool:
	if not (ctx is SettleCommand.Context):
		return false
	var sctx: SettleCommand.Context = ctx as SettleCommand.Context
	if sctx.phase != SettleCommand.Context.Phase.EFFECT:
		return false
	return sctx.get_settle_card() == card

## 压制时：在斗牌初始化阶段，且当前卡牌为顶层牌（压制方）
static func is_suppressing(ctx: CommandContext, source_card: Card) -> bool:
	if not (ctx is BattleCommand.Context):
		return false
	var bctx: BattleCommand.Context = ctx as BattleCommand.Context
	if bctx.phase != BattleCommand.Context.Phase.INIT:
		return false
	return bctx.top_card == source_card

## 被压制时：在斗牌初始化阶段，且当前卡牌为次层牌（被压制方）
static func is_being_suppressed(ctx: CommandContext, target_card: Card) -> bool:
	if not (ctx is BattleCommand.Context):
		return false
	var bctx: BattleCommand.Context = ctx as BattleCommand.Context
	if bctx.phase != BattleCommand.Context.Phase.PRE_DUEL:
		return false
	return bctx.second_card == target_card

## 斗牌拼点开始：拼点命令的初始化阶段，且拼点由斗牌命令发起（可通过event_name判断）
static func is_duel_start_from_battle(ctx: CommandContext, _card: Card) -> bool:
	if not (ctx is DuelCommand.Context):
		return false
	var dctx: DuelCommand.Context = ctx as DuelCommand.Context
	if dctx.phase != DuelCommand.Context.Phase.INIT:
		return false
	return dctx.event_name == &"BattleCommand"

## 结算拼点开始：拼点命令的初始化阶段，且拼点由结算命令发起
static func is_duel_start_from_settle(ctx: CommandContext, _card: Card) -> bool:
	if not (ctx is DuelCommand.Context):
		return false
	var dctx: DuelCommand.Context = ctx as DuelCommand.Context
	if dctx.phase != DuelCommand.Context.Phase.INIT:
		return false
	return dctx.event_name == &"Settle"

## 任意拼点开始：拼点命令的初始化阶段
static func is_any_duel_start(ctx: CommandContext, _card: Card) -> bool:
	if not (ctx is DuelCommand.Context):
		return false
	var dctx: DuelCommand.Context = ctx as DuelCommand.Context
	return dctx.phase == DuelCommand.Context.Phase.INIT

## 弃牌时：当前命令为弃牌命令，且被弃的卡牌列表中包含当前卡牌
static func is_discard(ctx: CommandContext, card: Card) -> bool:
	if not (ctx is DiscardCardsCommand.Context):
		return false
	# DiscardCardsCommand 的阶段是继承自 CardMoveCommand，我们关心 MOVE_IN 之后
	# 但为简化，只要命令类型匹配且卡牌被移除即可，这里取 MOVE_IN 阶段后
	var dctx: DiscardCardsCommand.Context = ctx as DiscardCardsCommand.Context
	if dctx.phase < CardMoveCommand.Context.Phase.MOVE_IN:
		return false
	if not dctx.get_moved_cards().has(card):
		return false
	return true

## 打出时：当前命令为出牌命令，且被打出的卡牌列表中包含当前卡牌
static func is_play(ctx: CommandContext, card: Card) -> bool:
	if not (ctx is PlayCardsCommand.Context):
		return false
	var pctx: PlayCardsCommand.Context = ctx as PlayCardsCommand.Context
	if pctx.phase < CardMoveCommand.Context.Phase.MOVE_IN:
		return false
	if not pctx.get_moved_cards().has(card):
		return false
	return true
## 技能阶段：在技能命令的技能阶段，且当前卡牌为技能卡牌
static func is_skill_phase(ctx: CommandContext, card: Card) -> bool:
	if not (ctx is SkillCommand.Context):
		return false
	var sctx: SkillCommand.Context = ctx as SkillCommand.Context
	if sctx.phase != SkillCommand.Context.Phase.SKILL:
		return false
	return sctx.skill_card == card
