local addon = select(2, ...)
addon._dir = "Interface\\AddOns\\DragonUI\\assets\\"

-- Debug tracking for mainbars module
if addon.DebugInfo then
    addon:DebugInfo("Mainbars", "主动作条模块开始加载")
    -- Check critical APIs
    addon:CheckAPI("MainMenuBar", "Mainbars")
    addon:CheckAPI("MainMenuBarArtFrame", "Mainbars")
    addon:CheckAPI("MultiBarRight", "Mainbars")
    addon:CheckAPI("MultiBarLeft", "Mainbars")
    addon:CheckAPI("ReputationWatchBar", "Mainbars")
    addon:CheckAPI("MainMenuExpBar", "Mainbars")
end

-- ============================================================================
-- CONFIGURATION FUNCTIONS (ALWAYS AVAILABLE)
-- ============================================================================

local function GetModuleConfig()
    return addon.db and addon.db.profile and addon.db.profile.modules and addon.db.profile.modules.mainbars
end

local function IsModuleEnabled()
    local cfg = GetModuleConfig()
    return cfg and cfg.enabled
end
-- ============================================================================
-- PET BAR FUNCTION (ALWAYS AVAILABLE)
-- ============================================================================

-- Update pet bar visibility and positioning
function addon.UpdatePetBarVisibility()
    if InCombatLockdown() then
        return
    end

    local petBar = PetActionBarFrame
    if not petBar then
        return
    end

    -- Check if player has a pet or is in a vehicle
    local hasPet = UnitExists("pet") and UnitIsVisible("pet")
    local inVehicle = UnitInVehicle("player")
    local hasVehicleActionBar = HasVehicleActionBar and HasVehicleActionBar()

    -- Show pet bar if player has a pet or relevant vehicle controls
    if hasPet or (inVehicle and hasVehicleActionBar) then
        if not petBar:IsShown() then
            petBar:Show()
        end

        -- Ensure proper positioning and scaling
        local db = addon.db and addon.db.profile and addon.db.profile.mainbars
        if db and db.scale_petbar then
            petBar:SetScale(db.scale_petbar)
        end

        -- Update pet action buttons
        for i = 1, NUM_PET_ACTION_SLOTS do
            local button = _G["PetActionButton" .. i]
            if button then
                button:Show()
            end
        end
    else
        -- Hide pet bar when no pet and not in vehicle
        if petBar:IsShown() then
            petBar:Hide()
        end
    end
end

-- ============================================================================
-- ONLY EXECUTE IF MODULE IS ENABLED
-- ============================================================================
-- ============================================================================
-- ONLY EXECUTE IF MODULE IS ENABLED
-- ============================================================================

-- Check if module is enabled when addon loads
local function InitializeMainbars()
    if not IsModuleEnabled() then
        return -- DO NOTHING if disabled
    end

    -- ============================================================================
    -- EVERYTHING BELOW ONLY RUNS IF MODULE IS ENABLED
    -- ============================================================================

    -- MODULE STATE TRACKING
    local MainbarsModule = {
        initialized = false,
        applied = false,
        originalStates = {},
        registeredEvents = {},
        hooks = {},
        stateDrivers = {},
        frames = {},
        eventFrames = {},
        originalScales = {},
        originalPositions = {},
        originalTextures = {},
        originalVisibility = {},
        actionBarFrames = nil
    }

    -- CORE COMPONENTS
    local config = addon.config;
    local event = addon.package;
    local do_action = addon.functions;
    local select = select;
    local pairs = pairs;
    local ipairs = ipairs;
    local format = string.format;
    local UIParent = UIParent;
    local hooksecurefunc = hooksecurefunc;
    local UnitFactionGroup = UnitFactionGroup;
    local _G = getfenv(0);

    -- constants
    local faction = UnitFactionGroup('player');
    local MainMenuBarMixin = {};
    addon.MainMenuBarMixin = MainMenuBarMixin;  -- Store globally for access
    local pUiMainBar = CreateFrame('Frame', 'pUiMainBar', UIParent, 'MainMenuBarUiTemplate');
    addon.pUiMainBar = pUiMainBar;  -- Store globally for access

    local pUiMainBarArt = CreateFrame('Frame', 'pUiMainBarArt', pUiMainBar);

    -- ⭐ 辅助函数：检查表是否包含某个值
    local function tableContains(tbl, value)
        if not tbl then return false end
        for _, v in pairs(tbl) do
            if v == value then return true end
        end
        return false
    end

    -- ACTION BAR SYSTEM
    addon.ActionBarFrames = {
        mainbar = nil,
        rightbar = nil,
        leftbar = nil,
        bottombarleft = nil,
        bottombarright = nil,
        repexpbar = nil,
        reputationbar = nil,  -- 声望条独立容器
        artifactbar = nil     -- 神器能量条独立容器
    }

    -- Set initial scale and properties
    pUiMainBar:SetScale(config.mainbars.scale_actionbar);
    pUiMainBarArt:SetFrameStrata('HIGH');
    pUiMainBarArt:SetFrameLevel(pUiMainBar:GetFrameLevel() + 4);
    pUiMainBarArt:SetAllPoints(pUiMainBar);
    -- CRÍTICO: Desactivar mouse para evitar zona muerta en iconos
    pUiMainBarArt:EnableMouse(false);

    -- ============================================================================
    -- ALL THE MAINBARS FUNCTIONS (ONLY WHEN ENABLED)
    -- ============================================================================

    -- Use the global UpdateGryphonStyle function
    local UpdateGryphonStyle = addon.UpdateGryphonStyle

    -- ============================================================================
    -- ORIGINAL STATE STORAGE
    -- ============================================================================

    local function StoreOriginalMainbarStates()
        -- Store MainMenuBar state
        if MainMenuBar then
            MainbarsModule.originalStates.MainMenuBar = {
                parent = MainMenuBar:GetParent(),
                scale = MainMenuBar:GetScale(),
                points = {},
                mouseEnabled = MainMenuBar:IsMouseEnabled(),
                movable = MainMenuBar:IsMovable(),
                userPlaced = MainMenuBar:IsUserPlaced()
            }
            for i = 1, MainMenuBar:GetNumPoints() do
                local point, relativeTo, relativePoint, xOfs, yOfs = MainMenuBar:GetPoint(i)
                table.insert(MainbarsModule.originalStates.MainMenuBar.points,
                    {point, relativeTo, relativePoint, xOfs, yOfs})
            end
        end

        -- Store other action bars states
        local bars = {MultiBarRight, MultiBarLeft, MultiBarBottomLeft, MultiBarBottomRight, PetActionBarFrame}
        for _, bar in pairs(bars) do
            if bar then
                local name = bar:GetName()
                MainbarsModule.originalStates[name] = {
                    parent = bar:GetParent(),
                    scale = bar:GetScale(),
                    points = {},
                    mouseEnabled = bar:IsMouseEnabled(),
                    movable = bar:IsMovable(),
                    userPlaced = bar:IsUserPlaced()
                }
                for i = 1, bar:GetNumPoints() do
                    local point, relativeTo, relativePoint, xOfs, yOfs = bar:GetPoint(i)
                    table.insert(MainbarsModule.originalStates[name].points,
                        {point, relativeTo, relativePoint, xOfs, yOfs})
                end
            end
        end
    end

    -- ============================================================================
    -- RESTORE ORIGINAL STATE (When disabled)
    -- ============================================================================

    local function RestoreMainbarsSystem()
        if not MainbarsModule.applied then
            return
        end

        -- Hide DragonUI frames
        if MainbarsModule.frames.pUiMainBar then
            MainbarsModule.frames.pUiMainBar:Hide()
            MainbarsModule.frames.pUiMainBar = nil
        end
        if MainbarsModule.frames.pUiMainBarArt then
            MainbarsModule.frames.pUiMainBarArt:Hide()
            MainbarsModule.frames.pUiMainBarArt = nil
        end

        -- Clear ActionBarFrames
        if MainbarsModule.actionBarFrames then
            for name, frame in pairs(MainbarsModule.actionBarFrames) do
                if frame and frame.Hide then
                    frame:Hide()
                end
            end
            MainbarsModule.actionBarFrames = nil
            addon.ActionBarFrames = nil
        end

        -- Restore original states
        for frameName, state in pairs(MainbarsModule.originalStates) do
            local frame = _G[frameName]
            if frame and state then
                frame:SetParent(state.parent or UIParent)
                frame:SetScale(state.scale or 1.0)
                frame:ClearAllPoints()
                if state.points and #state.points > 0 then
                    for _, pointData in pairs(state.points) do
                        frame:SetPoint(pointData[1], pointData[2], pointData[3], pointData[4], pointData[5])
                    end
                else
                    -- Default positioning for action bars
                    if frameName == "MainMenuBar" then
                        frame:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 0)
                    elseif frameName == "MultiBarRight" then
                        frame:SetPoint("RIGHT", UIParent, "RIGHT", -6, 0)
                    elseif frameName == "MultiBarLeft" then
                        frame:SetPoint("RIGHT", MultiBarRight, "LEFT", -6, 0)
                    elseif frameName == "MultiBarBottomLeft" then
                        frame:SetPoint("BOTTOMLEFT", ActionButton1, "TOPLEFT", 0, 6)
                    elseif frameName == "MultiBarBottomRight" then
                        frame:SetPoint("BOTTOMLEFT", MultiBarBottomLeftButton1, "TOPLEFT", 0, 6)
                    end
                end
                frame:EnableMouse(state.mouseEnabled ~= false)
                frame:SetMovable(state.movable ~= false)
                frame:SetUserPlaced(state.userPlaced == true)
            end
        end

        -- Show action bars
        local bars = {MainMenuBar, MultiBarRight, MultiBarLeft, MultiBarBottomLeft, MultiBarBottomRight}
        for _, bar in pairs(bars) do
            if bar then
                bar:Show()
            end
        end

        MainbarsModule.originalStates = {}
        MainbarsModule.applied = false

    end

    -- ============================================================================
    -- CORE MAINBAR FUNCTIONS (From working code)
    -- ============================================================================

   function MainMenuBarMixin:actionbutton_setup()
    for _, obj in ipairs({MainMenuBar:GetChildren(), MainMenuBarArtFrame:GetChildren()}) do
        obj:SetParent(pUiMainBar)
    end

    for index = 1, NUM_ACTIONBAR_BUTTONS do
        pUiMainBar:SetFrameRef('ActionButton' .. index, _G['ActionButton' .. index])
    end

    -- 关键修复：确保按钮背景纹理正确创建和显示
    local db = addon.db and addon.db.profile and addon.db.profile.buttons
    local shouldHideBackground = db and db.hide_main_bar_background
    
    addon:DebugInfo("Mainbars", string.format("actionbutton_setup - hide_main_bar_background: %s", tostring(shouldHideBackground)))
    
    -- 为所有主动作条按钮应用SetThreeSlice（除非明确隐藏背景）
    if not shouldHideBackground then
        for index = 1, NUM_ACTIONBAR_BUTTONS - 1 do
            local ActionButtons = _G['ActionButton' .. index]
            if ActionButtons then
                do_action.SetThreeSlice(ActionButtons);
                addon:DebugInfo("Mainbars", string.format("已为ActionButton%d应用SetThreeSlice", index))
            end
        end
    else
        addon:DebugInfo("Mainbars", "背景被配置为隐藏，跳过SetThreeSlice")
    end

    for index = 2, NUM_ACTIONBAR_BUTTONS do
        local ActionButtons = _G['ActionButton' .. index]
        if ActionButtons then
            ActionButtons:SetParent(pUiMainBar)
            ActionButtons:SetClearPoint('LEFT', _G['ActionButton' .. (index - 1)], 'RIGHT', 7, 0)
        end

        local BottomLeftButtons = _G['MultiBarBottomLeftButton' .. index]
        if BottomLeftButtons then
            BottomLeftButtons:SetClearPoint('LEFT', _G['MultiBarBottomLeftButton' .. (index - 1)], 'RIGHT', 7, 0)
        end

        local BottomRightButtons = _G['MultiBarBottomRightButton' .. index]
        if BottomRightButtons then
            BottomRightButtons:SetClearPoint('LEFT', _G['MultiBarBottomRightButton' .. (index - 1)], 'RIGHT', 7, 0)
        end

        -- 7.3.5 compatibility: BonusActionButton was removed
        local BonusActionButtons = _G['BonusActionButton' .. index]
        if BonusActionButtons then
            BonusActionButtons:SetClearPoint('LEFT', _G['BonusActionButton' .. (index - 1)], 'RIGHT', 7, 0)
        end
    end
