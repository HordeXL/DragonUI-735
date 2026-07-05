local addon = select(2, ...)

-- ============================================================================
-- DRAGONUI NAMEPLATE MODULE - WoW 7.3.5
-- ============================================================================
-- DragonUI 风格的姓名版模块，基于暴雪 NamePlate2 系统

local Module = {
    initialized = false,
    activePlates = {},
    unitToPlate = {},
}

-- ============================================================================
-- CONFIGURATION
-- ============================================================================

local function GetConfig()
    local config
    if addon and addon.GetConfigValue then
        config = addon:GetConfigValue("unitframe", "nameplate")
    end
    if not config then
        config = {}
    end

    local defaults = {
        enabled = true,
        classcolor = true,
        showThreatGlow = true,
        showNameBackground = true,
        showLevel = true,
        showCastBar = true,
        showPowerBar = false,
        showHealthText = true,
        borderStyle = "castbar",
        width = 120,
        healthBarHeight = 8,
        castBarHeight = 6,
        powerBarHeight = 4,
        nameFontSize = 10,
        healthFontSize = 9,
    }

    if addon and addon.defaults and addon.defaults.profile and addon.defaults.profile.unitframe and addon.defaults.profile.unitframe.nameplate then
        for k, v in pairs(addon.defaults.profile.unitframe.nameplate) do
            defaults[k] = v
        end
    end

    for key, value in pairs(defaults) do
        if config[key] == nil then
            config[key] = value
        end
    end

    return config
end

-- ============================================================================
-- CONSTANTS & TEXTURES
-- ============================================================================

local function FormatNumber(num)
    if not num then return "0" end
    if num >= 1000000 then
        return string.format("%.1fM", num / 1000000)
    elseif num >= 1000 then
        return string.format("%.1fK", num / 1000)
    else
        return tostring(num)
    end
end

local TEXTURES = {
    HEALTH_BAR = "Interface\\AddOns\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-Target-PortraitOn-Bar-Health",
    HEALTH_STATUS = "Interface\\AddOns\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-Target-PortraitOn-Bar-Health-Status",
    UNITFRAME_BORDER = "Interface\\AddOns\\DragonUI\\Textures\\UI-HUD-UnitFrame-Target-PortraitOn-BORDER",
    CAST_BAR = "Interface\\AddOns\\DragonUI\\Textures\\CastbarOriginal\\CastingBarStandard2",
    CASTBAR_ATLAS = "Interface\\AddOns\\DragonUI\\Textures\\CastbarOriginal\\uicastingbar2x",
}

local UV_COORDS = {
    background = {0.0009765625, 0.4130859375, 0.3671875, 0.41796875},
    border = {0.412109375, 0.828125, 0.001953125, 0.060546875},
}

local THREAT_COLORS = {
    [3] = {r = 1, g = 0, b = 0},
    [2] = {r = 1, g = 0.6, b = 0},
    [1] = {r = 1, g = 1, b = 0},
    [0] = {r = 0.8, g = 0.8, b = 0.8},
}

-- ============================================================================
-- STRUCTURE DETECTION
-- ============================================================================

local function FindNameplateElements(namePlate)
    if not namePlate then return nil end
    if namePlate.__dragonUIElements then return namePlate.__dragonUIElements end

    local result = {
        namePlate = namePlate,
        unitFrame = nil,
        healthBar = nil,
        nameText = nil,
        castBar = nil,
        powerBar = nil,
        unitToken = nil,
    }

    -- 尝试获取 unit token
    if namePlate.namePlateUnitToken then
        result.unitToken = namePlate.namePlateUnitToken
    end

    -- 尝试 UnitFrame
    if namePlate.UnitFrame then
        result.unitFrame = namePlate.UnitFrame
        local uf = namePlate.UnitFrame

        if uf.unit and not result.unitToken then
            result.unitToken = uf.unit
        end

        -- 查找 healthBar
        if uf.healthBar then
            result.healthBar = uf.healthBar
        end

        -- 查找名字
        if uf.name then
            result.nameText = uf.name
        end

        -- 查找施法条
        if uf.castBar then
            result.castBar = uf.castBar
        end

        -- 查找能量条
        if uf.powerBar then
            result.powerBar = uf.powerBar
        end
    end

    -- 如果没找到 healthBar，尝试在 namePlate 直接子元素中查找
    if not result.healthBar then
        local regions = { namePlate:GetRegions() }
        for _, region in ipairs(regions) do
            if region and region.GetObjectType then
                local oType = region:GetObjectType()
                if oType == "StatusBar" then
                    local name = region:GetName() or ""
                    if not result.healthBar and (name:find("Health") or name:find("health")) then
                        result.healthBar = region
                    end
                end
            end
        end

        local children = { namePlate:GetChildren() }
        for _, child in ipairs(children) do
            if child and child.GetObjectType then
                local oType = child:GetObjectType()
                if oType == "StatusBar" then
                    local name = child:GetName() or ""
                    if not result.healthBar and (name:find("Health") or name:find("health")) then
                        result.healthBar = child
                    end
                    if not result.castBar and (name:find("Cast") or name:find("cast")) then
                        result.castBar = child
                    end
                elseif oType == "FontString" then
                    if not result.nameText then
                        result.nameText = child
                    end
                end
            end
        end
    end

    -- 从映射表中查找 unit token
    if not result.unitToken then
        for unitToken, plate in pairs(Module.unitToPlate) do
            if plate == namePlate then
                result.unitToken = unitToken
                break
            end
        end
    end

    -- 缓存结果
    namePlate.__dragonUIElements = result
    return result
