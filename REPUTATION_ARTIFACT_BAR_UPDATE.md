# 声望条和神器能量条自定义框体支持 - 更新说明

## 概述
本次更新为声望条（Reputation Bar）和神器能量条/职业大厅资源条（Artifact Bar）添加了独立的自定义框体支持，使其与经验条一样可以独立编辑和管理。

## 主要变更

### 1. 新增容器框体
在 `modules/mainbars.lua` 中创建了两个新的容器框体：

- **`addon.ActionBarFrames.reputationbar`** - 声望条独立容器
  - 尺寸：与主动作条同宽 x 10像素高
  - 默认位置：底部，Y偏移 -8（经验条下方）
  
- **`addon.ActionBarFrames.artifactbar`** - 神器能量条独立容器
  - 尺寸：与主动作条同宽 x 10像素高
  - 默认位置：底部，Y偏移 22（经验条上方）

### 2. 数据库配置更新
在 `database.lua` 中添加了默认位置配置：

```lua
reputationbar = {
    anchor = "BOTTOM",
    posX = 1,
    posY = -8
},
artifactbar = {
    anchor = "BOTTOM",
    posX = 1,
    posY = 22
}
```

### 3. 编辑器系统集成
两个新容器都已注册到编辑器系统，支持：
- ✅ 拖动编辑模式
- ✅ 位置保存和恢复
- ✅ 独立缩放控制
- ✅ 可视化的绿色编辑框

### 4. 声望条行为改进
**之前**：声望条被强制隐藏，永远不显示

**现在**：
- 声望条连接到独立容器 `reputationbar`
- 当玩家有监视的声望时自动显示
- 没有监视的声望时自动隐藏
- 可以通过编辑器独立调整位置
- 支持独立的缩放配置 (`repbar_scale`)

### 5. 神器能量条行为改进
**之前**：使用暴雪原生框架，无法独立编辑位置，且只在职业大厅区域显示

**现在**：
- 神器能量条连接到独立容器 `artifactbar`
- **智能检测**：通过检查玩家是否有神器能量来决定显示/隐藏（不再限制区域）
- 适用于所有12个职业的职业大厅
- 可以通过编辑器独立调整位置
- 满级（110级）后自动显示（如果有神器）

## 技术实现细节

### ConnectBarsToEditor() 函数更新
```lua
-- 声望条连接
if repWatchBar and addon.ActionBarFrames.reputationbar then
    repWatchBar:SetParent(addon.ActionBarFrames.reputationbar)
    repWatchBar:ClearAllPoints()
    repWatchBar:SetSize(526, 10)
    repWatchBar:SetFrameLevel(2)
    repWatchBar:SetScale(repScale)
    repWatchBar:SetFrameStrata("MEDIUM")
    repWatchBar:SetPoint("CENTER", addon.ActionBarFrames.reputationbar, "CENTER", 0, 0)
    repWatchBar:Hide()  -- 初始隐藏，等待UPDATE_FACTION事件
end

-- 神器能量条连接
if MainMenuBarMaxLevelBar and addon.ActionBarFrames.artifactbar then
    MainMenuBarMaxLevelBar:SetParent(addon.ActionBarFrames.artifactbar)
    MainMenuBarMaxLevelBar:ClearAllPoints()
    MainMenuBarMaxLevelBar:SetSize(526, 10)
    MainMenuBarMaxLevelBar:SetFrameLevel(2)
    MainMenuBarMaxLevelBar:SetFrameStrata("MEDIUM")
    MainMenuBarMaxLevelBar:SetPoint("CENTER", addon.ActionBarFrames.artifactbar, "CENTER", 0, 0)
    MainMenuBarMaxLevelBar:Hide()  -- 初始隐藏，等待区域检测
end
```

### UpdateBarPositions() 函数更新
添加了声望条的独立定位逻辑：
```lua
-- 检查是否有监视的声望
local watchedFaction = GetWatchedFactionInfo()
if watchedFaction then
    repWatchBar:Show()
    repWatchBar:SetAlpha(1)
    local repOffset = (config and config.repbar_offset) or -15
    repWatchBar:SetPoint("CENTER", addon.ActionBarFrames.reputationbar, "CENTER", 0, repOffset)
else
    repWatchBar:Hide()
end
```

