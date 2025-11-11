extends AtomicCommand
class_name CardMoveCommand

class Out extends CardMoveCommand:
	# 定义三种移除模式
	enum MODE {
		TOP,        # 顶部移除
		INDICES,    # 索引移除
		BY_ID,      # ID移除
		NOT_SET     # 未设置模式（默认）
	}
	var _source_area: Area
	var _cards: Array[Card] = []
	var _mode: MODE = MODE.NOT_SET
	var _top_count: int
	var _indices: PackedInt32Array
	var _card_ids: PackedInt32Array
	func _init(source_area: Area, player_id: int) -> void:
		super._init(&"card_move_out", player_id)
		_source_area = source_area
	# 显式设置顶部移除模式
	func set_top_mode(count: int) -> Out:
		_mode = MODE.TOP
		_top_count = count
		return self
	# 显式设置索引移除模式
	func set_indices_mode(indices: PackedInt32Array) -> Out:
		_mode = MODE.INDICES
		_indices = indices
		return self
	# 显式设置ID移除模式
	func set_id_mode(ids: PackedInt32Array) -> Out:
		_mode = MODE.BY_ID
		_card_ids = ids
		return self
	func execute() -> void:
		assert(_mode != MODE.NOT_SET, "必须显式声明移除模式")
		match _mode:
			MODE.TOP:
				_cards = _source_area.remove_top_cards(_top_count)
			MODE.INDICES:
				_cards = _source_area.remove_cards_at_indices(_indices)
			MODE.BY_ID:
				_cards = _source_area.remove_cards_by_ids(_card_ids)
	func get_cards() -> Array[Card]:
		return _cards

class In extends CardMoveCommand:
	var _target_area: Area
	var _cards: Array[Card]
	func _init(target_area: Area, target_cards: Array[Card], player_id: int)->void:
		super._init(&"card_move_in",player_id)
		_target_area = target_area
		_cards = target_cards
	func execute()->void:
		_target_area.cards_add(_cards)
