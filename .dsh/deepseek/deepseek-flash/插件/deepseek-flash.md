# 插件 · deepseek-flash 提示词

keywords: 插件,plugin_manager,工具面,token成本,缓存纪律

- 判据：`public/插件/` 论文 + `custom_tools/README.md` 工具表。
- 装插件走 `plugin_manager`（工作区写包 → 安装），不手改 profile 的 package.json / cordis.patch.yml。
- 工具面评价指标：省 token、快、泛用；落后工具直接删，不负债。
- 缓存纪律：Deepseek 类严格追加性上下文，会话中不卸载/重注入工具。
