extends ItemRenderArea
class_name RenderAreaDefence

## 当前守区结算次数
var settle_count: int = 0
## 最近一次结算的结算牌 id（无则 -1）
var settle_card_id: int = -1
## 最近一次结算的对抗牌 id（无则 -1）
var oppose_card_id: int = -1
## 最近一次收到的主阶段名（用于识别主阶段切换）
var _last_main_stage_name: StringName = &""

## 静态区域名：供工厂与注册表在无实例时查询
static func get_area_name_static()->StringName:
	return DefaultArea.DEFENCE

## 请求入口：结算摘要单独处理，其余交给父类
func process_request(request: RenderRequest) -> void:
	super.process_request(request)
	if request is RenderRequest.SettleSet:
		_process_settle_set(request as RenderRequest.SettleSet)

## 绑定渲染上下文：更换上下文时断开旧上下文的主阶段监听
## @override @signal_listener
func set_render_context(context: RenderContext) -> void:
	if render_context:
		render_context.state_manager.main_stage_notified.disconnect(_on_main_stage_notified)
	super.set_render_context(context)
	if render_context:
		render_context.state_manager.main_stage_notified.connect(_on_main_stage_notified)

## 处理结算摘要请求：记录结算计数与结算牌 / 对抗牌 id
func _process_settle_set(settle_set: RenderRequest.SettleSet) -> void:
	settle_count = settle_set.settle_count
	settle_card_id = settle_set.settle_card_id
	oppose_card_id = settle_set.oppose_card_id

## 主阶段切换：离开 Main 阶段时清零结算计数（Main 内的临时阶段不触发）
## @signal_listener
func _on_main_stage_notified(stage_name: StringName, _player_id: int, _params: Dictionary) -> void:
	if _last_main_stage_name == &"Main" and stage_name != &"Main":
		settle_count = 0
	_last_main_stage_name = stage_name

## 退出场景树：断开主阶段监听
## @override
func _exit_tree() -> void:
	if render_context:
		render_context.state_manager.main_stage_notified.disconnect(_on_main_stage_notified)
	super._exit_tree()