end

-- ============================================================================
-- STYLE CREATION
-- ============================================================================

local function CreateDragonUIStyle(namePlate)
    if not namePlate then return nil end
    if namePlate.DragonUI then return namePlate.DragonUI end

    local elements = FindNameplateElements(namePlate)
    if not elements or not elements.healthBar then
        return nil
    end

    local parent = elements.unitFrame or namePlate
    local dragonStyle = {}

    -- 背景条
    local bg = parent:CreateTexture(nil, "BACKGROUND")
    dragonStyle.bg = bg

    -- 边框
    local border = parent:CreateTexture(nil, "ARTWORK")
    dragonStyle.border = border

    -- 等级文字
    local levelText = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    levelText:SetJustifyH("RIGHT")
    dragonStyle.levelText = levelText

    -- 血量文字（血条中间）
    local healthText = parent:CreateFontString(nil, "TOPMOST", "GameFontNormalSmall")
    healthText:SetJustifyH("CENTER")
    healthText:SetJustifyV("MIDDLE")
    healthText:SetShadowColor(0, 0, 0, 1)
    healthText:SetShadowOffset(1, -1)
    healthText:SetTextColor(1, 1, 1)
    dragonStyle.healthText = healthText

    namePlate.DragonUI = dragonStyle
    return dragonStyle
end

-- ============================================================================
-- BORDER STYLE
-- ============================================================================

local function ApplyBorderStyle(namePlate)
    if not namePlate or not namePlate.DragonUI then return end

    local elements = FindNameplateElements(namePlate)
    if not elements or not elements.healthBar then return end

    local config = GetConfig()
    local dragonStyle = namePlate.DragonUI
    local healthBar = elements.healthBar

    if config.borderStyle == "castbar" then
        -- 背景：从 uicastingbar2x 图集裁切，SetAllPoints 铺满血条
        dragonStyle.bg:SetTexture(TEXTURES.CASTBAR_ATLAS)
        dragonStyle.bg:SetTexCoord(unpack(UV_COORDS.background))
        dragonStyle.bg:ClearAllPoints()
        dragonStyle.bg:SetAllPoints(healthBar)

        -- 边框：从 uicastingbar2x 图集裁切，四周向外扩展 2 像素
        dragonStyle.border:SetTexture(TEXTURES.CASTBAR_ATLAS)
        dragonStyle.border:SetTexCoord(unpack(UV_COORDS.border))
        dragonStyle.border:ClearAllPoints()
        dragonStyle.border:SetPoint("TOPLEFT", healthBar, "TOPLEFT", -2, 2)
        dragonStyle.border:SetPoint("BOTTOMRIGHT", healthBar, "BOTTOMRIGHT", 2, -2)
    else
        dragonStyle.bg:SetTexture(TEXTURES.UNITFRAME_BORDER)
        dragonStyle.bg:SetTexCoord(0, 1, 0, 1)
        dragonStyle.bg:ClearAllPoints()
        dragonStyle.bg:SetPoint("TOPLEFT", healthBar, "TOPLEFT", -3, 3)
        dragonStyle.bg:SetPoint("BOTTOMRIGHT", healthBar, "BOTTOMRIGHT", 3, -3)

        dragonStyle.border:SetTexture(TEXTURES.UNITFRAME_BORDER)
        dragonStyle.border:SetTexCoord(0, 1, 0, 1)
        dragonStyle.border:ClearAllPoints()
        dragonStyle.border:SetPoint("TOPLEFT", healthBar, "TOPLEFT", -2, 2)
        dragonStyle.border:SetPoint("BOTTOMRIGHT", healthBar, "BOTTOMRIGHT", 2, -2)
    end
