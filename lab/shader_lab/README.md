# 着色器实验室（Shader Lab）

## 用途

双资源实验室：**图片**与**着色器**各自独立选择。左侧把图原样呈现，右侧同一张图挂所选着色器。

- 左右两侧即时预览，两个下拉分别换图、换着色器，下方参数面板按着色器源里的 `uniform` 声明**自动生成**控件，拖动即时生效。

## 三组件分工

| 件 | 实指 |
|---|---|
| `LabData`（内核算） | 缓存组合资源：组合标识 → `ShaderLabPreset`；自由对拍每次换选都把当前组合记在里面 |
| `ShaderLabHandler` | 认领组合、把舞台装出来：`resolve_preset()` 经操作参数库取组合，`apply()` 交舞台重建；**组装结果不入树**，由实验室摆放 |
| `shader_lab.gd`（Face） | 实参、键位（`R` / `Esc`）与退出码由 `FaceLab` 承担；本类只声明界面、选择器、参数面板与舞台摆放 |

组合资源 `ShaderLabPreset` 只装三个字段：`texture_path`、`shader_path`、`params`（uniform 名 → 值）；界面每次换选即构造一份运行期组合存进 `LabData`。舞台 `ShaderStage`（`shader_stage.tscn`）是处理器组装、实验室呈现的共同载体。

## 候选清单

扫目录得到，不写死：着色器扫 `res://resource/default/shader/gdshader/**/*.gdshader`（递归），参考图扫 `res://resource/default/assets/**/*.png`。

## 运行与按键

```
res://lab/shader_lab/shader_lab.tscn
（无头不跑预设；判据走 `.dsh/custom_tools/business/godot/shader_lab_check.mjs`）
```

`R` 重新加载（换资源后）；`Esc` 回主菜单。

## 参数面板（自由对拍）

控件由着色器源文件（含 `#include` 的 `.gdshaderinc`）里的声明生成，不依赖引擎反射，也不要求预先列出参数名：

| 声明 | 控件 |
|---|---|
| `uniform float x : hint_range(a, b) = v` | 滑杆（范围取 hint_range，默认取 `v`） |
| `uniform bool x = v` | 复选（`enable_*` 且默认关的在这里默认打开） |
| `uniform int x : hint_range(a, b) = v` | 步进框 |
| `uniform vec4 x : source_color = ...` | 取色器 |

未支持的参数类型只显示一行说明，不报错；参数写入右侧舞台的 `instance_shader_parameter`，参考图一侧不受影响。

## 读数

状态栏依次显示：着色器文件名，以及各参数的实际生效值。标「默认」表示该 uniform 没有覆盖，使用着色器声明值。

## 边界

- 只对 **`instance uniform`** 生效；普通 `uniform` 两侧会完全相同。
- 基线严格来说就是**只读图片资源**的效果，与着色器参数无关。
- 参数面板按**源文件文本**解析，脚本生成的 uniform 或宏拼接出来的声明不会被识别。
- 着色器实验室只有自由对拍一种形态；与真实场景并排对拍已按 Owner 决定移除。

## 与模组

- 每次选择或按 `R` 都从 `res://` 重新加载资源；模组若以同名贴图或着色器覆盖这些路径，两侧会同时反映。
- 当前资源包注册表只登记卡牌、卡面、翻译等类型（`resource/default/resource_config.cfg`），背景贴图未登记，普通资源包模组不会自动替换，需要同名覆盖。

## 实现约束

- 必须隐藏 `/root/GlobalTransition` 的全屏黑幕（由 `FaceLab` 统一处理）。
- 全部变量显式类型；参数声明是内部类 `ParamSpec`（`@record`）。
