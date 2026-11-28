## 实验室界面根基类：承载实参、预设清单、观测帧推进与判定上报。
## 具体实验室的 Face 继承本类、实现界面与处理器，本类不认识任何具体游戏类。
## @template
extends Control
class_name FaceLab

#==导出==
## 实验室标识
@export var lab_id: StringName = &""
## 预设表所在端
@export var lab_scope: StringName = &"render"
## 预设表名（不含扩展名）
@export var lab_table: StringName = &"lab"
## 窗口标题
@export var lab_title: String = "实验室"
## 无头墙钟上限（秒）：超时以退出码 2 结束
@export var headless_timeout: float = 30.0

#==信号==
## 单条预设结束：{tag, ok, failures, lines}
## @emitter
signal preset_finished(result: Dictionary[StringName, Variant])

#==字段==
## 返回目标场景路径；非空时退出实验室回到该场景（静态，跨实验室共享）
static var return_scene: String = ""
## 预设清单，按名排序
var presets: Array[StringName] = []
## 预设名 → 观测帧数
var observe: Dictionary[StringName, int] = {}
## 单次呈现的超时秒数，取自实验室默认值段
var run_timeout: float = 5.0
## 处理器：由具体实验室提供实现
var handler: LabHandler = null
## 操作参数库：界面侧缓存，无头为空
var data: LabData = null
## 当前预设下标
var index: int = -1
## 无头队列
var queue: Array[int] = []
## 队列游标
var queue_cursor: int = 0
## 当前预设失败数
var failures: int = 0
## 当前预设输出行
var lines: PackedStringArray = PackedStringArray()
## 累计失败数（退出码）
var total_failures: int = 0
## 剩余观测帧
var wait_frames: int = 0
## 当前预设截止时间（毫秒）
var deadline_msec: int = 0
## 是否在跑预设
var running: bool = false
## 当前预设实例
var instance: Node = null
## 无头看门狗
var watchdog: Timer = null
## 实参指定的预设
var wanted_preset: StringName = &""
## 实参是否跑全部
var run_all: bool = false
## 实参是否先重载配置表
var reload_requested: bool = false
#==常量==
## 缺省超时（秒）
const DEFAULT_TIMEOUT: float = 5.0
#==生命周期==
## @override
func _ready() -> void:
	_parse_cli()
	_hide_transition()
	if reload_requested:
		GlobalConfig.reload_config_tables()
	_load_table()
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
		_fail("预设超时：%s" % str(_current_preset()))
		_finish_current()
		return
	if failures > 0:
		_finish_current()
		return
	if wait_frames > 0:
		wait_frames -= 1
		return
	_end_preset()
	_finish_current()

#==钩子==
## 判据入口：建参数库、读表、界面与处理器，不解析实参、不起无头队列
## @hook
func _lab_boot() -> void:
	data = LabData.new()
	_load_table()
	_build_gui()
	handler = _create_handler()

## 建界面：只在不无头时调用，由具体实验室实现
## @hook
func _build_gui() -> void:
	pass

## 提供处理器：由具体实验室返回自己的处理器实现
## @hook
func _create_handler() -> LabHandler:
	return null

## 预设实例的挂载容器：缺省挂在自己身上
## @hook
func _preset_container() -> Node:
	return self

## 实例入树后的安置：具体实验室在此缩放、剪裁与居中
## @hook
func _attach_instance(_node: Node) -> void:
	pass

## 上报落地：默认不做事，界面覆盖以写入读数区
## @hook
func _on_reported(_text: String) -> void:
	pass

## 单条预设的判定扩展点：实验室覆盖以追加自己的判据
## @hook
func _end_preset() -> void:
	pass

## 子类自定义键位；Esc 与 R 已被基类占用
## @hook
func _lab_input(_key: InputEventKey) -> void:
	pass

## 重载配置表后重建：基类已重载表，子类在此重绘
## @hook
func _on_reload() -> void:
	pass

