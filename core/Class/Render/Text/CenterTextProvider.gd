## 中央文本生成器基类：由管理器部署，被驱动时依渲染上下文输出一路文本。
@abstract
extends RefCounted
class_name CenterTextProvider

#==vars==
## 生成器身份，用于只清空自己写入的条目
var provider_id: int = 0
## 关联的渲染上下文
var context: RenderContext = null

#==contract==
## 部署监听与驱动逻辑
## @hook
func setup(p_context: RenderContext) -> void:
	context = p_context
	provider_id = get_instance_id()
