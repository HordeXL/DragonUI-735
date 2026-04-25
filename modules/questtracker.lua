local addon = select(2, ...);

-- =============================================================================
-- DRAGONUI QUEST TRACKER MODULE 
-- =============================================================================

local QuestTrackerModule = {}
addon.QuestTrackerModule = QuestTrackerModule

QuestTrackerModule.questTrackerFrame = nil

-- =============================================================================
-- CONFIG SYSTEM (DragonUI style using database)
-- =============================================================================
local function GetQuestTrackerConfig()
    if not (addon.db and addon.db.profile and addon.db.profile.questtracker) then
        return -100, -37, "TOPRIGHT", true -- defaults con show_header = true
    end
    local config = addon.db.profile.questtracker
    return config.x or -100, config.y or -37, config.anchor or "TOPRIGHT", config.show_header ~= false
end

-- =============================================================================
-- REPLACE BLIZZARD FRAME 
-- =============================================================================
local function ReplaceBlizzardFrame(frame)
    -- ⚠️ 7.3.5版本可能使用不同的任务追踪框架
    -- 尝试多个可能的名称
    local watchFrame = WatchFrame or _G["WatchFrame"] or _G["ObjectiveTrackerFrame"] or _G["QuestWatchFrame"]
    
    if not watchFrame then 
        addon:DebugWarning("QuestTracker", "WatchFrame不存在")
        
        -- 检查是否有ObjectiveTrackerFrame(7.0+版本使用的新框架)
        if _G["ObjectiveTrackerFrame"] then
            addon:DebugInfo("QuestTracker", "发现ObjectiveTrackerFrame,7.3.5可能使用新系统")
            watchFrame = _G["ObjectiveTrackerFrame"]
        else
            addon:DebugWarning("QuestTracker", "所有已知的任务追踪框架都不存在")
            addon:DebugInfo("QuestTracker", "尝试的名称: WatchFrame, ObjectiveTrackerFrame, QuestWatchFrame")
            return 
        end
    end

    -- 诊断: 记录WatchFrame的当前父框架
    local currentParent = watchFrame:GetParent()
    if currentParent then
        addon:DebugInfo("QuestTracker", "WatchFrame当前父框架: %s", currentParent:GetName() or "<unnamed>")
    else
        addon:DebugInfo("QuestTracker", "WatchFrame当前父框架: nil")
    end
    
    -- ⚠️ 关键修复: 必须将WatchFrame的parent设置为DragonUI_QuestTrackerFrame
    -- 这样它就不会跟随小地图移动了
    addon:DebugInfo("QuestTracker", "将WatchFrame的parent设置为: %s", frame:GetName())
    watchFrame:SetParent(frame)
    
    -- 设置可移动属性
    watchFrame:SetMovable(true)
    watchFrame:SetUserPlaced(true)
    
    -- 清除旧锤点并设置新锤点
    watchFrame:ClearAllPoints()
    watchFrame:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    
    -- 验证设置
    local newParent = watchFrame:GetParent()
    if newParent then
        addon:DebugInfo("QuestTracker", "WatchFrame新父框架: %s", newParent:GetName() or "<unnamed>")
    else
        addon:DebugWarning("QuestTracker", "WatchFrame新父框架仍然为 nil!")
    end
    
    local point, relativeTo, relativePoint, xOfs, yOfs = watchFrame:GetPoint()
    if relativeTo then
        addon:DebugInfo("QuestTracker", "WatchFrame锤点: %s -> %s (%s) [%.1f, %.1f]", 
            point, relativeTo:GetName() or "<unnamed>", relativePoint, xOfs, yOfs)
    end
end

-- =============================================================================
-- QUEST TRACKER STYLING (simplified - no hooks)
-- =============================================================================
-- 在 7.3.5 Legion 中，ObjectiveTrackerFrame 默认折叠只显示少量任务
-- 强制展开以显示所有追踪的任务
local function ForceExpandObjectiveTracker()
    -- 尝试多种方式展开任务追踪器
    if ObjectiveTrackerFrame then
        -- 设置展开宽度
        local expandWidth = WATCHFRAME_EXPANDEDWIDTH or 280
        ObjectiveTrackerFrame:SetWidth(expandWidth)

        -- 如果有折叠状态，强制设为展开
        if ObjectiveTrackerFrame.collapsed then
            ObjectiveTrackerFrame.collapsed = false
        end
        if ObjectiveTrackerFrame.isCollapsed then
            ObjectiveTrackerFrame.isCollapsed = false
        end

        -- 强制显示所有任务模块
        if ObjectiveTrackerFrame.MODULES then
            for _, module in pairs(ObjectiveTrackerFrame.MODULES) do
                if module and module.forceUpdate then
                    module:forceUpdate()
                end
            end
        end
    end

    -- 兼容旧版 WatchFrame
    local wf = WatchFrame
    if wf then
        wf:SetWidth(WATCHFRAME_EXPANDEDWIDTH or 250)
    end
