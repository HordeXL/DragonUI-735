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
    -- ⚠️ MainMenuExpBar 不在此列表！由 DragonUI 的 mainbars.lua 完全接管
    -- 禁用它的 OnValueChanged 会导致进度条无法实时刷新（StatusBar 核心机制）
    -- 纹理隐藏已在下方步骤3单独处理

    -- 经验条相关
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
    -- ⚠️ 重要：不 KillBlizzardBar，让它存活作为 mainbars.lua 的数据源
    -- 但视觉上必须隐藏（暴雪的 OnShow 会尝试显示它）
    if MainMenuBarMaxLevelBar then
        MainMenuBarMaxLevelBar:Hide()
        MainMenuBarMaxLevelBar:SetAlpha(0)
        MainMenuBarMaxLevelBar:SetFrameLevel(0)
        -- 覆盖 Show() 方法：允许内部逻辑运行但保持视觉隐藏
        -- 这样 OnShow 脚本能更新 StatusBar 值，但玩家看不到原生条
        local origShow = MainMenuBarMaxLevelBar.Show
        MainMenuBarMaxLevelBar.Show = function(self, ...)
            origShow(self, ...)
            -- 立即隐藏，防止可见
            self:Hide()
            self:SetAlpha(0)
        end
        addon:DebugInfo("DisableBlizzard", "✅ MainMenuBarMaxLevelBar保持存活（数据源），Show()覆盖保护已安装")
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
        
        -- 第一层：永久覆盖 Show() 方法（阻止 :Show() 调用）
        if not frame.__dragonuiShowBlocked then
            frame.__originalShow = frame.Show
            frame.Show = function(self)
                -- ⚠️ 特殊处理：允许 MainMenuExpBar 正常显示（由 DragonUI 控制）
                if name == "MainMenuExpBar" then
                    if frame.__originalShow then
                        frame.__originalShow(self)
                    end
                    return
                end
                
                addon:DebugInfo("DisableBlizzard", string.format("⛔ Show()被拦截: %s", name))
            end
            frame.__dragonuiShowBlocked = true
        end

        -- 第二层：覆盖 SetShown() 方法（阻止 :SetShown(true) 调用）
        if not frame.__dragonuiSetShownBlocked then
            frame.__originalSetShown = frame.SetShown
            frame.SetShown = function(self, shown)
                -- ⚠️ 特殊处理：允许 MainMenuExpBar 正常显示（由 DragonUI 控制）
                if name == "MainMenuExpBar" then
                    if frame.__originalSetShown then
                        frame.__originalSetShown(self, shown)
                    end
                    return
                end
                
                if shown then
                    addon:DebugInfo("DisableBlizzard", string.format("⛔ SetShown(true)被拦截: %s", name))
                    return
                end
                if frame.__originalSetShown then
                    frame.__originalSetShown(self, false)
                end
            end
            frame.__dragonuiSetShownBlocked = true
        end

        -- 第三层：覆盖 SetAlpha()（防止透明度被恢复）
        if not frame.__dragonuiAlphaBlocked then
            frame.__originalSetAlpha = frame.SetAlpha
            frame.SetAlpha = function(self, alpha)
                -- ⚠️ 特殊处理：允许 MainMenuExpBar 设置透明度（由 DragonUI 控制）
                if name == "MainMenuExpBar" then
                    -- 允许 DragonUI 控制透明度
                    if frame.__originalSetAlpha then
                        frame.__originalSetAlpha(self, alpha)
                    end
                    return
                end
                
                if alpha > 0 then
                    addon:DebugInfo("DisableBlizzard", string.format("⛔ SetAlpha(%.1f)被拦截: %s", alpha or 0, name))
                    return
                end
                if frame.__originalSetAlpha then
                    frame.__originalSetAlpha(self, 0)
                end
            end
            frame.__dragonuiAlphaBlocked = true
        end
        
        -- 第四层：覆盖 SetParent()，防止被重新挂到可见父级
        if not frame.__dragonuiParentBlocked then
            frame.__originalSetParent = frame.SetParent
            frame.SetParent = function(self, newParent)
                -- ⚠️ 特殊处理：允许 MainMenuExpBar 设置到 DragonUI 的 repexpbar 容器
                local isAllowedParent = false
                if name == "MainMenuExpBar" then
                    -- 允许设置到 repexpbar 容器（由 DragonUI 创建）
                    if newParent and newParent.GetName and newParent:GetName() == "DragonUI_RepExpBar" then
                        isAllowedParent = true
                    end
                end
                
                if not isAllowedParent and newParent ~= hiddenFrame and newParent ~= UIParent then
                    addon:DebugInfo("DisableBlizzard", string.format("⛔ 拦截 SetParent(%s -> %s)", name, newParent and newParent.GetName and newParent:GetName() or tostring(newParent)))
                    return
                end
                frame.__originalSetParent(self, newParent)
            end
            frame.__dragonuiParentBlocked = true
        end
        
        -- 第五层：OnShow脚本强制隐藏（引擎级保护，即使C++层面显示也会被拦截）
        frame:SetScript("OnShow", function(self)
            -- ⚠️ 特殊处理：允许 MainMenuExpBar 正常显示（由 DragonUI 控制）
            if name == "MainMenuExpBar" then
                return  -- 放行，让 DragonUI 控制显示
            end
            
            self:Hide()
            self:SetAlpha(0)
            addon:DebugInfo("DisableBlizzard", string.format("⛔ OnShow拦截: %s (引擎级)", name))
        end)

        -- 第六层：物理移除到隐藏框架（断绝视觉路径）
        -- ⚠️ 特殊处理：MainMenuExpBar 不移动到隐藏框架（由 DragonUI 控制）
        if name ~= "MainMenuExpBar" then
            frame:SetParent(hiddenFrame)
            frame:ClearAllPoints()
        end

        -- 第七层：强制隐藏+零透明（双重保险）
        -- ⚠️ 特殊处理：MainMenuExpBar 不强制隐藏（由 DragonUI 控制）
        if name ~= "MainMenuExpBar" then
            frame:Hide()
            frame:SetAlpha(0)
        end

        -- 第八层：禁用所有事件和脚本（断绝逻辑路径）
        -- ⚠️ 特殊处理：MainMenuExpBar 不禁用事件和脚本（需要更新经验值）
        if name ~= "MainMenuExpBar" then
            frame:UnregisterAllEvents()
            DisableAllScripts(frame)
        end

        addon:DebugInfo("DisableBlizzard", string.format("☢️ 已从底层杀死: %s (8层防护)", name))
    end
    
    -- 执行深层杀死
    KillBlizzardBar(MainMenuExpBar, "MainMenuExpBar")
    KillBlizzardBar(ReputationWatchBar, "ReputationWatchBar")
    -- ⚠️ MainMenuBarMaxLevelBar 保持存活，作为神器能量条的数据源供主模块读取
    
    -- 8. ⚡ 全局函数挂钩：拦截暴雪的更新函数
    -- 即使暴雪引擎重新初始化这些条，也会被拦截
    if MainMenuExpBar_Update then
        hooksecurefunc("MainMenuExpBar_Update", function()
            if MainMenuExpBar then
                -- ⚠️ 不再隐藏经验条，由DragonUI的UpdateBarPositions管理显示/隐藏
                -- 只拦截暴雪的纹理重置和装饰恢复
                if MainMenuXPBarTextureMid then MainMenuXPBarTextureMid:Hide() end
                if MainMenuXPBarTextureLeftCap then MainMenuXPBarTextureLeftCap:Hide() end
                if MainMenuXPBarTextureRightCap then MainMenuXPBarTextureRightCap:Hide() end
                for i = 1, 19 do
                    local div = _G["MainMenuXPBarDiv" .. i]
                    if div then div:Hide() end
                end
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
    
    BlockSetPoint(ReputationWatchBar, "ReputationWatchBar")
    -- ⚠️ MainMenuExpBar 不拦截 SetPoint，由 mainbars.lua 的 Hook SetPoint 机制管理（更完善，支持 DragonUI_RepExpBar 容器定位）
    
    self.initialized = true
    addon:DebugInfo("DisableBlizzard", "========== 禁用暴雪原生UI元素完成 ==========")
end

-- ============================================================================
-- 模块初始化
-- ============================================================================
local function InitializeDisableBlizzard()
    -- ⚠️ 移除配置检查：声望条禁用是核心功能，必须始终执行
    -- 即使模块未启用，也需要阻止原生声望条显示
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
