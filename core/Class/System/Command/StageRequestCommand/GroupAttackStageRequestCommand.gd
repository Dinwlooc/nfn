## 请求启动群体攻击响应阶段（仅入栈，由 stage_manager 延迟启动）
## 时序纪律：目标快照必须在触发器回调里就做好并传进来——中央区被清空会清 skill_target_players，
## 等到 START_TEMP 时再取就已经是空的了。
extends StageRequestCommand
class_name GroupAttackStageRequestCommand

## 群体攻击阶段脚本（preload 规避新建 class_name 未进全局类缓存）
const StageGroupAttackScript := preload("res://core/Class/System/Stage/TempStage/StageGroupAttack.gd")

## @context
class Context extends StageRequestCommand.Context:
	## 群体攻击来源卡
	var source_card: Card
	## 攻击方玩家（来源卡持有者）
	var attacker: Player
	## 目标玩家快照
	var target_players: Array[Player] = []

## @seam_override
func _init(
	card: Card,
	attacker_player: Player,
	targets: Array[Player],
	name_overriding: StringName = &"RequestGroupAttackStage",
	context_overriding: Context = Context.new()
) -> void:
	super._init(attacker_player.get_id(), name_overriding, context_overriding)
	context_overriding.source_card = card
	context_overriding.attacker = attacker_player
	context_overriding.target_players = targets

## 静态初始化：过滤无效目标、去重、栈内同类型去重，并构造阶段实例
## @atomic
static func do_init(context: Context, game_state: GameState) -> void:
	if context.is_virtual:
		return
	if not context.source_card or not context.attacker:
		context.phase = Context.Phase.DONE
		return
	# 同一时刻只允许一个群体攻击阶段（用脚本比对，避免依赖尚未入全局类缓存的 class_name）
	for stage in game_state.stage_manager.temp_stage_stack:
		if stage and stage.get_script() == StageGroupAttackScript:
			context.phase = Context.Phase.DONE
			return
	var sanitized: Array[Player] = []
	for target: Player in context.target_players:
		if not target or target == context.attacker:
			continue
		if sanitized.has(target):
			continue
		sanitized.append(target)
	if sanitized.is_empty():
		context.phase = Context.Phase.DONE
		return
	context.target_players = sanitized
	context.stage = StageGroupAttackScript.new(context.source_card, context.attacker, sanitized)

## @hook
func _on_init_phase(game_state: GameState, context_overriding: CommandContext = _context as Context) -> void:
	do_init(context_overriding as Context, game_state)
