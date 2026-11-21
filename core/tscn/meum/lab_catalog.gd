## 实验室目录：扫描实验室根目录下的实验室场景，供菜单列出并加载。
## 只读场景文本与脚本链，不实例化场景——实例化会执行实验室的 _ready、无头看门狗与预设解析。
class_name LabCatalog
extends RefCounted

#==consts==
## 实验室根目录
const LAB_ROOT: String = "res://lab/"
## 实验室场景后缀
const SCENE_SUFFIX: String = ".tscn"
## 实验室界面根基类脚本，用于判定一个场景是不是实验室
const FACE_LAB_PATH: String = "res://lab/lab_core/FaceLab.gd"

#==public==
## 扫描实验室场景，返回按路径升序排列的场景路径；根节点脚本链未到达 FaceLab 的场景被排除
## @external
static func scan(root: String = LAB_ROOT) -> Array[String]:
	var found: Array[String] = []
	_collect(root, found)
	found.sort()
	return found

## 场景路径的显示名：取文件名，下划线分段首字母大写
## @pure
static func display_name(scene_path: String) -> String:
	var stem: String = scene_path.get_file().get_basename()
	var words: PackedStringArray = PackedStringArray()
	for part: String in stem.split("_", false):
		words.append(part.substr(0, 1).to_upper() + part.substr(1))
	return " ".join(words)

#==internal==
## 递归收集目录下合格的实验室场景
## @external
static func _collect(dir_path: String, found: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while not entry.is_empty():
		var full_path: String = dir_path.path_join(entry)
		if dir.current_is_dir():
			_collect(full_path, found)
		elif entry.ends_with(SCENE_SUFFIX) and _is_lab_scene(full_path):
			found.append(full_path)
		entry = dir.get_next()
	dir.list_dir_end()

## 场景根节点所挂脚本的继承链是否到达实验室引导壳；只读场景文本，不加载场景资源
## @external
static func _is_lab_scene(scene_path: String) -> bool:
	var script_path: String = _root_script_path(scene_path)
	if script_path.is_empty():
		return false
	var script: Script = load(script_path) as Script
	while script != null:
		if script.resource_path == FACE_LAB_PATH:
			return true
		script = script.get_base_script()
	return false

## 从场景文本里取出根节点挂的脚本路径；根节点没有脚本时返回空串
## @external
static func _root_script_path(scene_path: String) -> String:
	var file: FileAccess = FileAccess.open(scene_path, FileAccess.READ)
	if file == null:
		return ""
	var text: String = file.get_as_text()
	file.close()
	var lines: PackedStringArray = text.split("\n")
	var script_ids: Dictionary[String, String] = {}
	for line: String in lines:
		if not line.begins_with("[ext_resource") or not line.contains("type=\"Script\""):
			continue
		var path: String = _attr(line, "path")
		var id: String = _attr(line, "id")
		if not path.is_empty() and not id.is_empty():
			script_ids[id] = path
	var root_index: int = -1
	for index: int in lines.size():
		if lines[index].begins_with("[node "):
			root_index = index
			break
	if root_index < 0:
		return ""
	for index: int in range(root_index + 1, lines.size()):
		var line: String = lines[index]
		if line.begins_with("["):
			return ""
		if not line.begins_with("script = ExtResource("):
			continue
		var id: String = _resource_id(line)
		return script_ids.get(id, "")
	return ""

## 取形如 key="value" 的属性值；不存在时返回空串
## @pure
static func _attr(line: String, key: String) -> String:
	var marker: String = " " + key + "=\""
	var start: int = line.find(marker)
	if start < 0:
		return ""
	start += marker.length()
	var end: int = line.find("\"", start)
	if end < 0:
		return ""
	return line.substr(start, end - start)

## 取形如 script = ExtResource("id") 里的 id；不存在时返回空串
## @pure
static func _resource_id(line: String) -> String:
	var marker: String = "ExtResource(\""
	var start: int = line.find(marker)
	if start < 0:
		return ""
	start += marker.length()
	var end: int = line.find("\"", start)
	if end < 0:
		return ""
	return line.substr(start, end - start)
