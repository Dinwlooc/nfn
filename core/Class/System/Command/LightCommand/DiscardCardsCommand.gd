extends CardMoveCommand
class_name DiscardCardsCommand

## 弃牌命令上下文类
class Context extends CardMoveCommand.Context:
	var source_player_id: int = 0
	var card_ids: PackedInt32Array = PackedInt32Array()

	## 设置源玩家ID
	func set_source_player_id(id: int) -> void:
		source_player_id = id

	## 设置卡牌ID数组
	func set_card_ids(ids: PackedInt32Array) -> void:
		card_ids = ids

	## 检查卡牌ID数组是否有效
	func are_card_ids_valid() -> bool:
		return not card_ids.is_empty()

## 弃牌命令
func _init(
	source_player_id: int,
	card_ids: PackedInt32Array,
	name_overriding: StringName = &"DiscardCards",
	context_overriding: Context = Context.new()
) -> void:
	super._init(source_player_id, name_overriding, context_overriding)
	_context.set_source_player_id(source_player_id)
	_context.set_card_ids(card_ids)

## 覆盖父类的初始化阶段方法
func _on_init_phase(game_state: GameState) -> void:
	# 卫语句：检查上下文类型
	if not _context is Context:
		push_error("DiscardCardsCommand: 上下文类型错误")
		_context.phase = CardMoveCommand.Context.Phase.DONE
		return
	# 卫语句：检查卡牌ID数组是否有效
	if not _context.are_card_ids_valid():
		push_error("DiscardCardsCommand: 无效的卡牌ID数组")
		_context.phase = CardMoveCommand.Context.Phase.DONE
		return
	# 获取源玩家
	var source_player: Player = game_state.player_manager.get_player_by_id(_context.source_player_id)
	if not source_player:
		push_error("DiscardCardsCommand: 未找到源玩家")
		_context.phase = CardMoveCommand.Context.Phase.DONE
		return
	_context.source_area = source_player.area_hand
	# 目标区域是弃牌堆
	_context.target_area = game_state.area_discard
	# 设置移出模式为ID模式
	_context.set_id_mode(_context.card_ids)
	# 切换到MOVE_OUT阶段
	_context.phase = CardMoveCommand.Context.Phase.MOVE_OUT
