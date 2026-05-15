local addon = select(2, ...)

-- ============================================================================
-- 禁用暴雪原生UI元素模块
-- 参考 NDui-735 的实现方式
-- ============================================================================

local DisableBlizzardModule = {
    initialized = false,
    disabledFrames = {},
}

-- 需要完全隐藏的框架列表
local framesToHide = {
    -- 注意：MainMenuBar 不应该被隐藏，因为DragonUI需要它作为按钮容器
    -- MainMenuBar,
    OverrideActionBar,        -- 载具动作条
}

-- 需要禁用事件和脚本的框架列表
local framesToDisable = {
    -- 经验条相关
    MainMenuExpBar,           -- 主经验条（只禁用事件，不隐藏，由DragonUI接管）
    ExhaustionTick,           -- 休息状态标记
    
    -- 声望条相关
    ReputationWatchBar,       -- 声望监视条（只禁用事件，不隐藏，由DragonUI接管）
    ReputationXPBar,          -- 声望/经验切换条
    
    -- 神器能量条相关
    -- ⚠️ 重要：MainMenuBarMaxLevelBar 不应该在这里禁用！
    -- 它需要保持功能完整，由DragonUI的artifactbar容器管理显示/隐藏
    -- MainMenuBarMaxLevelBar,
    ArtifactWatchBar,         -- 神器监视条
    
    -- 荣誉条相关
    HonorWatchBar,            -- 荣誉条
    
    -- 其他相关
    ActionBarDownButton,      -- 动作条向下按钮
    ActionBarUpButton,        -- 动作条向上按钮
    MainMenuBarVehicleLeaveButton, -- 载具离开按钮
    OverrideActionBar,        -- 载具动作条
    OverrideActionBarExpBar,  -- 载具经验条
    OverrideActionBarHealthBar, -- 载具血条
    OverrideActionBarPowerBar,  -- 载具能量条
    OverrideActionBarPitchFrame, -- 载具俯仰框体

    -- ⭐ NDui参考：禁用状态追踪管理器
    -- 这是暴雪控制经验条/声望条/神器能量条显示的核心管理器
    -- 不禁用它的话，即使上面禁用了各个条，它也会反复重新显示
    StatusTrackingBarManager, -- 状态追踪管理器
}

-- 所有需要禁用的脚本事件
local scripts = {
    "OnShow", 
    "OnHide", 
    "OnEvent", 
    "OnEnter", 
    "OnLeave", 
    "OnUpdate", 
    "OnValueChanged", 
    "OnClick", 
    "OnMouseDown", 
    "OnMouseUp",
}

-- ============================================================================
-- 辅助函数：禁用框架的所有脚本
-- ============================================================================
local function DisableAllScripts(frame)
    if not frame then return end
    
    for _, script in pairs(scripts) do
        if frame:HasScript(script) then
            frame:SetScript(script, nil)
        end
    end
end

-- ============================================================================
-- 辅助函数：创建隐藏父框架
-- ============================================================================
local hiddenFrame = CreateFrame("Frame")
hiddenFrame:Hide()

