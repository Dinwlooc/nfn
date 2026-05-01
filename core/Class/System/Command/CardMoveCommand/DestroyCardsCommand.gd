extends CardMoveCommand
class_name DestroyCardsCommand

## 摧毁命令上下文类
class Context extends CardMoveCommand.Context:
	var source_player: Player = null       ## 实施摧毁的玩家（可为空）
	var source_card: Card = null           ## 实施摧毁的卡牌（可为空）
	var target_card_id: int = 0           ## 要摧毁的目标卡牌ID
	var target_defense_area: AreaDefence = null  ## 目标守区

	## 设置实施摧毁的玩家
	func set_source_player(player: Player) -> void:
		source_player = player

	## 设置实施摧毁的卡牌
	func set_source_card(card: Card) -> void:
		source_card = card

	## 设置目标卡牌ID
	func set_target_card_id(id: int) -> void:
		target_card_id = id

	## 设置目标守区
	func set_target_defense_area(area: AreaDefence) -> void:
		target_defense_area = area

## 摧毁命令：将目标守区中的一张卡牌移至弃牌堆
## @param player_id: 命令发起者ID
## @param target_defense_area: 目标守区
## @param target_card_id: 要摧毁的卡牌ID
## @param source_player: 实施摧毁的玩家（可选，可为空）
## @param source_card: 实施摧毁的卡牌（可选，可为空）
## @param name_overriding: 命令名称
## @param context_overriding: 外部传入的上下文（通常不传）
func _init(
	player_id: int,
	target_defense_area: AreaDefence,
	target_card_id: int,
	source_player: Player = null,
	source_card: Card = null,
	name_overriding: StringName = &"DestroyCards",
	context_overriding: Context = Context.new()
) -> void:
	super._init(player_id, name_overriding, context_overriding)
	_context.set_target_defense_area(target_defense_area)
	_context.set_target_card_id(target_card_id)
	_context.set_source_player(source_player)
	_context.set_source_card(source_card)
	_context.set_event_type(RenderRequest.ItemSet.EventType.DEATH)

## 初始化阶段：检查目标卡牌所在，若不在目标守区则取消命令
func _on_init_phase(game_state: GameState) -> void:
	var ctx := _context as Context
	if not ctx:
		push_error("DestroyCardsCommand: 上下文类型错误")
		_context.phase = CardMoveCommand.Context.Phase.DONE
		return
	if not ctx.target_defense_area:
		push_error("DestroyCardsCommand: 目标守区未设置")
		_context.phase = CardMoveCommand.Context.Phase.DONE
		return
	# 从目标守区查询目标卡牌
	var cards: Array[Card] = ctx.target_defense_area.get_cards_by_ids(PackedInt32Array([ctx.target_card_id]))
	if cards.is_empty():
		# 卡牌不在目标守区，摧毁取消，直接完成
		GlobalConsole._print(["DestroyCardsCommand: 目标卡牌不在目标守区，取消摧毁。"])
		_context.phase = CardMoveCommand.Context.Phase.DONE
		return
	# 设置源区域与移出模式
	_context.source_area = ctx.target_defense_area
	_context.target_area = game_state.area_discard
	_context.set_id_mode(PackedInt32Array([ctx.target_card_id]))
	_context.phase = CardMoveCommand.Context.Phase.MOVE_OUT