#==公共==
## 可用预设标识
func preset_ids() -> Array[StringName]:
	return presets.duplicate()

## 执行指定预设（界面入口）
func start_preset(preset_id: StringName) -> void:
	var found: int = presets.find(preset_id)
	if found < 0:
		report_line("未知预设：%s" % str(preset_id))
		return
	index = found
	_start_current()

## 输出一行普通信息：同时进标准输出与日志
func report_line(text: String) -> void:
	print(text)
	push_warning(text)
	_on_reported(text)

## 输出单条预设判定：判定行进日志与读数区，失败明细只进日志
func report_result(result: Dictionary[StringName, Variant]) -> void:
	var ok: bool = bool(result.get(&"ok", false))
	report_line("RESULT %s: %s" % [str(result.get(&"tag", "?")), "PASS" if ok else "FAIL"])
	var detail: PackedStringArray = result.get(&"lines", PackedStringArray())
	for line: String in detail:
		push_warning("    " + line)

## 退出实验室
func lab_exit() -> void:
	var target: String = return_scene
	if target.is_empty():
		get_tree().quit()
		return
	GlobalTransition.change_scene_with_transition(target)

#==预设推进==
## 启动当前预设：装配实例、入树、施加预设
## @internal
func _start_current() -> void:
	var preset_id: StringName = _current_preset()
	failures = 0
	lines = PackedStringArray()
	wait_frames = maxi(_observe_frames(preset_id), 0)
	deadline_msec = Time.get_ticks_msec() + int(maxf(run_timeout, 0.1) * 1000.0)
	running = true
	if _reuse_instance():
		handler.reset(instance)
		_attach_instance(instance)
	if instance == null:
		_mount_instance(preset_id)
		if instance == null:
			_finish_current()
			return
	handler.anchor(instance)
	var preset: Resource = handler.resolve_preset(preset_id, _preset_path(preset_id))
	if preset == null:
		_fail("预设缺失：%s" % str(preset_id))
		_finish_current()
		return
	handler.apply(preset, instance)

## 复用判定：同场景的实例留着不重建
## @internal
func _reuse_instance() -> bool:
	if not is_instance_valid(instance):
		return false
	return instance.scene_file_path == _scene_path()

## 装配并挂载当前预设的实例
## @internal
func _mount_instance(preset_id: StringName) -> void:
	instance = handler.assemble(preset_id, _scene_path(), {})
	if instance == null:
		_fail("场景实例化失败：%s" % _scene_path())
		return
	_preset_container().add_child(instance)
	_attach_instance(instance)

## 结束当前预设：汇总、上报、无头时推进队列
## @internal
func _finish_current() -> void:
	var result: Dictionary[StringName, Variant] = {
		&"tag": "%s/%s" % [lab_id, _current_preset()],
		&"ok": failures == 0,
		&"failures": failures,
		&"lines": lines,
	}
	running = false
	total_failures += failures
	report_result(result)
	preset_finished.emit(result)
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
	_start_current()

## 当前预设；未开始时返回空名
## @internal
func _current_preset() -> StringName:
	if index < 0 or index >= presets.size():
		return &""
	return presets[index]

## 预设名到资源路径：读 [preset:<实验室标识>] 段
## @internal
func _preset_path(name_overriding: StringName) -> String:
	var table: ConfigTable = GlobalConfig.get_config_table(lab_scope, lab_table)
	if table == null:
		return ""
	var section: StringName = StringName("preset:" + String(lab_id))
	if not (section in table.sections):
		return ""
	return str(table.get_section(section).get(String(name_overriding), ""))

## 实验室场景路径：读 [lab:<实验室标识>] 段
## @internal
func _scene_path() -> String:
	var table: ConfigTable = GlobalConfig.get_config_table(lab_scope, lab_table)
	if table == null:
		return ""
	var section: StringName = StringName("lab:" + String(lab_id))
	if not (section in table.sections):
		return ""
	return str(table.get_section(section).get("scene", ""))

