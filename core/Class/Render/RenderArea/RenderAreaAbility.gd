## 技能区渲染区域：承载玩家技能区（`DefaultArea.ABILITY`）内放置的牌。
## 与 `RenderAreaHand` 同形——继承 `ItemRenderArea` 即可获得渲染项维护、选择与拖拽能力；
## 技能区是否需要特殊交互（例如只读）由后续规则决定，届时在此覆写 `_connect_item_to_area`。
extends ItemRenderArea
class_name RenderAreaAbility

## 静态区域名：供工厂与注册表在无实例时查询
static func get_area_name_static() -> StringName:
	return DefaultArea.ABILITY
