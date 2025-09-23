extends BehaviorEvent
class_name DrawCardsEvent

enum Phase {
	INIT,       # 声明即将创建移出事件
	MOVE_OUT,   # 执行移出事件
	MOVE_IN,    # 执行移入事件
	DONE        # 完成
}

var _draw_count: int
var _player_index: int
var _drawn_cards: Array[Card] = []

func _init(init_player_index: int, draw_count: int):
	super._init(&"DrawCards", init_player_index)
	_player_index = init_player_index
	_draw_count = draw_count
	current_phase = Phase.INIT

func execute(system: System) -> void:
	match current_phase:
		Phase.INIT:
			current_phase = Phase.MOVE_OUT
		Phase.MOVE_OUT:
			var card_pool = system.area_drawing.card_pool
			var draw_count = min(_draw_count, card_pool.size())
			if draw_count <= 0:
				current_phase = Phase.DONE
			var move_out:CardMoveEvent.Out = CardMoveEvent.Out.new(
				system.area_drawing,_player_id).set_top_mode(draw_count)
			move_out.execute()
			_drawn_cards = move_out.get_cards()
			current_phase = Phase.MOVE_IN
		Phase.MOVE_IN:
			var target_area = system.player_manager.get_player_by_seat(_player_index).area_hand
			var move_in = CardMoveEvent.In.new(
				target_area,
				_drawn_cards,
				_player_id
			)
			move_in.execute()
			current_phase = Phase.DONE
		Phase.DONE:
			complete()
