## 实验室界面根基类：承载实参、用例队列、观测帧推进与判定上报。
## 具体实验室的 Face 继承本类、实现界面与处理器，本类不认识任何具体游戏类。
## @template
extends Control
class_name FaceLab

#==导出==
## 实验室标识
@export var lab_id: StringName = &""
## 用例表所在端
@export var lab_scope: StringName = &"render"
## 用例表名（不含扩展名）
@export var lab_table: StringName = &"lab"
## 窗口标题
@export var lab_title: String = "实验室"
## 无头墙钟上限（秒）：超时以退出码 2 结束
@export var headless_timeout: float = 30.0

#==信号==
## 单条用例结束：{tag, ok, failures, lines}
## @emitter
signal case_finished(result: Dictionary[StringName, Variant])

#==字段==
## 返回目标场景路径；非空时退出实验室回到该场景
## @context
static var return_scene: String = ""
## 用例清单
var cases: Array[LabCase] = []
## 处理器：由具体实验室提供实现
var handler: LabHandler = null
## 操作参数库：界面侧缓存，无头为空
var data: LabData = null
## 当前用例下标
var index: int = -1
## 无头队列
var queue: Array[int] = []
## 队列游标
var queue_cursor: int = 0
## 当前用例失败数
var failures: int = 0
## 当前用例输出行
var lines: PackedStringArray = PackedStringArray()
## 累计失败数（退出码）
var total_failures: int = 0
## 剩余观测帧
var wait_frames: int = 0
## 当前用例截止时间（毫秒）
var deadline_msec: int = 0
## 是否在跑用例
var running: bool = false
## 当前用例实例
var instance: Node = null
## 无头看门狗
var watchdog: Timer = null
## 实参指定的用例
var wanted_case: StringName = &""
## 实参是否跑全部
var run_all: bool = false
## 实参是否先重载配置表
var reload_requested: bool = false
## 参数基线：全部用例声明过的属性路径在初始实例上的取值
var param_baseline: Dictionary[StringName, Variant] = {}

#==生命周期==
## @override
func _ready() -> void:
	_parse_cli()
	_hide_transition()
	if reload_requested:
		GlobalConfig.reload_config_tables()
	cases = LabSpec.load_cases(lab_scope, lab_table, lab_id)
	if not _is_headless():
		data = LabData.new()
		_build_gui()
	handler = _create_handler()
	if not _is_headless():
		return
	_start_watchdog()
	_start_cli_run()

## 主循环：观测帧走完即判定收尾
## @override
func _process(_delta: float) -> void:
	if not running:
		return
	if Time.get_ticks_msec() > deadline_msec:
		_fail("用例超时：%s" % str(_current_case().case_id))
		_finish_current_case()
		return
	if failures > 0:
		_finish_current_case()
		return
	if wait_frames > 0:
		wait_frames -= 1
		return
	_end_case()
	_finish_current_case()

#==钩子==
## 建界面：只在不无头时调用，由具体实验室实现
## @hook
func _build_gui() -> void:
	pass

## 提供处理器：由具体实验室返回自己的处理器实现
## @hook
func _create_handler() -> LabHandler:
	return null

## 用例实例的挂载容器：缺省挂在自己身上
## @hook
func _case_container() -> Node:
	return self

## 实例入树后的安置：具体实验室在此缩放、剪裁与居中
## @hook
func _attach_instance(_node: Node) -> void:
	pass
## 上报落地：默认不做事，界面覆盖以写入读数区
## @hook
func _on_reported(_text: String) -> void:
	pass

## 单条用例的期望判定：实验室覆盖以定义自己的判据
## @hook
func _end_case() -> void:
	var case: LabCase = _current_case()
	for path: StringName in case.expect:
		var actual: Variant = LabHandler.read_property(instance, String(path))
		if actual != case.expect[path]:
			_fail("期望不符：%s 实际 %s，期望 %s" % [path, str(actual), str(case.expect[path])])

## 子类自定义键位；Esc 与 R 已被基类占用
## @hook
func _lab_input(_key: InputEventKey) -> void:
	pass

## 重载配置表后重建：基类已重载表，子类在此重绘
## @hook
func _on_reload() -> void:
	pass

#==公共==
## 可用用例标识
func case_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for case: LabCase in cases:
		ids.append(case.case_id)
	return ids

## 执行指定用例（界面入口）
func start_case(case_id: StringName) -> void:
	var found: int = case_ids().find(case_id)
	if found < 0:
		report_line("未知用例：%s" % str(case_id))
		return
	index = found
	_start_current_case()

## 输出一行普通信息：同时进标准输出与日志
func report_line(text: String) -> void:
	print(text)
	push_warning(text)
	_on_reported(text)

## 输出单条用例判定：判定行进日志与读数区，失败明细只进日志
func report_result(result: Dictionary[StringName, Variant]) -> void:
	var ok: bool = bool(result.get(&"ok", false))
	report_line("RESULT %s: %s" % [str(result.get(&"tag", "?")), "PASS" if ok else "FAIL"])
	var detail: PackedStringArray = result.get(&"lines", PackedStringArray())
	for line: String in detail:
		push_warning("    " + line)

## 退出实验室
func lab_exit() -> void:
	var target: String = return_scene

