## 实验室处理器基类：统一经输入资源类执行测试接口。
## 只负责组装与执行；组装出的对象独立存放、不入场景树，也不认识任何界面。
extends RefCounted
class_name LabHandler

#==字段==
## 已组装对象缓存：标识 → 节点（独立存放，不入树）
var assembled: Dictionary[StringName, Node] = {}
## 操作参数库；无头模式为空，此时按路径直读
var data: LabData = null

#==构造==
## 绑定可选的操作参数库
func _init(data_lib: LabData = null) -> void:
	data = data_lib

#==组装==
## 组装一个对象：按场景实例化并施加参数，结果缓存但**不入树**
func assemble(key: StringName, scene_path: String, params: Dictionary[StringName, Variant]) -> Node:
	discard(key)
	if not ResourceLoader.exists(scene_path):
		return null
	var packed: PackedScene = load(scene_path)
	var node: Node = packed.instantiate() if packed else null
	if node == null:
		return null
	for path: StringName in params:
		if not write_property(node, String(path), params[path]):
			push_warning("无法写入参数路径：%s" % path)
	assembled[key] = node
	return node

## 取出缓存对象：交出所有权并移出缓存；未组装过返回 null
func take(key: StringName) -> Node:
	if not assembled.has(key):
		return null
	var node: Node = assembled[key]
	assembled.erase(key)
	return node

## 丢弃缓存对象
func discard(key: StringName) -> void:
	if not assembled.has(key):
		return
	var node: Node = assembled[key]
	assembled.erase(key)
	if is_instance_valid(node):
		node.queue_free()

## 清空全部缓存
func clear() -> void:
	for key: StringName in assembled.keys():
		discard(key)

#==执行==
## 执行一条预设：具体处理器在此认领目标接口
## 解析预设：具体处理器在此按名取资源
## @hook
func resolve_preset(_name: StringName, _path: String) -> Resource:
	return null
## @hook
func apply(_preset: Resource, _target: Node) -> void:
	pass

## 复位到默认状态：具体处理器在此停止当前演出
## @hook
func reset(_target: Node) -> void:
	pass

## 重新锚定目标：具体处理器在被摆放后调用，使演出原点跟上当前位置
## @hook
func anchor(_target: Node) -> void:
	pass

#==属性路径==
## 按属性路径写值；途经资源先复制成副本，避免写回 res://
static func write_property(root: Object, path: String, value: Variant) -> bool:
	if root == null:
		return false
	var segments: PackedStringArray = path.split(".")
	if segments.is_empty() or segments[0].is_empty():
		return false
	var cursor: Variant = root
	for index: int in segments.size() - 1:
		cursor = descend(cursor, StringName(segments[index]))
		if cursor == null:
			return false
	var last: StringName = StringName(segments[segments.size() - 1])
	if not (cursor is Object) or not (last in cursor):
		return false
	cursor.set(last, value)
	return true

## 按属性路径读值，读不到返回 null
static func read_property(root: Object, path: String) -> Variant:
	if root == null:
		return null
	var cursor: Variant = root
	for segment: String in path.split("."):
		if not (cursor is Object) or not (StringName(segment) in cursor):
			return null
		cursor = cursor.get(StringName(segment))
	return cursor

## 下钻一层；资源在此复制成副本并写回父对象
static func descend(cursor: Variant, property: StringName) -> Variant:
	if not (cursor is Object) or not (property in cursor):
		return null
	var child: Variant = cursor.get(property)
	if child is Resource and child.resource_path != "":
		var copy: Resource = child.duplicate(true)
		copy.resource_path = ""
		cursor.set(property, copy)
		child = copy
	return child
