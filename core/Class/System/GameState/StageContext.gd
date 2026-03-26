extends RefCounted
class_name StageContext
# 当前正在执行的阶段（可能是主阶段或临时阶段）
var current_stage: Stage = null
# 被暂停的父阶段栈（后进先出），用于临时阶段回退
var temp_stage_stack: Array[Stage] = []
# 当前回合的主阶段名称（StringName 形式）
var current_main_stage_name: StringName = &""
# 当前回合的玩家 ID
var current_player_id: int = 0
