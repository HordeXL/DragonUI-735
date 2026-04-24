local addon = select(2, ...)

-- ============================================================================
-- DRAGONUI TARGET OF TARGET FRAME MODULE - WoW 7.3.5
-- ============================================================================
-- Crea un frame ToT independiente en lugar de depender de TargetFrameToT,
-- que es un secure frame en 7.3.5 y causa problemas de visibilidad.

local Module = {
    frame = nil,
    healthBar = nil,
    powerBar = nil,
    nameText = nil,
    background = nil,
    border = nil,
    elite = nil,
    textSystem = nil,
    initialized = false,
    configured = false,
    eventsFrame = nil,
    updateThrottle = 0,
}

local TEXTURES = {
    BACKGROUND = "Interface\\AddOns\\DragonUI\\Textures\\UI-HUD-UnitFrame-TargetofTarget-PortraitOn-BACKGROUND",
    BORDER = "Interface\\AddOns\\DragonUI\\Textures\\UI-HUD-UnitFrame-TargetofTarget-PortraitOn-BORDER",
    BAR_PREFIX = "Interface\\AddOns\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-TargetofTarget-PortraitOn-Bar-",
}

local BOSS_COORDS = {
    elite = {0.001953125, 0.314453125, 0.322265625, 0.630859375},
    rare = {0.00390625, 0.31640625, 0.64453125, 0.953125},
    rareelite = {0.001953125, 0.388671875, 0.001953125, 0.31835937},
}

local POWER_MAP = {
    [0] = "Mana",
    [1] = "Rage",
    [2] = "Focus",
    [3] = "Energy",
    [6] = "RunicPower",
}

-- ============================================================================
-- UTILITY
-- ============================================================================

local function GetConfig()
    return addon:GetConfigValue("unitframe", "tot") or {}
end

-- ============================================================================
-- CREATE FRAME (called once)
-- ============================================================================

