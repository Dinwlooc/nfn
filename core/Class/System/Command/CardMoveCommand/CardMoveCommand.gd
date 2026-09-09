## 卡牌移动命令基类
extends BehaviorCommand
class_name CardMoveCommand
## @context @deep_inherit
class Context extends CommandContext:
	enum Phase { INIT, MOVE_OUT, MOVE_IN, DONE }
	enum MoveOutMode { TOP, INDICES, BY_ID }
	var source_area: Area = null
	var move_out_mode: MoveOutMode = MoveOutMode.TOP
	var move_out_param = null
	var target_area: Area = null
	var moved_cards: Array[Card] = []
	var source_player: Player = null
	var event_type: RenderRequest.ItemSet.EventType = RenderRequest.ItemSet.EventType.DRAW
	var custom_event_name: StringName = &""

	func set_source_player(player: Player) -> Context:
		source_player = player
		return self
	func get_source_player() -> Player:
		return source_player
	func get_moved_cards() -> Array[Card]:
		return moved_cards
	func set_top_mode(count: int) -> Context:
		move_out_mode = MoveOutMode.TOP
		move_out_param = count
		return self
	func set_indices_mode(indices: PackedInt32Array) -> Context:
		move_out_mode = MoveOutMode.INDICES
		move_out_param = indices
		return self
	func set_id_mode(ids: PackedInt32Array) -> Context:
		move_out_mode = MoveOutMode.BY_ID
		move_out_param = ids
		return self
	func set_target_area(area: Area) -> Context:
		target_area = area
		return self
	func set_source_area(area: Area) -> Context:
		source_area = area
		return self
	func set_event_type(type: RenderRequest.ItemSet.EventType) -> Context:
		event_type = type
		return self
	func set_custom_event_name(name: StringName) -> Context:
		if event_type == RenderRequest.ItemSet.EventType.CUSTOM:
			custom_event_name = name
		else:
			push_error("Cannot set custom event name when event_type is not CUSTOM")
		return self

	func get_primary_modifier_players() -> Array[Player]:
		var players: Array[Player] = []
		if source_player:
			players.append(source_player)
		if source_area and source_area.player and not source_area.player in players:
			players.append(source_area.player)
		if target_area and target_area.player and not target_area.player in players:
			players.append(target_area.player)
		return players

	func get_primary_modifier_cards() -> Array[Card]:
		if phase < Phase.MOVE_OUT:
			return []
		return moved_cards

	func complete() -> void:
		phase = Phase.DONE
		super.complete()

## 静态移出。默认可以对空的合法类型参数进行生成空的移出卡牌数组，但将跳过移入阶段。行为设计如此。
static func do_move_out(context: Context, game_state: GameState) -> void:
	if not context.source_area:
		BehaviorCommand.fail(context, "移出区域未设置")
		return

	var moved: Array[Card]
	match context.move_out_mode:
		Context.MoveOutMode.TOP:
			var count: int = context.move_out_param
			if count and count >= 0:
				moved = context.source_area.get_top_cards(count) if context.is_virtual else context.source_area.remove_top_cards(count)
		Context.MoveOutMode.INDICES:
			var indices: PackedInt32Array = context.move_out_param
			if indices:
				moved = context.source_area.get_cards_at_indices(indices) if context.is_virtual else context.source_area.remove_cards_at_indices(indices)
		Context.MoveOutMode.BY_ID:
			var ids: PackedInt32Array = context.move_out_param
			if ids:
				moved = context.source_area.get_cards_by_ids(ids) if context.is_virtual else context.source_area.remove_cards_by_ids(ids)
		_:
			BehaviorCommand.fail(context, "无效的移出模式")
			return
	context.moved_cards = moved
	if context.moved_cards.is_empty():
		context.phase = Context.Phase.DONE

## 静态移入
static func do_move_in(context: Context, game_state: GameState) -> void:
	if context.is_virtual:
		return
	if not context.target_area:
		context.source_area.cards_add(context.moved_cards)
		return
	context.target_area.cards_add(context.moved_cards)
	RuleTrans.send_cards(context.source_area, context.target_area, context.moved_cards)
	GlobalConsole._print(["CardMoveCommand:卡牌移动完成"])

## @seam_override
func _init(player: Player = Player.PUBLIC_PLAYER, name_overriding: StringName = &"Move", context_overriding: Context = Context.new()) -> void:
	super._init(player.get_id(), name_overriding, context_overriding)
	_context.set_source_player(player)

## @template
func execute(game_state: GameState) -> void:
	match _context.phase:
		Context.Phase.INIT:
			_context.phase = Context.Phase.MOVE_OUT
			_on_init_phase(game_state)
		Context.Phase.MOVE_OUT:
			_context.phase = Context.Phase.MOVE_IN
			_on_move_out_phase(game_state)
		Context.Phase.MOVE_IN:
			_context.phase = Context.Phase.DONE
			_on_move_in_phase(game_state)
		Context.Phase.DONE:
			_on_done_phase(game_state)

## @hook
func _on_init_phase(_game_state: GameState, context_overriding: Context = _context as Context) -> void:
	pass
## @hook
func _on_move_out_phase(_game_state: GameState, context_overriding: Context = _context as Context) -> void:
	CardMoveCommand.do_move_out(context_overriding, _game_state)
## @hook
func _on_move_in_phase(_game_state: GameState, context_overriding: Context = _context as Context) -> void:
	CardMoveCommand.do_move_in(context_overriding, _game_state)
## @hook
func _on_done_phase(_game_state: GameState, context_overriding: Context = _context as Context) -> void:
	complete()
