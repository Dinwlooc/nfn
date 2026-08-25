## HP 动画控制器：管理 HP 变化时的块更新、闪烁、渐变、背景、呼吸/颤动控制，以及粒子请求。
extends RefCounted

## 信号：请求设置块容量（新容量）
signal request_set_capacity(new_max: int)
## 信号：请求设置单个块颜色（索引，颜色，是否动画）
signal request_set_block_color(index: int, color: Color, animate: bool)
## 信号：请求两步渐变（索引，闪色，目标色，闪时长，渐时长）
signal request_two_step_gradient(index: int, flash_color: Color, target_color: Color, flash_duration: float, gradient_duration: float)
## 信号：请求闪烁块（索引，起始色，目标色，时长）
signal request_blink_block(index: int, from_color: Color, to_color: Color, duration: float)
## 信号：请求设置背景比例（比例，是否动画）
signal request_set_background_ratio(ratio: float, animate: bool)
## 信号：请求更新标签文本（当前，最大）
signal request_update_label(current: int, max: int)
## 信号：请求启用/禁用呼吸动画
signal request_breath_active(active: bool)
## 信号：请求更新颤动幅度（当前HP，最大HP）
signal request_tremor_update(hp: int, max_hp: int)
## 信号：请求启用/禁用颤动动画
signal request_tremor_active(active: bool)
## 信号：请求发射受击粒子（全局位置，损失量，比例）
signal request_emit_hit(global_pos: Vector2, hp_loss: int, hp_ratio: float)
## 信号：请求发射井喷粒子（全局位置）
signal request_emit_gush(global_pos: Vector2)

var _hp_max: int = 0
var _hp_cur: int = 0
var _initialized: bool = false

## 设置当前 HP 状态
func set_hp(hp: int, max_hp: int) -> void:
	_hp_max = max_hp
	_hp_cur = max(0, hp)

## 应用 HP 变化（old_hp, old_max, new_hp, new_max）
func apply_hp_change(old_max: int, old_cur: int, new_max: int, new_cur: int) -> void:
	var clamped_new_cur: int = max(0, new_cur)
	var clamped_old_cur: int = max(0, old_cur)

	# 1. 容量变化
	if new_max != old_max:
		request_set_capacity.emit(new_max)

	# 2. 背景比例
	var ratio: float = 1.0 if new_max == 0 else clamp(float(clamped_new_cur) / float(new_max), 0.0, 1.0)
	request_set_background_ratio.emit(ratio, true)

	# 3. 标签更新
	request_update_label.emit(clamped_new_cur, new_max)

	# 4. 处理新增块（全设为失去颜色）
	if new_max > old_max:
		for i in range(old_max, new_max):
			request_set_block_color.emit(i, C.COLOR_HP_LOST, false)

	# 5. 处理每个块的变化
	var start: int = min(clamped_old_cur, clamped_new_cur)
	var end: int = max(clamped_old_cur, clamped_new_cur) - 1
	var use_gradient: bool = ratio > 0.5
	var blink_duration: float = C.HP_BLINK_DURATION
	if not use_gradient:
		var t: float = (0.5 - ratio) / 0.5
		blink_duration = lerp(C.MIN_BLINK_DURATION, C.HP_BLINK_DURATION, t)

	for i in range(start, end + 1):
		if i >= new_max:
			break
		var old_color: Color = C.COLOR_HP_CURRENT if i < clamped_old_cur else C.COLOR_HP_LOST
		var new_color: Color = C.COLOR_HP_CURRENT if i < clamped_new_cur else C.COLOR_HP_LOST
		if old_color == new_color:
			continue
		if use_gradient:
			var flash_color: Color = Color.WHITE if new_cur > old_cur else Color.BLACK
			request_two_step_gradient.emit(i, flash_color, new_color, C.HP_TWO_STEP_FLASH_DURATION, C.HP_TWO_STEP_GRADIENT_DURATION)
		else:
			request_blink_block.emit(i, old_color, new_color, blink_duration)

	# 6. 呼吸/颤动控制
	if ratio > 0.5:
		request_breath_active.emit(true)
		request_tremor_active.emit(false)
	else:
		request_breath_active.emit(false)
		request_tremor_active.emit(clamped_new_cur > 0)
		request_tremor_update.emit(clamped_new_cur, new_max)

	# 7. 粒子发射（损失量）
	var hp_loss: int = clamped_old_cur - clamped_new_cur
	if hp_loss > 0:
		if clamped_new_cur == 0:
			# 井喷位置需由主类提供，暂发信号带占位，主类从第一个块获取位置
			request_emit_gush.emit(Vector2.ZERO)  # 主类需自行计算
		else:
			var idx: int = clamped_new_cur
			# 位置由主类根据索引计算，只发信号，主类负责获取块位置
			request_emit_hit.emit(Vector2.ZERO, hp_loss, ratio)  # 主类自行填充位置
