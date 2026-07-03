@abstract
extends RefCounted
class_name Area

## 区域可见性枚举
enum Visibility {
	PUBLIC,      ## 公共可见（所有玩家可见）
	PRIVATE,     ## 私有可见（仅所属玩家可见）
	INVISIBLE    ## 不可见（任何玩家都看不到，不传输任何变化）
}
var player: Player
var area_name: StringName
var visibility: Visibility = Visibility.PUBLIC   ## 默认私有可见

signal area_request_command(command: BehaviorCommand)
signal area_request_command_with_callback(command: BehaviorCommand, callback: Callable)
signal area_card_added(new_cardpool: Card, area: Area)
signal area_card_removed(removed_cards: Card, area: Area)
signal after_cards_removed()

func _init(_player: Player = Player.PUBLIC_PLAYER) -> void:
	player = _player

## 判断某个玩家是否可以看到此区域
func is_visible_to(peer_id: int) -> bool:
	match visibility:
		Visibility.PUBLIC:
			if player.get_id() == RenderRequest.PUBLIC_AREA_PLAYER_ID and visibility == Visibility.PRIVATE:
				return false
			return true
		Visibility.PRIVATE:
			return peer_id == player.peer_id
		Visibility.INVISIBLE:
			return false
	return false

## 抽象方法
@abstract
func cards_add(_new_cardpool: Array[Card]) -> void
@abstract
func remove_cards_by_ids(_ids: PackedInt32Array) -> Array[Card]
@abstract
func card_count() -> int
@abstract
func get_card_by_id(_card_id: int) -> Card
@abstract
func get_all_cards() -> Array[Card]
@abstract
func get_card_ids() -> PackedInt32Array
@abstract
func remove_cards_at_indices(_indices: PackedInt32Array) -> Array[Card]
@abstract
func remove_top_cards(_count: int) -> Array[Card]
@abstract
func get_cards_at_indices(_indices: PackedInt32Array) -> Array[Card]
@abstract
func get_top_cards(_count: int) -> Array[Card]

func get_cards_by_ids(ids: PackedInt32Array) -> Array[Card]:
	var result: Array[Card] = []
	for id in ids:
		var card = get_card_by_id(id)
		if card:
			result.append(card)
	return result

func shuffle_card_pool() -> void:
	pass

func request_command(command: BehaviorCommand) -> void:
	area_request_command.emit(command)

func request_command_with_callback(command: BehaviorCommand, callback: Callable) -> void:
	area_request_command_with_callback.emit(command, callback)

func is_empty() -> bool:
	return true

func get_player() -> Player:
	return player
