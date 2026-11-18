# 实验室内核（Lab Core）

## 用途

所有实验室共用的骨架：**用例写在配置表里，动作由处理器实现，界面归实验室自己**。交互（人）与无头（AI）跑同一份用例，代码里不出现任何用例内容。

## 三件套

- `FaceLab`：实验室场景的根节点基类（`extends Control`）。承担实参（`--all` / `--case=` / `--reload`）、用例队列、观测帧推进、`RESULT` 行与退出码、`Esc` / `R` 键位。**界面在 `_build_gui()` 里建，无头模式不建界面、也不构造操作参数库**。
- `LabHandler`：处理器基类。`assemble()` 按场景实例化并施加参数，**结果只进缓存、不入场景树**；由界面侧取出后自行入树与摆放。`apply()` / `reset()` / `anchor()` 是钩子，由具体处理器认领目标接口。**处理器不认识界面。**
- `LabData`：操作参数库，缓存**资源**（`Resource`）按预设名索引；只在界面侧构造，无头为空，此时处理器按路径直读。

具体实验室的 Face 与 Handler：`characterface_lab/characterface_lab.gd`（`extends FaceLab`，无全局类名）与 `CharacterFaceLabHandler`（`extends LabHandler`），预设资源类为 `CharacterFacePreset`。

## 数据与预设

- `LabCase`：一条用例（场景、预设名、观测帧、期望、超时、参数）。
- `LabSpec`：从全局配置表读用例，段名约定 `[lab:<标识>]` / `[case:<标识>:<用例>]` / `[preset:<标识>]`；预设段声明**预设名 → 资源路径**。
- 操作的**参数**由预设资源承载，运行期不保存；**资源参数**（如 `CharacterProfile` / `CharacterHitPack`）不走用例参数，按可选资源处理。

## 运行方式

```
godot --headless --path project res://lab/characterface_lab/characterface_lab.tscn -- --all
godot --headless --path project res://lab/characterface_lab/characterface_lab.tscn -- --case=hit_normal
```

判定：每条用例打印 `RESULT <实验室>/<用例>: PASS|FAIL`，进程退出码 = 失败用例数。

## 新实验室三件套

1. `lab/<名字>_lab/<名字>_lab.gd`：`extends FaceLab`，实现 `_create_handler()` 与 `_build_gui()`，**不写 class_name**。
2. `lab/<名字>_lab/<名字>_lab.tscn`：根 `Control` 挂上述脚本，填导出项。
3. 配置表段：`[lab:<标识>]`、`[case:<标识>:*]`、`[preset:<标识>]`。

## 边界

- 判据只保证跑得完、不崩、期望成立；观感归 Owner。
- 用例参数只写运行期副本：途经资源先 `duplicate(true)` 并清空 `resource_path`，绝不写回 `.tres`。
- 处理器组装的对象不入树，入树与排列由实验室负责——依赖方向是实验室 → 处理器，不是反过来。
