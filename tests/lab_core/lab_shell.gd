## 实验室引导壳：实参与键位、上报、退出码与配置表重载。
## 不认识用例语义——用例标识、判定与呈现都由子类给出；零用例合法。
## @template
class_name LabShell
extends Control

#==exports==
## 实验室标识
@export var lab_id: StringName = &""
## 用例表所在端
@export var lab_scope: StringName = &"render"
## 用例表名（不含扩展名）
@export var lab_table: StringName = &"lab"
## 窗口标题
@export var lab_title: String = "实验室"
## 无头模式的墙钟上限（秒）：超时以退出码 2 结束，避免解析错误把进程挂死
@export var headless_timeout: float = 30.0

#==vars==
## 无头看门狗
var _watchdog: Timer
## 实参指定的用例标识；空表示未指定
var _wanted_case: StringName = &""
## 实参是否要求跑全部用例
var _run_all_cases: bool = false
## 实参是否要求先重载配置表
var _reload_requested: bool = false

#==lifecycle==
## @override
func _ready() -> void:
	_parse_cli()
	_hide_transition()
	if _reload_requested:
		reload_config()
	_lab_boot()
	if not _is_headless():
		return
	_start_watchdog()
	await _run_cli()

#==hooks==
## 建界面并读入用例
## @hook
func _lab_boot() -> void:
	pass

## 重载后的重建（R 键：先 reload_config 再进这里）
## @hook
func _lab_reload() -> void:
	pass

## 子类自定义键位；Esc 与 R 已被壳占用
## @hook
func _lab_input(_key: InputEventKey) -> void:
	pass

## 上报落地：默认只进日志，子类可追加到自己的读数区
## @hook
func _on_reported(_text: String) -> void:
	pass

## 可用用例标识；返回空数组即零用例实验室
## @hook
func case_ids() -> Array[StringName]:
	return []

## 执行一条用例；返回 {tag, ok, failures, lines}，failures 缺省按 ok 折算
## @hook
func run_case(_case_id: StringName) -> Dictionary[StringName, Variant]:
	return {}

#==public==
## 重载配置表；接缝默认即全局表重载，子类可换成别处数据源
## @seam
func reload_config() -> void:
	GlobalConfig.reload_config_tables()

## 输出一行普通信息：同时进标准输出与日志
func report_line(text: String) -> void:
	print(text)
	push_warning(text)
	_on_reported(text)

## 输出单条用例判定：判定行进日志与读数区，失败明细只进日志
func report_result(result: Dictionary[StringName, Variant]) -> void:
	var ok: bool = bool(result.get(&"ok", false))
	var verdict: String = "PASS" if ok else "FAIL"
	report_line("RESULT %s: %s" % [str(result.get(&"tag", "?")), verdict])
	var lines: PackedStringArray = result.get(&"lines", PackedStringArray())
	for line: String in lines:
		push_warning("    " + line)

#==internal==
## @internal
func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_ESCAPE:
		get_tree().quit(0)
		return
	if key.keycode == KEY_R:
		reload_config()
		_lab_reload()
		return
	_lab_input(key)

## 解析 --all / --case=<标识> / --reload
## @internal
func _parse_cli() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--case="):
			_wanted_case = StringName(arg.substr("--case=".length()))
			continue
		if arg == "--all":
			_run_all_cases = true
			continue
		if arg == "--reload":
			_reload_requested = true

## 无头入口：逐条执行选中用例，以失败数作为退出码
## @internal
func _run_cli() -> void:
	var selected: Array[StringName] = _select_cli_ids()
	if selected.is_empty():
		report_line("no cases: lab=%s scope=%s table=%s" % [lab_id, lab_scope, lab_table])
		get_tree().quit(0)
		return
	var failures: int = 0
	for case_id: StringName in selected:
		var result: Dictionary[StringName, Variant] = await run_case(case_id)
		var ok: bool = bool(result.get(&"ok", false))
		failures += int(result.get(&"failures", 0 if ok else 1))
		report_result(result)
	get_tree().quit(failures)

## 按实参选择用例；未给 --case 时跑全部
## @internal
func _select_cli_ids() -> Array[StringName]:
	var available: Array[StringName] = case_ids()
	var selected: Array[StringName] = []
	if _wanted_case != &"":
		if _wanted_case in available:
			selected.append(_wanted_case)
		else:
			push_error("未知用例：%s（可用：%s）" % [_wanted_case, str(available)])
		return selected
	if _run_all_cases or not available.is_empty():
		selected.assign(available)
	return selected

## 隐藏全局转场黑幕；单例缺失时只告警
## @internal
func _hide_transition() -> void:
	var transition: Node = get_node_or_null("/root/GlobalTransition")
	if transition == null:
		push_warning("全局转场单例缺失，实验室可能被黑幕覆盖")
		return
	transition.fade_out(0.0)

## @internal
func _is_headless() -> bool:
	return DisplayServer.get_name() == "headless"

## @internal
func _start_watchdog() -> void:
	_watchdog = Timer.new()
	_watchdog.one_shot = true
	_watchdog.wait_time = maxf(headless_timeout, 1.0)
	_watchdog.timeout.connect(_on_watchdog_timeout)
	add_child(_watchdog)
	_watchdog.start()

## 无头超时：把挂死变成可判定的失败
## @internal
func _on_watchdog_timeout() -> void:
	push_error("实验室无头运行超时：%.1f 秒" % headless_timeout)
	get_tree().quit(2)
