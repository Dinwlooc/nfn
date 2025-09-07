extends RefCounted
class_name RenderPack
#通信层向客户端生成的结果类，对客户端而言是只读类。

class CardData:
	var id:int
	var name:StringName
	var type:StringName

class HandCardData extends CardData:
	var power:int
	var cost:int
	var suit:int
	var modified_power:int
	var modified_cost:int