end

    function MainMenuBarMixin:actionbar_art_setup()
        -- setup art frames - CORREGIDO
        MainMenuBarArtFrame:SetParent(pUiMainBarArt)  -- ✅ Va al contenedor de arte
        
        -- CRÍTICO: Los grifones deben ir a pUiMainBarArt, NO a pUiMainBar
        for _, art in pairs({MainMenuBarLeftEndCap, MainMenuBarRightEndCap}) do
            art:SetParent(pUiMainBarArt)  -- ✅ Al contenedor de arte correcto
            art:SetDrawLayer('OVERLAY', 7)  -- ✅ Layer más alto que ARTWORK
        end

        -- apply background settings
        self:update_main_bar_background()

        -- apply gryphon styling
        UpdateGryphonStyle()
    end

    function MainMenuBarMixin:update_main_bar_background()
    local db = addon.db and addon.db.profile and addon.db.profile.buttons
    local shouldHideBackground = db and db.hide_main_bar_background
    local alpha = shouldHideBackground and 0 or 1

    addon:DebugInfo("Mainbars", string.format("update_main_bar_background - hide_main_bar_background: %s, alpha: %.1f", tostring(shouldHideBackground), alpha))

    -- handle button background textures
    for i = 1, NUM_ACTIONBAR_BUTTONS do
        local button = _G["ActionButton" .. i]
        if button then
            if button.NormalTexture then
                button.NormalTexture:SetAlpha(alpha)
            end
            
            -- 处理按钮的背景纹理（由setup_background创建）
            if button.background then
                button.background:SetAlpha(alpha)
                if alpha > 0 then
                    button.background:Show()
                else
                    button.background:Hide()
                end
            end
            
            -- Ocultar también las texturas aplicadas por SetThreeSlice
            local regions = {button:GetRegions()}
            for j = 1, #regions do
                local region = regions[j]
                if region and region:GetObjectType() == "Texture" then
                    local drawLayer = region:GetDrawLayer()
                    -- Ocultar texturas de fondo y artwork que no sean iconos
                    if (drawLayer == "BACKGROUND" or drawLayer == "ARTWORK") and region ~= button:GetNormalTexture() then
                        local texPath = region:GetTexture()
                        if texPath and not string.find(texPath, "ICON") and not string.find(texPath, "Interface\\Icons") then
                            region:SetAlpha(alpha)
                        end
                    end
                end
                -- 关键修复：明确跳过 FontString 对象，不要修改它们的 Alpha
                -- FontString 是文本对象（宏名称、快捷键、数量等），不应该被背景透明度影响
            end
        end
    end

    if pUiMainBar then
        -- hide loose textures within pUiMainBar
        for i = 1, pUiMainBar:GetNumRegions() do
            local region = select(i, pUiMainBar:GetRegions())
            if region and region:GetObjectType() == "Texture" then
                local texPath = region:GetTexture()
                if texPath and not string.find(texPath, "ICON") then
                    region:SetAlpha(alpha)
                end
            end
        end

        -- hide child frame textures with protection for UI elements
        for i = 1, pUiMainBar:GetNumChildren() do
            local child = select(i, pUiMainBar:GetChildren())
            local name = child and child:GetName()

            -- protect important UI elements from being hidden
            if child and name ~= "pUiMainBarArt" and not string.find(name or "", "ActionButton") and name ~=
                "MultiBarBottomLeft" and name ~= "MultiBarBottomRight" and name ~= "MicroButtonAndBagsBar" and
                not string.find(name or "", "MicroButton") and not string.find(name or "", "Bag") and name ~=
                "CharacterMicroButton" and name ~= "SpellbookMicroButton" and name ~= "TalentMicroButton" and name ~=
                "AchievementMicroButton" and name ~= "bagsFrame" and name ~= "MainMenuBarBackpackButton" and name ~=
                "QuestLogMicroButton" and name ~= "SocialsMicroButton" and name ~= "PVPMicroButton" and name ~=
                "LFGMicroButton" and name ~= "MainMenuMicroButton" and name ~= "HelpMicroButton" and name ~=
                "MainMenuExpBar" and name ~= "ReputationWatchBar" then

                for j = 1, child:GetNumRegions() do
                    local region = select(j, child:GetRegions())
                    if region and region:GetObjectType() == "Texture" then
                        region:SetAlpha(alpha)
                    end
                end
            end
        end
    end
