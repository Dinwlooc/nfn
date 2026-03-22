## 卡牌移动命令 - 重构后
extends BehaviorCommand
class_name CardMoveCommand

## 卡牌移动上下文类
class Context extends CommandContext:
	enum Phase {
		INIT,           # 初始化阶段
		MOVE_OUT,       # 执行移出事件
		MOVE_IN,        # 执行移入事件
		DONE            # 完成
	}
	enum MoveOutMode {
		TOP,            # 顶部移除
		INDICES,        # 索引移除
		BY_ID           # ID移除
	}
	var source_area: Area = null
	var move_out_mode: MoveOutMode = MoveOutMode.TOP
	var move_out_param = null
	var target_area: Area = null
	var moved_cards: Array[Card] = []
	## 获取移动的卡牌
	func get_moved_cards() -> Array[Card]:
		return moved_cards
	## 工具方法：设置顶部移除模式
	func set_top_mode(count: int) -> void:
		move_out_mode = MoveOutMode.TOP
		move_out_param = count
	## 工具方法：设置索引移除模式
	func set_indices_mode(indices: PackedInt32Array) -> void:
		move_out_mode = MoveOutMode.INDICES
		move_out_param = indices
	## 工具方法：设置ID移除模式
	func set_id_mode(ids: PackedInt32Array) -> void:
		move_out_mode = MoveOutMode.BY_ID
		move_out_param = ids
## 卡牌移动命令
func _init( player_id: int ,name_overriding: StringName, context_overriding:Context = Context.new()) -> void:
	super._init(player_id,name_overriding,context_overriding)

func execute(game_state: GameState) -> void:
	match _context.phase:
		Context.Phase.INIT:
			_on_init_phase(game_state, _context)
		Context.Phase.MOVE_OUT:
			_on_move_out_phase(game_state, _context)
		Context.Phase.MOVE_IN:
			_on_move_in_phase(game_state, _context)
		Context.Phase.DONE:
			_on_done_phase(game_state, _context)

func _on_init_phase(game_state: GameState, _context: Context) -> void:
	_context.phase = Context.Phase.MOVE_OUT

func _on_move_out_phase(game_state: GameState, _context: Context) -> void:
	if not _context.source_area:
		push_error("移出区域未设置")
		_context.phase = Context.Phase.DONE
		return
	if _context.is_virtual:
		match _context.move_out_mode:
			Context.MoveOutMode.TOP:
				var count: int = _context.move_out_param as int
				var cards = _context.source_area.get_top_cards(count)
				_context.moved_cards = cards
			Context.MoveOutMode.INDICES:
				var indices: PackedInt32Array = _context.move_out_param as PackedInt32Array
				var cards = _context.source_area.get_cards_at_indices(indices)
				_context.moved_cards = cards
			Context.MoveOutMode.BY_ID:
				var ids: PackedInt32Array = _context.move_out_param as PackedInt32Array
				var cards = _context.source_area.get_cards_by_ids(ids)
				_context.moved_cards = cards
			_:
				push_error("无效的移出模式")
	else:
		match _context.move_out_mode:
			Context.MoveOutMode.TOP:
				var count: int = _context.move_out_param as int
				_context.moved_cards = _context.source_area.remove_top_cards(count)
			Context.MoveOutMode.INDICES:
				var indices: PackedInt32Array = _context.move_out_param as PackedInt32Array
				_context.moved_cards = _context.source_area.remove_cards_at_indices(indices)
			Context.MoveOutMode.BY_ID:
				var ids: PackedInt32Array = _context.move_out_param as PackedInt32Array
				_context.moved_cards = _context.source_area.remove_cards_by_ids(ids)
			_:
				push_error("无效的移出模式")
	if _context.moved_cards.is_empty():
		_context.phase = Context.Phase.DONE
		return
	_context.phase = Context.Phase.MOVE_IN

func _on_move_in_phase(game_state: GameState, _context: Context) -> void:
	if not _context.target_area:
		push_error("移入区域未设置")
		_context.phase = Context.Phase.DONE
		return
	if not _context.is_virtual:
		_context.target_area.cards_add(_context.moved_cards)
		_context.target_area.send_cards(_context.moved_cards)
	_context.phase = Context.Phase.DONE
	GlobalConsole._print(["CardMoveCommand:卡牌移动完成"])
	complete()

func _on_done_phase(game_state: GameState, _context: Context) -> void:
	pass
