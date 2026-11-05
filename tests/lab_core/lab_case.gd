## 实验室用例：从配置表读出的一条可执行测试流程。
## 只承载数据；参数与期望都留在配置表里，步骤语义由 LabRunner 的步骤注册表实现。
class_name LabCase
extends RefCounted

#==fields==
## 用例标识（同一实验室内唯一）
var case_id: StringName = &""
## 目标场景路径
var scene_path: String = ""
## 参数覆盖：目标属性路径 → 值（路径以 . 分隔，根是场景实例）
var params: Dictionary[StringName, Variant] = {}
## 步骤列表：每项是以 &"kind" 区分动作的字典
var steps: Array[Dictionary] = []
## 期望键值（可缺省；由实验室场景自行解释）
var expect: Dictionary[StringName, Variant] = {}
## 单用例帧预算折算用的超时秒数
var timeout: float = 5.0

#==lifecycle==
## 构造：持有原始行数据，缺省值由读取方填入
func _init(p_case_id: StringName = &"", p_scene_path: String = "", p_params: Dictionary[StringName, Variant] = {}, p_steps: Array[Dictionary] = [], p_expect: Dictionary[StringName, Variant] = {}, p_timeout: float = 5.0) -> void:
	case_id = p_case_id
	scene_path = p_scene_path
	params = p_params
	steps = p_steps
	expect = p_expect
	timeout = p_timeout
