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

# ========== 回合/阶段相关信号 ==========
## 阶段完成时发射，参数为刚刚结束的阶段
signal stage_completed(stage: Stage)
## 回退到上一个阶段时发射（临时阶段结束恢复主阶段）
signal stage_rolled_back(old_stage: Stage, new_stage: Stage)
## 所有临时阶段被清空时发射
signal temp_stages_cleared()
## 当前回合结束时发射
signal round_ended()
## 阶段切换时发射（主阶段切换，或临时阶段开始前切换）
signal stage_changed(old_stage: Stage, new_stage: Stage)
## 临时阶段开始时发射
signal temp_stage_started(temp_stage: Stage)
## 回合完全结束（包括清理）时发射
signal round_completed()
