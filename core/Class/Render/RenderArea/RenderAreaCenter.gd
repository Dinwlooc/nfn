## 中心区渲染区域，继承自 ItemRenderArea 以支持显示卡牌。
## 额外处理阶段通知请求（StageNotifyRequest），转发给 RenderContext。
extends ItemRenderArea
class_name RenderAreaCenter
## 返回静态区域名 "center"，与 StageNotifyRequest 的 target_area 匹配。
static func get_area_name_static() -> StringName:
	return DefaultArea.CENTER

## 处理渲染请求。若为阶段通知则单独处理，否则交给父类处理 ItemSet 等传统请求。
func process_request(request: RenderRequest) -> void:
	super.process_request(request)
	if request is RenderRequest.StageNotifyRequest:
		_process_stage_notify(request as RenderRequest.StageNotifyRequest)
		return
## 处理阶段通知请求：将阶段信息传递给全局 RenderContext，由其发射信号通知其他模块。
func _process_stage_notify(notify: RenderRequest.StageNotifyRequest) -> void:
	if not render_context:
		push_error("RenderAreaCenter: render_context is null, cannot forward stage notification")
		return
	render_context.notify_stage(notify.stage_name, notify.current_player_id, notify.custom_params)
