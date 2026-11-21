# 角色表现（CharacterFace）实验室

## 用途

一个场景覆盖角色表现面：物理受击、魔法受击、倒地与边界数据。一次呈现只写**操作参数预设名**，不写动作序列；预设是操作参数数据体的资源文件，配置在 `res://config/render/lab.cfg` 的 `[lab:characterface]`、`[preset:characterface]`（名 → 资源路径）与 `[observe:characterface]`（名 → 观测帧，即预设清单）段。

三件套：`characterface_lab.gd`（extends `FaceLab`，界面与安置）、`CharacterFaceLabHandler`（测试接口：先 `stop_damage_animation` 再 `play_damage_animation`）、`CharacterFacePreset`（预设资源，字段 `hp_damage` / `mp_damage` / `remaining_ratio`）。

启动（交互）：`res://lab/characterface_lab/characterface_lab.tscn`，点左侧预设列表或按 `1-9`/`0` 选预设执行，`↑`/`↓` 移动、`Enter` 执行，`R` 重跑，`Esc` 回主菜单。预设实例在执行结束后**保留在舞台上**（停在结束状态，便于观看），下一次执行前才替换；舞台自动把实例摆到中央。

回归（无头）：

```
godot --headless --path project res://lab/characterface_lab/characterface_lab.tscn -- --all
godot --headless --path project res://lab/characterface_lab/characterface_lab.tscn -- --preset=hit_normal
```

读 `RESULT characterface/<预设>: PASS|FAIL` 与退出码（= 失败数）。内核说明见 `lab_core/README.md`。

## 预设清单

| 预设 | 覆盖 |
|---|---|
| `hit_normal` | 普通物理受击（有恢复阶段） |
| `hit_light` | 低伤害、高剩余血量 |
| `magic_hit` | 仅魔法伤害分支 |
| `hit_down` | 伤害致死倒地（第二段平躺） |
| `boundary_zero` | 0 伤害 0 法力：入口直接返回 |
| `boundary_huge` | 极大伤害与极小剩余血量比例 |
| `ratio_over_one` | 剩余血量比例 > 1（越界） |
| `ratio_negative` | 剩余血量比例 < 0（越界，进入倒地分支） |

预设文件在 `res://resource/default/assets/Character/charactercard/preset/`。镜像不作预设（实验室侧不设该轴）；停止不作预设——它由处理器在每次切换预设前自动执行，即复位。

## 边界与已知问题

- 判据只保证**跑得完、不崩**；观感由 Owner 判断，实验室不声称已验证视觉。
- 倒地分支在互斥门之前 return（既有缺陷）：同帧重复触发时两条补间会同时写 position/rotation。实验室只记录该现象，不在本切片修。
- 修正包只作用于资源副本，不会写回 `mizukagami.tres`。
