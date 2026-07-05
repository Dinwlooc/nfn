extends GameStateTrigger
class_name CenterSkillTrigger

var _center_area: AreaCenter
var _connected: bool = false

func _init(game_state: GameState, command_bus: CommandBus) -> void:
	_game_state = game_state
	_command_bus = command_bus
	_center_area = game_state.area_registry.get_center_area()
	if _center_area:
		_center_area.area_card_added.connect(_on_card_added_to_center)
		_connected = true

func _on_card_added_to_center(card: Card, _area: Area) -> void:
	var trigger_type:RuleCenterSkill.TriggerType = RuleCenterSkill.get_trigger_type(card)
	match trigger_type:
		RuleCenterSkill.TriggerType.SKILL:
			_schedule_skill(card)
		RuleCenterSkill.TriggerType.GROUP_ATTACK:
			_schedule_group_attack(card)
		_:
			_schedule_move_to_discard(card)

func _schedule_skill(card: Card) -> void:
	_command_bus.queue_behavior(_create_move_to_discard_command(card))
	var target_ids: PackedInt32Array = _center_area.skill_target_player_ids
	_command_bus.queue_behavior(SkillCommand.new(card, _center_area, target_ids))

func _schedule_group_attack(card: Card) -> void:
	_command_bus.queue_behavior(_create_move_to_discard_command(card))
	# 群体攻击命令暂未实现，预留
func _schedule_move_to_discard(card: Card) -> void:
	_command_bus.queue_behavior(_create_move_to_discard_command(card))

func _create_move_to_discard_command(card: Card) -> BehaviorCommand:
	var discard_area:AreaDiscard = _game_state.get_discard_area()
	return CardTransferCommand.new(
		card.get_owner_id(),
		_center_area,
		discard_area,
		CardTransferCommand.Context.MoveOutMode.BY_ID,
		PackedInt32Array([card.id])
	)
