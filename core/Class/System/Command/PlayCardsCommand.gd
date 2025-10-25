extends BehaviorCommand
class_name PlayCardsCommand

enum Phase {
	INIT,       # 声明即将创建移出事件
	MOVE_OUT,   # 执行移出事件
	MOVE_IN,    # 执行移入事件
	DONE        # 完成
}
enum TargetAreaType {
	CENTER,     # 中心区域
	PLAYER_DEF  # 玩家防御区
}
var _source_player_id: int
var _card_ids: PackedInt32Array
var _target_player_id: int
var _target_area_type: TargetAreaType
var _moved_cards: Array[Card] = []
var _source_area: AreaHand
var _target_area: Area

func _init(
	source_player_id: int,
	card_ids: PackedInt32Array,
	target_player_id: int,
	target_area_type: TargetAreaType = TargetAreaType.PLAYER_DEF
) -> void:
	super._init(GlobalConstants.OP_PLAY_CARD, source_player_id)
	_source_player_id = source_player_id
	_card_ids = card_ids
	_target_player_id = target_player_id
	_target_area_type = target_area_type
	current_phase = Phase.INIT
func execute(system: System) -> void:
	match current_phase:
		Phase.INIT:
			_source_area = system.player_manager.get_player_by_id(_source_player_id).area_hand
			if _card_ids.size() == 0:
				push_error("无效的卡牌ID数组")
				current_phase = Phase.DONE
				return
			current_phase = Phase.MOVE_OUT
		Phase.MOVE_OUT:
			var move_out := CardMoveCommand.Out.new(_source_area, _source_player_id).set_id_mode(_card_ids)
			move_out.execute()
			_moved_cards = move_out.get_cards()
			current_phase = Phase.MOVE_IN
		Phase.MOVE_IN:
			match _target_area_type:
				TargetAreaType.CENTER:
					_target_area = system.area_center
				TargetAreaType.PLAYER_DEF:
					var target_player: Player = system.player_manager.get_player_by_id(_target_player_id)
					_target_area = target_player.area_defensive
				_:
					push_error("无效的目标区域类型")
			var move_in := CardMoveCommand.In.new(
				_target_area,
				_moved_cards,
				_target_player_id
			)
			move_in.execute()
			current_phase = Phase.DONE
			complete()
