extends BehaviorEvent
class_name DrawCardsEvent

var _draw_count: int
var _player_index: int

func _init(init_player_index: int, draw_count: int) -> void:
	super._init(&"DrawCards", init_player_index)
	_player_index = init_player_index
	_draw_count = draw_count

func generate_runtime_event(system: System) -> RuntimeEvent:
	var card_pool: Array[Card] = system.area_drawing.card_pool
	var actual_draw_count: int = min(_draw_count, card_pool.size())
	if actual_draw_count <= 0:
		return null
	var indices := PackedInt32Array()
	indices.resize(actual_draw_count)
	var start_index: int = card_pool.size() - actual_draw_count
	for i in range(actual_draw_count):
		indices[i] = start_index + i
	var target_area: Area = system.alive_players[_player_index].area_hand
	return CardMovementEvent.new(system.area_drawing, target_area, indices, player_id)
