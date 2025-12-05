## 斗牌命令
class_name BattleCommand
extends BehaviorCommand

var defensive_area: AreaDefensive
var top_card: Card
var pending_card: Card
var duel_result: int = 3
var duel_diff: int = 0
var _phase: int = 0

func _init(area: AreaDefensive, top: Card, pending: Card) -> void:
	event_name = &"BattleCommand"
	defensive_area = area
	top_card = top
	pending_card = pending

func execute(system: System) -> void:
	match _phase:
		0:
			_phase = 1
		1:
			var duel = DuelCommand.new(top_card, pending_card, &"BattleCommand")
			duel.duel_completed.connect(_on_duel_completed)
			append_companion_command(duel)
			_phase = 2
		2:
			match duel_result:
				DuelCommand.Result.A_WIN:
					pass
				DuelCommand.Result.B_WIN:
					pass
				DuelCommand.Result.TIE:
					pass
			complete()

func _on_duel_completed(result:DuelCommand.Result, diff: int) -> void:
	duel_result = result
	duel_diff = diff
