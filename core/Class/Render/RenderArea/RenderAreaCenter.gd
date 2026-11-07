## 中心区渲染区域，继承自 ItemRenderArea 以支持显示卡牌。
## 额外处理阶段集合请求（StageSet），转发给 RenderContext。
extends ItemRenderArea
class_name RenderAreaCenter
## 返回静态区域名 "center"。
static func get_area_name_static() -> StringName:
	return DefaultArea.CENTER
## 处理渲染请求。若为阶段集合请求则单独处理，否则交给父类处理 ItemSet 等传统请求。
func process_request(request: RenderRequest) -> void:
	super.process_request(request)
	if request is RenderRequest.StageSet:
		_process_stage_set(request as RenderRequest.StageSet)

## 处理阶段集合请求：转发给渲染上下文，由状态管理器按嵌套位点合并并广播
func _process_stage_set(stage_set: RenderRequest.StageSet) -> void:
	if not render_context:
		push_error("RenderAreaCenter: render_context is null, cannot forward stage set")
		return
	render_context.notify_stage_set(stage_set)
