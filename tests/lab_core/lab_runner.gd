## 实验室执行器：把用例场景实例化到舞台上，施加参数、按步骤派发并给出判定。
## 不退出进程、不持有界面；退出与实参解析在实验室场景的引导层。
## 参数只写进资源副本，绝不把改动写回 res://。
class_name LabRunner
extends RefCounted

## 步骤处理器注册表：步骤 kind → 处理器；新增动作只注册处理器，不改本类
var _handlers: Dictionary[StringName, Callable] = {}
## 用例宿主（提供场景树与舞台容器）
var _host: Node
## 当前用例场景实例
var _instance: Node = null
## 当前用例输出行
var _lines: PackedStringArray = PackedStringArray()
## 当前用例失败数
var _failures: int = 0
## 剩余等待帧预算（由用例超时折算）
var _frame_budget: int = 0

#==lifecycle==
## 构造：绑定宿主并注册内置步骤动作
func _init(host: Node) -> void:
	_host = host
	_handlers[&"call"] = _step_call
	_handlers[&"set"] = _step_set
	_handlers[&"wait"] = _step_wait

#==public==
## 执行一条用例；返回 {tag, ok, failures, lines}
func run_case(lab_id: StringName, case: LabCase) -> Dictionary[StringName, Variant]:
	_failures = 0
	_lines = PackedStringArray()
	_instance = null
	_frame_budget = int(maxf(case.timeout, 0.1) * float(Engine.get_physics_ticks_per_second()))
	var deadline_msec: int = Time.get_ticks_msec() + int(maxf(case.timeout, 0.1) * 1000.0)
	if not ResourceLoader.exists(case.scene_path):
		_fail("场景不存在：%s" % case.scene_path)
		return _result(lab_id, case)
	var packed: PackedScene = load(case.scene_path)
	_instance = packed.instantiate() if packed else null
	if _instance == null:
		_fail("场景实例化失败：%s" % case.scene_path)
		return _result(lab_id, case)
	# 参数先于入树施加，场景 _ready 时即可读到预设值
	_apply_params(case.params)
	_host.get_case_container().add_child(_instance)
	await _host.get_tree().process_frame
	for step: Dictionary in case.steps:
		if Time.get_ticks_msec() > deadline_msec:
			_fail("用例超时：%.1f 秒" % case.timeout)
			break
		var kind: StringName = StringName(str(step.get(&"kind", "")))
		if not _handlers.has(kind):
			_fail("未知步骤动作：%s" % kind)
			break
		await _handlers[kind].call(step)
		if _failures > 0:
			break
	_check_expect(case.expect)
	_release()
	return _result(lab_id, case)

#==steps==
## 步骤：调用目标方法
## @internal
func _step_call(step: Dictionary) -> void:
	var method: StringName = StringName(str(step.get(&"method", "")))
	var target: Node = _resolve_node(str(step.get(&"target", ".")))
	if target == null or method == &"" or not target.has_method(method):
		_fail("无法调用：target=%s method=%s" % [str(step.get(&"target", ".")), method])
		return
	var args: Array = step.get(&"args", []).duplicate()
	target.callv(method, args)
## 步骤：写目标属性（路径以 . 分隔）
## @internal
func _step_set(step: Dictionary) -> void:
	var path: String = str(step.get(&"path", ""))
	if not _assign(path, step.get(&"value", null)):
		_fail("无法写入路径：%s" % path)
## 步骤：等待若干帧，消耗帧预算
## @internal
func _step_wait(step: Dictionary) -> void:
	var frames: int = maxi(int(step.get(&"frames", 1)), 1)
	if frames > _frame_budget:
		_fail("帧预算耗尽：需要 %d，剩余 %d" % [frames, _frame_budget])
		return
	_frame_budget -= frames
	for index: int in frames:
		await _host.get_tree().process_frame

#==internal==
## 施加用例参数
## @internal
func _apply_params(params: Dictionary[StringName, Variant]) -> void:
	for path: StringName in params:
		if not _assign(String(path), params[path]):
			_fail("无法写入参数路径：%s" % path)
## 按属性路径写值；途经资源先复制，避免写回磁盘
## @internal
func _assign(path: String, value: Variant) -> bool:
	var segments: PackedStringArray = path.split(".")
	if segments.is_empty() or segments[0].is_empty():
		return false
	var cursor: Variant = _instance
	for index: int in segments.size() - 1:
		cursor = _descend(cursor, StringName(segments[index]))
		if cursor == null:
			return false
	var last: StringName = StringName(segments[segments.size() - 1])
	if not (cursor is Object) or not (last in cursor):
		return false
	cursor.set(last, value)
	return true
## 下钻一层；资源在此复制成副本并写回父对象
## @internal
func _descend(cursor: Variant, property: StringName) -> Variant:
	if not (cursor is Object) or not (property in cursor):
		return null
	var child: Variant = cursor.get(property)
	if child is Resource and child.resource_path != "":
		var copy: Resource = child.duplicate(true)
		copy.resource_path = ""
		cursor.set(property, copy)
		child = copy
	return child
## 按属性路径读值，读不到返回 null
## @internal
func _read(path: String) -> Variant:
	var cursor: Variant = _instance
	for segment: String in path.split("."):
		if not (cursor is Object) or not (StringName(segment) in cursor):
			return null
		cursor = cursor.get(StringName(segment))
	return cursor
## 解释用例期望键值
## @internal
func _check_expect(expect: Dictionary[StringName, Variant]) -> void:
	for path: StringName in expect:
		var actual: Variant = _read(String(path))
		if actual != expect[path]:
			_fail("期望不符：%s 实际 %s，期望 %s" % [path, str(actual), str(expect[path])])
## 取用例实例上的节点；空或 . 表示实例根
## @internal
func _resolve_node(selector: String) -> Node:
	if selector.is_empty() or selector == ".":
		return _instance
	return _instance.get_node_or_null(selector)
## 记录一次失败
## @internal
func _fail(reason: String) -> void:
	_failures += 1
	_lines.append("FAIL " + reason)
## 回收用例实例
## @internal
func _release() -> void:
	if is_instance_valid(_instance):
		_instance.queue_free()
	_instance = null
## 汇总判定
## @internal
func _result(lab_id: StringName, case: LabCase) -> Dictionary[StringName, Variant]:
	var tag: String = "%s/%s" % [lab_id, case.case_id]
	return { &"tag": tag, &"ok": _failures == 0, &"failures": _failures, &"lines": _lines }