end

-- 钩子兼容：尝试钩住 Legion 的展开函数，如果不存在则用旧的
local hookSuccess, _ = pcall(hooksecurefunc, 'ObjectiveTrackerFrame_Collapse', ForceExpandObjectiveTracker)
if not hookSuccess then
    pcall(hooksecurefunc, 'WatchFrame_Collapse', ForceExpandObjectiveTracker)
end

-- Función para aplicar el styling del header de forma independiente
local function ApplyQuestTrackerStyling()
    local watchFrame = WatchFrame
    if not watchFrame or not watchFrame:IsShown() then return end
    if not WatchFrameCollapseExpandButton then return end

    -- Contar objetivos mostrados actualmente
    local totalObjectives = 0
    local success, numWatches = pcall(GetNumQuestWatches)
    if success and numWatches then
        for i = 1, numWatches do
            local questIndex = GetQuestIndexForWatch(i)
            if questIndex then
                totalObjectives = totalObjectives + 1
            end
        end
    end

    -- Crear/actualizar background
    watchFrame.background = watchFrame.background or watchFrame:CreateTexture(nil, 'BACKGROUND')
    local background = watchFrame.background
    background:SetPoint('RIGHT', WatchFrameCollapseExpandButton, 'RIGHT', 0, 0)

    pcall(SetAtlasTexture, background, 'QuestTracker-Header')
    background:SetSize(watchFrame:GetWidth(), 36)

    local _, _, _, showHeader = GetQuestTrackerConfig()
    if totalObjectives > 0 and showHeader then
        background:Show()
        background:SetAlpha(1)
    else
        background:Hide()
    end
end

local function ForceUpdateQuestTracker()
    if InCombatLockdown() then return end

    -- 7.3.5 Legion: ObjectiveTrackerFrame 使用模块化系统
    pcall(function()
        if ObjectiveTrackerFrame then
            -- 强制展开以显示所有追踪的任务
            ForceExpandObjectiveTracker()
            -- 刷新 ObjectiveTrackerFrame 的模块
            if ObjectiveTrackerFrame_Update then
                ObjectiveTrackerFrame_Update()
            end
        end
    end)

    -- 应用 DragonUI 样式（在 pcall 中安全执行，兼容新旧 API）
    pcall(ApplyQuestTrackerStyling)
end

-- =============================================================================
-- CONFIG SYSTEM (DragonUI style using database)
-- =============================================================================
local function UpdateQuestTrackerPosition()
    if InCombatLockdown() then return end

    if QuestTrackerModule.questTrackerFrame then
        local x, y, anchor = GetQuestTrackerConfig()
        QuestTrackerModule.questTrackerFrame:ClearAllPoints()
        QuestTrackerModule.questTrackerFrame:SetPoint(anchor, UIParent, anchor, x, y)
    end
end

-- =============================================================================
-- DRAGONUI REFRESH FUNCTION
-- =============================================================================
function addon.RefreshQuestTracker()
    if InCombatLockdown() then return end
    UpdateQuestTrackerPosition()

    -- Forzar actualización completa del tracker
    ForceUpdateQuestTracker()
end

