## Agent 决策快照：纯数据值对象，跨线程传递，不含任何系统层 / 渲染层引用。
extends RefCounted
class_name NPCDecisionData

## 所属玩家 id
var player_id: int
## 手牌快照：{id, type}
var hand_cards: Array[Dictionary]
## 守区是否为空
var defense_area_empty: bool
## 本主阶段是否已出过攻击
var has_attacked_in_main: bool
## 当前阶段名
var current_stage_name: StringName
## 防御阶段的归属玩家 id
var defense_stage_owner_id: int
## 是否持有响应权
var is_responsive: bool
## 其它玩家 id 列表
var other_player_ids: PackedInt32Array
## 自己的速度属性
var self_speed: int
## 其它玩家守区结算次数：玩家 id → 次数
var other_players_settle_counts: Dictionary[int, int]
## 是否以 NPC 身份发起（为真时请求标记为 NPC 来源）
var is_npc: bool
