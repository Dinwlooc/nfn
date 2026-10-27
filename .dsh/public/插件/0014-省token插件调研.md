# DSH 省 Token 插件调研（大型项目 / 2026-10-23）

keywords: token,工具schema,插件调研,成本杠杆,最小推荐集

**摘要**：本会话每个请求携带的工具 schema 是最大固定开销（87 工具 ≈ 34.5k token，godot-ai MCP 占 72.7%）；C 轴（工具管理）杠杆最大但缓存风险最高；最小推荐集是"非 Godot 会话不下发 MCP + save-token + tool-search + code-index 试点"。
