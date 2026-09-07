## 游戏开始命令。目前并不支持虚拟化，而且在大部分时候调用都会造成未知影响。
## 目前，需要自定义游戏开始行为时，应该在其发生前的修饰点内取消这个默认命令。
## 其静态能力均不依赖于CommandContext，复用起来很方便。
extends ScheduleCommand
class_name GameStartCommand

## @context
class Context extends CommandContext:
	enum Phase {
		INIT_SETUP,
		START_DRAW,
		DONE
	}

## @seam_override
func _init(
	command_bus: CommandBus,
	name_overriding: StringName = &"GameStart",
	context_overriding: Context = Context.new()
) -> void:
	super._init(command_bus, name_overriding, context_overriding)

## @template
func execute(game_state: GameState) -> void:
	if _context.is_cancelled:
		complete()
		return
	var ctx: Context = _context
	match ctx.phase:
		Context.Phase.INIT_SETUP:
			ctx.phase = Context.Phase.START_DRAW
			_on_init_setup_phase(game_state, ctx)
		Context.Phase.START_DRAW:
			ctx.phase = Context.Phase.DONE
			_on_start_draw_phase(game_state, ctx)
		Context.Phase.DONE:
			_on_done_phase(game_state, ctx)

## 静态初始化设置：创建玩家并发送更新
static func do_init_setup(game_state: GameState) -> void:
	if game_state.users:
		for user in game_state.users.values():
			game_state.player_manager.add_player(user.id)
	else:
		game_state.player_manager.add_player(1)
	game_state.player_manager.ensure_min_players(2)
	RuleTrans.send_player_delta_updates(game_state.player_manager.get_seated_players())

## 静态开始抽牌：创建新回合命令与抽牌命令
static func do_start_draw(game_state: GameState, command_bus: CommandBus) -> Array[BehaviorCommand]:
	var commands: Array[BehaviorCommand] = []
	var new_round_cmd := NewRoundCommand.new(command_bus, 2)
	commands.append(new_round_cmd)
	for player in game_state.player_manager.players:
		var draw_cmd := DrawCardsCommand.new(player, 4)
		commands.append(draw_cmd)
	return commands

## @hook
func _on_init_setup_phase(game_state: GameState, _context: Context) -> void:
	do_init_setup(game_state)

## @hook
func _on_start_draw_phase(game_state: GameState, _context: Context) -> void:
	var cmds := do_start_draw(game_state, _command_bus)
	for cmd in cmds:
		append_companion_command(cmd)
	GlobalConsole._print("GameStartCommand:游戏初始化完成")

## @hook
func _on_done_phase(_game_state: GameState, _context: Context) -> void:
	complete()
