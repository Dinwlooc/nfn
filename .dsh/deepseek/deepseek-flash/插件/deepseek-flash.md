# 插件 · deepseek-flash 提示词

keywords: 插件,plugin_manager,工具面,token成本,缓存纪律

- 判据：`public/插件/` 论文 + `custom_tools/README.md` 工具表。
- 装插件走 `plugin_manager`（工作区写包 → 安装），不手改 profile 的 package.json / cordis.patch.yml。
- 工具面评价指标：省 token、快、泛用；落后工具直接删，不负债。
- 缓存纪律：Deepseek 类严格追加性上下文，会话中不卸载/重注入工具。

## 开发前：先比对成品（Owner 2026-10-29 定）

写自研插件之前必须做一次市场比对，结论写进论文，不允许跳过：

1. **同题检索**：`npm search keywords:dsh-plugin <术语>`，至少覆盖 3 个措辞（领域词、故障词、机制词）。
2. **判定**：能覆盖我们需求的社区件 → **优先复用**；我们的判据/机制独一份 → 才自研，并在论文写清"差异化在哪"。
3. **已有同类就退役自研**：社区件换掉我们那段，`remove_bundle` + README 顶标注 RETIRED，写清"被谁取代、残留风险是什么"。
4. 版本兼容要查 `peerDependencies`（`@deepseek-ai/dsh-llm` 精确版本会卡安装）；不兼容时不擅自要豁免，报 Owner。

## 交付前：产品信息完备

自研插件交付即按"将来可能发布"备齐，缺件不算完成：

- `name` 用 `dsh-` 前缀（社区 91% 惯例）；`private: true` 且不发即可。
- `keywords: ["dsh-plugin", <领域词…>]` —— 没有它，发布了也搜不到。
- `license` 字段 + `LICENSE` 文件（MIT 全文）。
- `author`、`description`（一句话说清"解决什么故障/给谁用"）。
- README 首段写**定位**，避免与邻域撞词（例：`dsh-meta-tools` 是"元层治理"，不是"知识库"）。
