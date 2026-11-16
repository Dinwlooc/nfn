# 着色器实验室（Shader Lab）

## 用途

两种模式：

- **自由对拍**（默认）：左侧参考图原样，右侧同一张图挂所选着色器；参考图与着色器都能从下拉切换，下方参数面板按着色器源里的 `uniform` 声明**自动生成**控件，拖动即时生效。
- **用例对拍**：把某条用例的**基线**与**当前**并排显示，参数差异由用例数据定义。泛光只是其中一类用例，实验室本身不识别任何具体着色器、uniform 或场景名。

候选清单扫目录得到，不写死：着色器扫 `res://resource/default/shader/gdshader/**/*.gdshader`（递归），参考图扫 `res://resource/default/assets/**/*.png`。

## 运行与按键

```
res://lab/shader_lab/shader_lab.tscn
```

`M` 切换两种模式；用例模式下 `1-N` 或点选右下用例列表；`R` 重新加载（换资源/改场景后）；`Esc` 回主菜单。

## 参数面板（自由对拍）

控件由着色器源文件（含 `#include` 的 `.gdshaderinc`）里的声明生成，不依赖引擎反射，也不要求预先列出参数名：

| 声明 | 控件 |
|---|---|
| `uniform float x : hint_range(a, b) = v` | 滑杆（范围取 hint_range，默认取 `v`） |
| `uniform bool x = v` | 复选 |
| `uniform int x : hint_range(a, b) = v` | 步进框 |
| `uniform vec4 x : source_color = ...` | 取色器 |

未支持的参数类型只显示一行说明，不报错；参数写入右侧的 `instance_shader_parameter`，参考图一侧不受影响。

## 用例定义（用例对拍）

在 `shader_lab.gd` 的 `_build_cases()` 追加一条 `ShaderCase`：

| 字段 | 含义 |
|---|---|
| `label` | 标题 |
| `scene_path` | 真实场景路径；每次重建都重新实例化，同名覆盖会生效 |
| `display_selector` | 要显示的子树（相对场景根，`.` 表示根） |
| `target_selector` | 带材质的 CanvasItem（相对显示子树，`.` 表示显示根） |
| `shader_file` | 目标材质必须使用的着色器文件名，用于校验 |
| `baseline_params` | 基线侧 instance uniform 覆盖 |
| `current_params` | 当前侧 instance uniform 覆盖 |
| `readout_params` | 底部要显示的实际生效参数名 |
| `display_scale` | 显示子树缩放（1600×900 背景用 0.475） |

泛光用例：

1. 菜单背景：`main_meum.tscn` / `MeumControl/Backgound`，基线 `enable_bloom=false`，当前 `true`。
2. 区域背景：`backgound.tscn` / 根，基线 `enable_bloom=false`，当前 `true`；区域场景的调参保存在节点 `instance_shader_parameters` 上，基线只关总开关，不改其余参数。

## 读数

状态栏依次显示：着色器文件名，以及各参数的实际生效值。取值顺序为 **实例覆盖 → 材质参数 → “默认”**；标“默认”表示该 uniform 没有覆盖，使用着色器声明值。

## 边界

- 自由对拍只对 **`instance uniform`** 生效；普通 `uniform` 着色器两侧会完全相同。
- 基线/当前是同一着色器的两套参数，不是新旧着色器文件对比。
- 显示子树保留原场景脚本；脚本在 `_ready` 里改参数时两侧都会继承。
- 区域背景保存的实例参数为 `sample_mip=0`、`sample_jitter=0`，抗锯齿主要靠 25 taps；需要更平滑可在场景里调高这两个值。
- 参数面板按**源文件文本**解析，脚本生成的 uniform 或宏拼接出来的声明不会被识别。

## 与模组

- 每次选择或按 `R` 都从 `res://` 重新实例化真实场景；模组若以同名场景、贴图或材质覆盖这些路径，两侧会同时反映。
- 当前资源包注册表只登记卡牌、卡面、翻译等类型（`resource/default/resource_config.cfg`），背景场景未登记；普通资源包模组不会自动替换这两个背景，需要同名覆盖或直接改场景/材质。
- 本场景只做视觉对比，不执行游戏逻辑，也不做自动断言。

## 实现约束

- 必须隐藏 `/root/GlobalTransition` 的全屏黑幕，否则非菜单场景整幅全黑。
- 从场景实例摘子树时清除 `owner`，避免跨场景挂载的 owner 不一致警告。
- 两侧等比缩放并裁切到 760×427.5 面板；着色器偏移按纹理像素计，缩放后相对观感不变。
- 全部变量显式类型；用例是内部类 `ShaderCase`、参数声明是内部类 `ParamSpec`（均 `@record`）。
