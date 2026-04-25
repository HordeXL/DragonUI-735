# DragonUI - Legion 7.3.5 版本

![界面版本](https://img.shields.io/badge/Interface-70300-blue)
![魔兽世界版本](https://img.shields.io/badge/WoW-7.3.5-orange)
![状态](https://img.shields.io/badge/Status-Stable-green)

一个个人项目，将《巨龙时代》的 UI 美学带到《军团再临》7.3.5 版本。

<img width="816" height="551" alt="{649C1BC5-978C-4852-B622-5ED11CE01A1F}" src="https://github.com/user-attachments/assets/54b8d8df-caf2-40e4-bb1e-5fec3a7f5039" />
<img width="816" height="551" alt="{1233C38B-B4C6-4D9F-BF7F-40165F6417E8}" src="https://github.com/user-attachments/assets/28b3ccfa-55a2-470f-8510-c6f5a484c063" />

## 功能特性

*   **模块化系统：** 可以单独启用或禁用主要的 UI 模块，包括施法条、小地图、动作条、微型菜单（集成背包）和冷却时间系统。
*   **按键绑定系统：** 只需将鼠标悬停在按钮上并按下按键即可轻松设置或更改动作条按键绑定，无需打开菜单。
*   **单位框架：** 重构的玩家、目标、焦点和队伍框架，每个都作为独立模块实现（包括目标的目标/焦点的目标）
*   **微型菜单：** 提供两种样式（彩色和灰度），均采用增强设计，包含玩家头像、基于阵营的 PvP 指示器和集成的背包栏。
*   **施法条：** 具有现代风格的改进施法条。
*   **动作条：** 完全重新设计的动作条。
*   **冷却时间系统：** 独立的冷却时间追踪模块。
*   **小地图：** 重新设计，提供更好的集成和自定义选项。
*   **编辑模式：** 简单的拖放系统，用于重新定位框架和 UI 元素。
*   **全面的配置：** 丰富的游戏内选项面板，可自定义位置、缩放和视觉元素。
*   **配置文件管理：** 为每个角色保存和切换不同的 UI 配置。
*   **兼容性管理器：** 自动检测并与其他插件协调，实现无缝集成。

## 安装方法

1. 从 [发布页面](https://github.com/NeticSoul/DragonUI/releases) 下载最新的 `DragonUI.zip`
2. 将 ZIP 文件解压到您的 `Interface\AddOns` 文件夹
3. 通过 ESC 菜单 > DragonUI 按钮或输入 `/dragonui` 打开配置面板
4. 根据您的喜好自定义位置、缩放和视觉元素

## 说明

此插件仍在开发中，可能存在一些 bug。我独自开发这个项目，同时仍在学习，所以某些代码可能看起来有点粗糙，但计划是随着时间的推移不断改进它。

如果您有兴趣帮助开发或改进它，欢迎贡献！肯定还有优化和修复的空间。

## 已知问题

- **载具和队伍 UI 问题：** 进入载具时，动作条、单位框架和队伍框架可能会出现故障、移动或显示不正确。所有与载具相关的 UI 行为仍需修复。
- 还存在其他 bug，将随着时间的推移逐步完善。

## 致谢

本项目结合并改编了多个来源的代码：

- **[s0h2x](https://github.com/s0h2x)** – 两个特定插件：一个用于动作条，另一个用于小地图，已合并并集成到 DragonUI 中。
- **[KarlHeinz_Schneider - Dragonflight UI (Classic)](https://www.curseforge.com/wow/addons/dragonflight-ui-classic)** – 原始插件，从中获取了许多元素并反向移植/适配到 7.3.5，包括微型菜单和其他基于此设计从头构建的功能。
- **[a3st - RetailUI](https://github.com/a3st/RetailUI)** – 大量代码用作参考并直接集成，用于 UI 元素和实现方法。

## 特别感谢

- **CromieCraft 社区** – 帮助测试各种插件功能并提供反馈。
- **Teknishun** – 特别感谢广泛的测试和宝贵的反馈。
- **Project Epoch 社区和管理团队** – 在开发和测试期间提供帮助和反馈。
