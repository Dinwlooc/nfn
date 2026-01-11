extends CardMoveCommand
class_name PlayCardsCommand

## 出牌命令上下文类
class Context extends CardMoveCommand.Context:
	enum TargetAreaType {
		CENTER,     # 中心区域
		PLAYER_DEF  # 玩家防御区
	}
	var source_player_id: int = 0
	var target_player_id: int = 0
	var target_area_type: TargetAreaType = TargetAreaType.PLAYER_DEF
	var card_ids: PackedInt32Array = PackedInt32Array()
	## 设置源玩家ID
	func set_source_player_id(id: int) -> void:
		source_player_id = id
	## 设置目标玩家ID
	func set_target_player_id(id: int) -> void:
		target_player_id = id
	## 设置目标区域类型
	func set_target_area_type(area_type: TargetAreaType) -> void:
		target_area_type = area_type
	## 设置卡牌ID数组
	func set_card_ids(ids: PackedInt32Array) -> void:
		card_ids = ids
	## 检查卡牌ID数组是否有效
	func are_card_ids_valid() -> bool:
		return card_ids.size() > 0
## 出牌命令
func _init(
	source_player_id: int,
	card_ids: PackedInt32Array,
	target_player_id: int,
	target_area_type: Context.TargetAreaType = Context.TargetAreaType.PLAYER_DEF,
	context = Context.new()
) -> void:
	super._init(&"PlayCards", source_player_id,	context)
	_context.set_source_player_id(source_player_id)
	_context.set_target_player_id(target_player_id)
	_context.set_target_area_type(target_area_type)
	_context.set_card_ids(card_ids)
## 覆盖父类的初始化阶段方法
func _on_init_phase(game_state: GameState, context: CardMoveCommand.Context) -> void:
	var play_context := context as Context
	if not play_context:
		push_error("PlayCardsCommand: 上下文类型错误")
		context.phase = CardMoveCommand.Context.Phase.DONE
		return
	context.source_area = game_state.player_manager.get_player_by_id(play_context.source_player_id).area_hand
	match play_context.target_area_type:
		Context.TargetAreaType.CENTER:
			context.target_area = game_state.area_center
		Context.TargetAreaType.PLAYER_DEF:
			var target_player: Player = game_state.player_manager.get_player_by_id(play_context.target_player_id)
			if target_player:
				context.target_area = target_player.area_defensive
			else:
				push_error("PlayCardsCommand: 未找到目标玩家")
				context.phase = CardMoveCommand.Context.Phase.DONE
				return
		_:
			push_error("PlayCardsCommand: 无效的目标区域类型")
			context.phase = CardMoveCommand.Context.Phase.DONE
			return
	if not play_context.are_card_ids_valid():
		push_error("PlayCardsCommand: 无效的卡牌ID数组")
		context.phase = CardMoveCommand.Context.Phase.DONE
		return
	play_context.set_id_mode(play_context.card_ids)
	context.phase = CardMoveCommand.Context.Phase.MOVE_OUT
