## 群体攻击命令：对若干目标玩家依次结算（威力 - 响应牌威力）的生命伤害与精神伤害
## 来源：中央区中由不指定目标的技能牌生成（RuleCenterSkill.TriggerType.GROUP_ATTACK）
## 响应：每个目标至多一张响应牌，按响应牌威力同时削减本次生命伤害与精神伤害；未响应即单方面攻击
## 结算：先对所有目标依次造成伤害，再把响应牌移入弃牌区
extends BehaviorCommand
class_name GroupAttackCommand

## @context
class Context extends CommandContext:
	## 群体攻击命令的三阶段状态
	enum Phase { INIT, RESOLVE, DONE }
	## 群体攻击来源卡牌（中央区技能牌）
	var source_card: Card
	## 目标玩家列表，顺序即结算顺序
	var target_players: Array[Player] = []
	## 目标玩家 id → 响应牌；未响应的目标不在表中
	var response_cards: Dictionary[int, Card] = {}
	## INIT 阶段缓存的威力（已含卡牌修饰）
	var cached_power: int = 0
	## INIT 阶段缓存的生命伤害，与 target_players 同序
	var cached_health_damages: PackedInt32Array = PackedInt32Array()
	## INIT 阶段缓存的精神伤害，与 target_players 同序
	var cached_mental_damages: PackedInt32Array = PackedInt32Array()

	## 链式设置来源卡、目标与响应牌
	func set_group_attack(card: Card, targets: Array[Player], responses: Dictionary[int, Card]) -> Context:
		source_card = card
		target_players = targets
		response_cards = responses
		return self

	## 链式登记单个目标的响应牌
	func set_response_card(player_id: int, card: Card) -> Context:
		if card:
			response_cards[player_id] = card
		return self

	## 取目标玩家的响应牌；未响应返回 null
	## @nullable_pure
	func get_response_card(player_id: int) -> Card:
		return response_cards.get(player_id)

	## 来源卡与全部响应牌参与修饰
	## @hook @override
	func get_primary_modifier_cards() -> Array[Card]:
		var cards: Array[Card] = []
		if source_card:
			cards.append(source_card)
		for card: Card in response_cards.values():
			if card and not cards.has(card):
				cards.append(card)
		return cards

	## 来源卡持有者与全部目标玩家参与修饰
	## @hook @override
	func get_primary_modifier_players() -> Array[Player]:
		var players: Array[Player] = []
		if source_card and source_card.player and source_card.player != Player.PUBLIC_PLAYER:
			players.append(source_card.player)
		for target: Player in target_players:
			if target and not players.has(target):
				players.append(target)
		return players

## 信号：群体攻击结算完成（逐目标实际生命/精神伤害，与 target_ids 同序）
## @emitter
signal group_attack_resolved(power: int, target_ids: PackedInt32Array, health_damages: PackedInt32Array, mental_damages: PackedInt32Array)

## @internal @seam_override
func _init(
	card: Card,
	targets: Array[Player] = [],
	responses: Dictionary[int, Card] = {},
	name_overriding: StringName = &"GroupAttack",
	context_overriding: Context = Context.new()
) -> void:
	context_overriding.set_group_attack(card, targets, responses)
	var owner_id: int = 0
	if card:
		owner_id = card.get_owner_id()
	super._init(owner_id, name_overriding, context_overriding)

## @facade @template
func execute(game_state: GameState) -> void:
	var ctx: Context = _context as Context
	match ctx.phase:
		Context.Phase.INIT:
			ctx.phase = Context.Phase.RESOLVE
			_on_init_phase(game_state, ctx)
		Context.Phase.RESOLVE:
			ctx.phase = Context.Phase.DONE
			_on_resolve_phase(game_state, ctx)
		Context.Phase.DONE:
			_on_done_phase(game_state, ctx)

## 准备阶段：缓存威力与每个目标的实际伤害
## @hook @operation(do_prepare)
func _on_init_phase(game_state: GameState, context_overriding: Context = _context as Context) -> void:
	if context_overriding.source_card == null:
		# fail() 只写 context 的完成标记，命令自身仍需 complete()，否则不会被弹出
		context_overriding.phase = Context.Phase.DONE
		BehaviorCommand.fail(context_overriding, "群体攻击来源卡为空")
		complete()
		return
	do_prepare(context_overriding, game_state)

