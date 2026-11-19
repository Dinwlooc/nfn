## 实验室操作参数库：缓存测试接口需要的数据体资源。
## 只在界面侧构造；无头模式不构造它，处理器直接从配置表按路径加载。
## 只认 Resource，不认任何具体预设类型——具体类型的判定留给处理器。
extends RefCounted
class_name LabData

#==字段==
## 已解析的数据体资源：预设名 → 资源
var presets: Dictionary[StringName, Resource] = {}

#==公共==
## 取预设：命中缓存直接返回，未命中按路径加载并缓存
func get_preset(name: StringName, path: String) -> Resource:
	if presets.has(name):
		return presets[name]
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var preset: Resource = load(path)
	if preset == null:
		return null
	presets[name] = preset
	return preset

## 放入一份组合：覆盖同名项，供处理器按名解析
## @side_effect
func put_preset(name: StringName, preset: Resource) -> void:
	if preset == null:
		presets.erase(name)
		return
	presets[name] = preset

## 清空缓存：换预设集或重载配置表后调用
func clear() -> void:
	presets.clear()
