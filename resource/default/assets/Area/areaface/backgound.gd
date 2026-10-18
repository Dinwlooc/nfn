extends Control

## 视差目标偏移
var target_position := Vector2.ZERO
## 当前视差补间
var tween: Tween

## 就绪：关闭自动处理并忽略鼠标事件
func _ready():
	set_process(false)  # 初始时不运行_process
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # 忽略鼠标穿透

## 鼠标移动时按缩放比例反算视差目标
func _input(event):
	if event is InputEventMouseMotion && scale.x > 1:
		var mouse_pos = get_global_mouse_position()
		mouse_pos.x = clamp(mouse_pos.x, 0, 1600)
		mouse_pos.y = clamp(mouse_pos.y, 0, 900)
		target_position = -mouse_pos * (scale.x - 1)
		start_tween()
## 启动视差补间（指数缓出）
func start_tween():
	if tween:
		tween.kill()  # 停止现有缓动
	tween = create_tween()
	tween.set_trans(Tween.TRANS_EXPO)    # 使用正弦过渡平滑加速减速
	tween.set_ease(Tween.EASE_OUT)       # 缓出效果（平滑结束）
	tween.tween_property(self, ^"position", target_position, 3.0)
