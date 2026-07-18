## 治疗修饰器：在【技能】阶段生效，治疗目标玩家4点生命与2点精神。
extends Modifier

@export var health_damage: int = 0
@export var mental_damage: int = 0

func process(ctx: CommandContext, state: GameState, command_bus: CommandBus, creator: Item) -> ModifierResult:
	if not RuleModifierTiming.is_skill_phase(ctx, creator):
		return ModifierResult.PASS
	var sctx: SkillCommand.Context = ctx as SkillCommand.Context
	if sctx.target_player_ids.is_empty():
		return ModifierResult.PASS
	var source_player_id: int = 0
	if creator is Card:
		source_player_id = creator.get_owner_id()
	for target_id in sctx.target_player_ids:
		var target_player: Player = state.get_player_by_id(target_id)
		if not target_player:
			continue
		var heal_cmd := DamageCommand.new(
			target_player,
			health_damage,
			mental_damage,
			DamageCommand.SourceMechanism.GENERAL,
			source_player_id
		)
		command_bus.queue_behavior(heal_cmd)
	return ModifierResult.WORK