end

    function MainMenuBarMixin:actionbar_setup()
        ActionButton1:SetParent(pUiMainBar)
        ActionButton1:SetClearPoint('BOTTOMLEFT', pUiMainBar, 2, 2)

        if config.buttons.pages.show then
            do_action.SetNumPagesButton(ActionBarUpButton, pUiMainBarArt, 'pageuparrow', 8)
            do_action.SetNumPagesButton(ActionBarDownButton, pUiMainBarArt, 'pagedownarrow', -14)

            MainMenuBarPageNumber:SetParent(pUiMainBarArt)
            MainMenuBarPageNumber:SetClearPoint('CENTER', ActionBarDownButton, -1, 12)
            local pagesFont = config.buttons.pages.font
            MainMenuBarPageNumber:SetFont(pagesFont[1], pagesFont[2], pagesFont[3])
            MainMenuBarPageNumber:SetShadowColor(0, 0, 0, 1)
            MainMenuBarPageNumber:SetShadowOffset(1.2, -1.2)
            MainMenuBarPageNumber:SetDrawLayer('OVERLAY', 7)
        else
            ActionBarUpButton:Hide();
            ActionBarDownButton:Hide();
            MainMenuBarPageNumber:Hide();
        end

        MultiBarBottomRight:EnableMouse(false)
        MultiBarRight:SetScale(config.mainbars.scale_rightbar)
        MultiBarLeft:SetScale(config.mainbars.scale_leftbar)
        if MultiBarBottomLeft then
            MultiBarBottomLeft:SetScale(config.mainbars.scale_bottomleft or 0.9)
        end
        if MultiBarBottomRight then
            MultiBarBottomRight:SetScale(config.mainbars.scale_bottomright or 0.9)
        end
    end

    -- Register event to update page number when action bar page changes
    event:RegisterEvents(function()
        MainMenuBarPageNumber:SetText(GetActionBarPage());
    end,
        'ACTIONBAR_PAGE_CHANGED'
    );

    function addon.PositionActionBars()
        if InCombatLockdown() then
            return
        end

        local db = addon.db and addon.db.profile and addon.db.profile.mainbars
        if not db then
            return
        end

        -- Configure MultiBarRight orientation
        if MultiBarRight then
            if db.right.horizontal then
                -- Horizontal mode: buttons go from left to right
                for i = 2, 12 do
                    local button = _G["MultiBarRightButton" .. i]
                    if button then
                        button:ClearAllPoints()
                        button:SetPoint("LEFT", _G["MultiBarRightButton" .. (i - 1)], "RIGHT", 7, 0)
                    end
                end
            else
                -- Vertical mode: buttons go from top to bottom (default)
                for i = 2, 12 do
                    local button = _G["MultiBarRightButton" .. i]
                    if button then
                        button:ClearAllPoints()
                        button:SetPoint("TOP", _G["MultiBarRightButton" .. (i - 1)], "BOTTOM", 0, -7)
                    end
                end
            end
        end

        -- Configure MultiBarLeft orientation
        if MultiBarLeft then
            if db.left.horizontal then
                -- Horizontal mode: buttons go from left to right
                for i = 2, 12 do
                    local button = _G["MultiBarLeftButton" .. i]
                    if button then
                        button:ClearAllPoints()
                        button:SetPoint("LEFT", _G["MultiBarLeftButton" .. (i - 1)], "RIGHT", 7, 0)
                    end
                end
            else
                -- Vertical mode: buttons go from top to bottom (default)
                for i = 2, 12 do
                    local button = _G["MultiBarLeftButton" .. i]
                    if button then
                        button:ClearAllPoints()
                        button:SetPoint("TOP", _G["MultiBarLeftButton" .. (i - 1)], "BOTTOM", 0, -7)
                    end
                end
            end
        end
    end

    function MainMenuBarMixin:statusbar_setup()
        -- Setup pet bar initial configuration
        if PetActionBarFrame then
            -- Ensure pet bar uses correct scale from config
            local db = addon.db and addon.db.profile and addon.db.profile.mainbars
            if db and db.scale_petbar then
                PetActionBarFrame:SetScale(db.scale_petbar)
            elseif config.mainbars.scale_petbar then
                PetActionBarFrame:SetScale(config.mainbars.scale_petbar)
            end

            -- Enable mouse interaction
            PetActionBarFrame:EnableMouse(true)
        end

        -- Initial setup for XP/Rep bars with NEW style sizes
        if MainMenuExpBar then
            MainMenuExpBar:SetClearPoint('BOTTOM', UIParent, 0, 31)
            MainMenuExpBar:SetFrameLevel(1) -- Lower level for editor overlay visibility
            -- Set NEW style size immediately
            MainMenuExpBar:SetSize(537, 10)

            if MainMenuBarExpText then
                MainMenuBarExpText:SetParent(MainMenuExpBar)
                -- Text will be positioned later based on style
            end
        end

    end

    -- Connect XP/Rep bars to the editor system
    local function ConnectBarsToEditor()
        if not addon.ActionBarFrames.repexpbar then
            return
        end
        
        -- ⚠️ 关键：确保容器框架可见（CreateUIFrame 默认不显示）
        addon.ActionBarFrames.repexpbar:Show()
        
        -- Get config values for initial setup
        local config = addon.db and addon.db.profile.xprepbar
        local expScale = (config and config.expbar_scale) or 0.9
        local repScale = (config and config.repbar_scale) or 0.9

        local mainMenuExpBar = MainMenuExpBar
        if mainMenuExpBar then
            mainMenuExpBar:SetParent(addon.ActionBarFrames.repexpbar)
            mainMenuExpBar:ClearAllPoints()
            mainMenuExpBar:SetSize(526, 10)
            mainMenuExpBar:SetFrameLevel(2)
            mainMenuExpBar:SetScale(expScale)
            mainMenuExpBar:SetFrameStrata("MEDIUM")
            mainMenuExpBar:SetPoint("CENTER", addon.ActionBarFrames.repexpbar, "CENTER", 0, 0)
            
            -- ⚠️ 关键：重置初始状态（可能被 KillBlizzardBar 隐藏了）
            -- 显示/隐藏的最终决策由 UpdateBarPositions 处理
            mainMenuExpBar:Show()
            mainMenuExpBar:SetAlpha(1)
        end

        -- ⚠️ 声望条和神器能量条已在disableblizzard.lua中被彻底禁用
        -- 这里不再尝试连接它们，让它们保持被杀死状态
        if addon.ActionBarFrames.reputationbar then
            addon:DebugInfo("ExpRepBar", "✅ 声望条容器已创建（原生条已禁用）")
        end
        
        if addon.ActionBarFrames.artifactbar then
            addon:DebugInfo("ExpRepBar", "✅ 神器能量条容器已创建（原生条已禁用）")
        end
    end

    -- Force reputation text configuration (ensures text is properly configured but hidden by default)
    local function ForceReputationTextConfiguration()
        if ReputationWatchStatusBarText and ReputationWatchStatusBar then
            -- Force correct parent
            ReputationWatchStatusBarText:SetParent(ReputationWatchStatusBar)
            -- Force reasonable layering - not excessively high
            ReputationWatchStatusBarText:SetDrawLayer("OVERLAY", 2)
            -- Force correct positioning for NEW style
            ReputationWatchStatusBarText:SetClearPoint('CENTER', ReputationWatchStatusBar, 'CENTER', 0, 1)
            -- IMPORTANT: Hide by default - only show on hover (Blizzard handles this)
            ReputationWatchStatusBarText:Hide()
        end
    end

    -- Update bar positioning when needed
    local function UpdateBarPositions()
        addon:DebugInfo("ExpRepBar", "========== 开始UpdateBarPositions ==========")
        
        if not addon.ActionBarFrames.repexpbar then
            addon:DebugInfo("ExpRepBar", "错误：ActionBarFrames.repexpbar不存在")
            return
        end

        local mainMenuExpBar = MainMenuExpBar
        
        -- Get config values
        local config = addon.db and addon.db.profile.xprepbar
        local expScale = (config and config.expbar_scale) or 0.9
        local hideAllBars = (config and config.hide_all_bars) or false
        
        addon:DebugInfo("ExpRepBar", string.format("expScale:%.2f, hideAllBars:%s", expScale, tostring(hideAllBars)))
        
        -- ⚠️ 如果选项为隐藏所有条，则隐藏经验条
        if hideAllBars then
            addon:DebugInfo("ExpRepBar", "⚠️ 隐藏所有条模式已启用")
            if mainMenuExpBar then
                mainMenuExpBar:Hide()
                mainMenuExpBar:SetAlpha(0)
                addon:DebugInfo("ExpRepBar", "✅ 已隐藏经验条")
            end
            return
        end
        
        addon:DebugInfo("ExpRepBar", "---------- 单条模式：经验条/声望条切换 ----------")

        -- 检查玩家是否满级
        local playerLevel = UnitLevel("player")
        local maxLevel = GetMaxPlayerLevel()
        local isMaxLevel = playerLevel == maxLevel
        local factionName = GetWatchedFactionInfo()
        local hasWatchedFaction = factionName ~= nil

        addon:DebugInfo("ExpRepBar", string.format("玩家等级 %d/%d, 满级=%s, 声望名=%s, 已监视=%s",
            playerLevel or 0, maxLevel or 0, tostring(isMaxLevel),
            tostring(factionName), tostring(hasWatchedFaction)))
        
        -- 确保自定义声望条已创建
        if not addon.RepBar then
            -- 已由模块级代码自动创建
        end
        
        if isMaxLevel and hasWatchedFaction then
            if mainMenuExpBar then
                mainMenuExpBar:Hide()
                mainMenuExpBar:SetAlpha(0)
            end
            addon.ShowRepBar()
        elseif not isMaxLevel then
            addon:DebugInfo("ExpRepBar", "未满级状态：显示经验条")
            
            if mainMenuExpBar then
                mainMenuExpBar:ClearAllPoints()
                mainMenuExpBar:SetSize(526, 10)
                mainMenuExpBar:SetFrameLevel(2)
                mainMenuExpBar:SetScale(expScale)
                mainMenuExpBar:Show()
                mainMenuExpBar:SetAlpha(1)
                local singleOffset = (config and config.singlebar_offset) or 0
                mainMenuExpBar:SetPoint("CENTER", addon.ActionBarFrames.repexpbar, "CENTER", 0, singleOffset)
                
                local expX, expY = mainMenuExpBar:GetCenter()
                local expW, expH = mainMenuExpBar:GetSize()
                addon:DebugInfo("ExpRepBar", string.format("经验条设置后 - 坐标:(%.1f,%.1f) 大小:%.1fx%.1f Offset:%.1f", expX or 0, expY or 0, expW, expH, singleOffset))
            end
            
            -- 隐藏自定义声望条
            addon.HideRepBar()
        else
            -- 满级但没有监视的声望：隐藏所有条
            addon:DebugInfo("ExpRepBar", "满级状态 + 无监视声望：隐藏所有条")
            
            if mainMenuExpBar then
                mainMenuExpBar:Hide()
                mainMenuExpBar:SetAlpha(0)
            end
            
            addon.HideRepBar()
        end
        
        addon:DebugInfo("ExpRepBar", "========== UpdateBarPositions完成 ==========")
    end

    -- SOLUCIÓN ANTI-PARPADEO: Hook SetPoint para interceptar movimientos no deseados de Blizzard
    local originalExpBarSetPoint = nil
    local originalRepBarSetPoint = nil

    local function ApplyExpBarPosition()
        if InCombatLockdown() then
            return
        end
        
        local config = addon.db and addon.db.profile.xprepbar
        if not config then
            return
        end
        
        local expScale = config.expbar_scale or 0.9
        local singleOffset = config.singlebar_offset or 0
        
        if MainMenuExpBar and addon.ActionBarFrames.repexpbar then
            MainMenuExpBar:ClearAllPoints()
            MainMenuExpBar:SetPoint("CENTER", addon.ActionBarFrames.repexpbar, "CENTER", 0, singleOffset)
        end
    end

    local function ApplyRepBarPosition()
        if InCombatLockdown() then
            return
        end
        
        local config = addon.db and addon.db.profile.xprepbar
        if not config then
            return
        end
        
        -- ⚠️ 声望条已在disableblizzard.lua中被彻底禁用
    end

    -- Hook experience bar SetPoint
    if MainMenuExpBar then
        originalExpBarSetPoint = MainMenuExpBar.SetPoint
        MainMenuExpBar.SetPoint = function(self, point, relativeTo, relativePoint, x, y)
            -- SEGURO: En combate, usar el comportamiento original
            if InCombatLockdown() then
                if originalExpBarSetPoint then
                    originalExpBarSetPoint(self, point, relativeTo, relativePoint, x, y)
                end
                return
            end

            -- Si Blizzard intenta mover la barra a UIParent u otros frames no deseados,
            -- forzar la posición de DragonUI
            if relativeTo == UIParent or (type(relativeTo) == "string" and relativeTo ~= "DragonUI_RepExpBar") then
                -- Ignorar el intento de Blizzard y aplicar nuestra posición
                ApplyExpBarPosition()
            else
                -- Permitir otros anclajes legítimos
                if originalExpBarSetPoint then
                    originalExpBarSetPoint(self, point, relativeTo, relativePoint, x, y)
                end
            end
        end
    end

    -- ⚠️ 声望条和神器能量条已在disableblizzard.lua中被彻底禁用
    -- 相关的SetPoint挂钩已移除

    -- ⚠️ 注意：此函数只处理暴雪UI的装饰纹理
    -- 框架的禁用（事件、脚本等）由 disableblizzard 模块负责
    local function RemoveBlizzardFrames()
        -- ⚠️ 神器能量条已在disableblizzard.lua中被彻底禁用
        
        -- 隐藏装饰纹理（这些不是框架，只是纹理对象）
        local blizzTextures = {
            MainMenuBarPerformanceBar,
            MainMenuBarTexture0, MainMenuBarTexture1, MainMenuBarTexture2, MainMenuBarTexture3,
            ReputationXPBarTexture1, ReputationXPBarTexture2, ReputationXPBarTexture3,
            ReputationWatchBarTexture1, ReputationWatchBarTexture2, ReputationWatchBarTexture3,
            MainMenuXPBarTexture1, MainMenuXPBarTexture2, MainMenuXPBarTexture3,
            SlidingActionBarTexture0, SlidingActionBarTexture1,
            BonusActionBarTexture0, BonusActionBarTexture1,
            ShapeshiftBarLeft, ShapeshiftBarMiddle, ShapeshiftBarRight,
            PossessBackground1, PossessBackground2
        }

        for _, texture in pairs(blizzTextures) do
            if texture then
                texture:SetAlpha(0)
                texture:Hide()
            end
        end
        
        addon:DebugInfo("Mainbars", "✅ 已隐藏暴雪装饰纹理（框架禁用由disableblizzard模块负责）")
    end

    function MainMenuBarMixin:initialize()
        self:actionbutton_setup();
        self:actionbar_setup();
        self:actionbar_art_setup();
        self:statusbar_setup();
    end

    -- Create action bar container frames (RetailUI pattern)
    local function CreateActionBarFrames()
        -- Main bar - create a NEW container frame instead of using pUiMainBar directly
        addon.ActionBarFrames.mainbar = addon.CreateUIFrame(pUiMainBar:GetWidth(), pUiMainBar:GetHeight(), "MainBar")

        -- Create other action bar containers
        addon.ActionBarFrames.rightbar = addon.CreateUIFrame(40, 490, "RightBar")
        addon.ActionBarFrames.leftbar = addon.CreateUIFrame(40, 490, "LeftBar")
        addon.ActionBarFrames.bottombarleft = addon.CreateUIFrame(490, 40, "BottomBarLeft")
        addon.ActionBarFrames.bottombarright = addon.CreateUIFrame(490, 40, "BottomBarRight")

        -- RepExp bar container (RetailUI pattern) - for experience bar
        addon.ActionBarFrames.repexpbar = addon.CreateUIFrame(addon.ActionBarFrames.mainbar:GetWidth(), 10, "RepExpBar")
        
        -- ⭐ 新增：声望条独立容器
        addon.ActionBarFrames.reputationbar = addon.CreateUIFrame(addon.ActionBarFrames.mainbar:GetWidth(), 10, "ReputationBar")
        
        -- ⭐ 新增：神器能量条独立容器（职业大厅资源条）
        addon.ActionBarFrames.artifactbar = addon.CreateUIFrame(addon.ActionBarFrames.mainbar:GetWidth(), 10, "ArtifactBar")
    end

    -- Position action bars to their container frames (initialization only - safe during addon load)
    local function PositionActionBarsToContainers_Initial()
        -- Position main bar - anchor pUiMainBar to its container
        if pUiMainBar and addon.ActionBarFrames.mainbar then
            pUiMainBar:SetParent(UIParent)
            pUiMainBar:ClearAllPoints()
            pUiMainBar:SetPoint("CENTER", addon.ActionBarFrames.mainbar, "CENTER")
        end

        -- Position right bar
        if MultiBarRight and addon.ActionBarFrames.rightbar then
            MultiBarRight:SetParent(UIParent)
            MultiBarRight:ClearAllPoints()
            MultiBarRight:SetPoint("CENTER", addon.ActionBarFrames.rightbar, "CENTER")
        end

        -- Position left bar
        if MultiBarLeft and addon.ActionBarFrames.leftbar then
            MultiBarLeft:SetParent(UIParent)
            MultiBarLeft:ClearAllPoints()
            MultiBarLeft:SetPoint("CENTER", addon.ActionBarFrames.leftbar, "CENTER")
        end

        -- Position bottom left bar
        if MultiBarBottomLeft and addon.ActionBarFrames.bottombarleft then
            MultiBarBottomLeft:SetParent(UIParent)
            MultiBarBottomLeft:ClearAllPoints()
            MultiBarBottomLeft:SetPoint("CENTER", addon.ActionBarFrames.bottombarleft, "CENTER")
        end

        -- Position bottom right bar
        if MultiBarBottomRight and addon.ActionBarFrames.bottombarright then
            MultiBarBottomRight:SetParent(UIParent)
            MultiBarBottomRight:ClearAllPoints()
            MultiBarBottomRight:SetPoint("CENTER", addon.ActionBarFrames.bottombarright, "CENTER")
        end
    end

    -- Position action bars to their container frames
    local function PositionActionBarsToContainers()
        -- Only proceed if not in combat to avoid taint
        if InCombatLockdown() then
            return
        end

        -- Use the initial function for runtime positioning
        PositionActionBarsToContainers_Initial()
    end

    -- Apply saved positions from database (RetailUI pattern)
    local function ApplyActionBarPositions()
        -- CRÍTICO: No tocar frames durante combate para evitar taint
        if InCombatLockdown() then
            return
        end

        if not addon.db or not addon.db.profile or not addon.db.profile.widgets then
            return
        end

        local widgets = addon.db.profile.widgets

        -- Apply mainbar container position
        if widgets.mainbar and addon.ActionBarFrames.mainbar then
            local config = widgets.mainbar
            if config.anchor then
                addon.ActionBarFrames.mainbar:ClearAllPoints()
                addon.ActionBarFrames.mainbar:SetPoint(config.anchor, config.posX, config.posY)
            end
        end

        -- Apply other bar positions
        local barConfigs = {{
            frame = addon.ActionBarFrames.rightbar,
            config = widgets.rightbar,
            default = {"RIGHT", -10, -70}
        }, {
            frame = addon.ActionBarFrames.leftbar,
            config = widgets.leftbar,
            default = {"RIGHT", -45, -70}
        }, {
            frame = addon.ActionBarFrames.bottombarleft,
            config = widgets.bottombarleft,
            default = {"BOTTOM", 0, 120}
        }, {
            frame = addon.ActionBarFrames.bottombarright,
            config = widgets.bottombarright,
            default = {"BOTTOM", 0, 160}
        }, -- RetailUI pattern: RepExp bar positioning
        {
            frame = addon.ActionBarFrames.repexpbar,
            config = widgets.repexpbar,
            default = {"BOTTOM", 0, 60}
        }, -- ⭐ 新增：声望条默认位置（经验条下方）
        {
            frame = addon.ActionBarFrames.reputationbar,
            config = widgets.reputationbar,
            default = {"BOTTOM", 0, 20}
        }, -- ⭐ 新增：神器能量条默认位置（经验条上方）
        {
            frame = addon.ActionBarFrames.artifactbar,
            config = widgets.artifactbar,
            default = {"BOTTOM", 0, 50}
        }}

        for _, barData in ipairs(barConfigs) do
            if barData.frame and barData.config and barData.config.anchor then
                local config = barData.config
                barData.frame:ClearAllPoints()
                barData.frame:SetPoint(config.anchor, config.posX, config.posY)
            elseif barData.frame then
                -- Apply default position
                local default = barData.default
                barData.frame:ClearAllPoints()
                barData.frame:SetPoint(default[1], UIParent, default[1], default[2], default[3])
            end
        end
    end

    -- Register action bar frames with the centralized system (RetailUI pattern)
    local function RegisterActionBarFrames()
        -- Register all action bar frames
        local frameRegistrations = {{
            name = "mainbar",
            frame = addon.ActionBarFrames.mainbar,
            blizzardFrame = MainMenuBar,
            configPath = {"widgets", "mainbar"}
        }, {
            name = "rightbar",
            frame = addon.ActionBarFrames.rightbar,
            blizzardFrame = MultiBarRight,
            configPath = {"widgets", "rightbar"}
        }, {
            name = "leftbar",
            frame = addon.ActionBarFrames.leftbar,
            blizzardFrame = MultiBarLeft,
            configPath = {"widgets", "leftbar"}
        }, {
            name = "bottombarleft",
            frame = addon.ActionBarFrames.bottombarleft,
            blizzardFrame = MultiBarBottomLeft,
            configPath = {"widgets", "bottombarleft"}
        }, {
            name = "bottombarright",
            frame = addon.ActionBarFrames.bottombarright,
            blizzardFrame = MultiBarBottomRight,
            configPath = {"widgets", "bottombarright"}
        }, -- RetailUI pattern: RepExp bar registration
        {
            name = "repexpbar",
            frame = addon.ActionBarFrames.repexpbar,
            blizzardFrame = nil,
            configPath = {"widgets", "repexpbar"}
        }, -- ⚠️ 声望条独立容器注册（原生条已禁用）
        {
            name = "reputationbar",
            frame = addon.ActionBarFrames.reputationbar,
            blizzardFrame = nil, -- ⚠️ 原生声望条已在disableblizzard.lua中被彻底禁用
            configPath = {"widgets", "reputationbar"}
        }, -- ⚠️ 神器能量条独立容器注册（原生条已禁用）
        {
            name = "artifactbar",
            frame = addon.ActionBarFrames.artifactbar,
            blizzardFrame = nil, -- ⚠️ 原生神器能量条已在disableblizzard.lua中被彻底禁用
            configPath = {"widgets", "artifactbar"}
        }}

        for _, registration in ipairs(frameRegistrations) do
            if registration.frame then
                addon:RegisterEditableFrame({
                    name = registration.name,
                    frame = registration.frame,
                    blizzardFrame = registration.blizzardFrame,
                    configPath = registration.configPath,
                    module = addon.MainBars
                })
            end
        end
    end

    -- Hook drag events to ensure action bars follow their containers
    local function SetupActionBarDragHandlers()
        -- Add drag end handlers to reposition action bars
        for name, frame in pairs(addon.ActionBarFrames) do
            -- Exclude bars that don't need repositioning after drag
            if frame and name ~= "mainbar" then
                frame:HookScript("OnDragStop", function(self)
                    -- RetailUI Pattern: Only reposition if not in combat
                    PositionActionBarsToContainers()
                end)
            end
        end
    end

    -- update position for secondary action bars - LEGACY FUNCTION
    function addon.RefreshUpperActionBarsPosition()
        if not MultiBarBottomLeftButton1 or not MultiBarBottomRight then
            return
        end

        -- calculate offset based on background visibility
        local yOffset1, yOffset2
        if addon.db and addon.db.profile.buttons.hide_main_bar_background then
            -- values when background is hidden
            yOffset1 = 45
            yOffset2 = 8
        else
            -- default values when background is visible
            yOffset1 = 48
            yOffset2 = 8
        end
    end

    -- Apply the mainbars system
    local function ApplyMainbarsSystem()
        if MainbarsModule.applied then
            return
        end

        -- ⚠️ 神器能量条已在disableblizzard.lua中被彻底禁用

        MainMenuBarMixin:initialize()
        addon.pUiMainBar = pUiMainBar

        CreateActionBarFrames()
        ApplyActionBarPositions()
        RegisterActionBarFrames()

        -- Note: Gryphon frame levels will be set after all positioning is complete

        -- Set up hooks for XP/Rep bars - RESTORED FUNCTIONALITY
        -- Connect bars to editor system first
        ConnectBarsToEditor()

        -- Force reputation text configuration
        ForceReputationTextConfiguration()

        -- Hook for maintaining editor connection
        -- 7.3.5 compatibility: MainMenuExpBar_Update may not exist
        if MainMenuExpBar_Update then
            hooksecurefunc('MainMenuExpBar_Update', UpdateBarPositions)
        end
        
        -- ⚠️ 声望条已在disableblizzard.lua中被彻底禁用，无需挂钩

        -- ⭐ NDui参考：挂钩StatusTrackingBarManager.UpdateBarsShown
        -- 当管理器试图更新经验/声望/神器能量条的显示状态时，
        -- 强制重新应用DragonUI的布局配置，防止暴雪恢复原生显示
        -- ⚠️ 声望条和神器能量条已在disableblizzard.lua中被彻底禁用
        if StatusTrackingBarManager and StatusTrackingBarManager.UpdateBarsShown then
            hooksecurefunc(StatusTrackingBarManager, "UpdateBarsShown", function()
                if not IsModuleEnabled() then return end
                UpdateBarPositions()
            end)
        end

        -- Position action bars immediately
        PositionActionBarsToContainers_Initial()

        -- Set up drag handlers - Execute immediately
        SetupActionBarDragHandlers()

        -- CRITICAL: Ensure gryphons are above all action bars after everything is positioned
        local function EnsureGryphonsOnTop()
            if pUiMainBarArt then
                -- Get the highest frame level from all action bars including containers
                local maxLevel = 1
                local bars = {MultiBarBottomLeft, MultiBarBottomRight, MultiBarLeft, MultiBarRight, pUiMainBar}
                for _, bar in pairs(bars) do
                    if bar then
                        maxLevel = math.max(maxLevel, bar:GetFrameLevel())
                    end
                end
                
                -- Check container frame levels too
                for _, frame in pairs(addon.ActionBarFrames) do
                    if frame and frame.GetFrameLevel then
                        maxLevel = math.max(maxLevel, frame:GetFrameLevel())
                    end
                end

                -- Set gryphon art frame level significantly higher than all bars
                pUiMainBarArt:SetFrameLevel(maxLevel + 15)
                
                -- Also ensure individual gryphons have high draw layers
                if MainMenuBarLeftEndCap then
                    MainMenuBarLeftEndCap:SetDrawLayer('OVERLAY', 7)
                end
                if MainMenuBarRightEndCap then
                    MainMenuBarRightEndCap:SetDrawLayer('OVERLAY', 7)
                end
            end
        end
        
        -- Execute immediately to ensure gryphons are on top
        EnsureGryphonsOnTop()

        -- Store module state
        MainbarsModule.frames.pUiMainBar = pUiMainBar
        MainbarsModule.frames.pUiMainBarArt = pUiMainBarArt
        MainbarsModule.actionBarFrames = addon.ActionBarFrames
        MainbarsModule.applied = true
    end

    -- Store functions globally for RefreshMainbarsSystem access
    addon.ApplyActionBarPositions = ApplyActionBarPositions
    addon.PositionActionBarsToContainers = PositionActionBarsToContainers
    
    -- ⭐ 新增: 导出声望经验条刷新函数，供配置面板调用
    addon.RefreshXpRepBarPosition = function()
        if not InCombatLockdown() then
            UpdateBarPositions()
        end
    end
    
    -- ⚠️ 声望条和神器能量条已在disableblizzard.lua中被彻底禁用
    addon.RefreshRepBarPosition = function()
        -- 声望条已禁用
    end
    
    -- ⚠️ 神器能量条已在disableblizzard.lua中被彻底禁用
    addon.RefreshArtifactBarPosition = function()
        -- 神器能量条已禁用
    end

    -- Initialize immediately since we're already enabled
    ApplyMainbarsSystem()

    -- Set up event handlers - Apply exp bar visual styling only
    local function ApplyModernExpBarVisual()
        addon:DebugInfo("ExpRepBar", "========== 开始ApplyModernExpBarVisual ==========")
        
        local exhaustionStateID = GetRestState()
        local mainMenuExpBar = MainMenuExpBar

        if not mainMenuExpBar then
            addon:DebugInfo("ExpRepBar", "错误：MainMenuExpBar不存在")
            return
        end
        
        -- ⭐ 深度调试：输出经验条基本信息
        local expX, expY = mainMenuExpBar:GetCenter()
        local expW, expH = mainMenuExpBar:GetSize()
        addon:DebugInfo("ExpRepBar", string.format("经验条MainMenuExpBar - 坐标:(%.1f,%.1f) 大小:%.1fx%.1f", expX or 0, expY or 0, expW, expH))
        addon:DebugInfo("ExpRepBar", string.format("经验条FrameLevel:%d FrameStrata:%s", mainMenuExpBar:GetFrameLevel(), mainMenuExpBar:GetFrameStrata()))

        -- ⚠️ 隐藏暴雪装饰纹理（但保留Div格子）
        if MainMenuXPBarTextureMid then
            MainMenuXPBarTextureMid:Hide()
            addon:DebugInfo("ExpRepBar", "已隐藏MainMenuXPBarTextureMid")
        end
        if MainMenuXPBarTextureLeftCap then
            MainMenuXPBarTextureLeftCap:Hide()
            addon:DebugInfo("ExpRepBar", "已隐藏MainMenuXPBarTextureLeftCap")
        end
        if MainMenuXPBarTextureRightCap then
            MainMenuXPBarTextureRightCap:Hide()
            addon:DebugInfo("ExpRepBar", "已隐藏MainMenuXPBarTextureRightCap")
        end
        
        -- ⚠️ 关键：隐藏Div1-19分隔条（它们是为暴雪原始宽度设计的，会超出526px）
        for i = 1, 19 do
            local div = _G["MainMenuXPBarDiv" .. i]
            if div then
                div:Hide()
            end
        end
        addon:DebugInfo("ExpRepBar", "已隐藏所有Div分隔条")
        
        -- ✅ 关键：使用DragonUI的双层纹理系统（正确理解）
        -- 第1层（BORDER）：StatusBarTexture用于进度填充（由暴雪自动管理宽度）

        -- 获取StatusBarTexture并设置属性
        local originalTexture = mainMenuExpBar:GetStatusBarTexture()
        if originalTexture then
            originalTexture:SetDrawLayer('BORDER')
            -- ⚠️ 只设置高度和锚点，不设置宽度！
            -- 暴雪的SetValue()会自动根据百分比调整宽度，SetSize会干扰此机制
            originalTexture:SetHeight(10)
            originalTexture:SetPoint('TOPLEFT', mainMenuExpBar, 'TOPLEFT', 0, 0)
            originalTexture:SetPoint('BOTTOMLEFT', mainMenuExpBar, 'BOTTOMLEFT', 0, 0)
            addon:DebugInfo("ExpRepBar", "已设置BORDER层（高度+锚点，宽度由暴雪自动管理）")
        end

        -- 第2层（ARTWORK）：创建边框纹理，使用ui-hud-experiencebar-round区域
        if not mainMenuExpBar.status then
            mainMenuExpBar.status = mainMenuExpBar:CreateTexture(nil, 'ARTWORK')
            addon:DebugInfo("ExpRepBar", "已创建mainMenuExpBar.status纹理")
        end

        -- 设置边框纹理（使用ui-hud-experiencebar-round的TexCoord）
        mainMenuExpBar.status:SetTexture(addon._dir .. "uiexperiencebar")
        mainMenuExpBar.status:SetSize(537, 18)  -- ui-hud-experiencebar-round的尺寸
        mainMenuExpBar.status:SetPoint('CENTER', mainMenuExpBar, 'CENTER', 0, 0)
        mainMenuExpBar.status:SetTexCoord(1/2048, 572/2048, 1/64, 18/64)  -- ui-hud-experiencebar-round区域
        addon:DebugInfo("ExpRepBar", "已设置status纹理为边框（ui-hud-experiencebar-round）")
        
        -- ⚠️ 关键：配置ExhaustionLevelFillBar（休息经验）
        if ExhaustionLevelFillBar then
            ExhaustionLevelFillBar:SetParent(mainMenuExpBar)
            if mainMenuExpBar.GetFrameLevel and ExhaustionLevelFillBar.SetFrameLevel then
                pcall(function()
                    ExhaustionLevelFillBar:SetFrameLevel(mainMenuExpBar:GetFrameLevel() - 1)
                end)
            end
            ExhaustionLevelFillBar:SetHeight(10)
            ExhaustionLevelFillBar:SetTexture(addon._dir .. 'statusbarfill.tga')
            -- ⚠️ 让暴雪自己管理ExhaustionLevelFillBar的颜色
            addon:DebugInfo("ExpRepBar", "已配置ExhaustionLevelFillBar")
        end
        
        -- 隐藏ExhaustionTick
        if ExhaustionTick then
            ExhaustionTick:Hide()
            addon:DebugInfo("ExpRepBar", "已隐藏ExhaustionTick")
        end
        
        addon:DebugInfo("ExpRepBar", "========== ApplyModernExpBarVisual完成 ==========")
    end

    -- Single event handler for addon initialization
    local initFrame = CreateFrame("Frame")
    initFrame:RegisterEvent("ADDON_LOADED")
    initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    initFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    initFrame:RegisterEvent("UPDATE_FACTION")
    initFrame:RegisterEvent("PET_BAR_UPDATE")
    initFrame:RegisterEvent("PET_BAR_UPDATE_COOLDOWN")
    initFrame:RegisterEvent("UNIT_PET")
    initFrame:RegisterEvent("UNIT_EXITED_VEHICLE")
    initFrame:RegisterEvent("UNIT_ENTERED_VEHICLE")
    initFrame:RegisterEvent("PLAYER_LOGIN")

    -- ⚠️ eventFrame只处理UPDATE_EXHAUSTION和PLAYER_XP_UPDATE，不处理PLAYER_ENTERING_WORLD（避免与initFrame冲突）
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("UPDATE_EXHAUSTION")
    eventFrame:RegisterEvent("PLAYER_XP_UPDATE")  -- ⚠️ 关键：监听经验值变化
    eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")  -- ⭐ 修复：监听区域变化以控制职业大厅资源条
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")  -- ⭐ 修复：监听玩家进入世界以控制职业大厅资源条
    eventFrame:RegisterEvent("ORDER_HALL_LANDING_PAGE_CLOSED")  -- ⭐ 修复：监听职业大厅界面关闭
    eventFrame:RegisterEvent("UPDATE_FACTION")  -- ⭐ 新增：监听声望变化，防止位置重置
    eventFrame:SetScript("OnEvent", function(self, event)
        if event == "UPDATE_EXHAUSTION" then
            addon:DebugInfo("ExpRepBar", "========== 事件：UPDATE_EXHAUSTION ===========")
            -- Update exhaustion state immediately - no timer needed
            ApplyModernExpBarVisual()
            ForceReputationTextConfiguration()
        elseif event == "PLAYER_XP_UPDATE" then
            addon:DebugInfo("ExpRepBar", "========== 事件：PLAYER_XP_UPDATE ==========")
            -- ⚠️ 不再调用 ApplyModernExpBarVisual()！
            -- 进度填充由暴雪 SetValue() 自动管理，每次 XP 变化都会实时更新宽度
            -- 这里只做轻量级操作：更新自定义文本数据
            if addon.UpdateExpBarText then
                addon.UpdateExpBarText()
            end
        elseif event == "UPDATE_FACTION" then
            addon:DebugInfo("ExpRepBar", "UPDATE_FACTION事件：更新声望条")
            UpdateBarPositions()
        elseif event == "ORDER_HALL_LANDING_PAGE_CLOSED" then
            addon:DebugInfo("Mainbars", "ORDER_HALL_LANDING_PAGE_CLOSED事件")
        elseif event == "ZONE_CHANGED_NEW_AREA" or event == "PLAYER_ENTERING_WORLD" then
        end
    end)

    initFrame:SetScript("OnEvent", function(self, event, addonName)
        if event == "ADDON_LOADED" and addonName == "DragonUI" then
            -- Initialize basic components immediately
            if IsModuleEnabled() then
                ApplyMainbarsSystem()
            end

        elseif event == "PLAYER_ENTERING_WORLD" then
            -- Apply XP/Rep bar styling and connect to editor - Execute immediately
            if IsModuleEnabled() then
                -- Remove interfering Blizzard textures FIRST
                RemoveBlizzardFrames()

                -- Connect bars to editor system
                ConnectBarsToEditor()

                -- Apply modern exhaustion system and styling
                ApplyModernExpBarVisual()
                
                -- Force reputation text configuration
                ForceReputationTextConfiguration()

                -- Update positions
                UpdateBarPositions()

                -- Hide text by default
                if MainMenuBarExpText then
                    MainMenuBarExpText:Hide()
                end

                if addon.UpdateExpBarText then
                    C_Timer.After(0.2, function()
                        addon.UpdateExpBarText()
                    end)
                end
                
                -- Ensure gryphons are on top after all setup is complete
                if pUiMainBarArt then
                    local maxLevel = 1
                    local bars = {MultiBarBottomLeft, MultiBarBottomRight, MultiBarLeft, MultiBarRight, pUiMainBar}
                    for _, bar in pairs(bars) do
                        if bar then
                            maxLevel = math.max(maxLevel, bar:GetFrameLevel())
                        end
                    end
                    
                    for _, frame in pairs(addon.ActionBarFrames) do
                        if frame and frame.GetFrameLevel then
                            maxLevel = math.max(maxLevel, frame:GetFrameLevel())
                        end
                    end

                    pUiMainBarArt:SetFrameLevel(maxLevel + 15)
                end
            end

            -- Initialize pet bar visibility - Execute immediately
            if IsModuleEnabled() then
                addon.UpdatePetBarVisibility()
            end

            self:UnregisterEvent("PLAYER_ENTERING_WORLD")

        elseif event == "PLAYER_LOGIN" then
            -- Set up profile callbacks - Execute immediately
            do
                if addon.db then
                    addon.db.RegisterCallback(addon, "OnProfileChanged", function()
                        -- Execute immediately - no timer needed
                        addon.RefreshMainbarsSystem()
                    end)
                    addon.db.RegisterCallback(addon, "OnProfileCopied", function()
                        -- Execute immediately - no timer needed  
                        addon.RefreshMainbarsSystem()
                    end)
                    addon.db.RegisterCallback(addon, "OnProfileReset", function()
                        -- Execute immediately - no timer needed
                        addon.RefreshMainbarsSystem()
                    end)

                    -- Initial refresh
                    addon.RefreshMainbarsSystem()
                end
            end

            self:UnregisterEvent("PLAYER_LOGIN")

        elseif event == "PLAYER_REGEN_ENABLED" then
            if IsModuleEnabled() then
                ApplyActionBarPositions()
                PositionActionBarsToContainers()
                UpdateBarPositions()
            end

        elseif event == "UPDATE_FACTION" then
            if IsModuleEnabled() then
                ApplyModernExpBarVisual()
                UpdateBarPositions()
            end

        elseif event == "PET_BAR_UPDATE" or event == "PET_BAR_UPDATE_COOLDOWN" or event == "UNIT_PET" then
            -- Handle pet bar visibility and updates - Execute immediately
            if IsModuleEnabled() and (arg1 == "player" or not arg1) then
                addon.UpdatePetBarVisibility()
            end

        elseif event == "UNIT_ENTERED_VEHICLE" or event == "UNIT_EXITED_VEHICLE" then
            -- Handle vehicle events that affect pet bar - Execute immediately
            if IsModuleEnabled() and arg1 == "player" then
                addon.UpdatePetBarVisibility()
            end
        end
    end)

