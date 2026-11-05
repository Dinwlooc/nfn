## 实验室用例表读取：按实验室标识从全局配置表收集用例，代码里不写任何用例。
## 表内约定：\[lab:<实验室标识>\] 存该实验室的默认值（scene / timeout），\[case:<实验室标识>:<用例标识>\] 逐条用例覆盖。
class_name LabSpec
extends RefCounted

## 用例段前缀
const CASE_SECTION_PREFIX: String = "case:"
## 实验室默认值段前缀
const LAB_SECTION_PREFIX: String = "lab:"
## 缺省超时（秒）
const DEFAULT_TIMEOUT: float = 5.0

#==public==
## 读取某端某表下属于该实验室的全部用例；按用例标识排序，保证 GUI 与无头运行的顺序一致。
## 用例缺省场景由实验室默认值段补齐。
static func load_cases(scope: StringName, table_name: StringName, lab_id: StringName) -> Array[LabCase]:
	var table = GlobalConfig.get_config_table(scope, table_name)
	if table == null:
		push_error("实验室配置表缺失：%s/%s.cfg" % [scope, table_name])
		return []
	var defaults: Dictionary = table.get_section(StringName(LAB_SECTION_PREFIX + String(lab_id)))
	var cases: Array[LabCase] = []
	for section: StringName in table.sections:
		var case_id: StringName = _case_id_of(section, lab_id)
		if case_id == &"":
			continue
		var case: LabCase = _parse_case(case_id, table.get_section(section), defaults)
		if case == null:
			continue
		cases.append(case)
	cases.sort_custom(func(a: LabCase, b: LabCase) -> bool: return String(a.case_id) < String(b.case_id))
	return cases
## 单段转用例：用例没有的键从实验室默认值取；仍缺场景则告警并跳过。
static func _parse_case(case_id: StringName, row: Dictionary, defaults: Dictionary) -> LabCase:
	var scene_path: String = str(row.get("scene", defaults.get("scene", "")))
	if scene_path.is_empty():
		push_error("实验室用例缺少 scene：%s" % [case_id])
		return null
	var timeout: float = float(row.get("timeout", defaults.get("timeout", DEFAULT_TIMEOUT)))
	return LabCase.new(case_id, scene_path, _rename_keys(row.get("params", {})), _steps_of(row.get("steps", [])), _rename_keys(row.get("expect", {})), timeout)
## 步骤数组：逐项把键归一为 StringName
static func _steps_of(raw: Variant) -> Array[Dictionary]:
	var steps: Array[Dictionary] = []
	if not (raw is Array):
		return steps
	for item: Variant in raw:
		if item is Dictionary:
			steps.append(_rename_keys(item))
	return steps
## 字典键 String → StringName（配置表解析出的是 String）
static func _rename_keys(raw: Variant) -> Dictionary[StringName, Variant]:
	var result: Dictionary[StringName, Variant] = {}
	if not (raw is Dictionary):
		return result
	for key: Variant in raw:
		result[StringName(str(key))] = raw[key]
	return result
## 段名形如 case:<lab>:<case>；不属于该实验室时返回空
## @pure
static func _case_id_of(section: StringName, lab_id: StringName) -> StringName:
	var text: String = String(section)
	var prefix: String = CASE_SECTION_PREFIX + String(lab_id) + ":"
	if not text.begins_with(prefix):
		return &""
	return StringName(text.substr(prefix.length()))
