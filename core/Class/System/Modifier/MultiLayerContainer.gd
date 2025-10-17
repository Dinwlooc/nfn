## 多层容器：存储子容器并实现环形轮询策略
extends ModifierContainer
class_name MultiLayerContainer

var children: Array[ModifierContainer] = []  # 子容器数组
var start_index: int = 0  # 当前轮询起点索引

## 添加子容器
func add_child_container(container: ModifierContainer) -> void:
	children.append(container)
## 处理命令（环形轮询策略）
func process_command(command: BehaviorCommand) -> void:
	if children.is_empty():
		return
	var count = children.size()
	for i in range(count):
		var idx = (start_index + i) % count
		children[idx].process_command(command)
