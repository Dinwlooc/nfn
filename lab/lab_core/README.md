# 实验室内核（Lab Core）

## 用途

所有实验室共用的骨架：**预设写在配置表里，动作由处理器实现，界面归实验室自己**。交互（人）与无头（AI）跑同一份预设，代码里不出现任何呈现内容。

## 三件套

- `FaceLab`：实验室场景的根节点基类（`extends Control`）。承担实参（`--all` / `--preset=` / `--reload`）、预设清单、观测帧推进、`RESULT` 行与退出码、`Esc` / `R` 键位。**界面在 `_build_gui()` 里建，无头模式不建界面、也不构造操作参数库**。
- `LabHandler`：处理器基类。`assemble()` 按场景实例化并施加操作参数，**结果只进缓存、不入场景树**；由界面侧取出后自行入树与摆放。`apply()` / `reset()` / `anchor()` 是钩子，由具体处理器认领目标接口。**处理器不认识界面。**
- `LabData`：操作参数库，缓存**资源**（`Resource`）按预设名索引；只在界面侧构造，无头为空，此时处理器按路径直读。

具体实验室的 Face 与 Handler：`characterface_lab/characterface_lab.gd`（`extends FaceLab`，无全局类名）与 `CharacterFaceLabHandler`（`extends LabHandler`），预设资源类为 `CharacterFacePreset`。

## 数据与预设

- 一次呈现的单位是**操作参数预设**：预设名 + 该名的资源文件，不另设呈现条目。`CharacterFacePreset` 这类资源承载全部操作参数，运行期改动不保存。
- `LabPresetList`：把预设名渲染成按钮列并转发点选，只负责呈现。新类名未进全局类缓存时，引用方以预加载常量取它。
- 配置表段：`[lab:<标识>]` 存 `scene` 与 `timeout`；`[preset:<标识>]` 存**预设名 → 资源路径**，只作映射；`[observe:<标识>]` 存**预设名 → 观测帧数**，其键即预设清单，按名排序。
- 资源参数（如 `CharacterProfile` / `CharacterHitPack`）不进预设行，按可选资源处理。

## 运行方式

```
godot --headless --path project res://lab/characterface_lab/characterface_lab.tscn -- --all
godot --headless --path project res://lab/characterface_lab/characterface_lab.tscn -- --preset=hit_normal
```

判定：每个预设打印 `RESULT <实验室>/<预设>: PASS|FAIL`，进程退出码 = 失败预设数。

## 新实验室三件套

1. `lab/<名字>_lab/<名字>_lab.gd`：`extends FaceLab`，实现 `_create_handler()` 与 `_build_gui()`，**不写 class_name**。
2. `lab/<名字>_lab/<名字>_lab.tscn`：根 `Control` 挂上述脚本，填导出项。
3. 配置表段：`[lab:<标识>]`、`[preset:<标识>]`、`[observe:<标识>]`。没有预设的实验室（如配置表实验室、着色器实验室）不写后两段，无头跑时打印 `no presets` 并以 0 退出。

## 边界

- 判据只保证跑得完、不崩；观感归 Owner。
- 预设资源只写运行期副本：途经资源先 `duplicate(true)` 并清空 `resource_path`，绝不写回 `.tres`。
- 处理器组装的对象不入树，入树与排列由实验室负责——依赖方向是实验室 → 处理器，不是反过来。