-- =============================================================================
-- INITIALIZATION 
-- =============================================================================
function QuestTrackerModule:Initialize()

    addon:DebugInfo("QuestTracker", "===== 任务追踪器初始化 =====")
    
    -- 修复: 确保 questTrackerFrame 的 parent 是 UIParent，不是 MinimapCluster
    -- 这样它就可以独立于小地图移动
    self.questTrackerFrame = CreateFrame('Frame', 'DragonUI_QuestTrackerFrame', UIParent)
    self.questTrackerFrame:SetSize(230, 500)
    
    -- 设置frame的基本拖动属性(编辑模式会控制这些)
    self.questTrackerFrame:SetMovable(false) -- 初始状态不可移动
    self.questTrackerFrame:EnableMouse(false) -- 初始状态不响应鼠标
    self.questTrackerFrame:RegisterForDrag("LeftButton")
    self.questTrackerFrame:SetScript("OnDragStart", function(frame)
        frame:StartMoving()
    end)
    self.questTrackerFrame:SetScript("OnDragStop", function(frame)
        frame:StopMovingOrSizing()
        -- 保存位置
        local point, _, relativePoint, x, y = frame:GetPoint()
        if addon.db and addon.db.profile and addon.db.profile.questtracker then
            addon.db.profile.questtracker.anchor = point
            addon.db.profile.questtracker.x = x
            addon.db.profile.questtracker.y = y
            addon:DebugInfo("QuestTracker", "位置已保存: %s [%.1f, %.1f]", point, x, y)
        end
    end)
    
    self.questTrackerFrame:SetFrameLevel(1)
    self.questTrackerFrame:SetFrameStrata('BACKGROUND')
    
    addon:DebugInfo("QuestTracker", "创建 DragonUI_QuestTrackerFrame:")
    addon:DebugInfo("QuestTracker", "  - 父框架: %s", self.questTrackerFrame:GetParent():GetName() or "<unnamed>")
    addon:DebugInfo("QuestTracker", "  - 大小: %.0fx%.0f", self.questTrackerFrame:GetWidth(), self.questTrackerFrame:GetHeight())

    -- Position the frame
    UpdateQuestTrackerPosition()
    
    local point, relativeTo, relativePoint, x, y = self.questTrackerFrame:GetPoint()
    if relativeTo then
        addon:DebugInfo("QuestTracker", "  - 锤点: %s -> %s (%s) [%.1f, %.1f]",
            point, relativeTo:GetName() or "<unnamed>", relativePoint, x, y)
    end

    -- Replace Blizzard frame 
    ReplaceBlizzardFrame(self.questTrackerFrame)
    
    -- 为 questTrackerFrame 添加编辑模式视觉元素
    if not self.questTrackerFrame.editorTexture then
        local texture = self.questTrackerFrame:CreateTexture(nil, 'BACKGROUND')
        texture:SetAllPoints(self.questTrackerFrame)
        texture:SetTexture(0, 1, 0, 0.3) -- 绿色半透明
        texture:Hide()
        self.questTrackerFrame.editorTexture = texture
    end
    
    if not self.questTrackerFrame.editorText then
        local text = self.questTrackerFrame:CreateFontString(nil, 'OVERLAY', 'GameFontNormalLarge')
        text:SetPoint('CENTER')
        text:SetText('questtracker')
        text:Hide()
        self.questTrackerFrame.editorText = text
    end
    
    -- 注册到编辑模式系统，使其可以独立移动
    addon:DebugInfo("QuestTracker", "注册到编辑模式系统")
    addon:RegisterEditableFrame({
        name = "questtracker",
        frame = self.questTrackerFrame,
        blizzardFrame = WatchFrame,
        configPath = {"questtracker"},
        showTest = function()
            -- 在编辑模式中显示任务追踪器
            if QuestTrackerModule.questTrackerFrame then
                addon:DebugInfo("QuestTracker", "编辑模式 - 显示 questTrackerFrame")
            end
        end,
        hideTest = function()
            -- 退出编辑模式
            if QuestTrackerModule.questTrackerFrame then
                addon:DebugInfo("QuestTracker", "编辑模式 - 隐藏 questTrackerFrame")
            end
        end,
        onHide = function()
            UpdateQuestTrackerPosition() -- 应用新配置
        end,
        module = self
    })
    
    addon:DebugInfo("QuestTracker", "===== 任务追踪器初始化完成 =====")

    -- NO instalar hooks aquí - esperar a PLAYER_ENTERING_WORLD
    -- para asegurar que WatchFrame esté completamente inicializado
end

-- Función separada para instalar hooks de forma segura
local function InstallQuestTrackerHooks()
    -- Verificar que WatchFrame existe y está completamente inicializado
    if not WatchFrame then
        return
    end

    -- 确保 QuestObjectiveTracker 在任务变更时刷新（Legion 兼容）
    pcall(function()
        if QuestObjectiveTracker and QuestObjectiveTracker.forceUpdate then
            hooksecurefunc(QuestObjectiveTracker, 'forceUpdate', function()
                ForceExpandObjectiveTracker()
            end)
        end
    end)

    -- Hook adicionales para asegurar que las quests se muestren
    hooksecurefunc('AddQuestWatch', function()
        if not InCombatLockdown() then
            ForceUpdateQuestTracker()
        end
    end)

    hooksecurefunc('RemoveQuestWatch', function()
        if not InCombatLockdown() then
            ForceUpdateQuestTracker()
        end
    end)
end

-- =============================================================================
-- EDITOR MODE FUNCTIONS
-- =============================================================================
function QuestTrackerModule:ShowEditorTest()
    if self.questTrackerFrame then
        self.questTrackerFrame:SetMovable(true)
        self.questTrackerFrame:EnableMouse(true)
        self.questTrackerFrame:RegisterForDrag("LeftButton")

        self.questTrackerFrame:SetScript("OnDragStart", function(frame)
            frame:StartMoving()
        end)

        self.questTrackerFrame:SetScript("OnDragStop", function(frame)
            frame:StopMovingOrSizing()
            -- Save position to DragonUI database
            local point, _, relativePoint, x, y = frame:GetPoint()
            if addon.db and addon.db.profile then
                -- Initialize questtracker config if not exists
                if not addon.db.profile.questtracker then
                    addon.db.profile.questtracker = {}
                end
                addon.db.profile.questtracker.anchor = point
                addon.db.profile.questtracker.x = x
                addon.db.profile.questtracker.y = y
            end
        end)
    end
