extends CardMoveCommand
class_name PlayCardsCommand

## 出牌命令上下文类
class Context extends CardMoveCommand.Context:
	enum TargetAreaType {
		CENTER,
		PLAYER_DEF
	}
	var source_player_id: int = 0
	var target_player_id: int = 0
	var target_area_type: TargetAreaType = TargetAreaType.PLAYER_DEF
	var card_ids: PackedInt32Array = PackedInt32Array()
	var ap_source_player: Player = null

	func set_ap_source_player(player: Player) -> void:
		ap_source_player = player
	func set_source_player_id(id: int) -> void:
		source_player_id = id
	func set_target_player_id(id: int) -> void:
		target_player_id = id
	func set_target_area_type(area_type: TargetAreaType) -> void:
		target_area_type = area_type
	func set_card_ids(ids: PackedInt32Array) -> void:
		card_ids = ids
	func are_card_ids_valid() -> bool:
		return card_ids.size() > 0

func _init(
	source_player_id: int,
	card_ids: PackedInt32Array,
	target_player_id: int,
	target_area_type: Context.TargetAreaType = Context.TargetAreaType.PLAYER_DEF,
	ap_source_player: Player = null,
	name_overriding: StringName = &"PlayCards",
	context_overriding = Context.new()
) -> void:
	super._init(source_player_id, name_overriding, context_overriding)
	_context.set_source_player_id(source_player_id)
	_context.set_target_player_id(target_player_id)
	_context.set_target_area_type(target_area_type)
	_context.set_card_ids(card_ids)
	_context.set_ap_source_player(ap_source_player)
	_context.set_event_type(RenderRequest.ItemSet.EventType.TRANSFER)

func _on_init_phase(game_state: GameState) -> void:
	if not _context is Context:
		push_error("PlayCardsCommand: 上下文类型错误")
		_context.phase = CardMoveCommand.Context.Phase.DONE
		return
	if not _context.are_card_ids_valid():
		push_error("PlayCardsCommand: 无效的卡牌ID数组")
		_context.phase = CardMoveCommand.Context.Phase.DONE
		return
	# 行动点检查与消耗
	if _context.ap_source_player:
		var source_player: Player = _context.ap_source_player
		_context.source_area = game_state.get_hand_area(_context.source_player_id)
		var cards: Array[Card] = _context.source_area.get_cards_by_ids(_context.card_ids)
		var total_cost: int = 0
		for card in cards:
			total_cost += card.get_attribute(&"cost")
		var ap_cmd := ActionPointCommand.new(
			source_player,
			total_cost,
			ActionPointCommand.Context.Operation.SUB,
			&"play_card"
		)
		append_companion_command(ap_cmd)
	# 设置源区域（手牌）
	_context.source_area = game_state.get_hand_area(_context.source_player_id)
	match _context.target_area_type:
		Context.TargetAreaType.CENTER:
			_context.target_area = game_state.area_center
		Context.TargetAreaType.PLAYER_DEF:
			var target_player: Player = game_state.player_manager.get_player_by_id(_context.target_player_id)
			if not target_player:
				push_error("PlayCardsCommand: 未找到目标玩家")
				_context.phase = CardMoveCommand.Context.Phase.DONE
				return
			_context.target_area = game_state.get_defense_area(_context.target_player_id)
		_:
			push_error("PlayCardsCommand: 无效的目标区域类型")
			_context.phase = CardMoveCommand.Context.Phase.DONE
			return
	_context.set_id_mode(_context.card_ids)
	_context.phase = CardMoveCommand.Context.Phase.MOVE_OUT