end

-- ============================================================================
-- UPDATE FUNCTIONS
-- ============================================================================

local function UpdateHealthBar(namePlate)
    local elements = FindNameplateElements(namePlate)
    if not elements or not elements.healthBar or not elements.unitToken then return end

    local unit = elements.unitToken
    local healthBar = elements.healthBar
    local config = GetConfig()

    -- 确保 DragonUI 样式存在
    if not namePlate.DragonUI then
        CreateDragonUIStyle(namePlate)
        ApplyBorderStyle(namePlate)
    end

    -- 应用血条纹理和颜色（照搬施法条：使用 CastingBarStandard2 纹理）
    healthBar:SetStatusBarTexture(TEXTURES.CAST_BAR)
    local healthTexture = healthBar:GetStatusBarTexture()
    if healthTexture then
        healthTexture:SetVertexColor(1, 1, 1, 1)
    end

    if config.classcolor and UnitIsPlayer(unit) then
        local _, class = UnitClass(unit)
        local color = RAID_CLASS_COLORS[class]
        if color then
            healthBar:SetStatusBarColor(color.r, color.g, color.b)
        end
    else
        if not UnitIsPlayer(unit) and not UnitPlayerControlled(unit) then
            local reaction = UnitReaction(unit, "player")
            if reaction then
                if reaction <= 2 then
                    healthBar:SetStatusBarColor(1, 0, 0)
                elseif reaction == 3 then
                    healthBar:SetStatusBarColor(1, 1, 0)
                elseif reaction >= 4 then
                    healthBar:SetStatusBarColor(0, 1, 0)
                end
            end
        end
    end

    -- 调整尺寸
    if config.width then
        local function ApplyWidth(frame, width)
            if not frame then return end
            if not frame.__dragonUIWidthHooked then
                local origSW = frame.SetWidth
                local origSS = frame.SetSize
                frame.SetWidth = function(self, w)
                    if self.__dragonUIW then
                        origSW(self, self.__dragonUIW)
                    else
                        origSW(self, w)
                    end
                end
                frame.SetSize = function(self, w, h)
                    if self.__dragonUIW then
                        origSS(self, self.__dragonUIW, h)
                    else
                        origSS(self, w, h)
                    end
                end
                frame.__dragonUIWidthHooked = true
            end
            frame.__dragonUIW = width
            frame:SetWidth(width)
        end

        ApplyWidth(namePlate, config.width)
        if elements.unitFrame and elements.unitFrame ~= namePlate then
            ApplyWidth(elements.unitFrame, config.width)
        end

        if config.healthBarHeight then
            healthBar:SetHeight(config.healthBarHeight)
        end
    elseif config.healthBarHeight then
        healthBar:SetHeight(config.healthBarHeight)
    end

    -- 血量文字
    local dragonStyle = namePlate.DragonUI
    if dragonStyle and dragonStyle.healthText then
        local cur = UnitHealth(unit)
        local max = UnitHealthMax(unit)
        if max and max > 0 then
            local percent = math.floor((cur / max) * 100 + 0.5)
            dragonStyle.healthText:SetText(string.format("%s/%s%%", FormatNumber(cur), percent))
        else
            dragonStyle.healthText:SetText("")
        end

        -- 设置父对象为血条（确保层级正确）
        dragonStyle.healthText:SetParent(healthBar)

        -- 定位到血条中间
        dragonStyle.healthText:ClearAllPoints()
        dragonStyle.healthText:SetPoint("CENTER", healthBar, "CENTER", 0, 0)

        -- 防止父框架裁剪文字
        local parentFrame = elements.unitFrame or namePlate
        if parentFrame.SetClipsChildren then
            parentFrame:SetClipsChildren(false)
        end
        if healthBar.SetClipsChildren then
            healthBar:SetClipsChildren(false)
        end

        -- 字号
        if config.healthFontSize then
            local font, _, flags = dragonStyle.healthText:GetFont()
            if font then
                dragonStyle.healthText:SetFont(font, config.healthFontSize, flags or "OUTLINE")
            end
        end

        if config.showHealthText then
            dragonStyle.healthText:Show()
        else
            dragonStyle.healthText:Hide()
        end
    end
