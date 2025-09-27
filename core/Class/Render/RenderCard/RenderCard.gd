##卡牌
extends Control
class_name RenderCard

@export var area:RenderArea
enum DraggingState {
	READY,          # 0 - 准备就绪
	CHECKING,       # 1 - 长按检测中
	DRAGGING,       # 2 - 长按中
	FAILED          # 3 - 长按检测失败
}
var move_state:bool = false
var pool_id:int
var selected:bool = false
var dragged:bool = false
var dragging:DraggingState = DraggingState.READY
var hovering:bool = false
var data:CardPack
var card_size = Vector2(58,88)
signal select
signal drag
signal face_update()
signal render_requested(render_event:RenderEvent)
signal data_requested

func _init(card_data:CardPack = CardPack.new()) -> void:
	data = card_data

func _ready()-> void:
	name = &"RenderCard"
	data_requested.emit()

func data_update(new_card_data:CardPack)-> void:
	data = new_card_data
	data_requested.emit()

func render_update(render_event:RenderEvent)->void:
	render_requested.emit(render_event)

func get_card_size()->Vector2:
	return card_size

func set_card_size(new_size:Vector2):
	card_size = new_size

func request_select():
	area.on_select(pool_id)
	pass

func request_dragging():
	match dragging:
		DraggingState.READY:
			dragging = DraggingState.CHECKING
			await get_tree().create_timer(0.1).timeout
			if dragging == DraggingState.CHECKING:
				area.on_drag(pool_id)
				if not selected:
					request_select()  # 自动选中
				dragging = DraggingState.DRAGGING
			elif dragging == DraggingState.FAILED:
				dragging = DraggingState.READY
		DraggingState.CHECKING:
			dragging = DraggingState.FAILED
		DraggingState.DRAGGING:
			area.on_drag(pool_id)
			dragging = DraggingState.READY

func is_hovering(mouse_pos):
	return Rect2(position,position+card_size).has_point(mouse_pos)

func get_id()->int:
	return data.id
