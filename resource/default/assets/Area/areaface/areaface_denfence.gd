extends AreaFace

## 原始位置（未展开时的锚点）
var original_position: Vector2
## 原始尺寸
var original_size: Vector2
## 目标位置（动画过渡用）
var area_target_position: Vector2
## 目标尺寸
var area_target_size: Vector2
## 当前卡牌群组动画的 Tween 实例
var current_card_tween: Tween = null
## 卡牌缩放因子
var total_scale_factor: float = 1.0
## 常规补间动画时长
const TWEEN_TIME: float = 0.2
## 重置动画时长（通常为 TWEEN_TIME 的一半）
const RESET_TIME: float = TWEEN_TIME / 2.0
## 选中卡牌的 Y 轴偏移量（向上抬起）
const SELECTED_Y_OFFSET: float = -5.0
## 中性缩放值（无缩放时的基准）
const SCALE_NEUTRAL: float = 1.0
## 中性旋转值（无旋转）
const ROTATION_NEUTRAL: float = 0.0

enum Mode { AUTO, MANUAL }
@export var mode: Mode = Mode.AUTO

func _ready() -> void:
	if mode == Mode.AUTO:
		request_area(RenderArea.DefaultArea.DEFENCE)
	original_position = global_position
	original_size = size
	area_target_position = original_position
	area_target_size = original_size
	_update_total_scale_factor()

func _connect_to_area(target_area: RenderArea) -> void:
	super._connect_to_area(target_area)
	if not (target_area is RenderAreaDefence):
		return
	GlobalConsole._print(["守区接入,",target_area])

## 根据区域大小、卡牌数量和第一张卡牌高度更新缩放因子
func _update_total_scale_factor() -> void:
	if not area or area.items_pool.is_empty():
		total_scale_factor = 1.0
		return
	var first_card:RenderItem = area.items_pool[0]
	var original_height:float  = first_card.size.y
	var original_width:float = first_card.size.x
	var area_width:float  = size.x
	var area_height:float  = size.y
	var n:int = area.items_pool.size()
	var s_width:float  = area_width / (n * original_width)
	var s_height:float = area_height / original_height
	total_scale_factor = min(s_width, s_height)
	total_scale_factor = clamp(total_scale_factor, 0.2, 1.0)

## 更新渲染目标位置
func render_update(render_event: RenderEvent = RenderEvent.NULL_EVENT) -> void:
	var event_type: StringName = render_event.get_type()
	if event_type == RenderEvent.DefaultType.CARD_ADD or event_type == RenderEvent.DefaultType.CARD_REMOVE:
		_update_total_scale_factor()
	target_position = UIAnimationUtils.generate_coordinates(
		area_target_position,
		area_target_size,
		area.items_pool.size()
	)
	tween_update(render_event)

## 触发卡牌移动动画
func tween_update(render_event: RenderEvent = RenderEvent.NULL_EVENT) -> void:
	card_move(render_event)

## 进入区域时的展开动画
func _into_area() -> void:
	super._into_area()
	return


## 离开区域时的收起动画
func _outto_area() -> void:
	super._outto_area()
	return

## 核心动画调度函数
func card_move(render_event: RenderEvent = RenderEvent.NULL_EVENT) -> void:
	if area.items_pool.is_empty() or target_position.is_empty():
		return
	var master_tween: Tween = create_tween()
	master_tween.set_parallel(true)
	_add_base_movement_tweens(master_tween)
	master_tween.chain()
	_add_reset_tweens(master_tween)
	if current_card_tween:
		current_card_tween.kill()
	current_card_tween = master_tween

## 为所有非拖拽卡牌添加基础位置移动动画（含总数缩放动画）
func _add_base_movement_tweens(master_tween: Tween) -> void:
	for i in area.items_pool.size():
		var card: RenderItem = area.items_pool[i]
		if card.dragged:
			continue
		var card_target_pos: Vector2 = target_position[i]
		if card.selected:
			card_target_pos.y += SELECTED_Y_OFFSET
		if card.position != card_target_pos:
			master_tween.tween_property(card, ^"position", card_target_pos, TWEEN_TIME) \
				.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_OUT)
		var target_scale: Vector2 = Vector2(total_scale_factor, total_scale_factor)
		if card.scale != target_scale:
			master_tween.tween_property(card, ^"scale", target_scale, TWEEN_TIME) \
				.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_OUT)


## 恢复所有卡牌的默认旋转和缩放（恢复到总数因子）
func _add_reset_tweens(master_tween: Tween) -> void:
	for card in area.items_pool:
		if card.dragged:
			continue
		master_tween.tween_property(card, ^"rotation", ROTATION_NEUTRAL, RESET_TIME) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		var target_scale: Vector2 = Vector2(total_scale_factor, total_scale_factor)
		master_tween.tween_property(card, ^"scale", target_scale, RESET_TIME) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
