extends ItemRenderArea
class_name RenderAreaDefence

## 静态区域名：供工厂与注册表在无实例时查询
static func get_area_name_static()->StringName:
	return DefaultArea.DEFENCE
