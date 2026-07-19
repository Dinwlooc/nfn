extends RefCounted
class_name RuleModifierTiming

## 时机枚举
enum Timing {
	SETTLE_EFFECT,
	SUPPRESSING,
	BEING_SUPPRESSED,
	DUEL_START_FROM_BATTLE,
	DUEL_START_FROM_SETTLE,
	ANY_DUEL_START,
	DISCARD,
	PLAY,
	SKILL_PHASE,
}

## 统一检查方法
static func check(ctx: CommandContext, card: Card, timing: Timing) -> bool:
	match timing:
		Timing.SETTLE_EFFECT:
			return is_settle_effect(ctx, card)
		Timing.SUPPRESSING:
			return is_suppressing(ctx, card)
		Timing.BEING_SUPPRESSED:
			return is_being_suppressed(ctx, card)
		Timing.DUEL_START_FROM_BATTLE:
			return is_duel_start_from_battle(ctx, card)
		Timing.DUEL_START_FROM_SETTLE:
			return is_duel_start_from_settle(ctx, card)
		Timing.ANY_DUEL_START:
			return is_any_duel_start(ctx, card)
		Timing.DISCARD:
			return is_discard(ctx, card)
		Timing.PLAY:
			return is_play(ctx, card)
		Timing.SKILL_PHASE:
			return is_skill_phase(ctx, card)
		_:
			return false

## ----- 原有静态方法（保持不变）-----

static func is_settle_effect(ctx: CommandContext, card: Card) -> bool:
	if not (ctx is SettleCommand.Context):
		return false
	var sctx: SettleCommand.Context = ctx as SettleCommand.Context
	if sctx.phase != SettleCommand.Context.Phase.EFFECT:
		return false
	return sctx.get_settle_card() == card

static func is_suppressing(ctx: CommandContext, source_card: Card) -> bool:
	if not (ctx is BattleCommand.Context):
		return false
	var bctx: BattleCommand.Context = ctx as BattleCommand.Context
	if bctx.phase != BattleCommand.Context.Phase.PRE_DUEL:
		return false
	return bctx.top_card == source_card

static func is_being_suppressed(ctx: CommandContext, target_card: Card) -> bool:
	if not (ctx is BattleCommand.Context):
		return false
	var bctx: BattleCommand.Context = ctx as BattleCommand.Context
	if bctx.phase != BattleCommand.Context.Phase.PRE_DUEL:
		return false
	return bctx.second_card == target_card

static func is_duel_start_from_battle(ctx: CommandContext, _card: Card) -> bool:
	if not (ctx is DuelCommand.Context):
		return false
	var dctx: DuelCommand.Context = ctx as DuelCommand.Context
	if dctx.phase != DuelCommand.Context.Phase.INIT:
		return false
	return dctx.event_name == &"BattleCommand"

static func is_duel_start_from_settle(ctx: CommandContext, _card: Card) -> bool:
	if not (ctx is DuelCommand.Context):
		return false
	var dctx: DuelCommand.Context = ctx as DuelCommand.Context
	if dctx.phase != DuelCommand.Context.Phase.INIT:
		return false
	return dctx.event_name == &"Settle"

static func is_any_duel_start(ctx: CommandContext, _card: Card) -> bool:
	if not (ctx is DuelCommand.Context):
		return false
	var dctx: DuelCommand.Context = ctx as DuelCommand.Context
	return dctx.phase == DuelCommand.Context.Phase.INIT

static func is_discard(ctx: CommandContext, card: Card) -> bool:
	if not (ctx is DiscardCardsCommand.Context):
		return false
	var dctx: DiscardCardsCommand.Context = ctx as DiscardCardsCommand.Context
	if dctx.phase < CardMoveCommand.Context.Phase.MOVE_IN:
		return false
	if not dctx.get_moved_cards().has(card):
		return false
	return true

static func is_play(ctx: CommandContext, card: Card) -> bool:
	if not (ctx is PlayCardsCommand.Context):
		return false
	var pctx: PlayCardsCommand.Context = ctx as PlayCardsCommand.Context
	if pctx.phase < CardMoveCommand.Context.Phase.MOVE_IN:
		return false
	if not pctx.get_moved_cards().has(card):
		return false
	return true

static func is_skill_phase(ctx: CommandContext, card: Card) -> bool:
	if not (ctx is SkillCommand.Context):
		return false
	var sctx: SkillCommand.Context = ctx as SkillCommand.Context
	if sctx.phase != SkillCommand.Context.Phase.SKILL:
		return false
	return sctx.skill_card == card
