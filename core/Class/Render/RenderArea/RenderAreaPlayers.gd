## 玩家区：为每个入区的玩家建卡面；识别出本地玩家后，为非本地玩家动态创建手牌区与守区并挂在玩家卡面下。
extends ItemRenderArea
class_name RenderAreaPlayers

## 本地玩家卡实例（识别到本地玩家后写入）
var local_player:RenderItem
## 本地玩家被识别并记录
## @emitter
signal local_player_received(local_player:RenderItem)

## 就绪：接入玩家添加信号
## @override
func _ready()->void:
	super._ready()
	items_added.connect(_on_player_added)

## 玩家入区：识别本地玩家；其余玩家挂载其手牌区与守区
func _on_player_added(new_player:RenderItem)->void:
	if new_player.data.get_class_name() != PlayerPack.get_class_name_static():
		return
	if new_player.data.peer_id == multiplayer.get_unique_id():
		local_player = new_player
		new_player.mouse_filter = Control.MOUSE_FILTER_IGNORE
		render_context.area_manager.local_player_id = local_player.data.get_id()
		local_player_received.emit(local_player)
		return
	var hand_area:RenderAreaHand = render_context.create_render_area(DefaultArea.HAND,new_player.data.get_id())
	var defence_area:RenderAreaDefence = render_context.create_render_area(DefaultArea.DEFENCE,new_player.data.get_id())
	new_player.add_child(hand_area)
	new_player.add_child(defence_area)
	# 技能区：牌离手后落在玩家卡面下（区域类由 RenderAreaFactory 提供）
	var ability_area:RenderArea = render_context.create_render_area(DefaultArea.ABILITY,new_player.data.get_id())
	if ability_area:
		new_player.add_child(ability_area)

## 静态区域名：供工厂在无实例时查询
static func get_area_name_static()->StringName:
	return DefaultArea.PLAYERS