end

-- ============================================================================
-- INITIALIZATION CONTROL
-- ============================================================================

-- Event frame to handle initialization
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self, event, addonName)
    if event == "ADDON_LOADED" and addonName == "DragonUI" then
        -- Solo inicializar si está habilitado
        InitializeMainbars()
        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_LOGIN" then
        -- Backup check
        InitializeMainbars()
        self:UnregisterEvent("PLAYER_LOGIN")
    end
end)

-- Global UpdateGryphonStyle function (accessible from RefreshMainbarsSystem)
function addon.UpdateGryphonStyle()
    if not MainMenuBarLeftEndCap or not MainMenuBarRightEndCap then
        return
    end

    local db_style = addon.db and addon.db.profile and addon.db.profile.style
    if not db_style then
        db_style = config.style
    end

    local faction = UnitFactionGroup('player')

    if db_style.gryphons == 'old' then
        MainMenuBarLeftEndCap:SetClearPoint('BOTTOMLEFT', -85, -52)
        MainMenuBarRightEndCap:SetClearPoint('BOTTOMRIGHT', 84, -52)
        MainMenuBarLeftEndCap:set_atlas('ui-hud-actionbar-gryphon-left', true)
        MainMenuBarRightEndCap:set_atlas('ui-hud-actionbar-gryphon-right', true)
        MainMenuBarLeftEndCap:Show()
        MainMenuBarRightEndCap:Show()
    elseif db_style.gryphons == 'new' then
        MainMenuBarLeftEndCap:SetClearPoint('BOTTOMLEFT', -94, -18)
        MainMenuBarRightEndCap:SetClearPoint('BOTTOMRIGHT', 95, -18)
        if faction == 'Alliance' then
            MainMenuBarLeftEndCap:set_atlas('ui-hud-actionbar-gryphon-thick-left', true)
            MainMenuBarRightEndCap:set_atlas('ui-hud-actionbar-gryphon-thick-right', true)
        else
            MainMenuBarLeftEndCap:set_atlas('ui-hud-actionbar-wyvern-thick-left', true)
            MainMenuBarRightEndCap:set_atlas('ui-hud-actionbar-wyvern-thick-right', true)
        end
        MainMenuBarLeftEndCap:Show()
        MainMenuBarRightEndCap:Show()
    elseif db_style.gryphons == 'flying' then
        MainMenuBarLeftEndCap:SetClearPoint('BOTTOMLEFT', -80, -16)
        MainMenuBarRightEndCap:SetClearPoint('BOTTOMRIGHT', 80, -16)
        MainMenuBarLeftEndCap:set_atlas('ui-hud-actionbar-gryphon-flying-left', true)
        MainMenuBarRightEndCap:set_atlas('ui-hud-actionbar-gryphon-flying-right', true)
        MainMenuBarLeftEndCap:Show()
        MainMenuBarRightEndCap:Show()
    else
        MainMenuBarLeftEndCap:Hide()
        MainMenuBarRightEndCap:Hide()
    end