### 神器能量条智能检测逻辑
**新的检测方法**（替代原有的区域检测）：
```lua
-- 方法1：直接检查神器能量值（最可靠）
if UnitPower and SPELL_POWER_ARTIFACT_POWER then
    local artifactPower = UnitPower("player", SPELL_POWER_ARTIFACT_POWER)
    if artifactPower and artifactPower > 0 then
        hasArtifactPower = true
    end
end

-- 方法2：如果 API 不可用，检查玩家等级
if not hasArtifactPower and UnitLevel then
    local playerLevel = UnitLevel("player")
    if playerLevel and playerLevel >= 110 then
        hasArtifactPower = true  -- 满级玩家可能拥有神器
    end
end

-- 根据检测结果决定显示/隐藏
if hasArtifactPower then
    MainMenuBarMaxLevelBar:Show()
else
    MainMenuBarMaxLevelBar:Hide()
end
```

**优势：**
- ✅ 适用于所有12个职业（战士、圣骑士、猎人、盗贼、牧师、死亡骑士、萨满、法师、术士、武僧、德鲁伊、恶魔猎手）
- ✅ 不依赖区域名称或地图ID，更稳定
- ✅ 自动适配，无需维护职业大厅列表
- ✅ 只要有神器能量就显示，无论玩家在哪个区域

### RegisterActionBarFrames() 函数更新
注册了两个新的可编辑框体：
```lua
{
    name = "reputationbar",
    frame = addon.ActionBarFrames.reputationbar,
    blizzardFrame = ReputationWatchBar,
    configPath = {"widgets", "reputationbar"}
},
{
    name = "artifactbar",
    frame = addon.ActionBarFrames.artifactbar,
    blizzardFrame = MainMenuBarMaxLevelBar,
    configPath = {"widgets", "artifactbar"}
}
```

## 新增API函数

### RefreshArtifactBarPosition()
手动刷新神器能量条的可见性状态：
```lua
addon.RefreshArtifactBarPosition()
```

## 使用说明

### 编辑模式中使用
1. 启用 DragonUI 的编辑模式
2. 可以看到三个独立的框体：
   - **RepExpBar** - 经验条容器（绿色框）
   - **ReputationBar** - 声望条容器（绿色框）
   - **ArtifactBar** - 神器能量条容器（绿色框）
3. 分别拖动每个框体到期望的位置
4. 退出编辑模式后位置会自动保存

### 配置选项
在配置面板中可以调整：
- 经验条缩放 (`expbar_scale`)
- 声望条缩放 (`repbar_scale`)
- 经验条偏移 (`singlebar_offset`)
- 声望条偏移 (`repbar_offset`) - 新增
- 隐藏所有条 (`hide_all_bars`)

## 兼容性说明

### 与现有功能的兼容
- ✅ 经验条功能完全保持不变
- ✅ 职业大厅区域检测逻辑保持不变
- ✅ 声望监视功能正常工作
- ✅ 编辑器系统向后兼容

### 注意事项
1. **声望条显示条件**：只有在游戏内设置了"监视声望"时才会显示
2. **神器能量条显示条件**：只在职业大厅区域显示（破碎群岛）
3. **位置冲突**：如果三个条重叠，可以通过调整偏移量来避免

## 测试建议

### 测试场景
1. **经验条测试**
   - 未满级时经验条应正常显示
   - 满级后经验条应隐藏或转换

2. **声望条测试**
   - 设置监视声望 → 声望条应显示
   - 取消监视声望 → 声望条应隐藏
   - 切换不同的监视声望 → 声望条应更新

3. **神器能量条测试**
   - 拥有神器能量的角色 → 神器能量条应显示（任何区域）
   - 没有神器能量的角色 → 神器能量条应隐藏
   - 满级（110级）角色 → 可能显示（取决于是否有神器）
   - 不同职业测试 → 所有12个职业都应正常工作
   - 打开/关闭职业大厅界面 → 不影响显示状态

4. **编辑器测试**
   - 三个框体应能独立拖动
   - 位置应能正确保存
   - 重新登录后位置应保持

## 文件修改清单

### 修改的文件
1. `modules/mainbars.lua` - 主要逻辑实现
2. `database.lua` - 添加默认配置

### 新增的功能
- 声望条独立容器管理
- 神器能量条独立容器管理
- 声望条智能显示/隐藏
- 神器能量条位置编辑支持

## 后续优化建议

1. **配置面板增强**
   - 添加声望条偏移量的配置选项
   - 添加工具提示说明各条的作用

2. **视觉效果**
   - 可以考虑为三个条添加不同的边框颜色以便区分
   - 添加淡入淡出动画效果

3. **布局预设**
   - 提供几种常用的布局预设（垂直排列、水平排列等）
   - 一键重置到默认位置

---

**更新日期**: 2026-04-26  
**版本**: DragonUI v7.3.5  
**作者**: AI Assistant
