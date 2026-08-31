## 卡牌移动命令基类，提供移动流程框架。
## 子类通过重写钩子实现具体移动逻辑。
extends BehaviorCommand
class_name CardMoveCommand

## 卡牌移动上下文，包含移动所需的所有参数与状态。
## @context @deep_inherit
class Context extends CommandContext:
	enum Phase {
		INIT,
		MOVE_OUT,
		MOVE_IN,
		DONE
	}
	enum MoveOutMode {
		TOP,
		INDICES,
		BY_ID
	}
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
## @hook @seam_override
func _on_init_phase(_game_state: GameState, context_overriding: Context = _context as Context) -> void:
	pass
## @hook @seam_override
func _on_move_out_phase(_game_state: GameState, context_overriding: Context = _context as Context) -> void:
	if not context_overriding.source_area:
		_fail("移出区域未设置", context_overriding)
		return
	var moved_cards: Array[Card]
	match context_overriding.move_out_mode:
		Context.MoveOutMode.TOP:
			var count: int = context_overriding.move_out_param
			moved_cards = context_overriding.source_area.get_top_cards(count) if context_overriding.is_virtual else context_overriding.source_area.remove_top_cards(count)
		Context.MoveOutMode.INDICES:
			var indices: PackedInt32Array = context_overriding.move_out_param
			moved_cards = context_overriding.source_area.get_cards_at_indices(indices) if context_overriding.is_virtual else context_overriding.source_area.remove_cards_at_indices(indices)
		Context.MoveOutMode.BY_ID:
			var ids: PackedInt32Array = context_overriding.move_out_param
			moved_cards = context_overriding.source_area.get_cards_by_ids(ids) if context_overriding.is_virtual else context_overriding.source_area.remove_cards_by_ids(ids)
		_:
			_fail("无效的移出模式", context_overriding)
			return
	context_overriding.moved_cards = moved_cards
	if context_overriding.moved_cards.is_empty():
		context_overriding.phase = Context.Phase.DONE
		return
## @hook @seam_override
func _on_move_in_phase(_game_state: GameState, context_overriding: Context = _context as Context) -> void:
	if context_overriding.is_virtual:
		return
	if not context_overriding.target_area:
		context_overriding.source_area.cards_add(context_overriding.moved_cards)
		return
	context_overriding.target_area.cards_add(context_overriding.moved_cards)
	RuleTrans.send_cards(context_overriding.source_area, context_overriding.target_area, context_overriding.moved_cards)
	GlobalConsole._print(["CardMoveCommand:卡牌移动完成"])
## @hook @seam_override
func _on_done_phase(_game_state: GameState, context_overriding: Context = _context as Context) -> void:
	complete()
## 错误退出，自动将 phase 置为 DONE，并输出包含命令名的错误信息。
## @seam
func _fail(msg: String = _guard_error.text, context: CommandContext = _context) -> void:
	super._fail(msg,context)
	context.phase = context.Phase.DONE