end

-- Public API for options
function addon.RefreshMainbarsSystem()
    if not IsModuleEnabled() then
        return
    end

    addon:DebugInfo("Mainbars", "========== RefreshMainbarsSystem 被调用 ==========")

    -- CRÍTICO: No tocar frames protegidos durante combate
    if InCombatLockdown() then
        -- Solo actualizar cosas seguras (no frames)
        addon:DebugInfo("Mainbars", "战斗中，仅更新安全元素")
        addon.UpdateGryphonStyle()
        if addon.MainMenuBarMixin and addon.MainMenuBarMixin.update_main_bar_background then
            addon.MainMenuBarMixin:update_main_bar_background()
        end
        return
    end

    -- Apply scales to all action bars (SOLO FUERA DE COMBATE)
    local db = addon.db and addon.db.profile and addon.db.profile.mainbars
    if not db then
        addon:DebugInfo("Mainbars", "警告：无法获取mainbars配置")
        return
    end

    -- Apply main bar scale
    if addon.pUiMainBar and db.scale_actionbar then
        addon.pUiMainBar:SetScale(db.scale_actionbar)
    end

    -- Apply scales to other bars
    if MultiBarRight and db.scale_rightbar then
        MultiBarRight:SetScale(db.scale_rightbar)
    end

    if MultiBarLeft and db.scale_leftbar then
        MultiBarLeft:SetScale(db.scale_leftbar)
    end

    if MultiBarBottomLeft and db.scale_bottomleft then
        MultiBarBottomLeft:SetScale(db.scale_bottomleft)
    end

    if MultiBarBottomRight and db.scale_bottomright then
        MultiBarBottomRight:SetScale(db.scale_bottomright)
    end

    -- Update gryphon style and background
    addon.UpdateGryphonStyle()
    if addon.MainMenuBarMixin and addon.MainMenuBarMixin.update_main_bar_background then
        addon:DebugInfo("Mainbars", "调用 update_main_bar_background")
        addon.MainMenuBarMixin:update_main_bar_background()
    end

    -- Update positioning (safe check inside)
    if addon.PositionActionBars then
        addon.PositionActionBars()
    end

    -- Update widget positions if available
    if addon.ActionBarFrames and addon.ApplyActionBarPositions then
        addon.ApplyActionBarPositions()
        if addon.PositionActionBarsToContainers then
            addon.PositionActionBarsToContainers()
        end
    end
    
    addon:DebugInfo("Mainbars", "========== RefreshMainbarsSystem 完成 ==========")
