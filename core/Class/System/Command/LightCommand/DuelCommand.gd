## 拼点命令
class_name DuelCommand
extends BehaviorCommand

enum Result{
	A_WIN,
	B_WIN,
	TIE
}
signal duel_completed(winner:Result, point_difference: int)
var card1: HandCard
var card2: HandCard
var source_system: StringName
var _phase: int = 0
var _cached_power1: float = 0.0
var _cached_power2: float = 0.0
var _cached_result: Result = Result.TIE
var _cached_point_diff:int = 0
# 外部修饰接口
func _init(card_a: HandCard, card_b: HandCard, source: StringName) -> void:
	event_name = &"DuelCommand"
	card1 = card_a
	card2 = card_b
	source_system = source

func modify_cached_power(card_id: int, new_power: float) -> void:
	if _phase < 2:
		return
	match card_id:
		1: _cached_power1 = new_power
		2: _cached_power2 = new_power

func execute(system: System) -> void:
	match _phase:
		0:  # 预备阶段：缓存参数
			_cached_power1 = card1.get_attribute(&"power")
			_cached_power2 = card2.get_attribute(&"power")
			_phase = 1
		1:
			_cached_point_diff = abs(_cached_power1 - _cached_power2)
			if _cached_power1 > _cached_power2:
				_cached_result = Result.A_WIN
			elif _cached_power2 > _cached_power1:
				_cached_result = Result.B_WIN
			else:
				_cached_result = Result.TIE
			_phase = 2
		2:
			duel_completed.emit(_cached_result, _cached_point_diff)
			complete()
