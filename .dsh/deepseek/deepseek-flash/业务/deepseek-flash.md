# 业务 · deepseek-flash 提示词

keywords: 业务,游戏逻辑,命令实现,渲染区域,TransPack,headless验证,不顺手重构

## 入口

- 玩法与打法：`记忆/对局打法.md`（只在进牌桌对局前读）。
- 渲染层结构与坑位：`记忆/渲染层.md`。
- 群体攻击与区域渲染的现状、判据与欠账：`记忆/群体攻击与区域渲染.md`。
- Godot 验证手法与环境事实：`public/业务/细则.md`。

## 习惯与纪律

- 先读档案与偏好，**歧义解决后再写入**。
- 不顺手重构；发现的问题记录、不在本任务里修。
- 测试由人类跑功能检测；不符合预期再由我复现。
- 改 Godot 脚本后至少跑一次 `godot --headless --path . --quit-after 150`：EXIT=0 且日志无 `SCRIPT ERROR` 才算落地。
- 新建 `class_name` 脚本在编辑器扫描前不进全局类缓存；被别的脚本直接引用会让整条依赖链编译失败。解法：引用方 `preload("res://…")`，判据里用 `get_script() == X` 比对。
- **判据脚本一律走** `python .dsh/custom_tools/godot/_run_scene.py <res:// 场景>`（带超时；Parse Error 会让 `quit()` 不执行、进程挂死）。
- 构造对象前看签名（`StageGroupAttack._init(card, attacker, targets)`）；断言变量显式标类型。
- 序列化注册表**只追加**：下标即线上标识。
