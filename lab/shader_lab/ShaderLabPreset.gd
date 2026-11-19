## 着色器实验室预设：图片、着色器与参数表的一个组合。
## 双资源实验室的组合体：图片与着色器各自独立，参数表只装实例 uniform。
## 只承载数据，不认识界面，也不决定谁去组装。
extends Resource
class_name ShaderLabPreset

## 参考图路径；空表示不换图
@export_file("*.png") var texture_path: String = ""
## 着色器路径；空表示不换着色器
@export_file("*.gdshader") var shader_path: String = ""
## 参数覆盖：uniform 名 → 值
@export var params: Dictionary[StringName, Variant] = {}