## 结算阶段：追加每个目标的伤害命令与响应牌的弃置命令
## 栈为后进先出，故先追加弃置、再逆序追加伤害，使伤害按目标顺序先执行
## @hook @operation(schedule_disposals,schedule_damages) @delegates(append_companion_command)
func _on_resolve_phase(game_state: GameState, context_overriding: Context = _context as Context) -> void:
	schedule_card_disposals(context_overriding, game_state)
	# 弃置校验失败时不得继续算伤害：否则响应牌没进弃牌区却已按它的威力减免
	if not context_overriding.error.is_empty():
		return
	schedule_damages(context_overriding)

## 完成阶段：非虚拟执行时发出结算信号，然后完成命令
## @hook @delegates(complete)
func _on_done_phase(_game_state: GameState, context_overriding: Context = _context as Context) -> void:
	if not context_overriding.is_virtual:
		_emit_resolved(context_overriding)
	complete()

## @emitter
func _emit_resolved(context: Context) -> void:
	var ids: PackedInt32Array = PackedInt32Array()
	for target: Player in context.target_players:
		if target:
			ids.append(target.get_id())
	group_attack_resolved.emit(
		context.cached_power,
		ids,
		context.cached_health_damages,
		context.cached_mental_damages
	)

## 静态准备：缓存威力与逐目标伤害（响应牌威力同时削减生命与精神伤害，下限 0）
## @atomic
static func do_prepare(context: Context, _game_state: GameState) -> void:
	context.cached_power = context.source_card.get_power()
	var count: int = context.target_players.size()
	context.cached_health_damages.resize(count)
	context.cached_mental_damages.resize(count)
	for index: int in range(count):
		var target: Player = context.target_players[index]
		if not target:
			context.cached_health_damages[index] = 0
			context.cached_mental_damages[index] = 0
			continue
		var response: Card = context.get_response_card(target.get_id())
		var reduction: int = response.get_power() if response else 0
		var damage: int = max(0, context.cached_power - reduction)
		context.cached_health_damages[index] = damage
		context.cached_mental_damages[index] = damage

## 构建：为每个响应牌追加"移入弃牌区"的伴生命令（先追加，后执行）
## 响应牌必须确实在该目标的牌区里；区域不符时报错而不是静默空移
## @operation(schedule_disposals) @delegates(append_companion_command,fail)
func schedule_card_disposals(context_overriding: Context, game_state: GameState) -> void:
	for target: Player in context_overriding.target_players:
		if not target:
			continue
		var response: Card = context_overriding.get_response_card(target.get_id())
		if not response:
			continue
		if response.area_player_id != target.get_id():
			BehaviorCommand.fail(context_overriding, "响应牌不属于该目标：%s" % String(response.get_name()))
			return
		var source_area: Area = _resolve_response_area(response, game_state)
		var discard_area: AreaDiscard = game_state.get_discard_area()
		if BehaviorCommand.fail_if_null(source_area, context_overriding, "响应牌所在区域未知：%s" % String(response.area_name)):
			return
		if BehaviorCommand.fail_if_null(discard_area, context_overriding, "弃牌区缺失"):
			return
		append_companion_command(CardTransferCommand.new(
			target,
			source_area,
			discard_area,
			CardTransferCommand.Context.MoveOutMode.BY_ID,
			PackedInt32Array([response.id])
		))

## 按响应牌自身的区域名解析它所在的牌区（手牌区/其它持有区）
## @nullable_pure
static func _resolve_response_area(response: Card, game_state: GameState) -> Area:
	if response.area_name == GlobalConstants.DefaultArea.HAND:
		return game_state.get_hand_area(response.area_player_id)
	return null

## 构建：逆序追加每个目标的伤害命令，使栈弹出顺序与目标顺序一致
## @operation(schedule_damages) @delegates(append_companion_command)
func schedule_damages(context_overriding: Context) -> void:
	var target_count: int = context_overriding.target_players.size()
	if context_overriding.cached_health_damages.size() < target_count or context_overriding.cached_mental_damages.size() < target_count:
		BehaviorCommand.fail(context_overriding, "群体攻击伤害缓存未准备")
		return
	var last_index: int = target_count - 1
	for index: int in range(last_index, -1, -1):
		var target: Player = context_overriding.target_players[index]
		if not target:
			continue
		var health_damage: int = context_overriding.cached_health_damages[index]
		var mental_damage: int = context_overriding.cached_mental_damages[index]
		if health_damage == 0 and mental_damage == 0:
			continue
		append_companion_command(DamageCommand.new(
			target,
			health_damage,
			mental_damage,
			DamageCommand.SourceMechanism.GENERAL,
			context_overriding.player_id
		))