end

local function UpdateName(namePlate)
    local elements = FindNameplateElements(namePlate)
    if not elements or not elements.nameText or not elements.unitToken then return end

    local unit = elements.unitToken
    local nameText = elements.nameText
    local config = GetConfig()

    if not namePlate.DragonUI then
        CreateDragonUIStyle(namePlate)
        ApplyBorderStyle(namePlate)
    end

    local dragonStyle = namePlate.DragonUI

    -- 设置字体大小
    if config.nameFontSize then
        local font, _, flags = nameText:GetFont()
        if font then
            nameText:SetFont(font, config.nameFontSize, flags or "OUTLINE")
        end
    end

    -- 等级显示
    if dragonStyle.levelText then
        local level = UnitLevel(unit)
        if config.showLevel and level and level > 0 then
            local levelColor = GetQuestDifficultyColor(level)
            dragonStyle.levelText:SetText(tostring(level))
            dragonStyle.levelText:SetTextColor(levelColor.r, levelColor.g, levelColor.b)
            dragonStyle.levelText:SetPoint("RIGHT", nameText, "LEFT", -4, 0)
            dragonStyle.levelText:Show()
        else
            dragonStyle.levelText:Hide()
        end
    end
end

local function UpdateThreat(namePlate)
    local elements = FindNameplateElements(namePlate)
    if not elements or not elements.unitToken then return end

    local unit = elements.unitToken
    local config = GetConfig()

    if not namePlate.DragonUI then
        CreateDragonUIStyle(namePlate)
        ApplyBorderStyle(namePlate)
    end

    local dragonStyle = namePlate.DragonUI
    if not dragonStyle or not dragonStyle.border then return end

    if not config.showThreatGlow then
        dragonStyle.border:SetVertexColor(1, 1, 1)
        return
    end

    if UnitIsPlayer(unit) then
        dragonStyle.border:SetVertexColor(1, 1, 1)
        return
    end

    local _, threatStatus = UnitDetailedThreatSituation("player", unit)
    if threatStatus and THREAT_COLORS[threatStatus] then
        local color = THREAT_COLORS[threatStatus]
        dragonStyle.border:SetVertexColor(color.r, color.g, color.b)
    else
        dragonStyle.border:SetVertexColor(1, 1, 1)
    end
end

local function UpdateCastBar(namePlate)
    local elements = FindNameplateElements(namePlate)
    if not elements or not elements.castBar then return end

    local castBar = elements.castBar
    local config = GetConfig()

    -- 施法条纹理（照搬施法条：使用 CastingBarStandard2）
    castBar:SetStatusBarTexture(TEXTURES.CAST_BAR)
    local castTexture = castBar:GetStatusBarTexture()
    if castTexture then
        castTexture:SetVertexColor(1, 1, 1, 1)
    end

    -- 施法条高度
    if config.castBarHeight then
        castBar:SetHeight(config.castBarHeight)
    end

    -- DragonUI 施法条边框（照搬施法条：从 uicastingbar2x 图集裁切）
    if not castBar.DragonUIBorder then
        local parent = elements.unitFrame or castBar:GetParent()
        local castBorder = parent:CreateTexture(nil, "ARTWORK")
        castBorder:SetTexture(TEXTURES.CASTBAR_ATLAS)
        castBorder:SetTexCoord(unpack(UV_COORDS.border))
        castBorder:ClearAllPoints()
        castBorder:SetPoint("TOPLEFT", castBar, "TOPLEFT", -2, 2)
        castBorder:SetPoint("BOTTOMRIGHT", castBar, "BOTTOMRIGHT", 2, -2)
        castBar.DragonUIBorder = castBorder

        -- 施法条背景
        local castBg = parent:CreateTexture(nil, "BACKGROUND")
        castBg:SetTexture(TEXTURES.CASTBAR_ATLAS)
        castBg:SetTexCoord(unpack(UV_COORDS.background))
        castBg:ClearAllPoints()
        castBg:SetAllPoints(castBar)
        castBar.DragonUIBg = castBg
    end

    if castBar.DragonUIBorder then
        if config.showCastBar then
            castBar.DragonUIBorder:Show()
            if castBar.DragonUIBg then castBar.DragonUIBg:Show() end
        else
            castBar.DragonUIBorder:Hide()
            if castBar.DragonUIBg then castBar.DragonUIBg:Hide() end
        end
    end
