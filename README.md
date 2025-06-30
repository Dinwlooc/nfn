根据代码结构分析，该项目是一个基于 Godot 引擎开发的游戏项目，包含多个场景、脚本和资源文件。以下是该项目的 README 内容：

---

# 游戏项目简介

这是一个使用 [Godot 引擎](https://godotengine.org/) 开发的卡牌类游戏项目，包含了完整的场景构建、角色控制、卡牌系统、背景管理以及部分 UI 动画和过渡效果。

## 项目结构概览

- **Picture/**: 存放游戏所需的图像资源，包括背景、角色、卡牌、道具等。
- **Resource/Card/**: 卡牌资源定义文件（`.tres` 格式）。
- **Script/**: 游戏逻辑脚本，分为 `Class`、`Global`、`Node` 等模块。
  - `Class/`: 核心类定义，如玩家、卡牌、区域、系统等。
  - `Global/`: 全局管理脚本，如控制台、RPC 管理、UI 动画等。
  - `Node/`: 场景节点脚本，用于控制具体的游戏界面和交互。
- **tscn/**: Godot 场景文件（`.tscn`），包括主游戏界面、菜单、卡牌展示等。
- **addons/godot-git-plugin/**: Git 插件支持，用于版本控制集成。

## 主要功能模块

- **卡牌系统**：支持基础攻击、激光等卡牌行为，通过 `Class_Card.gd` 和相关场景实现。
- **区域控制**：包括手牌区、战场区、丢弃区等，由 `Class_AreaHand.gd`、`Class_AreaAttack.gd` 等类管理。
- **玩家与系统**：玩家状态、系统配置、全局 RPC 管理等功能由 `Class_Player.gd`、`Class_System.gd`、`global_rpcManager.gd` 等实现。
- **UI 与动画**：使用 `global_uiAnimation.gd` 和 `Transition.gd` 实现场景切换与动画效果。
- **背景与特效**：背景图片和着色器（如 `shader_wave.gd`、`shader_lights.gd`）用于视觉增强。

## 开发环境与依赖

- **Godot 引擎**：项目使用 Godot 4.x 开发，请确保使用兼容版本打开。
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