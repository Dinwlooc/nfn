## 单箭头控件：节点位置为箭头尖端，尾部在目标反方向，矩形尾部中心即线的起终点。
extends Control
class_name ArrowNode

enum State { HIDDEN, TRANSITION, STABLE }

## 隐藏时被移到的屏幕外坐标
const HIDDEN_POSITION: Vector2 = Vector2(-100.0, -100.0)
## 显示过渡动画时长（秒）
const SHOW_DURATION: float = 0.35
## 隐藏过渡动画时长（秒）
const HIDE_DURATION: float = 0.4
## 指向目标时反方向预留的默认余量（像素）
const DEFAULT_MARGIN: float = 10.0

## 箭头颜色
@export var arrow_color: Color = Color.AQUA

## 当前状态
var state: State = State.HIDDEN
## 当前箭头朝向（从尾部指向尖端的单位向量），用于外部查询，绘制不再依赖
var direction: Vector2 = Vector2.UP
## 当前 Tween
var current_tween: Tween = null

const WING_WIDTH: float = 20.0
const WING_HEIGHT: float = 6.0
const ARROW_HALF_WIDTH: float = 8.0
const ARROW_HEIGHT: float = 12.0
const TAIL_HEIGHT: float = 8.0
const TAIL_WIDTH_FACTOR: float = 1.0 / 3.0

func _ready() -> void:
	global_position = HIDDEN_POSITION
	state = State.HIDDEN
	rotation = 0.0

## 重置箭头至隐藏状态
func reset() -> void:
	if current_tween and current_tween.is_valid():
		current_tween.kill()
	current_tween = null
	state = State.HIDDEN

## 设置箭头尖端到目标点，并指定朝向（从尾部指向尖端）
func point_to(target: Vector2, dir: Vector2) -> void:
	direction = dir.normalized()
	if current_tween and current_tween.is_valid():
		current_tween.kill()
	state = State.TRANSITION
	current_tween = create_tween()
	current_tween.set_parallel(true)
	current_tween.tween_property(self, ^"global_position", target, SHOW_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	current_tween.tween_property(self, ^"rotation", direction.angle() + PI / 2, SHOW_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	current_tween.chain()
	current_tween.tween_callback(_on_stable)

## 便捷方法，在目标点反方向预留余量，避免箭头直接戳到物体
func point_to_target(target: Vector2, dir: Vector2, margin: float = DEFAULT_MARGIN) -> void:
	var norm_dir: Vector2 = dir.normalized()
	var offset_target: Vector2 = target - norm_dir * margin
	point_to(offset_target, dir)

## 返回尾部在局部坐标系中的位置（矩形远端边中心，基于固定向上方向）
func get_tail_local() -> Vector2:
	const UP: Vector2 = Vector2.UP
	return -UP * (ARROW_HEIGHT + TAIL_HEIGHT)

## 返回尾部全局坐标（应用节点旋转）
func get_tail_global() -> Vector2:
	return global_position + get_tail_local().rotated(rotation)

func hide_arrow() -> void:
	if state == State.HIDDEN:
		return
	if current_tween and current_tween.is_valid():
		current_tween.kill()
	state = State.TRANSITION
	current_tween = create_tween().set_parallel(true)
	current_tween.tween_property(self, ^"global_position", HIDDEN_POSITION, HIDE_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	current_tween.chain()
	current_tween.tween_callback(_on_hidden)

func _on_hidden() -> void:
	state = State.HIDDEN

func _on_stable() -> void:
	state = State.STABLE

func _draw() -> void:
	const UP: Vector2 = Vector2.UP
	var perp: Vector2 = Vector2(-UP.y, UP.x)
	var base_center: Vector2 = -UP * ARROW_HEIGHT
	var base_width: float = ARROW_HALF_WIDTH * 2.0
	var base_half: float = base_width * 0.5
	var base_left: Vector2 = base_center - perp * base_half
	var base_right: Vector2 = base_center + perp * base_half
	var tip: Vector2 = Vector2.ZERO
	var tail_pos: Vector2 = get_tail_local()
	var rect_width: float = base_width * TAIL_WIDTH_FACTOR
	var rect_half_width: float = rect_width * 0.5
	var far_left: Vector2 = tail_pos - perp * rect_half_width
	var far_right: Vector2 = tail_pos + perp * rect_half_width
	var near_left: Vector2 = base_center - perp * rect_half_width
	var near_right: Vector2 = base_center + perp * rect_half_width
	draw_colored_polygon(PackedVector2Array([far_left, far_right, near_right, near_left]), arrow_color)
	draw_colored_polygon(PackedVector2Array([base_right, base_left, tip]), arrow_color)

# ==================== 静态工具函数 ====================

## 计算卡片顶部中心全局坐标
static func get_card_top_center_global(card: RenderItem) -> Vector2:
	var card_size: Vector2 = card.get_item_size()
	return card.global_position + Vector2(card_size.x / 2, 0)

## 计算卡片底部中心全局坐标
static func get_card_bottom_center_global(card: RenderItem) -> Vector2:
	var card_size: Vector2 = card.get_item_size()
	return card.global_position + Vector2(card_size.x / 2, card_size.y)
