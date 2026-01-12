## 拼点命令 - 重构后
extends BehaviorCommand
class_name DuelCommand

## 拼点上下文类
class Context extends CommandContext:
	enum Phase {
		INIT,           # 初始化阶段
		CALCULATE_POWER, # 计算点数
		EVALUATE_RESULT, # 评估结果
		DONE            # 完成
	}

	var card1: HandCard
	var card2: HandCard
	var source_system: StringName
	var cached_power1: float = 0.0
	var cached_power2: float = 0.0
	var result: int = Result.TIE
	var point_difference: int = 0

	## 枚举：拼点结果
	enum Result {
		A_WIN,
		B_WIN,
		TIE
	}
	## 工具方法：设置拼点卡片
	func set_cards(card_a: HandCard, card_b: HandCard, source: StringName) -> void:
		card1 = card_a
		card2 = card_b
		source_system = source
## 拼点命令
func _init(player_id: int,name_overriding = &"Duel", context_overriding: Context = Context.new()) -> void:
	super._init(player_id,name_overriding, context_overriding)

## 外部修饰接口：修改缓存点数
func modify_cached_power(card_id: int, new_power: float) -> void:
	if _context.phase < Context.Phase.EVALUATE_RESULT:
		return
	match card_id:
		1: _context.cached_power1 = new_power
		2: _context.cached_power2 = new_power

func execute(game_state: GameState) -> void:
	match _context.phase:
		Context.Phase.INIT:
			_on_init_phase(game_state, _context)
		Context.Phase.CALCULATE_POWER:
			_on_calculate_power_phase(game_state, _context)
		Context.Phase.EVALUATE_RESULT:
			_on_evaluate_result_phase(game_state, _context)
		Context.Phase.DONE:
			_on_done_phase(game_state, _context)

func _on_init_phase(game_state: GameState, _context: Context) -> void:
	_context.phase = Context.Phase.CALCULATE_POWER

func _on_calculate_power_phase(game_state: GameState, _context: Context) -> void:
	_context.cached_power1 = _context.card1.get_attribute(&"power")
	_context.cached_power2 = _context.card2.get_attribute(&"power")
	_context.phase = Context.Phase.EVALUATE_RESULT

func _on_evaluate_result_phase(game_state: GameState, _context: Context) -> void:
	_context.point_difference = abs(_context.cached_power1 - _context.cached_power2)
	if _context.cached_power1 > _context.cached_power2:
		_context.result = Context.Result.A_WIN
	elif _context.cached_power2 > _context.cached_power1:
		_context.result = Context.Result.B_WIN
	else:
		_context.result = Context.Result.TIE
	_context.phase = Context.Phase.DONE

func _on_done_phase(game_state: GameState, _context: Context) -> void:
	# 触发完成信号
	duel_completed.emit(_context.result, _context.point_difference)
	complete()

## 信号：拼点完成
signal duel_completed(result: int, point_difference: int)