-- ============================================================================
-- 核心函数：禁用暴雪原生UI元素
-- ============================================================================
function DisableBlizzardModule:DisableBlizzardFrames()
    if self.initialized then
        return
    end
    
    addon:DebugInfo("DisableBlizzard", "========== 开始禁用暴雪原生UI元素 ==========")
    
    -- 1. 隐藏指定的框架（通过设置parent为隐藏框架）
    for _, frame in pairs(framesToHide) do
        if frame then
            local frameName = frame.GetName and frame:GetName() or "Unknown"
            frame:SetParent(hiddenFrame)
            addon:DebugInfo("DisableBlizzard", string.format("已隐藏框架: %s", frameName))
        end
    end
    
    -- 2. 禁用指定框架的事件和脚本
    for _, frame in pairs(framesToDisable) do
        if frame then
            local frameName = frame.GetName and frame:GetName() or "Unknown"
            
            -- 取消注册所有事件
            frame:UnregisterAllEvents()
            
            -- 禁用所有脚本
            DisableAllScripts(frame)
            
            -- 隐藏框架
            frame:Hide()
            
            -- 降低透明度确保不可见
            frame:SetAlpha(0)
            
            addon:DebugInfo("DisableBlizzard", string.format("已禁用框架: %s", frameName))
        end
    end
    
    -- 3. 特殊处理：禁用经验条纹理
    if MainMenuExpBar then
        -- 隐藏经验条装饰纹理
        local expTextures = {
            MainMenuXPBarTextureMid,
            MainMenuXPBarTextureLeftCap,
            MainMenuXPBarTextureRightCap,
        }
        
        for _, tex in pairs(expTextures) do
            if tex then
                tex:Hide()
                tex:SetAlpha(0)
            end
        end
        
        -- 隐藏Div分隔条（1-19）
        for i = 1, 19 do
            local div = _G["MainMenuXPBarDiv" .. i]
            if div then
                div:Hide()
                div:SetAlpha(0)
            end
        end
        
        addon:DebugInfo("DisableBlizzard", "已隐藏经验条装饰纹理")
    end
    
    -- 4. 特殊处理：禁用声望条纹理
    if ReputationWatchBar then
        local repTextures = {
            ReputationXPBarTexture1,
            ReputationXPBarTexture2,
            ReputationXPBarTexture3,
            ReputationWatchBarTexture1,
            ReputationWatchBarTexture2,
            ReputationWatchBarTexture3,
        }
        
        for _, tex in pairs(repTextures) do
            if tex then
                tex:Hide()
                tex:SetAlpha(0)
            end
        end
        
        addon:DebugInfo("DisableBlizzard", "已隐藏声望条装饰纹理")
    end
    
    -- 5. 特殊处理：MainMenuBarMaxLevelBar（神器能量条）
    -- ⚠️ 重要：不在这里禁用！由mainbars.lua的artifactbar容器管理
    if MainMenuBarMaxLevelBar then
        -- 只设置初始状态为隐藏，但保持功能完整
        MainMenuBarMaxLevelBar:Hide()
        MainMenuBarMaxLevelBar:SetAlpha(0)
        MainMenuBarMaxLevelBar:SetFrameLevel(0)
        -- 不禁用鼠标，允许暴雪的状态驱动正常工作
        addon:DebugInfo("DisableBlizzard", "✅ MainMenuBarMaxLevelBar已初始化（将由mainbars的artifactbar容器管理）")
    end

    -- 6. ⭐ NDui参考：额外确保StatusTrackingBarManager被隐藏
    -- 虽然已在framesToDisable列表中处理了UnregisterAllEvents，
    -- 但管理器有独立的显示逻辑，需要额外确保隐藏
    if StatusTrackingBarManager then
        StatusTrackingBarManager:UnregisterAllEvents()
        StatusTrackingBarManager:Hide()
        StatusTrackingBarManager:SetScript("OnShow", nil)
        StatusTrackingBarManager:SetScript("OnEvent", nil)
        addon:DebugInfo("DisableBlizzard", "✅ StatusTrackingBarManager已禁用")
    end

    -- 7. ☢️ 核武器级别防护：彻底阻断暴雪原生条
    -- 参考NDui做法：不重用暴雪框架，直接从底层阻断所有显示路径。
    local function KillBlizzardBar(frame, name)
        if not frame then return end
        
        -- 第一层：永久覆盖 Show() 方法
        if not frame.__dragonuiShowBlocked then
            frame.__originalShow = frame.Show
            frame.Show = function() end
            frame.__dragonuiShowBlocked = true
        end
        
        -- 第二层：覆盖 SetParent()，防止被重新挂到可见父级
        if not frame.__dragonuiParentBlocked then
            frame.__originalSetParent = frame.SetParent
            frame.SetParent = function(self, newParent)
                if newParent ~= hiddenFrame and newParent ~= UIParent then
                    addon:DebugInfo("DisableBlizzard", string.format("⛔ 拦截 SetParent(%s -> %s)", name, newParent and newParent.GetName and newParent:GetName() or tostring(newParent)))
                    return
                end
                frame.__originalSetParent(self, newParent)
            end
            frame.__dragonuiParentBlocked = true
        end
        
        -- 第三层：OnShow脚本强制隐藏（引擎级保护）
        frame:SetScript("OnShow", function(self)
            self:Hide()
            self:SetAlpha(0)
            addon:DebugInfo("DisableBlizzard", string.format("⛔ OnShow拦截: %s", name))
        end)
        
        -- 第四层：物理移除到隐藏框架
        frame:SetParent(hiddenFrame)
        frame:ClearAllPoints()
        
        -- 第五层：强制隐藏+透明
        frame:Hide()
        frame:SetAlpha(0)
        
        -- 第六层：禁用所有事件和脚本
        frame:UnregisterAllEvents()
        DisableAllScripts(frame)
        
        addon:DebugInfo("DisableBlizzard", string.format("☢️ 已从底层杀死: %s", name))
    end
    
    -- 执行深层杀死
    KillBlizzardBar(MainMenuExpBar, "MainMenuExpBar")
    KillBlizzardBar(ReputationWatchBar, "ReputationWatchBar")
    KillBlizzardBar(MainMenuBarMaxLevelBar, "MainMenuBarMaxLevelBar")
    
    -- 8. ⚡ 全局函数挂钩：拦截暴雪的更新函数
    -- 即使暴雪引擎重新初始化这些条，也会被拦截
    if MainMenuExpBar_Update then
        hooksecurefunc("MainMenuExpBar_Update", function()
            if MainMenuExpBar then
                MainMenuExpBar:Hide()
                MainMenuExpBar:SetAlpha(0)
            end
        end)
    end
    
    if ReputationWatchBar_Update then
        hooksecurefunc("ReputationWatchBar_Update", function()
            if ReputationWatchBar then
                ReputationWatchBar:Hide()
                ReputationWatchBar:SetAlpha(0)
            end
        end)
    end
    
    -- 拦截 SetPoint 防止任何定位尝试
    local function BlockSetPoint(frame, name)
        if not frame or frame.__dragonuiPointBlocked then return end
        frame.__originalSetPoint = frame.SetPoint
        frame.SetPoint = function(self, ...)
            addon:DebugInfo("DisableBlizzard", string.format("⛔ SetPoint拦截: %s", name))
        end
        frame.__dragonuiPointBlocked = true
    end
    
    BlockSetPoint(MainMenuExpBar, "MainMenuExpBar")
    BlockSetPoint(ReputationWatchBar, "ReputationWatchBar")
    BlockSetPoint(MainMenuBarMaxLevelBar, "MainMenuBarMaxLevelBar")
    
    self.initialized = true
    addon:DebugInfo("DisableBlizzard", "========== 禁用暴雪原生UI元素完成 ==========")
