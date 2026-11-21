## 层视差运行时：按层表把「推离 + 吸向」两个矢量叠加成位移，供任意面板复用。
## 持有平滑状态；不引用背景节点，指针由调用方每帧传入。
extends RefCounted

## 层视差换算工具
const LayerParallax = preload("res://core/Class/Face/Utils/LayerParallax.gd")

## 单层的运行态
class PanelLayer:
	## 视觉层节点
	var node: Node
	## 基准位置（局部坐标，首帧惰性采样）
	var base: Vector2 = Vector2.ZERO
	## 基准缩放
	var base_scale: Vector2 = Vector2.ONE
	## 深度系数
	var depth: float = 0.0
	## 层中心（局部坐标）
	var center: Vector2 = Vector2.ZERO
	## 层自身旋转（弧度）
	var rotation: float = 0.0
	## 当前位移
	var offset: Vector2 = Vector2.ZERO
	## 当前缩放
	var shrink: float = 1.0
	## 是否由运行时写回
	var auto_apply: bool = true
	## 是否相对叠加（true：只叠加增量，保留布局写入）
	var compose: bool = false
	## 已叠加到节点上的位移
	var applied: Vector2 = Vector2.ZERO
	## 基准是否已采样
	var sampled: bool = false
	## 上次写回后的位置（检测外部写入用）
	var last_written: Vector2 = Vector2.ZERO
	## 是否已写过一次
	var written: bool = false

## 推离幅度（屏幕像素，深度 1 时）
var push_amplitude: float = 30.0
## 推离对深度的混入量（很小，0.15 表示层间只差约 10%）
var push_depth_mix: float = 0.15
## 吸向幅度（屏幕像素，深度 1 时）
var pull_amplitude: float = 3.0
## 吸向对深度的敏感度：指数越高，层间差异越大
var pull_power: float = 2.5
## 指针死区
var deadzone: float = 0.08
## 缩放影响半径（屏幕像素）
var radius: float = 420.0
## 半径处的缩放下限
var min_scale: float = 0.92
## 跟随平滑（每秒衰减率）
var follow: float = 10.0

## 面板根（提供全局变换与缩放）
var _root: CanvasItem = null
## 层表
var _layers: Array[PanelLayer] = []

## 建立层表
func setup(root: CanvasItem, nodes: Array, depths: Array) -> void:
	_root = root
	_layers.clear()
	for i in range(nodes.size()):
		if i >= depths.size():
			break
		add(nodes[i], depths[i], true)

## 追加单层
func add(node: Node, depth: float, auto_apply: bool = true, compose: bool = false) -> void:
	if node == null:
		return
	var layer: PanelLayer = PanelLayer.new()
	layer.node = node
	layer.depth = depth
	layer.rotation = node.get(&"rotation")
	layer.auto_apply = auto_apply
	layer.compose = compose
	_layers.append(layer)

## 取某层的当前位移（供自动写回之外的合成通道使用）
func shift_of(node: Node) -> Vector2:
	for layer: PanelLayer in _layers:
		if layer.node == node:
			return layer.offset
	return Vector2.ZERO

## 首帧惰性采样：此时布局已结算，避免取到就绪前的零值
func _sample(layer: PanelLayer) -> void:
	if layer.sampled:
		return
	layer.base = layer.node.get(&"position")
	layer.base_scale = layer.node.get(&"scale")
	if layer.node is Control:
		layer.center = (layer.node as Control).size * 0.5
	layer.sampled = true

## 每帧：按指针位置更新各层
func update(delta: float, mouse_position: Vector2, active: bool = true) -> void:
	if _root == null or not is_instance_valid(_root) or _layers.is_empty():
		return
	var root_transform: Transform2D = _root.get_global_transform()
	var item_scale: float = root_transform.get_scale().x
	var viewport_size: Vector2 = _root.get_viewport_rect().size
	var pointer: Vector2 = LayerParallax.normalize_pointer(mouse_position, viewport_size, deadzone)
	var blend: float = 1.0 - exp(-follow * delta)
	for layer: PanelLayer in _layers:
		_sample(layer)
		var center_global: Vector2 = root_transform * (layer.base + layer.center)
		var push: Vector2 = LayerParallax.push_vector(pointer, layer.depth, push_amplitude, push_depth_mix)
		var pull: Vector2 = LayerParallax.pull_vector(center_global, mouse_position, layer.depth, pull_amplitude, pull_power)
		var target_offset: Vector2 = LayerParallax.offset_for(push + pull, item_scale) if active else Vector2.ZERO
		var target_shrink: float = LayerParallax.scale_for(center_global, mouse_position, radius, min_scale)
		layer.offset = layer.offset.lerp(target_offset, blend)
		layer.shrink = lerpf(layer.shrink, target_shrink, blend)
		if not layer.auto_apply:
			continue
		var node: Node = layer.node
		if layer.compose:
			var current: Vector2 = node.get(&"position")
			if layer.written and not current.is_equal_approx(layer.last_written):
				layer.applied = Vector2.ZERO
			var next: Vector2 = current + (layer.offset - layer.applied)
			node.set(&"position", next)
			layer.applied = layer.offset
			layer.last_written = next
			layer.written = true
			continue
		node.set(&"scale", layer.base_scale * layer.shrink)
		var scaled_center: Vector2 = _rotate_vector(layer.center * layer.shrink, layer.rotation)
		node.set(&"position", layer.base + layer.center + layer.offset - scaled_center)

## 把局部向量按层旋转角旋转（缩放后保持视觉中心不动）
func _rotate_vector(vector: Vector2, angle: float) -> Vector2:
	if is_zero_approx(angle):
		return vector
	var cosine: float = cos(angle)
	var sine: float = sin(angle)
	return Vector2(vector.x * cosine - vector.y * sine, vector.x * sine + vector.y * cosine)
