## 着色器实验室处理器：把组合资源装成舞台节点，并把参数写回舞台。
## 只做组装与施参，不碰场景树与界面；组合先经操作参数库取，取不到再按路径直读。
extends LabHandler
class_name ShaderLabHandler

## 解析预设：先查操作参数库，再按路径直读
func resolve_preset(name: StringName, path: String) -> Resource:
	if data != null:
		var cached: Resource = data.get_preset(name, path)
		if cached != null:
			return cached
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path)

## 执行预设：按组合重建舞台
func apply(preset: Resource, target: Node) -> void:
	var combo: ShaderLabPreset = preset as ShaderLabPreset
	var stage: ShaderStage = target as ShaderStage
	if combo == null or stage == null:
		return
	stage.compose(combo)

## 复位：按当前组合重新施加
func reset(target: Node) -> void:
	var stage: ShaderStage = target as ShaderStage
	if stage != null:
		stage.reset()