end

-- ============================================================================
-- 模块初始化
-- ============================================================================
local function InitializeDisableBlizzard()
    -- 检查模块是否启用
    local config = addon.db and addon.db.profile and addon.db.profile.modules
    if not config or not config.disableblizzard or not config.disableblizzard.enabled then
        addon:DebugInfo("DisableBlizzard", "模块未启用，跳过初始化")
        return
    end
    
    addon:DebugInfo("DisableBlizzard", "禁用暴雪原生UI模块开始加载")
    
    -- 在ADDON_LOADED事件中初始化
    local initFrame = CreateFrame("Frame")
    initFrame:RegisterEvent("ADDON_LOADED")
    initFrame:RegisterEvent("PLAYER_LOGIN")
    
    initFrame:SetScript("OnEvent", function(self, event, addonName)
        if event == "ADDON_LOADED" and addonName == "DragonUI" then
            -- 延迟一点执行，确保暴雪UI已完全加载
            C_Timer.After(0.1, function()
                DisableBlizzardModule:DisableBlizzardFrames()
            end)
            self:UnregisterEvent("ADDON_LOADED")
        elseif event == "PLAYER_LOGIN" then
            -- 备份检查
            if not DisableBlizzardModule.initialized then
                C_Timer.After(0.5, function()
                    DisableBlizzardModule:DisableBlizzardFrames()
                end)
            end
            self:UnregisterEvent("PLAYER_LOGIN")
        end
    end)
end

-- ============================================================================
-- 全局API：刷新禁用状态
-- ============================================================================
function addon.RefreshDisableBlizzard()
    if DisableBlizzardModule.initialized then
        -- 重新应用禁用
        DisableBlizzardModule.initialized = false
        DisableBlizzardModule:DisableBlizzardFrames()
    end
end

-- ============================================================================
-- 启动模块
-- ============================================================================
InitializeDisableBlizzard()

-- 导出模块
addon.DisableBlizzardModule = DisableBlizzardModule