## 某预设的观测帧数
## @internal
func _observe_frames(name_overriding: StringName) -> int:
	return observe.get(name_overriding, 0)

## 记录一次失败
## @internal
func _fail(reason: String) -> void:
	failures += 1
	lines.append("FAIL " + reason)

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
		_load_table()
		_on_reload()
		return
	_lab_input(key)

#==实参与无头==
## 解析 --all / --preset=<标识> / --reload
## @internal
func _parse_cli() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--preset="):
			wanted_preset = StringName(arg.substr("--preset=".length()))
			continue
		if arg == "--all":
			run_all = true
			continue
		if arg == "--reload":
			reload_requested = true

## 无头入口：建队列并启动第一条预设
## @internal
func _start_cli_run() -> void:
	var selected: Array[StringName] = _select_cli_presets()
	if selected.is_empty():
		report_line("no presets: lab=%s scope=%s table=%s" % [lab_id, lab_scope, lab_table])
		get_tree().quit(0)
		return
	queue = []
	for preset_id: StringName in selected:
		var found: int = presets.find(preset_id)
		if found >= 0:
			queue.append(found)
	queue_cursor = 0
	index = queue[0]
	_start_current()

## 按实参选择预设；未给 --preset 时跑全部
## @internal
func _select_cli_presets() -> Array[StringName]:
	if wanted_preset != &"":
		if wanted_preset in presets:
			var one: Array[StringName] = [wanted_preset]
			return one
		push_error("未知预设：%s（可用：%s）" % [wanted_preset, str(presets)])
		return []
	return presets.duplicate()

#==读表==
## 读本实验室的表：预设清单、观测帧与默认超时
## @internal
func _load_table() -> void:
	presets = _load_preset_ids(lab_scope, lab_table, lab_id)
	observe = _load_observe(lab_scope, lab_table, lab_id)
	run_timeout = _load_timeout(lab_scope, lab_table, lab_id)

## 读预设清单：以观测帧段的键为准，缺该段时取预设段的键；按名排序，界面与无头顺序一致
static func _load_preset_ids(scope: StringName, table_name: StringName, lab_id_overriding: StringName) -> Array[StringName]:
	var table: ConfigTable = GlobalConfig.get_config_table(scope, table_name)
	if table == null:
		push_error("实验室配置表缺失：%s/%s.cfg" % [scope, table_name])
		return []
	var ids: Array[StringName] = _section_keys(table, StringName("observe:" + String(lab_id_overriding)))
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return ids

## 读观测帧：预设名 → 帧数
static func _load_observe(scope: StringName, table_name: StringName, lab_id_overriding: StringName) -> Dictionary[StringName, int]:
	var frames: Dictionary[StringName, int] = {}
	var table: ConfigTable = GlobalConfig.get_config_table(scope, table_name)
	if table == null:
		return frames
	var section: StringName = StringName("observe:" + String(lab_id_overriding))
	var row: Dictionary = table.get_section(section)
	for key: StringName in _section_keys(table, section):
		frames[key] = int(row.get(String(key), 0))
	return frames

## 读默认超时：取实验室默认值段的 timeout
static func _load_timeout(scope: StringName, table_name: StringName, lab_id_overriding: StringName) -> float:
	var table: ConfigTable = GlobalConfig.get_config_table(scope, table_name)
	if table == null:
		return DEFAULT_TIMEOUT
	var row: Dictionary = table.get_section(StringName("lab:" + String(lab_id_overriding)))
	return float(row.get("timeout", DEFAULT_TIMEOUT))

## 某段的全部键；段不存在时返回空
## @pure
static func _section_keys(table: ConfigTable, section: StringName) -> Array[StringName]:
	var keys: Array[StringName] = []
	if table == null or not (section in table.sections):
		return keys
	var row: Dictionary = table.get_section(section)
	for key: Variant in row:
		keys.append(StringName(str(key)))
	return keys

#==环境==
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
