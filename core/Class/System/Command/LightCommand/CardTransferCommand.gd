extends CardMoveCommand
class_name CardTransferCommand

## 卡牌转移命令上下文（继承移动上下文，无需额外字段）
class Context extends CardMoveCommand.Context:
	pass

## 卡牌转移命令
## @param player_id: 发起者玩家ID
## @param source_area: 源区域
## @param target_area: 目标区域
## @param move_out_mode: 移出模式（默认为 TOP）
## @param move_out_param: 移出参数（根据模式不同可为 int / PackedInt32Array）
## @param name_overriding: 命令名称
## @param context_overriding: 外部传入的上下文（通常不传）
func _init(
	player_id: int,
	source_area: Area,
	target_area: Area,
	move_out_mode: Context.MoveOutMode = Context.MoveOutMode.TOP,
	move_out_param = null,
	name_overriding: StringName = &"Transfer",
	context_overriding: Context = Context.new()
) -> void:
	super._init(player_id, name_overriding, context_overriding)
	_context.source_area = source_area
	_context.target_area = target_area
	_context.move_out_mode = move_out_mode
	_context.move_out_param = move_out_param
	_context.set_event_type(RenderRequest.ItemSet.EventType.TRANSFER)
