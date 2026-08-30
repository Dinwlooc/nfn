extends CardMoveCommand
class_name PlayCardsCommand

## 出牌命令上下文类
class Context extends CardMoveCommand.Context:
	enum TargetAreaType {
		CENTER,
		PLAYER_DEF
	}
	var target_player_id: int = 0
	var target_area_type: TargetAreaType = TargetAreaType.PLAYER_DEF
	var card_ids: PackedInt32Array = PackedInt32Array()
	var ap_source_player: Player = null

	func set_ap_source_player(player: Player) -> void:
		ap_source_player = player
	func set_target_player_id(id: int) -> void:
		target_player_id = id
	func set_target_area_type(area_type: TargetAreaType) -> void:
		target_area_type = area_type
	func set_card_ids(ids: PackedInt32Array) -> void:
		card_ids = ids
	func are_card_ids_valid() -> bool:
		return card_ids.size() > 0

func _init(
	player: Player,
	card_ids: PackedInt32Array,
	target_player_id: int,
	target_area_type: Context.TargetAreaType = Context.TargetAreaType.PLAYER_DEF,
	ap_source_player: Player = player,
	name_overriding: StringName = &"PlayCards",
	context_overriding = Context.new()
) -> void:
	super._init(player, name_overriding, context_overriding)
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
	var source_player: Player = _context.get_source_player()
	if not source_player:
		push_error("PlayCardsCommand: 源玩家无效")
		_context.phase = CardMoveCommand.Context.Phase.DONE
		return
	# 统一获取源区域（手牌），仅获取一次
	var source_area: AreaHand = game_state.get_hand_area(source_player.get_id())
	if not source_area:
		push_error("PlayCardsCommand: 无法获取源玩家手牌区域")
		_context.phase = CardMoveCommand.Context.Phase.DONE
		return
	_context.source_area = source_area
	# 行动点消耗（源区域已确保存在，可直接使用）
	if _context.ap_source_player:
		var ap_player: Player = _context.ap_source_player
		var cards: Array[Card] = source_area.get_cards_by_ids(_context.card_ids)
		var total_cost: int = 0
		for card in cards:
			total_cost += card.get_attribute(&"cost")
		var ap_cmd := ActionPointCommand.new(
			ap_player,
			total_cost,
			ActionPointCommand.Context.Operation.SUB,
			&"play_card"
		)
		append_companion_command(ap_cmd)
	# 目标区域处理
	match _context.target_area_type:
		Context.TargetAreaType.CENTER:
			var center_area: AreaCenter = game_state.get_center_area()
			if not center_area:
				push_error("PlayCardsCommand: 无法获取中央区")
				_context.phase = CardMoveCommand.Context.Phase.DONE
				return
			var target_player: Player = game_state.player_manager.get_player_by_id(_context.target_player_id)
			if not target_player:
				push_error("PlayCardsCommand: 无效的目标玩家ID")
				_context.phase = CardMoveCommand.Context.Phase.DONE
				return
			center_area.set_skill_targets([target_player])
			_context.target_area = center_area
		Context.TargetAreaType.PLAYER_DEF:
			var def_area: AreaDefence = game_state.get_defense_area(_context.target_player_id)
			if not def_area:
				push_error("PlayCardsCommand: 无法获取目标玩家守备区域")
				_context.phase = CardMoveCommand.Context.Phase.DONE
				return
			_context.target_area = def_area
		_:
			push_error("PlayCardsCommand: 无效的目标区域类型")
			_context.phase = CardMoveCommand.Context.Phase.DONE
			return
	_context.set_id_mode(_context.card_ids)
