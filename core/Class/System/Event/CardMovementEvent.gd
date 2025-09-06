extends RuntimeEvent
class_name CardMovementEvent

enum Phase { PRE_MOVE, MOVE_OUT, MOVE_IN, POST_MOVE }

var source_area: Area
var target_area: Area
var cards: Array[Card]
var card_indices: PackedInt32Array
var current_phase: int = Phase.PRE_MOVE

func _init(src_area: Area, trg_area: Area, index_arr: PackedInt32Array, init_player_id: int = -1):
	super._init(EventType.RUNTIME, &"CardMovement", init_player_id)
	source_area = src_area
	target_area = trg_area
	card_indices = index_arr

# 实现运行事件的处理器接口
func execute(processor: EventProcessor) -> void:
	match current_phase:
		Phase.PRE_MOVE:
			for idx in card_indices:
				cards.append(source_area.card_pool[idx])
			current_phase = Phase.MOVE_OUT
		Phase.MOVE_OUT:
			card_indices.sort()  # 确保索引有序
			for i in range(card_indices.size() - 1, -1, -1):
				var idx = card_indices[i]
				if idx < source_area.card_pool.size():
					source_area.card_pool.remove_at(idx)
			current_phase = Phase.MOVE_IN
		Phase.MOVE_IN:
			target_area.cards_add(cards)
			current_phase = Phase.POST_MOVE         
		Phase.POST_MOVE:
			complete()
