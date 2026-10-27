## Agent 管理器（插件层）：系统层与渲染层两套 AI 决策快照构建模块的部署壳。
## 只负责注册表注册、模块实例化与节拍/输入转发；具体能力在 [AgentSystemModule] 与 [AgentRenderModule]。
## 就绪时经 [GlobalRegistry] 注册（AGENT_MANAGER_TYPE）：系统层由 [AgentTrigger] 从注册表取用并接线到系统层；渲染层无触发器概念，由 [RenderControl] 直接部署。
extends Node
class_name AgentManager

## 系统层快照构建模块（原 NPCPeerManager 本体）
var system_module: AgentSystemModule = AgentSystemModule.new()
## 渲染层快照构建模块（原 AutoPlayManager 本体）
var render_module: AgentRenderModule = AgentRenderModule.new()

#== Lifecycle ==
## 就绪：渲染模块未初始化前不参与帧处理；禁用须先于注册——
## 注册表信号会在本调用栈内同步触发订阅回调（订阅方先于注册时），任何路径的初始化都不得被本方法尾部的状态覆盖。
## 当前场景 AgentManager 位于 RenderControl 之前：注册时无人订阅，渲染部署由 RenderControl._ready 订阅后的即时回调触发。
func _ready() -> void:
	set_process(false)
	set_process_unhandled_input(false)
	GlobalRegistry.register_singleton(GlobalRegistry.AGENT_MANAGER_TYPE, self)

## 退出场景树时注销，防止注册表残留悬空引用
func _exit_tree() -> void:
	GlobalRegistry.unregister_singleton(GlobalRegistry.AGENT_MANAGER_TYPE)

## 转发渲染层托管节拍（轮询判定在模块内）
## @delegates(AgentRenderModule.process_tick)
func _process(delta: float) -> void:
	render_module.process_tick(delta)

## 转发输入：CTRL 切换托管开关（消费判定在模块内）
## @override
func _unhandled_input(event: InputEvent) -> void:
	if render_module.unhandled_input(event):
		get_viewport().set_input_as_handled()

#== Public Methods ==
## 初始化 System 层快照构建模块：补齐既有 AI 玩家并订阅玩家添加信号
## @facade(AgentSystemModule.initialize)
func initialize_system(game_state: GameState) -> void:
	system_module.initialize(game_state)

## 初始化 Render 层快照构建模块：解析渲染根并启用托管节拍
## @facade
func initialize_render(render_control: RenderControl) -> void:
	if render_module.initialize(render_control):
		set_process(true)
		set_process_unhandled_input(true)
