extends CardMoveCommand
class_name DiscardCardsCommand
## 弃牌命令上下文类
class Context extends CardMoveCommand.Context:
	var card_ids: PackedInt32Array = PackedInt32Array()
	## 设置卡牌ID数组
	func set_card_ids(ids: PackedInt32Array) -> void:
		card_ids = ids
	## 检查卡牌ID数组是否有效
	func are_card_ids_valid() -> bool:
		return not card_ids.is_empty()

## 弃牌命令
func _init(
	player: Player,
	card_ids: PackedInt32Array,
	name_overriding: StringName = &"DiscardCards",
	context_overriding: Context = Context.new()
) -> void:
	super._init(player, name_overriding, context_overriding)
	_context.set_card_ids(card_ids)
	_context.set_event_type(RenderRequest.ItemSet.EventType.DISCARD)
## 覆盖父类的初始化阶段方法
func _on_init_phase(game_state: GameState) -> void:
	if not _context is Context:
		push_error("DiscardCardsCommand: 上下文类型错误")
		_context.phase = CardMoveCommand.Context.Phase.DONE
		return
	if not _context.are_card_ids_valid():
		push_error("DiscardCardsCommand: 无效的卡牌ID数组")
		_context.phase = CardMoveCommand.Context.Phase.DONE
		return
	var source_player: Player = _context.get_source_player()
	if not source_player:
		push_error("DiscardCardsCommand: 未找到源玩家")
		_context.phase = CardMoveCommand.Context.Phase.DONE
		return
	_context.source_area = game_state.get_hand_area(source_player.get_id())
	_context.target_area = game_state.get_discard_area()
	_context.set_id_mode(_context.card_ids)
