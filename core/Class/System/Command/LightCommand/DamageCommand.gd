## 伤害命令
class_name DamageCommand
extends BehaviorCommand
## 伤害来源机制枚举
enum SourceMechanism {
	GENERAL,        # 一般伤害
	NEGATIVE_STATE, # 负面状态伤害
	DRAIN,          # 流失伤害
}
## 伤害修饰类型
var damage_modifiers: PackedInt32Array = PackedInt32Array()
## 命令参数
var _target_player:Player
var health_damage: int
var mental_damage: int
var source_mechanism: int
var source_player_id: int  # -1表示无来源玩家
var _phase:int = 0
## 缓存值
var _cached_health_damage: int
var _cached_mental_damage: int

func _init(
	target_player: Player,
	health_dmg: int,
	mental_dmg: int,
	mechanism: int = SourceMechanism.GENERAL,
	source_id: int = -1
) -> void:
	event_name = &"DamageCommand"
	_target_player = target_player
	health_damage = max(0, health_dmg)
	mental_damage = max(0, mental_dmg)
	source_mechanism = mechanism
	source_player_id = source_id

func execute(game_state: GameState) -> void:
	match _phase:
		0:
			_cached_health_damage = health_damage
			_cached_mental_damage = mental_damage
			_phase = 1
		1:
			if _target_player:
				if _cached_health_damage > 0:
					_target_player.apply_health_damage(
						_cached_health_damage,
						source_mechanism,
						source_player_id,
						damage_modifiers
					)
				if _cached_mental_damage > 0:
					_target_player.apply_mental_damage(
						_cached_mental_damage,
						source_mechanism,
						source_player_id,
						damage_modifiers
					)
			complete()
## 伤害修饰接口
func modify_health_damage(new_value: int) -> void:
	if _phase == 1:  # 只能在阶段0后修改
		_cached_health_damage = max(0, new_value)

func modify_mental_damage(new_value: int) -> void:
	if _phase == 1:  # 只能在阶段0后修改
		_cached_mental_damage = max(0, new_value)

func add_damage_modifier(modifier_id: int) -> void:
	damage_modifiers.append(modifier_id)

func remove_damage_modifier(modifier_id: int) -> void:
	var index = damage_modifiers.find(modifier_id)
	if index != -1:
		damage_modifiers.remove_at(index)