end

-- ============================================================================
-- FULL UPDATE
-- ============================================================================

local function UpdateNameplate(namePlate)
    if not namePlate then return end

    local elements = FindNameplateElements(namePlate)
    if not elements or not elements.healthBar then return end

    -- 确保样式已创建
    if not namePlate.DragonUI then
        CreateDragonUIStyle(namePlate)
        if not namePlate.DragonUI then return end
    end

    ApplyBorderStyle(namePlate)
    UpdateHealthBar(namePlate)
    UpdateName(namePlate)
    UpdateThreat(namePlate)
    UpdateCastBar(namePlate)
end

local function UpdateAllNameplates()
    for unit, namePlate in pairs(Module.activePlates) do
        if namePlate and namePlate:IsShown() then
            pcall(UpdateNameplate, namePlate)
        end
    end
end

-- ============================================================================
-- SAFE CALL
-- ============================================================================

local function SafeCall(func, ...)
    local ok, err = pcall(func, ...)
    return ok
end

-- ============================================================================
-- NAMEPLATE ADD/REMOVE
-- ============================================================================

local function OnNamePlateAdded(unit)
    if not unit or type(unit) ~= "string" then return end

    local namePlate = C_NamePlate.GetNamePlateForUnit(unit)
    if not namePlate then return end

    -- 缓存 unit → plate 映射
    Module.unitToPlate[unit] = namePlate
    Module.activePlates[unit] = namePlate

    -- 确保结构缓存中有 unit token
    local elements = FindNameplateElements(namePlate)
    if elements and not elements.unitToken then
        elements.unitToken = unit
    end

    -- 应用 DragonUI 样式
    SafeCall(UpdateNameplate, namePlate)
end

local function OnNamePlateRemoved(unit)
    if not unit or type(unit) ~= "string" then return end

    local namePlate = Module.activePlates[unit]
    if namePlate and namePlate.DragonUI then
        if namePlate.DragonUI.bg then namePlate.DragonUI.bg:Hide() end
        if namePlate.DragonUI.border then namePlate.DragonUI.border:Hide() end
        if namePlate.DragonUI.levelText then namePlate.DragonUI.levelText:Hide() end
    end

    if namePlate then
        namePlate.__dragonUIElements = nil
    end

    Module.unitToPlate[unit] = nil
    Module.activePlates[unit] = nil
end

-- ============================================================================
-- EVENT HANDLING
-- ============================================================================

local eventFrame = CreateFrame("Frame")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "NAME_PLATE_UNIT_ADDED" then
        local unit = ...
        SafeCall(OnNamePlateAdded, unit)
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        local unit = ...
        SafeCall(OnNamePlateRemoved, unit)
    elseif event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
        local unit = ...
        if not unit or not Module.unitToPlate[unit] then return end
        local namePlate = Module.unitToPlate[unit]
        if namePlate then
            SafeCall(UpdateHealthBar, namePlate)
            SafeCall(UpdateThreat, namePlate)
        end
    elseif event == "UNIT_THREAT_LIST_UPDATE" or event == "UNIT_THREAT_SITUATION_UPDATE" then
        local unit = ...
        if not unit or not Module.unitToPlate[unit] then return end
        local namePlate = Module.unitToPlate[unit]
        if namePlate then
            SafeCall(UpdateThreat, namePlate)
        end
    elseif event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then
        local unit = ...
        if not unit or not Module.unitToPlate[unit] then return end
        local namePlate = Module.unitToPlate[unit]
        if namePlate then
            SafeCall(UpdateCastBar, namePlate)
        end
    elseif event == "UNIT_LEVEL" or event == "UNIT_NAME_UPDATE" then
        local unit = ...
        if not unit or not Module.unitToPlate[unit] then return end
        local namePlate = Module.unitToPlate[unit]
        if namePlate then
            SafeCall(UpdateName, namePlate)
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- 清理缓存
        for unit in pairs(Module.activePlates) do
            local np = Module.activePlates[unit]
            if np then np.__dragonUIElements = nil end
            Module.activePlates[unit] = nil
            Module.unitToPlate[unit] = nil
        end
        C_Timer.After(0.5, function()
            SafeCall(UpdateAllNameplates)
        end)
    end
