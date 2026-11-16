# Balatro Plus

Balatro Plus 是基于 **Balatro 1.0.1o** 源码的修改版，当前版本号 **1.0.1o-PLUS.3**。

## 功能

- 小丑牌可在商店升级
- 选项新增SL按钮，可一键SL

## 仓库说明

这个仓库只包含游戏 Lua 源码。以下内容不包含在仓库中：

- `resources/`：游戏图片、音频、字体等资源
- `localization/`：本地化文本
- `tools/`：开发/打包工具
- `dist/`：构建产物

因此该仓库本身不能直接运行。要构建完整游戏，请自备合法的 Balatro 1.0.1o 游戏文件（包含上述资源和本地化），把本仓库的源码放入对应的源码目录后重新打包/运行。

## 主要改动

- `balatro_plus.lua`（新增）：升级系统、商店预览、隐形小丑选择界面等
- `balatro_plus_upgrades.lua`（新增）：130 条升级数据
- `card.lua`：升级标记、特殊小丑牌钩子、描述变量缓存
- `globals.lua`：版本号 `1.0.1o-PLUS.3`
- `main.lua`：加载 Balatro Plus 模块
- `functions/UI_definitions.lua`：商店升级按钮与紧凑布局、暂停菜单 SL 按钮
- `functions/misc_functions.lua`：升级版捷径的顺子判定、SL 存档清除
- `functions/state_events.lua`：升级版冲向月球的利息计算
- `game.lua`：按阶段检查点存档、SL 回档、商店/回合检查点
- `functions/button_callbacks.lua`：SL 按钮逻辑，移除回合内的重复自动存档

## Release

GitHub Releases 只提供打包好的完整游戏 `BalatroPlus.zip`，不提供其他附件。

## 版权

Balatro 的代码和资源版权归其权利人所有。使用、修改和分发前请确认符合相关许可；本仓库不包含官方资源和本地化文件。