end

function QuestTrackerModule:HideEditorTest(savePosition)
    if self.questTrackerFrame then
        self.questTrackerFrame:SetMovable(false)
        self.questTrackerFrame:EnableMouse(false)
        self.questTrackerFrame:SetScript("OnDragStart", nil)
        self.questTrackerFrame:SetScript("OnDragStop", nil)

        if savePosition then
            UpdateQuestTrackerPosition()
        end
    end
end

-- =============================================================================
-- EVENT SYSTEM 
-- =============================================================================
local hooksInstalled = false

local function OnPlayerEnteringWorld()
    addon:DebugInfo("QuestTracker", "===== 进入世界事件 =====")
    
    -- ⚠️ 关键发现: 在7.3.5中WatchFrame可能还不存在
    -- 添加延迟检查机制
    
    if not WatchFrame then
        addon:DebugWarning("QuestTracker", "WatchFrame尚未创建,等待0.5秒后重试...")
        
        -- 使用定时器延迟检查
        C_Timer.After(0.5, function()
            if WatchFrame then
                addon:DebugInfo("QuestTracker", "✅ 延迟0.5秒后WatchFrame已创建")
                
                if QuestTrackerModule.questTrackerFrame then
                    ReplaceBlizzardFrame(QuestTrackerModule.questTrackerFrame)
                    
                    if not hooksInstalled then
                        addon:DebugInfo("QuestTracker", "安装hooks")
                        InstallQuestTrackerHooks()
                        hooksInstalled = true
                    end
                    
                    ForceUpdateQuestTracker()
                end
            else
                addon:DebugError("QuestTracker", "❌ 延迟0.5秒后WatchFrame仍然不存在!")
                
                -- 再次延迟1秒重试
                C_Timer.After(1.0, function()
                    if WatchFrame then
                        addon:DebugInfo("QuestTracker", "✅ 延迟1.5秒后WatchFrame已创建")
                        
                        if QuestTrackerModule.questTrackerFrame then
                            ReplaceBlizzardFrame(QuestTrackerModule.questTrackerFrame)
                            
                            if not hooksInstalled then
                                addon:DebugInfo("QuestTracker", "安装hooks")
                                InstallQuestTrackerHooks()
                                hooksInstalled = true
                            end
                            
                            ForceUpdateQuestTracker()
                        end
                    else
                        addon:DebugError("QuestTracker", "❌ 延迟1.5秒后WatchFrame仍然不存在! 可能此版本没有WatchFrame")
                    end
                end)
            end
        end)
        
        addon:DebugInfo("QuestTracker", "===== 进入世界事件完成(已安排延迟检查) =====")
        return
    end
    
    -- WatchFrame存在,立即处理
    addon:DebugInfo("QuestTracker", "✅ WatchFrame已存在")
    
    if QuestTrackerModule.questTrackerFrame then
        -- 再次确认父框架设置
        ReplaceBlizzardFrame(QuestTrackerModule.questTrackerFrame)

        -- Instalar hooks SOLO UNA VEZ, después de que WatchFrame esté completamente listo
        if not hooksInstalled then
            addon:DebugInfo("QuestTracker", "安装hooks")
            InstallQuestTrackerHooks()
            hooksInstalled = true
        end

        -- Forzar actualización al entrar al mundo
        ForceUpdateQuestTracker()
    else
        addon:DebugWarning("QuestTracker", "questTrackerFrame不存在!")
    end
    
    addon:DebugInfo("QuestTracker", "===== 进入世界事件完成 =====")
end

-- Agregar eventos adicionales para actualizar el tracker
local lastUpdate = 0
local function OnQuestLogUpdate()
    local now = GetTime()
    if now - lastUpdate < 0.1 then return end -- Max 10 updates/seg
    lastUpdate = now

    if not InCombatLockdown() then
        ForceUpdateQuestTracker()
    end
end

-- Initialize module
addon.package:RegisterEvents(function()
    QuestTrackerModule:Initialize()
end, 'PLAYER_LOGIN')

-- Register PLAYER_ENTERING_WORLD 
addon.package:RegisterEvents(OnPlayerEnteringWorld, 'PLAYER_ENTERING_WORLD')

-- Registrar evento de actualización del log de quests
addon.package:RegisterEvents(OnQuestLogUpdate, 'QUEST_LOG_UPDATE')

-- Profile change handler
if addon.core and addon.core.RegisterMessage then
    addon.core.RegisterMessage(addon, "DRAGONUI_PROFILE_CHANGED", function()
        addon.RefreshQuestTracker()
    end)
end