end)

-- ============================================================================
-- THREAT UPDATE LOOP
-- ============================================================================

local threatFrame = CreateFrame("Frame")
local threatElapsed = 0

threatFrame:SetScript("OnUpdate", function(self, elapsed)
    threatElapsed = threatElapsed + elapsed
    if threatElapsed >= 0.15 then
        threatElapsed = 0
        local config = GetConfig()
        if config.showThreatGlow then
            for unit, namePlate in pairs(Module.activePlates) do
                if namePlate and namePlate:IsShown() then
                    SafeCall(UpdateThreat, namePlate)
                end
            end
        end
    end
end)

threatFrame:Hide()

-- ============================================================================
-- SCAN LOOP (fallback)
-- ============================================================================

local scanFrame = CreateFrame("Frame")
local scanElapsed = 0

scanFrame:SetScript("OnUpdate", function(self, elapsed)
    scanElapsed = scanElapsed + elapsed
    if scanElapsed >= 0.5 then
        scanElapsed = 0
        local config = GetConfig()
        for i = 1, 40 do
            local unit = "nameplate" .. i
            if UnitExists(unit) then
                if not Module.activePlates[unit] then
                    SafeCall(OnNamePlateAdded, unit)
                else
                    local np = Module.activePlates[unit]
                    if np and np:IsShown() then
                        if not np.DragonUI then
                            SafeCall(UpdateNameplate, np)
                        end
                        if config.width and np.__dragonUIW and np:GetWidth() ~= np.__dragonUIW then
                            np:SetWidth(np.__dragonUIW)
                        end
                    end
                end
            end
        end
    end
end)

scanFrame:Hide()

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

local function InitializeNameplates()
    if Module.initialized then return end
    if not C_NamePlate then return end

    local config = GetConfig()
    if not config.enabled then return end

    -- 注册事件
    eventFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    eventFrame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
    eventFrame:RegisterEvent("UNIT_HEALTH")
    eventFrame:RegisterEvent("UNIT_MAXHEALTH")
    eventFrame:RegisterEvent("UNIT_THREAT_LIST_UPDATE")
    eventFrame:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_START")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
    eventFrame:RegisterEvent("UNIT_LEVEL")
    eventFrame:RegisterEvent("UNIT_NAME_UPDATE")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

    -- 启用威胁更新
    if config.showThreatGlow then
        threatFrame:Show()
    end

    -- 启用扫描循环作为备用方案
    scanFrame:Show()

    Module.initialized = true

    -- 立即扫描已存在的姓名版
    for i = 1, 40 do
        local unit = "nameplate" .. i
        if UnitExists(unit) then
            SafeCall(OnNamePlateAdded, unit)
        end
    end
end

-- 使用多个初始化触发点确保模块能启动
local function TryInitialize()
    if Module.initialized then return end
    if not C_NamePlate then return end
    if not addon or not addon.db then return end

    InitializeNameplates()
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

local initTried = false
initFrame:SetScript("OnEvent", function(self, event, addonName)
    if event == "ADDON_LOADED" and addonName == "DragonUI" then
        C_Timer.After(0.5, TryInitialize)
    elseif event == "PLAYER_LOGIN" then
        C_Timer.After(0.2, TryInitialize)
    elseif event == "PLAYER_ENTERING_WORLD" then
        if not initTried then
            initTried = true
            C_Timer.After(0.3, TryInitialize)
        end
    end
end)

-- ============================================================================
-- REFRESH
-- ============================================================================

local function RefreshNameplates()
    local config = GetConfig()

    -- 更新威胁循环状态
    if config.showThreatGlow then
        threatFrame:Show()
    else
        threatFrame:Hide()
    end

    -- 更新所有姓名版的边框样式
    for unit, namePlate in pairs(Module.activePlates) do
        if namePlate and namePlate:IsShown() and namePlate.DragonUI then
            SafeCall(ApplyBorderStyle, namePlate)
        end
    end

    -- 重新应用所有样式
    SafeCall(UpdateAllNameplates)
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

addon.NamePlates = {
    Refresh = RefreshNameplates,
    RefreshNameplates = RefreshNameplates,
    UpdateAll = UpdateAllNameplates,
    IsInitialized = function() return Module.initialized end,
}
