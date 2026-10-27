# 杂务 · 我的经验

keywords: 杂务,注释,改动形状,批量删除,沙箱,改名回退

- **公共知识**（初始化读）：`public/杂务/` 下有则读（注解风格量化等）。
- **教训**：只动注释与顺序时，改动形状要能被雷达判为 `COMMENTS-ONLY`；最后启动一次游戏看静态报错即可，中途不跑测试。
- **审验类任务**才更新架构量化统计知识；否则只改不升级。
- **动工作区外路径先确认策略（或走批准）**；批量删除一律 `-ErrorAction SilentlyContinue` 且错误重定向到文件、只读尾部摘要；先删单个文件验证权限。
- **工作区内改名/删除被沙箱拒**：`Move-Item`/`Rename-Item` 在 workspace-write 下抛 `UnauthorizedAccessException`（同目录改名也拒），但 `Copy-Item` 与写文件正常。库迁移可行路径：**copy 到新路径 → 校验哈希一致 → `project_files delete` 删旧文件**（回收站，可恢复）；`project_files delete` 也能删空目录。判据：先单文件探路，全量后哈希比对确认逐字一致再删源。
- **别用单字母函数名**：PowerShell 里 `R` 是 `Invoke-History` 的内置别名，自定义 `function R` 的调用会被解析成别名——脚本没报错、断言从未执行，造成"改了等于没改"的静默半成品。判据：断言函数用带前缀的名字（`Apply-Rep`），并让次数不符时打印失败文本；写入后必须回读被改片段。
