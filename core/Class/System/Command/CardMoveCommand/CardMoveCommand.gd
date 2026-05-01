## 卡牌移动命令
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

	# 新增：渲染事件类型和自定义事件名
	var event_type: RenderRequest.ItemSet.EventType = RenderRequest.ItemSet.EventType.DRAW
	var custom_event_name: StringName = &""

	## 获取移动的卡牌
	func get_moved_cards() -> Array[Card]:
		return moved_cards

	## 工具方法：设置顶部移除模式
	func set_top_mode(count: int) -> Context:
		move_out_mode = MoveOutMode.TOP
		move_out_param = count
		return self
	## 工具方法：设置索引移除模式
	func set_indices_mode(indices: PackedInt32Array) -> Context:
		move_out_mode = MoveOutMode.INDICES
		move_out_param = indices
		return self
	## 工具方法：设置ID移除模式
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

	## 新增：设置事件类型（链式调用）
	func set_event_type(type: RenderRequest.ItemSet.EventType) -> Context:
		event_type = type
		return self

	## 新增：设置自定义事件名称（仅在 event_type 为 CUSTOM 时有效，否则报错）
	func set_custom_event_name(name: StringName) -> Context:
		if event_type == RenderRequest.ItemSet.EventType.CUSTOM:
			custom_event_name = name
		else:
			push_error("Cannot set custom event name when event_type is not CUSTOM")
		return self

	## 重写：主修饰玩家ID数组（从被移动卡牌的拥有者中提取，发起者置于首位）
	func get_primary_modifier_player_ids() -> PackedInt32Array:
		if not player_id or player_id < 0:
			return []
		var ids: PackedInt32Array = [player_id]
		for card in moved_cards:
			var owner_id = card.get_owner_id() if card else 0
			if not owner_id == 0 and not owner_id == player_id and not owner_id in ids:
				ids.append(owner_id)
		return ids

	## 重写：主修饰卡牌数组
	func get_primary_modifier_cards() -> Array[Card]:
		if phase < Phase.MOVE_OUT:
			return []
		return moved_cards
## 卡牌移动命令
func _init( player_id: int ,name_overriding: StringName = &"Move", context_overriding:Context = Context.new()) -> void:
	super._init(player_id,name_overriding,context_overriding)

func execute(game_state: GameState) -> void:
	match _context.phase:
		Context.Phase.INIT:
			_on_init_phase(game_state)
		Context.Phase.MOVE_OUT:
			_on_move_out_phase(game_state)
		Context.Phase.MOVE_IN:
			_on_move_in_phase(game_state)
		Context.Phase.DONE:
			_on_done_phase(game_state)

func _on_init_phase(_game_state: GameState) -> void:
	_context.phase = Context.Phase.MOVE_OUT

func _on_move_out_phase(_game_state: GameState) -> void:
	if not _context.source_area:
		push_error("移出区域未设置")
		_context.phase = Context.Phase.DONE
		return
	var moved_cards: Array[Card]
	match _context.move_out_mode:
		Context.MoveOutMode.TOP:
			var count: int = _context.move_out_param
			moved_cards = _context.source_area.get_top_cards(count) if _context.is_virtual else _context.source_area.remove_top_cards(count)
		Context.MoveOutMode.INDICES:
			var indices: PackedInt32Array = _context.move_out_param
			moved_cards = _context.source_area.get_cards_at_indices(indices) if _context.is_virtual else _context.source_area.remove_cards_at_indices(indices)
		Context.MoveOutMode.BY_ID:
			var ids: PackedInt32Array = _context.move_out_param
			moved_cards = _context.source_area.get_cards_by_ids(ids) if _context.is_virtual else _context.source_area.remove_cards_by_ids(ids)
		_:
			push_error("无效的移出模式")
	_context.moved_cards = moved_cards
	if _context.moved_cards.is_empty():
		_context.phase = Context.Phase.DONE
		return
	_context.phase = Context.Phase.MOVE_IN

func _on_move_in_phase(_game_state: GameState) -> void:
	if not _context.target_area:
		push_error("移入区域未设置")
		_context.phase = Context.Phase.DONE
		return
	if not _context.is_virtual:
		_context.target_area.cards_add(_context.moved_cards)
		RuleTrans.send_cards(_context.source_area,_context.target_area,_context.moved_cards)
	_context.phase = Context.Phase.DONE
	GlobalConsole._print(["CardMoveCommand:卡牌移动完成"])

func _on_done_phase(game_state: GameState) -> void:
	complete()
