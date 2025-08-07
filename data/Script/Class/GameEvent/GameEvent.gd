extends RefCounted
class_name GameEvent

enum EventType {
	DRAW_CARD,         # 行为事件：抽卡
	LEAVE_ZONE,        # 卡牌事件：离开区域
	ENTER_ZONE         # 卡牌事件：进入区域
}