end

-- Alias for compatibility
addon.RefreshMainbars = addon.RefreshMainbarsSystem

-- ============================================================================
-- 模块级自定义经验条文本（悬停显示，与声望条行为一致）
-- ============================================================================

addon.ExpBarText = nil

local function CreateExpBarText()
    if not MainMenuExpBar then return end

    if not addon.ExpBarText then
        local text = MainMenuExpBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        text:SetPoint("CENTER", MainMenuExpBar, "CENTER", 0, 0)
        text:SetJustifyH("CENTER")
        text:Hide()
        addon.ExpBarText = text
    end

    return addon.ExpBarText
end

local function UpdateExpBarText()
    local text = CreateExpBarText()
    if not text then return end

    local currentXP = UnitXP("player") or 0
    local maxXP = UnitXPMax("player") or 1
    local restXP = GetXPExhaustion() or 0
    local playerLevel = UnitLevel("player") or 0

    if maxXP > 0 then
        local percent = math.floor(currentXP / maxXP * 100)
        if restXP and restXP > 0 then
            text:SetText(string.format("%d / %d (%d%%) [+%d休息]", currentXP, maxXP, percent, restXP))
        else
            text:SetText(string.format("%d / %d (%d%%)", currentXP, maxXP, percent))
        end
    else
        text:SetText("")
    end
