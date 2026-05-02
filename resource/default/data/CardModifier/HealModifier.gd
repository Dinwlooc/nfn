## 治疗修饰器：在【技能】阶段生效，治疗目标玩家4点生命与2点精神。
extends Modifier

## 修饰器处理入口，由 ModifierManager 在技能命令执行前调用。
## @param ctx     当前命令上下文（应为 SkillCommand.Context）
## @param state   全局游戏状态
## @param creator 附着此修饰器的卡牌实例
static func process(ctx: CommandContext, state: GameState, creator: Object) -> void:
	# 仅处理技能命令的技能阶段，并且是当前卡牌发动的技能
	if not RuleModifierTiming.is_skill_phase(ctx, creator):
		return
	var sctx: SkillCommand.Context = ctx as SkillCommand.Context
	if sctx.target_player_ids.is_empty():
		return
	# 获取源玩家 ID（卡牌拥有者）
	var source_player_id: int = 0
	if creator is Card:
		source_player_id = creator.get_owner_id()
	# 为每个目标玩家生成治疗命令（4生命，2精神）
	for target_id in sctx.target_player_ids:
		var target_player: Player = state.get_player_by_id(target_id)
		if not target_player:
			continue
		var heal_cmd := DamageCommand.new(
			target_player,
			-4,                     # 生命治疗量（负数）
			-2,                     # 精神治疗量（负数）
			DamageCommand.SourceMechanism.GENERAL,
			source_player_id
		)
		state.queue_behavior(heal_cmd)