#==用例推进==
## 启动当前用例：装配实例、入树、施加预设
## @internal
func _start_current_case() -> void:
	var case: LabCase = _current_case()
	failures = 0
	lines = PackedStringArray()
	wait_frames = maxi(case.wait_frames, 0)
	deadline_msec = Time.get_ticks_msec() + int(maxf(case.timeout, 0.1) * 1000.0)
	running = true
	var reused: bool = is_instance_valid(instance) and instance.scene_file_path == case.scene_path
	if reused:
		handler.reset(instance)
		_restore_baseline(instance)
		_apply_params(instance, case.params)
		_attach_instance(instance)
	if not reused:
		instance = handler.assemble(case.case_id, case.scene_path, {})
		if instance == null:
			_fail("场景实例化失败：%s" % case.scene_path)
			_finish_current_case()
			return
		_case_container().add_child(instance)
		_attach_instance(instance)
		_capture_baseline(instance)
		_apply_params(instance, case.params)
	handler.anchor(instance)
	if case.preset == &"":
		return
	var preset: Resource = handler.resolve_preset(case.preset, _preset_path(case.preset))
	if preset == null:
		_fail("预设缺失：%s" % str(case.preset))
		_finish_current_case()
		return
	handler.apply(preset, instance)

## 结束当前用例：汇总、上报、无头时推进队列
## @internal
func _finish_current_case() -> void:
	var case: LabCase = _current_case()
	var result: Dictionary[StringName, Variant] = {
		&"tag": "%s/%s" % [lab_id, case.case_id],
		&"ok": failures == 0,
		&"failures": failures,
		&"lines": lines,
	}
	running = false
	total_failures += failures
	report_result(result)
	case_finished.emit(result)
	if not _is_headless():
		return
	_advance_cli_run()

## 推进无头队列；耗尽后以失败数退出
## @internal
func _advance_cli_run() -> void:
	queue_cursor += 1
	if queue_cursor >= queue.size():
		get_tree().quit(total_failures)
		return
	index = queue[queue_cursor]
	_start_current_case()

## 当前用例；未开始时返回空用例占位
## @internal
func _current_case() -> LabCase:
	if index < 0 or index >= cases.size():
		return LabCase.new()
	return cases[index]

## 预设名到资源路径：读 [preset:<实验室标识>] 段
## @internal
func _preset_path(name: StringName) -> String:
	var table: ConfigTable = GlobalConfig.get_config_table(lab_scope, lab_table)
	if table == null:
		return ""
	var section: StringName = StringName("preset:" + String(lab_id))
	if not (section in table.sections):
		return ""
	return str(table.get_section(section).get(String(name), ""))

## 记录一次失败
## @internal
func _fail(reason: String) -> void:
	failures += 1
	lines.append("FAIL " + reason)

## 记录参数基线：取全部用例声明过的路径在未施加参数时的取值
## @internal
func _capture_baseline(node: Node) -> void:
	if not param_baseline.is_empty():
		return
	for case: LabCase in cases:
		for path: StringName in case.params:
			if param_baseline.has(path):
				continue
			param_baseline[path] = LabHandler.read_property(node, String(path))

## 还原参数基线：复用实例前把上一次用例写过的路径全部复位
## @internal
func _restore_baseline(node: Node) -> void:
	for path: StringName in param_baseline:
		LabHandler.write_property(node, String(path), param_baseline[path])

## 施加用例参数
## @internal
func _apply_params(node: Node, params: Dictionary[StringName, Variant]) -> void:
	for path: StringName in params:
		if not LabHandler.write_property(node, String(path), params[path]):
			_fail("无法写入参数路径：%s" % path)

## 键位：Esc 退出实验室，R 重载配置表并重建，其余交给子类
## @internal
func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_ESCAPE:
		lab_exit()
		return
	if key.keycode == KEY_R:
		GlobalConfig.reload_config_tables()
		_on_reload()
		return
	_lab_input(key)

#==实参与无头==
## 解析 --all / --case=<标识> / --reload
## @internal
func _parse_cli() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--case="):
			wanted_case = StringName(arg.substr("--case=".length()))
			continue
		if arg == "--all":
			run_all = true
			continue
		if arg == "--reload":
			reload_requested = true

## 无头入口：建队列并启动第一条用例
## @internal
func _start_cli_run() -> void:
	var selected: Array[StringName] = _select_cli_ids()
	if selected.is_empty():
		report_line("no cases: lab=%s scope=%s table=%s" % [lab_id, lab_scope, lab_table])
		get_tree().quit(0)
		return
	queue = []
	for case_id: StringName in selected:
		var found: int = case_ids().find(case_id)
		if found >= 0:
			queue.append(found)
	queue_cursor = 0
	index = queue[0]
	_start_current_case()

## 按实参选择用例；未给 --case 时跑全部
## @internal
func _select_cli_ids() -> Array[StringName]:
	var available: Array[StringName] = case_ids()
	if wanted_case != &"":
		if wanted_case in available:
			var one: Array[StringName] = [wanted_case]
			return one
		push_error("未知用例：%s（可用：%s）" % [wanted_case, str(available)])
		return []
	if run_all or not available.is_empty():
		return available
	return []

## @internal
func _is_headless() -> bool:
	return DisplayServer.get_name() == "headless"

## @internal
func _start_watchdog() -> void:
	watchdog = Timer.new()
	watchdog.one_shot = true
	watchdog.wait_time = maxf(headless_timeout, 1.0)
	watchdog.timeout.connect(_on_watchdog_timeout)
	add_child(watchdog)
	watchdog.start()

## 无头超时：把挂死变成可判定的失败
## @internal
func _on_watchdog_timeout() -> void:
	push_error("实验室无头运行超时：%.1f 秒" % headless_timeout)
	get_tree().quit(2)

## 隐藏全局转场黑幕
## @internal
func _hide_transition() -> void:
	var transition: Node = get_node_or_null("/root/GlobalTransition")
	if transition == null:
		return
	transition.fade_out(0.0)