end

addon.UpdateExpBarText = UpdateExpBarText

C_Timer.After(1.0, function()
    if MainMenuBarExpText then
        hooksecurefunc(MainMenuBarExpText, "Show", function(self)
            self:Hide()
        end)
        MainMenuBarExpText:Hide()
    end
end)

local expTextUpdateFrame = CreateFrame("Frame")
expTextUpdateFrame:RegisterEvent("PLAYER_XP_UPDATE")
expTextUpdateFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
expTextUpdateFrame:RegisterEvent("UPDATE_EXHAUSTION")
expTextUpdateFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_XP_UPDATE" or event == "PLAYER_ENTERING_WORLD" or event == "UPDATE_EXHAUSTION" then
        C_Timer.After(0.1, UpdateExpBarText)
    end
end)

C_Timer.After(2.0, function()
    if MainMenuExpBar then
        MainMenuExpBar:EnableMouse(true)
        MainMenuExpBar:SetScript("OnEnter", function(self)
            UpdateExpBarText()
            if addon.ExpBarText then
                addon.ExpBarText:Show()
            end

            GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT", 0, 8)
            local currentXP = UnitXP("player") or 0
            local maxXP = UnitXPMax("player") or 1
            local restXP = GetXPExhaustion() or 0
            local playerLevel = UnitLevel("player") or 0
            GameTooltip:AddLine(string.format("等级 %d 经验", playerLevel), 1, 1, 1)
            GameTooltip:AddLine(" ")
            GameTooltip:AddDoubleLine("当前经验", string.format("%d / %d", currentXP, maxXP), 1, 1, 1, 1, 1, 1)
            if maxXP > 0 then
                GameTooltip:AddDoubleLine("完成百分比", string.format("%.1f%%", currentXP / maxXP * 100), 1, 1, 1, 1, 1, 1)
                local remaining = maxXP - currentXP
                GameTooltip:AddDoubleLine("剩余经验", tostring(remaining), 1, 1, 1, 1, 1, 1)
            end
            if restXP and restXP > 0 then
                GameTooltip:AddDoubleLine("休息经验", string.format("+%d (双倍)", restXP), 0, 0.8, 1, 0, 0.8, 1)
            end
            GameTooltip:Show()
        end)

        MainMenuExpBar:SetScript("OnLeave", function(self)
            if addon.ExpBarText then
                addon.ExpBarText:Hide()
            end
            GameTooltip:Hide()
        end)
    end
end)

