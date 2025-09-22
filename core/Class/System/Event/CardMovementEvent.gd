extends RuntimeEvent
class_name CardMovementEvent

enum Phase { PRE_MOVE, MOVE_OUT, MOVE_IN, POST_MOVE }

var source_area: Area
var target_area: Area
var cards: Array[Card]
var _card_indices: PackedInt32Array
var current_phase: int = Phase.PRE_MOVE

func _init(src_area: Area, trg_area: Area, index_arr: PackedInt32Array, init_player_id: int = -1):
	super._init(EventType.RUNTIME, &"card_movement", init_player_id)
	source_area = src_area
	target_area = trg_area
	_card_indices = index_arr
	cards.resize(_card_indices.size())
	_card_indices.sort()
	for i in _card_indices.size():
		cards.set(i,source_area.card_pool[_card_indices[i]])
# 实现运行事件的处理器接口
func execute(_processor: EventProcessor) -> void:
	match current_phase:
		Phase.PRE_MOVE:
			current_phase = Phase.MOVE_OUT
		Phase.MOVE_OUT:
			for i in range(_card_indices.size() - 1, -1, -1):
				var idx = _card_indices[i]
				if idx < source_area.card_pool.size():
					source_area.card_pool.remove_at(idx)
			current_phase = Phase.MOVE_IN
		Phase.MOVE_IN:
			target_area.cards_add(cards)
			current_phase = Phase.POST_MOVE
		Phase.POST_MOVE:
			complete()
