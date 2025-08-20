extends Control
class_name RenderCard
#总控卡牌渲染和并处理交互。

@export var cardface:RenderCardFace
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
var path:Dictionary
@export var data:Array
class DefaultType:
	const ATTACK = &"attack"
	const VOID = &"void"
signal select
signal drag

func _ready()-> void:
	name = "RenderCard"
	path = GlobalConfig._resource_registry[&"cardface"]
	area.render_requested.connect(render_update)
	pass

func data_update(new_card_data:Array)-> void:
	data = new_card_data
	if !(cardface)||new_card_data[Card.BaseKeys.TYPE] != cardface.type:
		_load_scene_by_type(new_card_data[Card.BaseKeys.TYPE])
	cardface.data_update()
	pass
	
func render_update(render_event:RenderEvent = RenderEvent.new())->void:
	if cardface:
		cardface.render_update(render_event)

func _load_scene_by_type(card_type: String) -> void:
	if cardface:
		remove_child(cardface)
		cardface.queue_free()
	cardface = load(path.get(card_type, path[DefaultType.VOID])).instantiate()
	if cardface:
		cardface.card = self
		add_child(cardface)

func get_face_size()->Vector2:
	if cardface:
		return cardface.size
	else:
		return Vector2.ZERO

func request_select():
	area.on_select(pool_id)
	pass
	
func request_dragging():
	# 优化2: 拖拽时若未选中则自动选中
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
	if cardface&&Rect2(position+cardface.position,cardface.size*cardface.scale).has_point(mouse_pos):
		return true
	else:
		return false

func get_id()->int:
	return data.get(Card.BaseKeys.ID)
