## 抽牌阶段：当前玩家抽牌并重置行动点。
extends Stage
class_name StageDraw

#== Constructor ==
func _init() -> void:
	super._init()
	stage_name = &"Draw"

#== Static Methods ==
## 获取当前阶段玩家
## @nullable_pure
static func get_current_player(game_state: GameState) -> Player:
	var player_id: int = game_state.stage_manager.current_player_id
	return game_state.player_manager.get_player_by_id(player_id)
## 获取玩家初始行动点
## @pure
static func get_init_ap(player: Player) -> int:
	return player.get_attribute(&"init_AP")
## 获取玩家抽牌数量
## @pure
static func get_draw_count(player: Player) -> int:
	return player.get_attribute(&"draw_cards_count")
## 创建重置行动点命令
## @factory
static func create_reset_ap_command(player: Player) -> ActionPointCommand:
	var init_ap: int = get_init_ap(player)
	return ActionPointCommand.new(
		player,
		init_ap,
		ActionPointCommand.Context.Operation.SET,
		&"draw_stage_reset_ap"
	)
## 创建抽牌命令
## @factory
static func create_draw_cards_command(player: Player) -> DrawCardsCommand:
	var draw_count: int = get_draw_count(player)
	return DrawCardsCommand.new(player, draw_count)

#== Public Methods ==
## 进入阶段
## @override @stack_local @side_effect
func enter(game_state: GameState, command_bus: CommandBus) -> void:
	super.enter(game_state, command_bus)
	var player: Player = get_current_player(game_state)
	if not player:
		push_error("StageDraw: 未找到当前玩家")
		request_end_stage(command_bus)
		return
	var reset_ap_command: ActionPointCommand = create_reset_ap_command(player)
	var draw_event: DrawCardsCommand = create_draw_cards_command(player)
	var callback: Callable = func() -> void: request_end_stage(command_bus)
	command_bus.queue_behavior_with_callback(draw_event, callback)
	command_bus.queue_behavior(reset_ap_command)
