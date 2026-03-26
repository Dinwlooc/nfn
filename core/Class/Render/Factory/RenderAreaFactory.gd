extends RefCounted
class_name RenderAreaFactory

static var area_classes: Array[Script] = [RenderAreaHand,RenderAreaDefence]
static var registry: Dictionary[StringName, Script] = build_registry(area_classes)

static func build_registry(classes: Array[Script]) -> Dictionary[StringName, Script]:
	var dict: Dictionary[StringName, Script] = {}
	for script in classes:
		# 调用脚本的静态方法获取区域名称
		var area_name: StringName = script.get_area_name_static()
		dict[area_name] = script
	return dict
## 辅助方法：根据区域名称获取对应的脚本类
static func get_area_class(area_name: StringName) -> Script:
	return registry.get(area_name, null)
## 辅助方法：获取所有已注册的区域名称
static func get_registered_area_names() -> Array[StringName]:
	return registry.keys()
## 辅助方法：获取所有已注册的脚本类
static func get_registered_area_classes() -> Array[Script]:
	return registry.values()
##根据区域名称创建并返回 RenderArea 实例
static func create_area(area_name: StringName,player_id:int = -1) -> RenderArea:
	var script: Script = registry.get(area_name)
	if not script:
		push_error("RenderAreaFactory: 未注册的区域名称 '%s'" % area_name)
		return null
	return script.new(player_id) as RenderArea