-- ============================================================================
-- 模块级自定义声望条（完全独立于 InitializeMainbars 作用域）
-- ============================================================================

-- 创建声望条
if not addon.RepBar then
    local bar = CreateFrame("StatusBar", "DragonUIRepBar", UIParent)
    bar:SetSize(526, 10)
    bar:SetFrameStrata("MEDIUM")
    bar:SetFrameLevel(1)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:Hide()
    
    local border = bar:CreateTexture(nil, "ARTWORK")
    border:SetTexture(addon._dir .. "uiexperiencebar")
    border:SetSize(537, 18)
    border:SetPoint("CENTER", bar, "CENTER", 0, 0)
    border:SetTexCoord(1/2048, 572/2048, 1/64, 18/64)
    
    addon.RepBar = bar
    addon.RepBarBorder = border
    
    local text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("CENTER", bar, "CENTER", 0, 0)
    text:SetJustifyH("CENTER")
    text:Hide()
    bar.text = text
    
    bar:SetScript("OnEnter", function(self)
        local name, standing, barMin, barMax, barValue = GetWatchedFactionInfo()
        if not name then return end
        local standingLabel = _G["FACTION_STANDING_LABEL" .. standing] or ""
        local progress = (barValue or 0) - (barMin or 0)
        local range = (barMax or 0) - (barMin or 0)
        
        self.text:SetText(string.format("%s  %s  %d/%d", name, standingLabel, progress, range))
        self.text:Show()
        
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT", 0, 8)
        GameTooltip:AddLine(name, 1, 1, 1)
        GameTooltip:AddLine(standingLabel, 1, 0.82, 0)
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("当前进度", string.format("%d / %d", progress, range), 1, 1, 1, 1, 1, 1)
        if range > 0 then
            GameTooltip:AddDoubleLine("完成百分比", string.format("%.1f%%", progress / range * 100), 1, 1, 1, 1, 1, 1)
        end
        GameTooltip:Show()
    end)
    bar:SetScript("OnLeave", function(self)
        self.text:Hide()
        GameTooltip:Hide()
    end)
end

-- 更新数据
addon.UpdateRepBar = function()
    local bar = addon.RepBar
    if not bar then return end
    
    local name, standing, barMin, barMax, barValue = GetWatchedFactionInfo()
    if not name then return end

    local color = FACTION_BAR_COLORS[standing] or FACTION_BAR_COLORS[1]
    bar:SetStatusBarColor(color.r, color.g, color.b, 0.85)
    local progress = (barValue or 0) - (barMin or 0)
    local range = (barMax or 0) - (barMin or 0)
    if range < 1 then range = 1 end
    bar:SetMinMaxValues(0, range)
    bar:SetValue(progress)
end

-- 显示（直接定位到屏幕底部中央，即经验条的位置）
addon.ShowRepBar = function()
    local bar = addon.RepBar
    if not bar then return end
    
    addon.UpdateRepBar()
    
    local config = addon.db and addon.db.profile.xprepbar
    local scale = (config and config.expbar_scale) or 0.9
    local offset = (config and config.singlebar_offset) or 0
    
    bar:ClearAllPoints()
    bar:SetPoint("CENTER", addon.ActionBarFrames.repexpbar, "CENTER", 0, offset)
    bar:SetSize(526, 10)
    bar:SetFrameStrata("MEDIUM")
    bar:SetFrameLevel(2)
    bar:SetScale(scale)
    bar:SetAlpha(1)
    bar:Show()
end

-- 隐藏
addon.HideRepBar = function()
    local bar = addon.RepBar
    if bar then
        bar:Hide()
        bar:SetAlpha(0)
    end
end
 
_G["TestBar"] = function()
     local bar = addon.RepBar
    if not bar then print("RepBar不存在") return end
    print(string.format("大小: %.0fx%.0f", bar:GetSize()))
    print(string.format("父框架: %s", bar:GetParent():GetName() or "无"))
    addon.ShowRepBar()

    local name, standing, barMin, barMax, barValue = GetWatchedFactionInfo()
    print(string.format("--- API原始值 ---"))
    print(string.format("name=%s", tostring(name)))
    print(string.format("standing=%d", standing or 0))
    print(string.format("barMin=%d", barMin or 0))
    print(string.format("barMax=%d", barMax or 0))
    print(string.format("barValue=%d", barValue or 0))

    local progress = (barValue or 0) - (barMin or 0)
    local range = (barMax or 0) - (barMin or 0)
    print(string.format("--- 计算值 ---"))
    print(string.format("progress(barValue-barMin)=%d", progress))
    print(string.format("range(barMax-barMin)=%d", range))

    local minVal, maxVal = bar:GetMinMaxValues()
    local curVal = bar:GetValue()
    print(string.format("--- StatusBar实际设置 ---"))
    print(string.format("SetMinMaxValues=(%d,%d)", minVal or 0, maxVal or 0))
    print(string.format("SetValue=%d", curVal or 0))

    local x, y = bar:GetCenter()
    print(string.format("位置: (%.0f,%.0f) IsShown:%s Alpha:%.2f", x or 0, y or 0, bar:IsShown() and "是" or "否", bar:GetAlpha()))
end

_G["TestRepAPI"] = function()
    local name, standing, barMin, barMax, barValue = GetWatchedFactionInfo()
    if not name then print("没有监视声望") return end
    local standingLabel = _G["FACTION_STANDING_LABEL" .. standing] or ""
    print(string.format("声望: %s | 等级: %s(%d)", name, standingLabel, standing))
    print(string.format("barMin=%d  barMax=%d  barValue=%d", barMin or 0, barMax or 0, barValue or 0))
    print(string.format("当前等级进度: %d / %d", (barValue or 0) - (barMin or 0), (barMax or 0) - (barMin or 0)))
end

-- ============================================================================
-- ⚠️ 独立初始化：确保经验条容器始终存在（不依赖模块启用状态）
-- ============================================================================
do
    -- 确保 ActionBarFrames 表存在
    if not addon.ActionBarFrames then
        addon.ActionBarFrames = {}
    end
    
    -- 如果 repexpbar 容器不存在，立即创建（模块未启用时也需要）
    if not addon.ActionBarFrames.repexpbar then
        local container = CreateFrame("Frame", "DragonUI_RepExpBar", UIParent)
        container:SetSize(537, 10)
        container:SetFrameStrata("MEDIUM")
        container:SetFrameLevel(1)
        -- 设置默认位置（屏幕底部中央）
        container:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 60)
        container:Show()  -- ⚠️ 关键：确保显示
        
        addon.ActionBarFrames.repexpbar = container
    end
    
    -- 初始化时直接设置经验条到容器
    C_Timer.After(1.0, function()
        if MainMenuExpBar and addon.ActionBarFrames.repexpbar then
            MainMenuExpBar:SetParent(addon.ActionBarFrames.repexpbar)
            MainMenuExpBar:ClearAllPoints()
            MainMenuExpBar:SetSize(526, 10)
            MainMenuExpBar:SetPoint("CENTER", addon.ActionBarFrames.repexpbar, "CENTER", 0, 0)
            
            -- 检查玩家等级决定是否显示
            local playerLevel = UnitLevel("player") or 0
            local maxLevel = GetMaxPlayerLevel() or 0
            
            if playerLevel < maxLevel then
                MainMenuExpBar:Show()
                MainMenuExpBar:SetAlpha(1)
            else
                MainMenuExpBar:Hide()
                MainMenuExpBar:SetAlpha(0)
            end
        end
    end)
end
