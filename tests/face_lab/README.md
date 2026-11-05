# 角色（Face）实验室

## 用途

一个场景覆盖角色表现面：受击（物理/魔法/镜像）、倒地、治疗起身、停止、重复触发与边界数据。用例表在 `res://config/render/lab.cfg` 的 `[lab:face]` 与 `[case:face:*]` 段，改用例不用改代码。

启动（交互）：`res://tests/face_lab/face_lab.tscn`，`1-9`/`0` 选用例执行，`↑`/`↓` 移动、`Enter` 执行，`R` 重跑，`Esc` 退出。

回归（无头）：

```
godot --headless --path project res://tests/face_lab/face_lab.tscn -- --all
godot --headless --path project res://tests/face_lab/face_lab.tscn -- --case=down_then_heal
```

读 `RESULT face/<case>: PASS|FAIL` 与退出码（= 失败数）。内核说明见 `tests/lab_core/README.md`。

## 用例清单

| 用例 | 覆盖 |
|---|---|
| `hit_normal` | 普通物理受击（有恢复阶段） |
| `hit_light` | 低伤害、高剩余血量 |
| `hit_mirrored` | 镜像方向 |
| `magic_hit` | 仅魔法伤害分支 |
| `hit_down` | 伤害致死倒地（第二段平躺） |
| `down_then_heal` | 倒地后治疗起身（两段步骤才真正进入起身路径） |
| `stop_mid_animation` | 动画中途停止并瞬时归位 |
| `double_trigger` | 互斥门：同帧重复触发 |
| `boundary_zero_damage` | 0 伤害 0 法力：入口直接返回 |
| `boundary_huge_damage` | 极大伤害与极小剩余血量比例 |
| `boundary_ratio_over_one` | 剩余血量比例 > 1（越界，不进入受击分支） |
| `boundary_ratio_negative` | 剩余血量比例 < 0（越界，进入倒地分支） |
| `boundary_negative_pack` | 六项修正全为负值；`expect` 断言原始数据未被钳制 |
| `boundary_huge_pack` | 六项修正极大值；`expect` 断言原始数据保持原值 |

## 边界与已知问题

- 判据只保证**跑得完、不崩、期望值成立**；观感由 Owner 判断，实验室不声称已验证视觉。
- 倒地分支在互斥门之前 return（既有缺陷）：同帧重复触发时两条补间会同时写 position/rotation。实验室只记录该现象，不在本切片修。
- 修正包只作用于资源副本，不会写回 `mizukagami.tres`。
