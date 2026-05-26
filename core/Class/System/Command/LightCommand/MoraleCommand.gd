## 战意变动命令
extends BehaviorCommand
class_name MoraleCommand

## 战意变动上下文类
class Context extends CommandContext:
	var target_player: Player = null          ## 被影响的玩家
	var attack_delta: int = 0                 ## 攻击战意增加量（非负）
	var defense_delta: int = 0                ## 防御战意增加量（非负）
	var source_player_id: int = 0             ## 来源玩家ID（0表示系统）
	var event_name: StringName = &""          ## 关联的事件名

	## 设置攻击战意增量（链式调用）
	func set_attack_delta(value: int) -> Context:
		attack_delta = max(0, value)
		return self

	## 设置防御战意增量（链式调用）
	func set_defense_delta(value: int) -> Context:
		defense_delta = max(0, value)
		return self

	## 设置来源玩家ID
	func set_source_player_id(id: int) -> Context:
		source_player_id = id
		return self

	## 设置事件名
	func set_event_name(name: StringName) -> Context:
		event_name = name
		return self

	## 设置被影响的玩家
	func set_target_player(player: Player) -> Context:
		target_player = player
		return self

	## 获取主修饰玩家ID（被影响的玩家）
	func get_primary_modifier_player_ids() -> PackedInt32Array:
		if not target_player:
			return PackedInt32Array()
		return PackedInt32Array([target_player.get_id()])

## 构造函数
## @param target_player 被影响的玩家
## @param attack_delta 攻击战意增量（非负）
## @param defense_delta 防御战意增量（非负）
## @param source_player_id 来源玩家ID
## @param event_name 关联的事件名
## @param name_overriding 命令名称覆盖
func _init(
	p_target_player: Player,
	p_attack_delta: int = 0,
	p_defense_delta: int = 0,
	p_source_player_id: int = 0,
	p_event_name: StringName = &"",
	name_overriding: StringName = &"MoraleChange",
	context_overriding: Context = Context.new()
) -> void:
	context_overriding.set_target_player(p_target_player)
	context_overriding.set_attack_delta(p_attack_delta)
	context_overriding.set_defense_delta(p_defense_delta)
	context_overriding.set_source_player_id(p_source_player_id)
	context_overriding.set_event_name(p_event_name)
	super._init(p_target_player.get_id(), name_overriding, context_overriding)

## 执行命令
func execute(game_state: GameState) -> void:
	var ctx: Context = _context
	if not ctx.target_player:
		push_error("MoraleCommand: 未设置被影响的玩家")
		complete()
		return
	var modified: bool = false
	if ctx.attack_delta > 0:
		ctx.target_player.add_morale_attack(ctx.attack_delta)
		modified = true
	if ctx.defense_delta > 0:
		ctx.target_player.add_morale_defense(ctx.defense_delta)
		modified = true
	if modified:
		RuleTrans.send_player_delta_updates([ctx.target_player])
	complete()
