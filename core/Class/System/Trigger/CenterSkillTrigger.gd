extends GameStateTrigger
class_name CenterSkillTrigger

## 中央区引用，_init 时从区域注册表取得
var _center_area: AreaCenter

## 构造：接管中央区并连接卡牌添加信号
func _init(game_state: GameState, command_bus: CommandBus) -> void:
	super._init(game_state, command_bus)
	_center_area = game_state.area_registry.get_center_area()
	if _center_area:
		_center_area.area_card_added.connect(_on_card_added_to_center)
## @signal_listener 中央区卡牌添加回调。
func _on_card_added_to_center(card: Card, _area: Area) -> void:
	var trigger_type: RuleCenterSkill.TriggerType = RuleCenterSkill.get_trigger_type(card)
	match trigger_type:
		RuleCenterSkill.TriggerType.SKILL:
			_schedule_skill(card)
		RuleCenterSkill.TriggerType.GROUP_ATTACK:
			_schedule_group_attack(card)
		_:
			_schedule_move_to_discard(card)
## 技能：先移入弃牌，再下技能命令
## @delegates
func _schedule_skill(card: Card) -> void:
	_command_bus.queue_behavior(_create_move_to_discard_command(card))
	var targets: Array[Player] = _center_area.skill_target_players
	_command_bus.queue_behavior(SkillCommand.new(card, _center_area, targets))
## 群体攻击：当前仅移入弃牌（群体攻击命令未实现）
## @delegates
func _schedule_group_attack(card: Card) -> void:
	_command_bus.queue_behavior(_create_move_to_discard_command(card))
	# 群体攻击命令暂未实现
## 无技能：仅移入弃牌
## @delegates
func _schedule_move_to_discard(card: Card) -> void:
	_command_bus.queue_behavior(_create_move_to_discard_command(card))
## 创建把该卡从中央区移入弃牌堆的命令
func _create_move_to_discard_command(card: Card) -> BehaviorCommand:
	var discard_area: AreaDiscard = _game_state.get_discard_area()
	return CardTransferCommand.new(
		_game_state.get_player_by_id(card.get_owner_id()),
		_center_area,
		discard_area,
		CardTransferCommand.Context.MoveOutMode.BY_ID,
		PackedInt32Array([card.id])
	)
## 断开中央区的卡牌添加信号
func disconnect_all() -> void:
	if _center_area:
		_center_area.area_card_added.disconnect(_on_card_added_to_center)