local function CreateToTFrame()
    if Module.configured then
        return
    end

    local f = CreateFrame("Frame", "DragonUI_ToT", UIParent)
    f:SetSize(200, 58)
    f:SetFrameLevel(50)
    f:Hide()

    -- Background (BACKGROUND layer, lowest)
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture(TEXTURES.BACKGROUND)
    bg:SetAllPoints(f)
    Module.background = bg

    -- Border (BORDER layer — below ARTWORK bars, so it doesn't cover them)
    local border = f:CreateTexture(nil, "BORDER")
    border:SetTexture(TEXTURES.BORDER)
    border:SetAllPoints(f)
    Module.border = border

    -- Portrait (ARTWORK layer, between border and overlay)
    local portrait = f:CreateTexture(nil, "ARTWORK")
    portrait:SetSize(48, 48)
    portrait:SetPoint("LEFT", f, "LEFT", 4, 0)
    Module.portrait = portrait

    -- Health bar
    local hb = CreateFrame("StatusBar", nil, f)
    hb:SetSize(120, 12)
    hb:SetPoint("LEFT", portrait, "RIGHT", 2, 3)
    hb:SetStatusBarTexture(TEXTURES.BAR_PREFIX .. "Health")
    hb:GetStatusBarTexture():SetDrawLayer("ARTWORK", 1)
    hb:SetMinMaxValues(0, 100)
    hb:SetValue(100)
    hb.SetStatusBarColor = function() end
    Module.healthBar = hb

    -- Power bar
    local pb = CreateFrame("StatusBar", nil, f)
    pb:SetSize(120, 8)
    pb:SetPoint("LEFT", portrait, "RIGHT", 2, -8)
    pb:SetStatusBarTexture(TEXTURES.BAR_PREFIX .. "Mana")
    pb:GetStatusBarTexture():SetDrawLayer("ARTWORK", 1)
    pb:SetMinMaxValues(0, 100)
    pb:SetValue(100)
    pb.SetStatusBarColor = function() end
    Module.powerBar = pb

    -- Name text (OVERLAY, on top of everything)
    local nt = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nt:SetPoint("BOTTOMLEFT", portrait, "TOPLEFT", 0, 2)
    nt:SetWidth(90)
    nt:SetJustifyH("LEFT")
    nt:SetTextColor(1.0, 0.82, 0.0, 1.0)
    Module.nameText = nt

    -- Elite decoration
    local eliteFrame = CreateFrame("Frame", nil, f)
    eliteFrame:SetSize(54, 54)
    eliteFrame:SetPoint("CENTER", portrait, "CENTER", 0, 0)
    local eliteTex = eliteFrame:CreateTexture(nil, "OVERLAY")
    eliteTex:Hide()
    Module.elite = eliteTex

    -- Position relative to TargetFrame
    local config = GetConfig()
    f:ClearAllPoints()
    f:SetPoint(config.anchor or "BOTTOMRIGHT", _G.TargetFrame or UIParent, config.anchorParent or "BOTTOMRIGHT", config.x or 22, config.y or -15)
    f:SetScale(config.scale or 1.0)

    Module.frame = f

    -- Setup text system
    if addon.TextSystem then
        Module.textSystem = addon.TextSystem.SetupFrameTextSystem("targettarget", "targettarget", f, hb, pb, "TargetFrameToT")
    end

    Module.configured = true
end

-- ============================================================================
-- UPDATE
-- ============================================================================

local function UpdateToT()
    local f = Module.frame
    if not f then
        return
    end

    if not UnitExists("targettarget") then
        if f:IsShown() then
            f:Hide()
        end
        return
    end

    -- Position relative to TargetFrame
    local config = GetConfig()
    local targetFrame = _G.TargetFrame
    if targetFrame then
        f:ClearAllPoints()
        f:SetPoint(config.anchor or "BOTTOMRIGHT", targetFrame, config.anchorParent or "BOTTOMRIGHT", config.x or 22, config.y or -15)
        f:SetScale(config.scale or 1.0)
    end

    -- Show
    if not f:IsShown() then
        f:Show()
    end

    -- Update portrait
    if Module.portrait then
        SetPortraitTexture(Module.portrait, "targettarget")
    end

    -- Update health bar (StatusBar handles SetTexCoord automatically)
    if Module.healthBar then
        local cur = UnitHealth("targettarget")
        local max = UnitHealthMax("targettarget")
        Module.healthBar:SetMinMaxValues(0, max > 0 and max or 100)
        Module.healthBar:SetValue(cur)

        local tex = Module.healthBar:GetStatusBarTexture()
        if tex then
            local texPath
            local config2 = GetConfig()
            if config2.classcolor and UnitIsPlayer("targettarget") then
                texPath = TEXTURES.BAR_PREFIX .. "Health-Status"
            else
                texPath = TEXTURES.BAR_PREFIX .. "Health"
            end
            if tex:GetTexture() ~= texPath then
                tex:SetTexture(texPath)
            end
            tex:SetVertexColor(1, 1, 1, 1)
        end
    end

    -- Update power bar (StatusBar handles SetTexCoord automatically)
    if Module.powerBar then
        local powerType = UnitPowerType("targettarget")
        local cur = UnitPower("targettarget", powerType)
        local max = UnitPowerMax("targettarget", powerType)
        Module.powerBar:SetMinMaxValues(0, max > 0 and max or 100)
        Module.powerBar:SetValue(cur)

        local tex = Module.powerBar:GetStatusBarTexture()
        if tex then
            local powerName = POWER_MAP[powerType] or "Mana"
            tex:SetTexture(TEXTURES.BAR_PREFIX .. powerName)
            tex:SetVertexColor(1, 1, 1, 1)
        end
    end

    -- Update name
    if Module.nameText then
        local name = UnitName("targettarget")
        Module.nameText:SetText(name or "")
        local font, size, flags = Module.nameText:GetFont()
        if font and size then
            Module.nameText:SetFont(font, math.max(size, 10), flags)
        end
    end

    -- Update classification
    if Module.elite then
        local classification = UnitClassification("targettarget")
        local coords = nil
        if classification == "worldboss" or classification == "elite" then
            coords = BOSS_COORDS.elite
        elseif classification == "rareelite" then
            coords = BOSS_COORDS.rareelite
        elseif classification == "rare" then
            coords = BOSS_COORDS.rare
        end

        if coords then
            Module.elite:SetTexture("Interface\\AddOns\\DragonUI\\Textures\\uiunitframeboss2x")
            local left, right, top, bottom = coords[1], coords[2], coords[3], coords[4]
            Module.elite:SetTexCoord(right, left, top, bottom)
            Module.elite:SetSize(51, 51)
            Module.elite:SetPoint("CENTER", f, "LEFT", 28, 0)
            Module.elite:SetDrawLayer("OVERLAY", 11)
            Module.elite:Show()
        else
            Module.elite:Hide()
        end
    end

    -- Update text system (health/power text)
    if Module.textSystem then
        Module.textSystem.update()
    end
end

-- ============================================================================
-- ONUPDATE (throttled)
-- ============================================================================

local function OnUpdate(self, elapsed)
    Module.updateThrottle = Module.updateThrottle + elapsed
    if Module.updateThrottle < 0.2 then
        return
    end
    Module.updateThrottle = 0
    UpdateToT()
end

-- ============================================================================
-- EVENTS
-- ============================================================================

local function OnEvent(self, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name == "DragonUI" and not Module.initialized then
            -- Create anchor frame for editor mode
            Module.totFrame = CreateFrame("Frame", "DragonUI_ToT_Anchor", UIParent)
            Module.totFrame:SetSize(120, 47)
            Module.totFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 370, -80)
            Module.initialized = true

            -- Register with centralized system
            addon:RegisterEditableFrame({
                name = "tot",
                frame = Module.totFrame,
                configPath = {"widgets", "tot"},
                hasTarget = function() return UnitExists("target") end,
                module = Module,
            })
        end

    elseif event == "PLAYER_ENTERING_WORLD" then
        CreateToTFrame()
        UpdateToT()

    elseif event == "PLAYER_TARGET_CHANGED" then
        -- Target changed, force immediate update
        Module.updateThrottle = 99 -- force update on next OnUpdate tick
    end
end

-- init
if not Module.eventsFrame then
    Module.eventsFrame = CreateFrame("Frame")
    Module.eventsFrame:RegisterEvent("ADDON_LOADED")
    Module.eventsFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    Module.eventsFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    Module.eventsFrame:SetScript("OnEvent", OnEvent)

    -- OnUpdate for continuous monitoring
    Module.eventsFrame:SetScript("OnUpdate", OnUpdate)
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

local function RefreshFrame()
    if not Module.configured then
        CreateToTFrame()
    end
    UpdateToT()
end

local function ResetFrame()
    addon:SetConfigValue("unitframe", "tot", "x", 22)
    addon:SetConfigValue("unitframe", "tot", "y", -15)
    addon:SetConfigValue("unitframe", "tot", "scale", 1.0)
    if Module.frame then
        Module.frame:ClearAllPoints()
        Module.frame:SetPoint("BOTTOMRIGHT", _G.TargetFrame, "BOTTOMRIGHT", 22, -15)
        Module.frame:SetScale(1.0)
    end
end

-- Export API
addon.TargetOfTarget = {
    Refresh = RefreshFrame,
    RefreshToTFrame = RefreshFrame,
    Reset = ResetFrame,
    anchor = function() return Module.totFrame end,
    ChangeToTFrame = RefreshFrame,
}

function Module:LoadDefaultSettings()
    if not addon.db.profile.widgets then
        addon.db.profile.widgets = {}
    end
    addon.db.profile.widgets.tot = {
        anchor = "TOPLEFT",
        posX = 370,
        posY = -80,
    }
end

function Module:UpdateWidgets()
    if not addon.db or not addon.db.profile.widgets or not addon.db.profile.widgets.tot then
        self:LoadDefaultSettings()
        return
    end
    local widgetConfig = addon.db.profile.widgets.tot
    if Module.totFrame then
        Module.totFrame:ClearAllPoints()
        Module.totFrame:SetPoint(widgetConfig.anchor or "TOPLEFT", UIParent, widgetConfig.anchor or "TOPLEFT",
                                 widgetConfig.posX or 370, widgetConfig.posY or -80)
    end
end

addon.unitframe = addon.unitframe or {}
addon.unitframe.ChangeToT = RefreshFrame
addon.unitframe.ReApplyToTFrame = RefreshFrame
addon.unitframe.StyleToTFrame = CreateToTFrame

function addon:RefreshToTFrame()
    RefreshFrame()
end
