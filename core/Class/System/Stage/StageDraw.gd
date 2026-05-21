extends Stage
class_name StageDraw

func _init() -> void:
	super._init()
	stage_name = &"Draw"

## 进入抽牌阶段，先恢复行动点至初始值，再抽牌
func enter(game_state: GameState) -> void:
	super.enter(game_state)
	var player_id: int = game_state.stage_manager.current_player_id
	var player: Player = game_state.player_manager.get_player_by_id(player_id)
	if not player:
		push_error("StageDraw: 未找到当前玩家")
		end_stage(game_state)
		return
	var init_ap: int = player.get_attribute(&"init_AP")
	var reset_ap_command := ActionPointCommand.new(
		player,
		init_ap,
		ActionPointCommand.Context.Operation.SET,
		&"draw_stage_reset_ap"
	)
	var draw_count: int = player.get_attribute(&"draw_cards_count")
	var draw_event := DrawCardsCommand.new(player_id, draw_count)
	var callback: Callable = func(): end_stage(game_state)
	# 先入栈抽牌命令（带回调），后入栈恢复行动点命令（无回调），利用LIFO确保恢复行动点先执行
	game_state.queue_behavior_with_callback(draw_event, callback)
	game_state.queue_behavior(reset_ap_command)
