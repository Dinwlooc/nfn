extends RuntimeEvent
class_name CardMoveEvent

class Out extends CardMoveEvent:
	enum MODE {
		TOP,
		INDICES
	}
	var _source_area: Area
	var _card_indices: PackedInt32Array
	var _cards: Array[Card] = []
	var _mode:MODE = MODE.INDICES
	var _top_mode_count:int
	func _init(source_area: Area, player_id: int , card_indices:PackedInt32Array = PackedInt32Array())->void:
		super._init(&"card_move_out",player_id)
		_source_area = source_area
		_card_indices = card_indices
	func execute()->void:
		match _mode:
			MODE.TOP:
				_cards = _source_area.remove_top_cards(_top_mode_count)
			MODE.INDICES:
				_cards = _source_area.remove_cards_at_indices(_card_indices)
	func set_top_mode(count:int = _card_indices.size())->Out:
		_top_mode_count = count
		_mode = MODE.TOP
		return self
	func get_cards()->Array[Card]:
		return _cards

class In extends CardMoveEvent:
	var _target_area: Area
	var _cards: Array[Card]
	func _init(target_area: Area, target_cards: Array[Card], player_id: int)->void:
		super._init(&"card_move_in",player_id)
		_target_area = target_area
		_cards = target_cards
	func execute()->void:
		_target_area.cards_add(_cards)
