## 管理 RenderItem 的对象池与映射（不涉及区域协调）。
extends RefCounted
class_name RenderItemManager

## 对象池
var _pool: Array[RenderItem] = []
const MAX_CACHE_SIZE: int = 20

## 当池为空且新建 item 时发出
signal item_created(item: RenderItem)

## 映射表：item_type -> { item_id -> RenderItem }
var item_mappings: Dictionary[StringName, Dictionary] = {}

## 从池中取出或新建 RenderItem
func create_item(item_data: TransPack, render_context: RenderContext) -> RenderItem:
	if not _pool.is_empty():
		var item: RenderItem = _pool.pop_back()
		item.data_update(item_data)
		return item
	var new_item: RenderItem = RenderItem.new(item_data)
	new_item.render_context = render_context
	item_created.emit(new_item)
	return new_item

## 将物品回收到池中（不做任何外部清理）
func recycle_item_to_pool(item: RenderItem) -> void:
	item.reset()
	if _pool.size() >= MAX_CACHE_SIZE:
		item.queue_free()
		return
	_pool.append(item)

## 注册物品到映射表
func register_render_item(item_type: StringName, item_id: int, render_item: RenderItem) -> void:
	if not item_mappings.has(item_type):
		item_mappings[item_type] = {}
	item_mappings[item_type][item_id] = render_item

## 从映射表中移除物品
func unregister_render_item(item_type: StringName, item_id: int) -> void:
	if item_mappings.has(item_type) and item_mappings[item_type].has(item_id):
		item_mappings[item_type].erase(item_id)

## 根据类型和ID查找物品
func get_render_item_by_id(item_type: StringName, item_id: int) -> RenderItem:
	if item_mappings.has(item_type):
		return item_mappings[item_type].get(item_id)
	return null

## 获取或创建物品（自动注册）
func get_or_create_item(item_pack: ItemPack, render_context: RenderContext) -> RenderItem:
	var item = get_render_item_by_id(item_pack.get_class_name(), item_pack.get_id())
	if not item:
		item = create_item(item_pack, render_context)
		register_render_item(item_pack.get_class_name(), item_pack.get_id(), item)
	return item

## 仅查找不创建
func get_item(item_pack: ItemPack) -> RenderItem:
	return get_render_item_by_id(item_pack.get_class_name(), item_pack.get_id())
