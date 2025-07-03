
# 游戏项目简介

本项目使用 [Godot 引擎](https://godotengine.org/) 开发，目标为实现多人卡牌对战游戏。目前仍在开发阶段。开发者属于业余爱好者，项目结构不具有参考价值。

## 项目结构概览

- **data/Script**: 存放游戏运行所需的逻辑类与场景文件。
  - `Class/`: 核心类定义。
  - `Global/`: 全局管理脚本。
  - `Node/`: 场景节点脚本。
- **offical/**: 官方资源包文件夹。
  - `Area/`: 区域渲染资源。
  - `Backgound/`: 背景图资源。
  - `Card/`: 卡牌及其渲染资源。
  - `Character/`: 角色及其渲染资源。
  - `Shader/`: 着色器资源。
- **mods/**: 预备给mod开发者的资源包文件夹。
- **addons/godot-git-plugin/**: Git 插件支持，用于版本控制集成。

## 主要功能模块

- **系统**：由且仅由服务器端运行System类实例实现。通过Area类和Player类等管理游戏数据，不负责任何渲染部分，允许通过控制台指令游玩。
- **渲染**：通过不同的RealArea类和RealCard类实现。接收来自于服务端的基础数据，转换为渲染数据并存储，总控RealAreaFace类和RealCardFace类的渲染。RealAreaFace类和RealCardFace类定义图形交互逻辑，决定信号的发送，可通过场景文件加载，允许实时切换。
- **全局控制**： 通过全局脚本实现。GlobalConsole提供调试指令定义和节点引用注册接口。GlobalConfig提供用户数据与游戏配置信息。GlobalRPCManager处理网络连接、数据序列化与通信。
- **其他**：全局脚本GlobalTransition提供场景文件切换时的转场方案，GlobalUIAnimation预备了动画控制函数。


## 开发环境与依赖

- **Godot 引擎**：项目使用 Godot 4.4.1 开发，请确保使用兼容版本打开。
- **Git 插件**：项目中集成了 `godot-git-plugin`，用于版本控制。

## 如何运行项目

1. 安装 [Godot 4.x](https://godotengine.org/download/)。
2. 克隆本仓库到本地。
3. 使用 Godot 打开项目目录并运行。

## 贡献指南

欢迎提交 Issue 和 Pull Request。请遵循项目现有代码风格，并确保新增功能通过基本测试。

## 许可证

本项目遵循 MIT License，请参阅 `LICENSE` 文件获取详细信息。

--- 

如需进一步了解某个模块的功能或实现细节，可查阅对应 `.gd` 脚本或 `.tscn` 场景文件。