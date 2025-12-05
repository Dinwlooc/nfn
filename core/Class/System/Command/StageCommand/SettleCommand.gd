class_name SettleCommand
extends BehaviorCommand

var defensive_area: AreaDefensive
var top_card: Card
var second_card: Card
var is_unilateral: bool = false
var duel_result:int = 3
var duel_diff: int = 0
var _phase: int = 0
var _attacker:Player

func _init(area: AreaDefensive,attacker:Player) -> void:
	event_name = &"SettleCommand"
	defensive_area = area
	_attacker = attacker

func execute(system: System) -> void:
	match _phase:
		0:  # 预备阶段
			top_card = defensive_area.get_top_card()
			second_card = defensive_area.get_second_card()
			is_unilateral = (second_card == null)
			_phase = 1
		1:  # 结算判断阶段
			if !is_unilateral:
				var duel = DuelCommand.new(top_card, second_card, &"SettleCommand")
				duel.duel_completed.connect(_on_duel_completed)
				append_companion_command(duel)
			_phase = 2
		2:  #伤害阶段
			_generate_damage_phase()
			_phase = 3
		3: #效果阶段，无原生功能，仅供修饰机制使用
			_phase = 4
		4:#守区清空
			defensive_area.clear_defense_area()
			complete()

func _on_duel_completed(result:DuelCommand.Result, diff: int) -> void:
	duel_result = result
	duel_diff = diff

func _generate_damage_phase() -> void:
	var defender = defensive_area.player
	if top_card.is_attack_card():  # 攻击牌结算
		var health_dmg = top_card.get_physical_damage()
		var mental_dmg = top_card.get_mental_damage()
		if !is_unilateral:
			match duel_result:
				DuelCommand.Result.A_WIN:  # 攻击牌胜
					mental_dmg = max(0, mental_dmg - duel_diff)
				DuelCommand.Result.TIE:
					var defense_power = second_card.get_attribute(&"power")
					mental_dmg = max(0, mental_dmg - defense_power)
				DuelCommand.Result.B_WIN:  # 防御牌胜
					var defense_power = second_card.get_attribute(&"power")
					mental_dmg = max(0, mental_dmg - (duel_diff + defense_power))
					health_dmg = max(0, health_dmg - duel_diff)
		var damage_cmd = DamageCommand.new(
			defender,
			health_dmg,
			mental_dmg,
			DamageCommand.SourceMechanism.GENERAL,
			_attacker.player_id
		)
		append_companion_command(damage_cmd)
	elif top_card.is_defense_card():  # 防御牌结算
		var mental_dmg = top_card.get_mental_damage()
		if !is_unilateral && duel_result == DuelCommand.Result.A_WIN:
			mental_dmg = max(0, mental_dmg - duel_diff)
		var damage_cmd = DamageCommand.new(
			_attacker,
			0,
			mental_dmg,
			DamageCommand.SourceMechanism.GENERAL,
			defender.player_id
		)
		append_companion_command(damage_cmd)
