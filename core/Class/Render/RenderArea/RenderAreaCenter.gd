## 中心区渲染区域，继承自 ItemRenderArea 以支持显示卡牌。
## 额外处理阶段通知请求（StageNotifyRequest），转发给 RenderContext。
extends ItemRenderArea
class_name RenderAreaCenter
## 返回静态区域名 "center"。
static func get_area_name_static() -> StringName:
	return DefaultArea.CENTER
## 处理渲染请求。若为阶段通知则单独处理，否则交给父类处理 ItemSet 等传统请求。
func process_request(request: RenderRequest) -> void:
	super.process_request(request)
	if request is RenderRequest.StageNotifyRequest:
		_process_stage_notify(request as RenderRequest.StageNotifyRequest)
		return
## 处理阶段通知请求：根据 temporary_stage_player_id 判断主/临时阶段并转发。
func _process_stage_notify(notify: RenderRequest.StageNotifyRequest) -> void:
	if not render_context:
		push_error("RenderAreaCenter: render_context is null, cannot forward stage notification")
		return
	if notify.temporary_stage_player_id != 0:
		render_context.notify_temp_stage(notify.stage_name, notify.current_player_id, notify.temporary_stage_player_id, notify.custom_params)
	else:
		render_context.notify_main_stage(notify.stage_name, notify.current_player_id, notify.custom_params)
