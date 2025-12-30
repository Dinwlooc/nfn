## 修饰器管理器：提供容器创建和命令处理功能
class_name ModifierManager
extends RefCounted

var game_state: GameState
var root_container: ModifierContainer  # 根容器

func _init(init_system: GameState):
	game_state = init_system
## 工厂方法：创建单射容器
func create_map_container() -> MapContainer:
	return MapContainer.new()
## 工厂方法：创建多射容器
func create_multi_map_container() -> MultiMapContainer:
	return MultiMapContainer.new()
## 工厂方法：创建多层容器
func create_multi_layer_container() -> MultiLayerContainer:
	return MultiLayerContainer.new()
## 设置根容器
func set_root_container(container: ModifierContainer) -> void:
	root_container = container
## 处理行为命令
func process_behavior(behavior: BehaviorCommand) -> void:
	if root_container:
		root_container.process_command(behavior)
