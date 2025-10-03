extends Stage
class_name StageDraw

func _init_expand() -> void:
	stage_name = &"Draw"
	time_limit = 0.0  # 设置为0表示不需要计时器

func run() -> void:
	var player_index = system.current_player_index
	var draw_count = system.player_manager.get_player_by_seat(player_index).draw_cards_count
	var draw_event = DrawCardsCommand.new(player_index, draw_count)
	system.command_processor.all_completed.connect(_on_draw_completed, CONNECT_ONE_SHOT)
	system.command_processor.queue_behavior(draw_event)

func _on_draw_completed() -> void:
	end_stage()  # 命令完成后立即结束阶段
