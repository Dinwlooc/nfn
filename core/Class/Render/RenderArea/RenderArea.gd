## 渲染区域基类：区域内渲染项的请求入口，并承载 Face 层共享的键值缓存。
## 由 [RenderControl] 注册进 [RenderContext]；请求从 [method process_request] 进入，向外以信号发布。
@abstract
extends Control
class_name RenderArea

#==const==
## 默认区域名常量引用
const DefaultArea = GlobalConstants.DefaultArea

#==signals==
## 请求外部执行渲染
## @requester
signal render_requested(render_event:RenderEvent)
## 请求外部执行补间渲染
## @requester
signal tween_requested(render_event:RenderEvent)
## 选中项变化广播
## @emitter
signal selected(item:RenderItem)
## 渲染项被添加
## @emitter
signal items_added(item:RenderItem)
## 渲染项被移除
## @emitter
signal items_removed(item:RenderItem)
## 上下文就绪
## @emitter
signal context_ready()
## 为播放移除动画而创建的临时渲染项
## @emitter
signal item_created_for_removing(item: RenderItem)
## 选择数量上限变化
## @emitter
signal select_limit_changed(new_limit: int)

#==vars==
## 选择数量上限
var select_limit:int = 1
## 所属渲染上下文
var render_context:RenderContext
## 区域归属玩家 id
var player_id:int
## Face 层共享的键值缓存
var _face_cache: Dictionary[StringName, Variant] = {}

#==abstract==
## 添加渲染项（子类实现）
@abstract func add_item(_item:RenderItem, _index:int = -1) -> void
## 移除渲染项（子类实现）
@abstract func remove_item(_item:RenderItem) -> void
## 按数量扣减计数（子类实现）
@abstract func remove_item_count(_count: int) -> void
## 按数量增加计数（子类实现）
@abstract func add_item_count(_count: int) -> void
## 取当前计数（子类实现）
@abstract func get_item_count() -> int

#==lifecycle==
## 构造：记录归属玩家 id
func _init(new_player_id:int = RenderContext.PUBLIC_PLAYER_ID) -> void:
	player_id = new_player_id

#==public==
## 请求入口：按请求类型分派（子类扩展时先调 super）
func process_request(request: RenderRequest) -> void:
	if request is RenderRequest.ItemSet:
		_process_item_set(request as RenderRequest.ItemSet)

## 拖拽开始：把拖拽态写入状态管理器
func on_drag(item:RenderItem) -> void:
	if not render_context:
		return
	render_context.set_card_on_drag(self, item)

## 拖拽取消：清除状态管理器中的拖拽态
func on_cancel_drag(item:RenderItem) -> void:
	if not render_context:
		return
	if render_context.get_dragged_card() == item:
		render_context.remove_card_on_drag()

## 修改选择数量上限并广播
func change_select_limit(new_limit)->void:
	select_limit = new_limit
	select_limit_changed.emit(select_limit)

## 取区域名
func get_area_name()->StringName:
	return self.get_area_name_static()

## 请求外部执行渲染
func render_update(render_event:RenderEvent = RenderEvent.NULL_EVENT) -> void:
	render_requested.emit(render_event)

## 请求外部执行补间渲染
func tween_update(render_event:RenderEvent = RenderEvent.NULL_EVENT) -> void:
	tween_requested.emit(render_event)

## 绑定渲染上下文
func set_render_context(context:RenderContext) -> void:
	render_context = context

#==face_cache==
## 注册缓存，键需使用命名空间，例如 "nfn:preview_mode"
func register_face_cache(key: StringName, value: Variant) -> void:
	_face_cache[key] = value
## 注销缓存
func unregister_face_cache(key: StringName) -> void:
	_face_cache.erase(key)
## 获取缓存，若不存在返回 null
func get_face_cache(key: StringName) -> Variant:
	return _face_cache.get(key, null)
## 清空所有缓存（退出时调用）
func clear_face_cache() -> void:
	_face_cache.clear()

#==internal==
## 用数据包更新渲染项并触发其渲染
func _update_item_data(render_item: RenderItem, item_pack: ItemPack) -> void:
	render_item.apply_pack(item_pack)
	render_update(RenderEvent.new(RenderEvent.DefaultType.CARD_UPDATE))

## 处理卡牌集合请求（基类不处理，由子类覆写）
func _process_item_set(_item_set: RenderRequest.ItemSet) -> void:
	pass

## 处理计数设置请求（基类不处理，由子类覆写）
func _process_item_count_set(_item_count_set: RenderRequest.ItemCountSet) -> void:
	pass

## 连接渲染项的选中/拖拽/悬停信号
func _connect_item_to_area(item:RenderItem) -> void:
	if render_requested.is_connected(item.render_update):
		render_requested.disconnect(item.render_update)
	render_requested.connect(item.render_update)

## 断开渲染项的信号连接
func _disconnect_item_from_area(item:RenderItem) -> void:
	if render_requested.is_connected(item.render_update):
		render_requested.disconnect(item.render_update)

## 离开场景树：清理 Face 缓存
func _exit_tree() -> void:
	if render_context:
		render_context.unregister_render_area(get_area_name())
	clear_face_cache()

#==static==
## 静态区域名：供工厂与注册表在无实例时查询（基类返回空名）
static func get_area_name_static()->StringName:
	return &""
