## 角色实验室处理器：认领角色表现接口，把操作参数预设演成受击演出。
## 只做拆包与调度，不碰场景树与界面。
extends LabHandler
class_name CharacterFaceLabHandler

#==预设==
## 解析预设：先查操作参数库，再按路径直读
func resolve_preset(name: StringName, path: String) -> Resource:
	if data != null:
		return data.get_preset(name, path)
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as CharacterFacePreset

#==执行==
## 执行预设：先复位再演，次序即本接口语义
## @override
func apply(preset: Resource, target: Node) -> void:
	var face: CharacterFace = target as CharacterFace
	var cue: CharacterFacePreset = preset as CharacterFacePreset
	if face == null or cue == null:
		return
	face.stop_damage_animation()
	face.play_damage_animation(cue.hp_damage, cue.mp_damage, cue.remaining_ratio)

## 复位：停止当前演出
## @override
func reset(target: Node) -> void:
	var face: CharacterFace = target as CharacterFace
	if face == null:
		return
	face.stop_damage_animation()

## 重新锚定：让角色把当前位姿记为演出原点
## @override
func anchor(target: Node) -> void:
	var face: CharacterFace = target as CharacterFace
	if face == null:
		return
	face.sync_anchor()
