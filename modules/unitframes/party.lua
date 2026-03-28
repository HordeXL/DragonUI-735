-- ===============================================================
-- DRAGONUI PARTY FRAMES MODULE
-- ===============================================================
local addon = select(2, ...)

-- ===============================================================
-- EARLY EXIT CHECK
-- ===============================================================
-- Simplified: Only check if addon.db exists, not specifically unitframe.party
if not addon or not addon.db then
    return -- Exit early if database not ready
end

-- ===============================================================
-- IMPORTS AND GLOBALS
-- ===============================================================

-- Cache globals and APIs
local _G = _G
local unpack = unpack
local select = select
local UnitHealth, UnitHealthMax = UnitHealth, UnitHealthMax
local UnitPower, UnitPowerMax = UnitPower, UnitPowerMax
local UnitPowerType = UnitPowerType
local UnitName, UnitClass = UnitName, UnitClass
local UnitExists, UnitIsConnected = UnitExists, UnitIsConnected
local UnitInRange, UnitIsDeadOrGhost = UnitInRange, UnitIsDeadOrGhost
local MAX_PARTY_MEMBERS = MAX_PARTY_MEMBERS or 4

-- ===============================================================
-- MODULE NAMESPACE AND STORAGE
-- ===============================================================

-- Module namespace
local PartyFrames = {}
addon.PartyFrames = PartyFrames

PartyFrames.textElements = {}
PartyFrames.anchor = nil
PartyFrames.initialized = false

-- ===============================================================
-- CONSTANTS AND CONFIGURATION
-- ===============================================================

-- Texture paths for our custom party frames
local TEXTURES = {
    healthBarStatus = "Interface\\Addons\\DragonUI\\Textures\\Partyframe\\UI-HUD-UnitFrame-Party-PortraitOn-Bar-Health-Status",
    frame = "Interface\\Addons\\DragonUI\\Textures\\Partyframe\\uipartyframe",
    border = "Interface\\Addons\\DragonUI\\Textures\\UI-HUD-UnitFrame-TargetofTarget-PortraitOn-BORDER",
    healthBar = "Interface\\Addons\\DragonUI\\Textures\\Partyframe\\UI-HUD-UnitFrame-Party-PortraitOn-Bar-Health",
    manaBar = "Interface\\Addons\\DragonUI\\Textures\\Partyframe\\UI-HUD-UnitFrame-Party-PortraitOn-Bar-Mana",
    focusBar = "Interface\\Addons\\DragonUI\\Textures\\Partyframe\\UI-HUD-UnitFrame-Party-PortraitOn-Bar-Focus",
    rageBar = "Interface\\Addons\\DragonUI\\Textures\\Partyframe\\UI-HUD-UnitFrame-Party-PortraitOn-Bar-Rage",
    energyBar = "Interface\\Addons\\DragonUI\\Textures\\Partyframe\\UI-HUD-UnitFrame-Party-PortraitOn-Bar-Energy",
    runicPowerBar = "Interface\\Addons\\DragonUI\\Textures\\Partyframe\\UI-HUD-UnitFrame-Party-PortraitOn-Bar-RunicPower"
}

-- ===============================================================
-- CENTRALIZED SYSTEM INTEGRATION
-- ===============================================================

-- Create auxiliary frame for anchoring (similar to target.lua)
local function CreatePartyAnchorFrame()
    if PartyFrames.anchor then
        return PartyFrames.anchor
    end

    -- Use centralized function from core.lua
    PartyFrames.anchor = addon.CreateUIFrame(120, 200, "PartyFrames")

    -- Customize text for party frames
    if PartyFrames.anchor.editorText then
        PartyFrames.anchor.editorText:SetText("Party Frames")
    end

    return PartyFrames.anchor
end

-- Function to apply position from widgets (similar to target.lua)
local function ApplyWidgetPosition()
    if not PartyFrames.anchor then
        return
    end

    -- CRITICAL: Set BACKGROUND strata to stay behind Compact Raid Frames (which use LOW/MEDIUM)
    PartyFrames.anchor:SetFrameStrata('BACKGROUND')
    PartyFrames.anchor:SetFrameLevel(1)

    -- Ensure configuration exists
    if not addon.db or not addon.db.profile or not addon.db.profile.widgets then
        return
    end

    local widgetConfig = addon.db.profile.widgets.party

    if widgetConfig and widgetConfig.posX and widgetConfig.posY then
        -- Use saved anchor, not always TOPLEFT
        local anchor = widgetConfig.anchor or "TOPLEFT"
        PartyFrames.anchor:ClearAllPoints()
        PartyFrames.anchor:SetPoint(anchor, UIParent, anchor, widgetConfig.posX, widgetConfig.posY)
    else
        -- Create default configuration if it doesn't exist
        if not addon.db.profile.widgets.party then
            addon.db.profile.widgets.party = {
                anchor = "TOPLEFT",
                posX = 10,
                posY = -200
            }
        end
        PartyFrames.anchor:ClearAllPoints()
        PartyFrames.anchor:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 10, -200)
    end
end

-- Functions required by the centralized system
function PartyFrames:LoadDefaultSettings()
    -- Ensure configuration exists in widgets
    if not addon.db.profile.widgets then
        addon.db.profile.widgets = {}
    end

    if not addon.db.profile.widgets.party then
        addon.db.profile.widgets.party = {
            anchor = "TOPLEFT",
            posX = 10,
            posY = -200
        }
    end

    -- Ensure configuration exists in unitframe
    if not addon.db.profile.unitframe then
        addon.db.profile.unitframe = {}
    end

    if not addon.db.profile.unitframe.party then
        addon.db.profile.unitframe.party = {
            enabled = true,
            classcolor = false,
            textFormat = 'both',
            breakUpLargeNumbers = true,
            showHealthTextAlways = false,
            showManaTextAlways = false,
            orientation = 'vertical',
            padding = 15,
            scale = 1.0,
            override = false,
            anchor = 'TOPLEFT',
            anchorParent = 'TOPLEFT',
            x = 10,
            y = -200
        }
    end
end

function PartyFrames:UpdateWidgets()
    ApplyWidgetPosition()
    if not InCombatLockdown() then
        local step = GetPartyStep()
        for i = 1, MAX_PARTY_MEMBERS do
            local frame = _G['PartyMemberFrame' .. i]
            if frame and PartyFrames.anchor then
                frame:ClearAllPoints()
                local yOffset = (i - 1) * -step
                frame:SetPoint("TOPLEFT", PartyFrames.anchor, "TOPLEFT", 0, yOffset)
            end
        end
    end
end

-- Function to check if party frames should be visible
local function ShouldPartyFramesBeVisible()
    return GetNumPartyMembers() > 0
end

-- Test functions for the editor
local function ShowPartyFramesTest()
    -- Display party frames even if not in a group
    for i = 1, MAX_PARTY_MEMBERS do
        local frame = _G['PartyMemberFrame' .. i]
        if frame then
            frame:Show()
        end
    end
end

local function HidePartyFramesTest()
    -- Hide empty frames when not in a party
    for i = 1, MAX_PARTY_MEMBERS do
        local frame = _G['PartyMemberFrame' .. i]
        if frame and not UnitExists("party" .. i) then
            frame:Hide()
        end
    end
end

-- ===============================================================
-- HELPER FUNCTIONS
-- ===============================================================

-- Get settings helper
local function GetSettings()
    -- Perform a robust check with default values
    if not addon.db or not addon.db.profile then
        return {
            scale = 1.0,
            classcolor = false,
            breakUpLargeNumbers = true
        }
    end

    local settings = addon.db.profile.unitframe and addon.db.profile.unitframe.party

    -- If configuration doesn't exist, create it with defaults
    if not settings then
        if not addon.db.profile.unitframe then
            addon.db.profile.unitframe = {}
        end

        addon.db.profile.unitframe.party = {
            enabled = true,
            classcolor = false,
            textFormat = 'both',
            breakUpLargeNumbers = true,
            showHealthTextAlways = false,
            showManaTextAlways = false,
            orientation = 'vertical',
            padding = 15,
            scale = 1.0,
            override = false,
            anchor = 'TOPLEFT',
            anchorParent = 'TOPLEFT',
            x = 10,
            y = -200
        }
        settings = addon.db.profile.unitframe.party
    end
    
    return settings
end

-- Format numbers helper
local function FormatNumber(value)
    if not value or value == 0 then
        return "0"
    end

    -- Check for large number formatting setting
    local shouldBreakUp = false
    local settings = GetSettings()
    
    if settings and settings.breakUpLargeNumbers ~= nil then
        shouldBreakUp = settings.breakUpLargeNumbers
    elseif addon and addon.db and addon.db.profile and addon.db.profile.unitframe then
        -- Fallback to general unitframe setting
        local general = addon.db.profile.unitframe.general
        if general and general.breakUpLargeNumbers ~= nil then
            shouldBreakUp = general.breakUpLargeNumbers
        else
            shouldBreakUp = true -- Default to true
        end
    else
        shouldBreakUp = true -- Default fallback
    end

    if shouldBreakUp then
        if value >= 1000000 then
            return string.format("%.1fm", value / 1000000)
        elseif value >= 1000 then
            return string.format("%.1fk", value / 1000)
        end
    end
    return tostring(value)
end

-- Safe text formatting (multiple formats without external dependencies)
local function GetFormattedText(current, max, textFormat, breakUpLargeNumbers)
    if not current or not max or max == 0 then
        return ""
    end
    
    -- Handle boolean parameter properly
    if breakUpLargeNumbers == nil then
        breakUpLargeNumbers = true
    end
    
    if textFormat == "percentage" then
        local percent = math.floor((current / max) * 100)
        return percent .. "%"
    elseif textFormat == "numeric" then
        return breakUpLargeNumbers and FormatNumber(current) or tostring(current)
    elseif textFormat == "both" then
        local percent = math.floor((current / max) * 100)
        local formatted = breakUpLargeNumbers and FormatNumber(current) or tostring(current)
        -- Sistema dual como TextSystem: devolver tabla con left y right separados
        return {
            left = percent .. "%",
            right = formatted
        }
    else -- "formatted" (default)
        local formattedCurrent = breakUpLargeNumbers and FormatNumber(current) or tostring(current)
        local formattedMax = breakUpLargeNumbers and FormatNumber(max) or tostring(max)
        return formattedCurrent .. "/" .. formattedMax
    end
end

-- Calcular el paso vertical usando el padding de la config
local function GetPartyStep()
    local settings = GetSettings()
    local pad = (settings and tonumber(settings.padding)) or 15      -- separación extra
    local base = 49                                                  -- alto visual del frame
    return base + pad
end


-- Get class color helper
local function GetClassColor(unit)
    if not unit or not UnitExists(unit) then
        return 1, 1, 1
    end

    local _, class = UnitClass(unit)
    if class and RAID_CLASS_COLORS[class] then
        local color = RAID_CLASS_COLORS[class]
        return color.r, color.g, color.b
    end

    return 1, 1, 1
end

-- Get texture coordinates for party frame elements
local function GetPartyCoords(type)
    if type == "background" then
        return 0.480469, 0.949219, 0.222656, 0.414062
    elseif type == "flash" then
        return 0.480469, 0.925781, 0.453125, 0.636719
    elseif type == "status" then
        return 0.00390625, 0.472656, 0.453125, 0.644531
    end
    return 0, 1, 0, 1
end

-- New function: Get power bar texture
local function GetPowerBarTexture(unit)
    if not unit or not UnitExists(unit) then
        return TEXTURES.manaBar
    end

    local powerType = UnitPowerType(unit)

    -- In 3.3.5a types are numbers, not strings
    if powerType == 0 then -- MANA
        return TEXTURES.manaBar
    elseif powerType == 1 then -- RAGE
        return TEXTURES.rageBar
    elseif powerType == 2 then -- FOCUS
        return TEXTURES.focusBar
    elseif powerType == 3 then -- ENERGY
        return TEXTURES.energyBar
    elseif powerType == 6 then -- RUNIC_POWER (if it exists in 3.3.5a)
        return TEXTURES.runicPowerBar
    else
        return TEXTURES.manaBar -- Default
    end
end

-- ===============================================================
-- CLASS COLORS
-- ===============================================================

-- New function: Get class color for party member
local function GetPartyClassColor(partyIndex)
    local unit = "party" .. partyIndex
    if not UnitExists(unit) or not UnitIsPlayer(unit) then
        return 1, 1, 1 -- White if not a player
    end

    local _, class = UnitClass(unit)
    if class and RAID_CLASS_COLORS[class] then
        local color = RAID_CLASS_COLORS[class]
        return color.r, color.g, color.b
    end

    return 1, 1, 1 -- White by default
end

-- New function: Update party health bar with class color
local function UpdatePartyHealthBarColor(partyIndex)
    if not partyIndex or partyIndex < 1 or partyIndex > 4 then
        return
    end

    local unit = "party" .. partyIndex
    if not UnitExists(unit) then
        return
    end

    local healthbar = _G['PartyMemberFrame' .. partyIndex .. 'HealthBar']
    if not healthbar then
        return
    end

    local settings = GetSettings()
    if not settings then
        return
    end

    local texture = healthbar:GetStatusBarTexture()
    if not texture then
        return
    end

    if settings.classcolor and UnitIsPlayer(unit) then
        -- Use constant instead of hardcoded string
        local statusTexturePath = TEXTURES.healthBarStatus
        if texture:GetTexture() ~= statusTexturePath then
            texture:SetTexture(statusTexturePath)
        end

        -- Apply class color
        local r, g, b = GetPartyClassColor(partyIndex)
        healthbar:SetStatusBarColor(r, g, b, 1)
    else
        -- Use constant instead of hardcoded string
        local normalTexturePath = TEXTURES.healthBar
        if texture:GetTexture() ~= normalTexturePath then
            texture:SetTexture(normalTexturePath)
        end

        -- White color (texture already has color)
        healthbar:SetStatusBarColor(1, 1, 1, 1)
    end
end
-- ===============================================================
-- SIMPLE BLIZZARD BUFF/DEBUFF REPOSITIONING
-- ===============================================================
local function RepositionBlizzardBuffs()
    for i = 1, MAX_PARTY_MEMBERS do
        local frame = _G['PartyMemberFrame' .. i]
        if frame then
            -- Move buffs and debuffs together
            for auraIndex = 1, 4 do
                local buff = _G['PartyMemberFrame' .. i .. 'Buff' .. auraIndex]
                local debuff = _G['PartyMemberFrame' .. i .. 'Debuff' .. auraIndex]

                if buff then
                    buff:ClearAllPoints()
                    buff:SetPoint('TOPLEFT', frame, 'TOPRIGHT', -5 + (auraIndex - 1) * 18, -5)
                    buff:SetSize(16, 16)
                end

                if debuff then
                    debuff:ClearAllPoints()
                    debuff:SetPoint('TOPLEFT', frame, 'TOPRIGHT', -5 + (auraIndex - 1) * 18, -22)
                    debuff:SetSize(16, 16)
                end
            end
        end
    end
end


-- ===============================================================
-- TEXT UPDATE SYSTEM (TAINT-FREE)
-- ===============================================================

-- Frame and variables for safe text updates
local updateFrame = CreateFrame("Frame")
local pendingUpdates = {}
local updateScheduled = false

-- Safe text update function
local function SafeUpdateTexts()
    for frameIndex, _ in pairs(pendingUpdates) do
        if PartyFrames.textElements[frameIndex] and PartyFrames.textElements[frameIndex].update then
            PartyFrames.textElements[frameIndex].update()
        end
    end

    -- Clear pending updates
    pendingUpdates = {}
    updateScheduled = false
    updateFrame:SetScript("OnUpdate", nil)
end

-- Schedule text update function (taint-free)
local function ScheduleTextUpdate(frameIndex)
    if not frameIndex then
        return
    end

    -- Mark frame for update
    pendingUpdates[frameIndex] = true

    -- If no update is scheduled, create one
    if not updateScheduled then
        updateScheduled = true
        -- Use OnUpdate with minimal delay (compatible with 3.3.5a)
        local elapsed = 0
        updateFrame:SetScript("OnUpdate", function(self, dt)
            elapsed = elapsed + dt
            if elapsed >= 0.01 then -- 10ms delay
                SafeUpdateTexts()
            end
        end)
    end
end
-- ===============================================================
-- DYNAMIC CLIPPING SYSTEM
-- ===============================================================

-- Setup dynamic texture clipping for health bars
local function SetupHealthBarClipping(frame)
    if not frame then
        return
    end

    local healthbar = _G[frame:GetName() .. 'HealthBar']
    if not healthbar or healthbar.DragonUI_ClippingSetup then
        return
    end

    -- Hook SetValue for dynamic clipping and class color
    hooksecurefunc(healthbar, "SetValue", function(self, value)
        local frameIndex = frame:GetID()
        local unit = "party" .. frameIndex
        if not UnitExists(unit) then
            return
        end

        local texture = self:GetStatusBarTexture()
        if not texture then
            return
        end

        -- Apply class color first
        UpdatePartyHealthBarColor(frameIndex)

        -- Dynamic clipping: Only show the filled part of the texture
        local min, max = self:GetMinMaxValues()
        local current = value or self:GetValue()

        if max > 0 and current then
            local percentage = current / max
            texture:SetTexCoord(0, percentage, 0, 1)
        else
            texture:SetTexCoord(0, 1, 0, 1)
        end
    end)

    healthbar.DragonUI_ClippingSetup = true
end

-- Setup dynamic texture clipping for mana bars
local function SetupManaBarClipping(frame)
    if not frame then
        return
    end

    local manabar = _G[frame:GetName() .. 'ManaBar']
    if not manabar or manabar.DragonUI_ClippingSetup then
        return
    end

    -- Hook SetValue for dynamic clipping
    hooksecurefunc(manabar, "SetValue", function(self, value)
        local unit = "party" .. frame:GetID()
        if not UnitExists(unit) then
            return
        end

        local texture = self:GetStatusBarTexture()
        if not texture then
            return
        end

        local min, max = self:GetMinMaxValues()
        local current = value or self:GetValue()

        if max > 0 and current then
            -- Dynamic clipping: Only show the filled part of the texture
            local percentage = current / max
            texture:SetTexCoord(0, percentage, 0, 1)
        else
            texture:SetTexCoord(0, 1, 0, 1)
        end

        -- Update texture based on power type
        local powerTexture = GetPowerBarTexture(unit)
        texture:SetTexture(powerTexture)
        texture:SetVertexColor(1, 1, 1, 1)
    end)

    manabar.DragonUI_ClippingSetup = true
end

-- ===============================================================
-- TEXT MANAGEMENT SYSTEM (TAINT-FREE)
-- ===============================================================

-- Hide Blizzard texts permanently with alpha 0 (no taint)
local function HideBlizzardTexts(frame)
    if not frame then return end
    
    local healthText = _G[frame:GetName() .. 'HealthBarText']
    local manaText = _G[frame:GetName() .. 'ManaBarText']
    
    -- Set alpha to 0 instead of hiding to avoid taint
    if healthText then
        healthText:SetAlpha(0)
        healthText.SetAlpha = function() end -- Prevent Blizzard from changing alpha
    end
    
    if manaText then
        manaText:SetAlpha(0)
        manaText.SetAlpha = function() end -- Prevent Blizzard from changing alpha
    end
end

-- Tracking hover state to prevent text disappearing during updates
local hoverStates = {}

-- Forward declaration for CreateCustomTexts (used in update functions)
local CreateCustomTexts

-- ===============================================================
-- TEXT AND COLOR UPDATE FUNCTIONS
-- ===============================================================

-- Health text update function (taint-free)
UpdateHealthText = function(statusBar, forceShow)
    if not statusBar then return end
    
    local frame = statusBar:GetParent()
    local frameIndex = frame:GetName():match("PartyMemberFrame(%d+)")
    if not frameIndex then return end
    
    local partyUnit = "party" .. frameIndex
    if not UnitExists(partyUnit) then return end
    
    -- Ensure our custom text exists
    CreateCustomTexts(frame)
    
    local healthText = frame.DragonUI_HealthText
    if not healthText then return end
    
    local settings = GetSettings()
    
    -- Check visibility logic with hover state (new structure)
    local frameIndexNum = tonumber(frameIndex)
    local hoverState = hoverStates[frameIndexNum]
    local isHovering = false
    
    if hoverState then
        isHovering = hoverState.portrait or hoverState.health
    end
    
    local shouldShow = false
    
    if forceShow or isHovering then
        shouldShow = true -- Force show during hover or explicit force
    elseif settings and settings.showHealthTextAlways then
        shouldShow = true -- Always show if enabled
    end
    
    if not shouldShow then
        -- Ocultar TODOS los elementos de texto (incluido formato both)
        if healthText then healthText:Hide() end
        if frame.DragonUI_HealthTextLeft then frame.DragonUI_HealthTextLeft:Hide() end
        if frame.DragonUI_HealthTextRight then frame.DragonUI_HealthTextRight:Hide() end
        return
    end
    
    local current = UnitHealth(partyUnit)
    local max = UnitHealthMax(partyUnit)
    
    if current and max and max > 0 then
        local textFormat = settings and settings.textFormat or "formatted"
        local breakUp = settings and settings.breakUpLargeNumbers
        local finalText = GetFormattedText(current, max, textFormat, breakUp)
        
        -- Sistema dual: tabla para "both", string para otros formatos
        if textFormat == "both" and type(finalText) == "table" then
            -- Formato dual: usar left y right, ocultar center
            if frame.DragonUI_HealthText then frame.DragonUI_HealthText:Hide() end
            if frame.DragonUI_HealthTextLeft then
                frame.DragonUI_HealthTextLeft:SetText(finalText.left or "")
                frame.DragonUI_HealthTextLeft:Show()
            end
            if frame.DragonUI_HealthTextRight then
                frame.DragonUI_HealthTextRight:SetText(finalText.right or "")
                frame.DragonUI_HealthTextRight:Show()
            end
        else
            -- Formato simple: usar center, ocultar left y right
            if frame.DragonUI_HealthTextLeft then frame.DragonUI_HealthTextLeft:Hide() end
            if frame.DragonUI_HealthTextRight then frame.DragonUI_HealthTextRight:Hide() end
            if healthText then
                healthText:SetText(finalText or "")
                healthText:Show()
            end
        end
    else
        -- Ocultar todos los textos si no hay datos válidos
        if healthText then healthText:Hide() end
        if frame.DragonUI_HealthTextLeft then frame.DragonUI_HealthTextLeft:Hide() end
        if frame.DragonUI_HealthTextRight then frame.DragonUI_HealthTextRight:Hide() end
    end
end

-- Mana text update function (taint-free)
UpdateManaText = function(statusBar, forceShow)
    if not statusBar then return end
    
    local frameName = statusBar:GetParent():GetName()
    local frameIndex = frameName:match("PartyMemberFrame(%d+)")
    if not frameIndex then return end
    
    local partyUnit = "party" .. frameIndex
    if not UnitExists(partyUnit) then return end
    
    -- Create custom text if it doesn't exist - look in the frame, not statusbar!
    local frame = statusBar:GetParent()
    CreateCustomTexts(frame)
    local customText = frame.DragonUI_ManaText
    
    if not customText then return end
    
    local settings = GetSettings()
    
    -- Check visibility logic with hover state (new structure)
    local frameIndexNum = tonumber(frameIndex)
    local hoverState = hoverStates[frameIndexNum]
    local isHovering = false
    
    if hoverState then
        isHovering = hoverState.portrait or hoverState.mana
    end
    
    local shouldShow = false
    
    if forceShow or isHovering then
        shouldShow = true -- Force show during hover or explicit force
    elseif settings and settings.showManaTextAlways then
        shouldShow = true -- Always show if enabled
    end
    
    if not shouldShow then
        -- Ocultar TODOS los elementos de texto (incluido formato both)
        if customText then customText:Hide() end
        if frame.DragonUI_ManaTextLeft then frame.DragonUI_ManaTextLeft:Hide() end
        if frame.DragonUI_ManaTextRight then frame.DragonUI_ManaTextRight:Hide() end
        return
    end
    
    local current = UnitPower(partyUnit)
    local max = UnitPowerMax(partyUnit)
    
    if current and max and max > 0 then
        local textFormat = settings and settings.textFormat or "formatted"
        local breakUp = settings and settings.breakUpLargeNumbers
        local finalText = GetFormattedText(current, max, textFormat, breakUp)
        
        -- Sistema dual: tabla para "both", string para otros formatos
        if textFormat == "both" and type(finalText) == "table" then
            -- Formato dual: usar left y right, ocultar center
            if customText then customText:Hide() end
            if frame.DragonUI_ManaTextLeft then
                frame.DragonUI_ManaTextLeft:SetText(finalText.left or "")
                frame.DragonUI_ManaTextLeft:Show()
            end
            if frame.DragonUI_ManaTextRight then
                frame.DragonUI_ManaTextRight:SetText(finalText.right or "")
                frame.DragonUI_ManaTextRight:Show()
            end
        else
            -- Formato simple: usar center, ocultar left y right
            if frame.DragonUI_ManaTextLeft then frame.DragonUI_ManaTextLeft:Hide() end
            if frame.DragonUI_ManaTextRight then frame.DragonUI_ManaTextRight:Hide() end
            if customText then
                customText:SetText(finalText or "")
                customText:Show()
            end
        end
    else
        -- Ocultar todos los textos si no hay datos válidos
        if customText then customText:Hide() end
        if frame.DragonUI_ManaTextLeft then frame.DragonUI_ManaTextLeft:Hide() end
        if frame.DragonUI_ManaTextRight then frame.DragonUI_ManaTextRight:Hide() end
    end
end

-- Create invisible hover frames for independent health/mana text display
local function CreateHoverFrames(frame, frameIndex)
    if not frame or frame.DragonUI_HoverFrames then return end
    
    local healthBar = _G[frame:GetName() .. 'HealthBar']
    local manaBar = _G[frame:GetName() .. 'ManaBar']
    
    -- Create hover frame for health bar
    if healthBar and not frame.DragonUI_HealthHover then
        frame.DragonUI_HealthHover = CreateFrame("Frame", nil, frame.DragonUI_TextFrame)
        frame.DragonUI_HealthHover:SetFrameLevel(frame.DragonUI_TextFrame:GetFrameLevel() + 1)
        frame.DragonUI_HealthHover:SetAllPoints(healthBar)
        frame.DragonUI_HealthHover:EnableMouse(true)
        frame.DragonUI_HealthHover:SetScript("OnEnter", function()
            hoverStates[frameIndex].health = true
            HideBlizzardTexts(frame)
            UpdateHealthText(healthBar, true) -- Solo mostrar texto de vida
            -- NO mostrar texto de mana durante hover de vida
            if frame.DragonUI_ManaText then frame.DragonUI_ManaText:Hide() end
            if frame.DragonUI_ManaTextLeft then frame.DragonUI_ManaTextLeft:Hide() end
            if frame.DragonUI_ManaTextRight then frame.DragonUI_ManaTextRight:Hide() end
        end)
        frame.DragonUI_HealthHover:SetScript("OnLeave", function()
            hoverStates[frameIndex].health = false
            HideBlizzardTexts(frame)
            -- Volver a la visibilidad normal de ambos textos
            UpdateHealthText(healthBar, false)
            if manaBar then UpdateManaText(manaBar, false) end
        end)
    end
    
    -- Create hover frame for mana bar
    if manaBar and not frame.DragonUI_ManaHover then
        frame.DragonUI_ManaHover = CreateFrame("Frame", nil, frame.DragonUI_TextFrame)
        frame.DragonUI_ManaHover:SetFrameLevel(frame.DragonUI_TextFrame:GetFrameLevel() + 1)
        frame.DragonUI_ManaHover:SetAllPoints(manaBar)
        frame.DragonUI_ManaHover:EnableMouse(true)
        frame.DragonUI_ManaHover:SetScript("OnEnter", function()
            hoverStates[frameIndex].mana = true
            HideBlizzardTexts(frame)
            UpdateManaText(manaBar, true) -- Solo mostrar texto de mana
            -- NO mostrar texto de vida durante hover de mana
            if frame.DragonUI_HealthText then frame.DragonUI_HealthText:Hide() end
            if frame.DragonUI_HealthTextLeft then frame.DragonUI_HealthTextLeft:Hide() end
            if frame.DragonUI_HealthTextRight then frame.DragonUI_HealthTextRight:Hide() end
        end)
        frame.DragonUI_ManaHover:SetScript("OnLeave", function()
            hoverStates[frameIndex].mana = false
            HideBlizzardTexts(frame)
            -- Volver a la visibilidad normal de ambos textos
            if healthBar then UpdateHealthText(healthBar, false) end
            UpdateManaText(manaBar, false)
        end)
    end
    
    frame.DragonUI_HoverFrames = true
end

-- Create our own text elements for party frames
CreateCustomTexts = function(frame)
    if not frame or frame.DragonUI_CustomTexts then return end
    
    local frameIndex = frame:GetID()
    if not frameIndex or frameIndex < 1 or frameIndex > 4 then return end
    
    -- Initialize hover states (separate for health and mana)
    if not hoverStates[frameIndex] then
        hoverStates[frameIndex] = {
            portrait = false,
            health = false,
            mana = false
        }
    end
    
    -- Create text frame with proper layering (above border)
    if not frame.DragonUI_TextFrame then
        frame.DragonUI_TextFrame = CreateFrame("Frame", nil, frame)
        frame.DragonUI_TextFrame:SetFrameLevel(frame:GetFrameLevel() + 4) -- Above border and bars
        frame.DragonUI_TextFrame:SetAllPoints(frame)
    end

    -- Create custom health text elements (dual system for "both" format)
    local healthBar = _G[frame:GetName() .. 'HealthBar']
    if healthBar then
        -- Texto central para formatos simples (numeric, percentage, formatted)
        if not frame.DragonUI_HealthText then
            frame.DragonUI_HealthText = frame.DragonUI_TextFrame:CreateFontString(nil, "OVERLAY")
            frame.DragonUI_HealthText:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
            frame.DragonUI_HealthText:SetTextColor(1, 1, 1, 1)
            frame.DragonUI_HealthText:SetPoint("CENTER", healthBar, "CENTER", 0, 0)
            frame.DragonUI_HealthText:SetJustifyH("CENTER")
            frame.DragonUI_HealthText:SetDrawLayer("OVERLAY", 1) -- Above everything
        end
        -- Texto izquierdo para formato "both" (porcentaje)
        if not frame.DragonUI_HealthTextLeft then
            frame.DragonUI_HealthTextLeft = frame.DragonUI_TextFrame:CreateFontString(nil, "OVERLAY")
            frame.DragonUI_HealthTextLeft:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
            frame.DragonUI_HealthTextLeft:SetTextColor(1, 1, 1, 1)
            frame.DragonUI_HealthTextLeft:SetPoint("RIGHT", healthBar, "RIGHT", -39, 0)
            frame.DragonUI_HealthTextLeft:SetJustifyH("LEFT")
            frame.DragonUI_HealthTextLeft:SetDrawLayer("OVERLAY", 1) -- Above everything
        end
        -- Texto derecho para formato "both" (números)
        if not frame.DragonUI_HealthTextRight then
            frame.DragonUI_HealthTextRight = frame.DragonUI_TextFrame:CreateFontString(nil, "OVERLAY")
            frame.DragonUI_HealthTextRight:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
            frame.DragonUI_HealthTextRight:SetTextColor(1, 1, 1, 1)
            frame.DragonUI_HealthTextRight:SetPoint("RIGHT", healthBar, "RIGHT", -3, 0)
            frame.DragonUI_HealthTextRight:SetJustifyH("RIGHT")
            frame.DragonUI_HealthTextRight:SetDrawLayer("OVERLAY", 1) -- Above everything
        end
    end

    -- Create custom mana text elements (dual system for "both" format)
    local manaBar = _G[frame:GetName() .. 'ManaBar']
    if manaBar then
        -- Texto central para formatos simples
        if not frame.DragonUI_ManaText then
            frame.DragonUI_ManaText = frame.DragonUI_TextFrame:CreateFontString(nil, "OVERLAY")
            frame.DragonUI_ManaText:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
            frame.DragonUI_ManaText:SetTextColor(1, 1, 1, 1)
            frame.DragonUI_ManaText:SetPoint("CENTER", manaBar, "CENTER", 1.5, 0)
            frame.DragonUI_ManaText:SetJustifyH("CENTER")
            frame.DragonUI_ManaText:SetDrawLayer("OVERLAY", 1) -- Above everything
        end
        -- Texto izquierdo para formato "both" (porcentaje)
        if not frame.DragonUI_ManaTextLeft then
            frame.DragonUI_ManaTextLeft = frame.DragonUI_TextFrame:CreateFontString(nil, "OVERLAY")
            frame.DragonUI_ManaTextLeft:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
            frame.DragonUI_ManaTextLeft:SetTextColor(1, 1, 1, 1)
            frame.DragonUI_ManaTextLeft:SetPoint("RIGHT", manaBar, "RIGHT", -39, 0)
            frame.DragonUI_ManaTextLeft:SetJustifyH("LEFT")
            frame.DragonUI_ManaTextLeft:SetDrawLayer("OVERLAY", 1) -- Above everything
        end
        -- Texto derecho para formato "both" (números)
        if not frame.DragonUI_ManaTextRight then
            frame.DragonUI_ManaTextRight = frame.DragonUI_TextFrame:CreateFontString(nil, "OVERLAY")
            frame.DragonUI_ManaTextRight:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
            frame.DragonUI_ManaTextRight:SetTextColor(1, 1, 1, 1)
            frame.DragonUI_ManaTextRight:SetPoint("RIGHT", manaBar, "RIGHT", -3, 0)
            frame.DragonUI_ManaTextRight:SetJustifyH("RIGHT")
            frame.DragonUI_ManaTextRight:SetDrawLayer("OVERLAY", 1) -- Above everything
        end
    end
    
    -- Create invisible dummy frames for independent hover (sin taint)
    CreateHoverFrames(frame, frameIndex)
    
    frame.DragonUI_CustomTexts = true
end

-- (Funciones UpdateHealthText y UpdateManaText movidas arriba antes de CreateHoverFrames)

-- Update party colors function
local function UpdatePartyColors(frame)
    if not frame then
        return
    end

    local settings = GetSettings()
    if not settings then
        return
    end

    local unit = "party" .. frame:GetID()
    if not UnitExists(unit) then
        return
    end

    local healthbar = _G[frame:GetName() .. 'HealthBar']
    if healthbar and settings.classcolor then
        local r, g, b = GetClassColor(unit)
        healthbar:SetStatusBarColor(r, g, b)
    end
end

-- New function: Update mana bar texture
local function UpdateManaBarTexture(frame)
    if not frame then
        return
    end

    local unit = "party" .. frame:GetID()
    if not UnitExists(unit) then
        return
    end

    local manabar = _G[frame:GetName() .. 'ManaBar']
    if manabar then
        local powerTexture = GetPowerBarTexture(unit)
        manabar:SetStatusBarTexture(powerTexture)
        manabar:SetStatusBarColor(1, 1, 1, 1) -- Keep white
    end
end
-- ===============================================================
-- FRAME STYLING FUNCTIONS
-- ===============================================================

-- Main styling function for party frames
local function StylePartyFrames()
    local settings = GetSettings()
    if not settings then return end

    CreatePartyAnchorFrame()
    ApplyWidgetPosition()

    local step = GetPartyStep()
    for i = 1, MAX_PARTY_MEMBERS do
        local frame = _G['PartyMemberFrame' .. i]
        if frame then
            frame:SetScale(settings.scale or 1)
            
            -- CRITICAL: Set each party frame to BACKGROUND strata like old code
            frame:SetFrameStrata('BACKGROUND')
            frame:SetFrameLevel(1)
            
            if not InCombatLockdown() then
                frame:ClearAllPoints()
                local yOffset = (i - 1) * -step
                frame:SetPoint("TOPLEFT", PartyFrames.anchor, "TOPLEFT", 0, yOffset)
            end

            -- Hide background
            local bg = _G[frame:GetName() .. 'Background']
            if bg then
                bg:Hide()
            end

            -- Hide default texture
            local texture = _G[frame:GetName() .. 'Texture']
            if texture then
                texture:SetTexture()
                texture:Hide()
            end

            -- Health bar
            local healthbar = _G[frame:GetName() .. 'HealthBar']
            if healthbar and not InCombatLockdown() then
                healthbar:SetStatusBarTexture(TEXTURES.healthBar)
                healthbar:SetSize(71, 10)
                healthbar:ClearAllPoints()
                healthbar:SetPoint('TOPLEFT', 44, -19)
                healthbar:SetFrameLevel(1)  -- Lower level so border texture can appear above
                healthbar:SetStatusBarColor(1, 1, 1, 1)

                -- Configure dynamic clipping with class color
                SetupHealthBarClipping(frame)

                -- Apply initial class color
                UpdatePartyHealthBarColor(i)
            end

            -- Replace mana bar setup (lines 192-199)
            local manabar = _G[frame:GetName() .. 'ManaBar']
            if manabar and not InCombatLockdown() then
                manabar:SetStatusBarTexture(TEXTURES.manaBar)
                manabar:SetSize(74, 6.5)
                manabar:ClearAllPoints()
                manabar:SetPoint('TOPLEFT', 41, -30.5)
                manabar:SetFrameLevel(1)  -- Lower level so border texture can appear above
                manabar:SetStatusBarColor(1, 1, 1, 1)

                -- Configure dynamic clipping
                SetupManaBarClipping(frame)
            end

            -- Name styling
           local name = _G[frame:GetName() .. 'Name']
            if name then
                name:SetFont("Fonts\\FRIZQT__.TTF", 10)
                name:SetShadowOffset(1, -1)
                name:SetTextColor(1, 0.82, 0, 1) -- Yellow like the rest

                if not InCombatLockdown() then
                    name:ClearAllPoints()
                    name:SetPoint('TOPLEFT', 46, -5)
                    name:SetSize(57, 12)
                end
            end

            -- LEADER ICON STYLING
            local leaderIcon = _G[frame:GetName() .. 'LeaderIcon']
            if leaderIcon then -- Removed and not InCombatLockdown()
                leaderIcon:ClearAllPoints()
                leaderIcon:SetPoint('TOPLEFT', 42, 9) -- Custom position
                leaderIcon:SetSize(16, 16) -- Custom size (optional)
            end

            -- Master looter icon styling
            local masterLooterIcon = _G[frame:GetName() .. 'MasterIcon']
            if masterLooterIcon then -- No combat restriction
                masterLooterIcon:ClearAllPoints()
                masterLooterIcon:SetPoint('TOPLEFT', 58, 20) -- Position next to leader icon
                masterLooterIcon:SetSize(16, 16) -- Custom size

            end

            -- Flash setup
            local flash = _G[frame:GetName() .. 'Flash']
            if flash then
                flash:SetSize(114, 47)
                flash:SetTexture(TEXTURES.frame)
                flash:SetTexCoord(GetPartyCoords("flash"))
                flash:SetPoint('TOPLEFT', 2, -2)
                flash:SetVertexColor(1, 0, 0, 1)
                flash:SetDrawLayer('ARTWORK', 5)
            end

            -- Create background and mark as styled
            if not frame.DragonUIStyled then
                -- Background (behind everything)
                local background = frame:CreateTexture(nil, 'BACKGROUND', nil, 0)
                background:SetTexture(TEXTURES.frame)
                background:SetTexCoord(GetPartyCoords("background"))
                background:SetSize(120, 49)
                background:SetPoint('TOPLEFT', 1, -2)

                -- Create border as a separate FRAME (not texture) to appear above bars
                if not frame.DragonUI_BorderFrame then
                    frame.DragonUI_BorderFrame = CreateFrame("Frame", nil, frame)
                    frame.DragonUI_BorderFrame:SetFrameLevel(frame:GetFrameLevel() + 3) -- Above health/mana bars (level 2)
                    frame.DragonUI_BorderFrame:SetAllPoints(frame)
                    
                    -- Now create border texture inside the border frame
                    local border = frame.DragonUI_BorderFrame:CreateTexture(nil, 'ARTWORK', nil, 1)
                    border:SetTexture(TEXTURES.border)
                    border:SetTexCoord(GetPartyCoords("border"))
                    border:SetSize(128, 64)
                    border:SetPoint('TOPLEFT', 1, -2)
                    border:SetVertexColor(1, 1, 1, 1)
                    frame.DragonUI_BorderFrame.texture = border
                end

                -- Create icon container well above border frame
                if not frame.DragonUI_IconContainer then
                    local iconContainer = CreateFrame("Frame", nil, frame)
                    iconContainer:SetFrameStrata("BACKGROUND")  -- Same strata as party frame
                    iconContainer:SetFrameLevel(frame:GetFrameLevel() + 10)  -- Well above border (+3)
                    iconContainer:SetAllPoints(frame)
                    frame.DragonUI_IconContainer = iconContainer
                end

                -- Move icons to HIGH strata container and configure layers
                local name = _G[frame:GetName() .. 'Name']
                local healthText = _G[frame:GetName() .. 'HealthBarText']
                local manaText = _G[frame:GetName() .. 'ManaBarText']
                local leaderIcon = _G[frame:GetName() .. 'LeaderIcon']
                local masterLooterIcon = _G[frame:GetName() .. 'MasterIcon']
                local pvpIcon = _G[frame:GetName() .. 'PVPIcon']
                local statusIcon = _G[frame:GetName() .. 'StatusIcon']
                local blizzardRoleIcon = _G[frame:GetName() .. 'RoleIcon']
                local guideIcon = _G[frame:GetName() .. 'GuideIcon']
                
                -- Text elements stay in normal layer
                if name then
                    name:SetDrawLayer('OVERLAY', 1)
                end
                if healthText then
                    healthText:SetDrawLayer('OVERLAY', 1)
                end
                if manaText then
                    manaText:SetDrawLayer('OVERLAY', 1)
                end
                
                -- Move PvP and status icons to icon container (above border)
                if leaderIcon then
                    leaderIcon:SetParent(frame.DragonUI_IconContainer)
                    leaderIcon:SetDrawLayer('OVERLAY', 1)
                end
                if masterLooterIcon then
                    masterLooterIcon:SetParent(frame.DragonUI_IconContainer)
                    masterLooterIcon:SetDrawLayer('OVERLAY', 1)
                end
                if pvpIcon then
                    pvpIcon:SetParent(frame.DragonUI_IconContainer)
                    pvpIcon:SetDrawLayer('OVERLAY', 1)
                end
                if statusIcon then 
                    statusIcon:SetParent(frame.DragonUI_IconContainer)
                    statusIcon:SetDrawLayer('OVERLAY', 1)
                end
                if blizzardRoleIcon then
                    blizzardRoleIcon:SetParent(frame.DragonUI_IconContainer)
                    blizzardRoleIcon:SetDrawLayer('OVERLAY', 1)
                end
                if guideIcon then
                    guideIcon:SetParent(frame.DragonUI_IconContainer)
                    guideIcon:SetDrawLayer('OVERLAY', 1)
                end

                frame.DragonUIStyled = true
            end
            -- Hide Blizzard texts and create our custom ones
            HideBlizzardTexts(frame)
            CreateCustomTexts(frame)
            
            -- Update our custom texts initially
            if healthbar then
                UpdateHealthText(healthbar, false)
            end
            if manabar then
                UpdateManaText(manabar, false)
            end

            frame.DragonUIStyled = true
        end
    end
end

-- ===============================================================
-- DISCONNECTED PLAYERS
-- ===============================================================
local function UpdateDisconnectedState(frame)
    if not frame then
        return
    end

    local unit = "party" .. frame:GetID()
    if not UnitExists(unit) then
        return
    end

    local isConnected = UnitIsConnected(unit)
    local healthbar = _G[frame:GetName() .. 'HealthBar']
    local manabar = _G[frame:GetName() .. 'ManaBar']
    local portrait = _G[frame:GetName() .. 'Portrait']
    local name = _G[frame:GetName() .. 'Name']

    if not isConnected then
        -- Disconnected member - apply gray effects
        if healthbar then
            healthbar:SetAlpha(0.3)
            healthbar:SetStatusBarColor(0.5, 0.5, 0.5, 1)
        end

        if manabar then
            manabar:SetAlpha(0.3)
            manabar:SetStatusBarColor(0.5, 0.5, 0.5, 1)
        end

        if portrait then
            portrait:SetVertexColor(0.5, 0.5, 0.5, 1)
        end

        if name then
            name:SetTextColor(0.6, 0.6, 0.6, 1)
        end

        -- Reposition icons so they don't get lost
        local leaderIcon = _G[frame:GetName() .. 'LeaderIcon']
        if leaderIcon then
            leaderIcon:ClearAllPoints()
            leaderIcon:SetPoint('TOPLEFT', 42, 9)
            leaderIcon:SetSize(16, 16)
        end

        local masterLooterIcon = _G[frame:GetName() .. 'MasterIcon']
        if masterLooterIcon then
            masterLooterIcon:ClearAllPoints()
            masterLooterIcon:SetPoint('TOPLEFT', 58, 20)
            masterLooterIcon:SetSize(16, 16)
        end

    else
        -- Connected member - undo exactly what was done when disconnecting

        -- Restore transparencies (without taint)
        if healthbar then
            healthbar:SetAlpha(1.0) -- Normal opacity
            -- Restore correct color (class color or white)
            local frameIndex = frame:GetID()
            UpdatePartyHealthBarColor(frameIndex) -- Only updates color, does not recreate frame
        end

        if manabar then
            manabar:SetAlpha(1.0) -- Normal opacity
            manabar:SetStatusBarColor(1, 1, 1, 1) -- White as it should be
        end

        if portrait then
            portrait:SetVertexColor(1, 1, 1, 1) -- Normal color
        end

        if name then
            name:SetTextColor(1, 0.82, 0, 1) -- Normal yellow
        end

        -- Reposition icons (without recreating frames)
        local leaderIcon = _G[frame:GetName() .. 'LeaderIcon']
        if leaderIcon then
            leaderIcon:ClearAllPoints()
            leaderIcon:SetPoint('TOPLEFT', 42, 9)
            leaderIcon:SetSize(16, 16)
        end

        local masterLooterIcon = _G[frame:GetName() .. 'MasterIcon']
        if masterLooterIcon then
            masterLooterIcon:ClearAllPoints()
            masterLooterIcon:SetPoint('TOPLEFT', 58, 20)
            masterLooterIcon:SetSize(16, 16)
        end
    end
end




-- ===============================================================
-- HOOK SETUP FUNCTION
-- ===============================================================

-- Setup all necessary hooks for party frames
local function SetupPartyHooks()
    hooksecurefunc("PartyMemberFrame_UpdateMember", function(frame)
        if frame and frame:GetName():match("^PartyMemberFrame%d+$") then
            if PartyFrames.anchor and not InCombatLockdown() then
                local frameIndex = frame:GetID()
                if frameIndex and frameIndex >= 1 and frameIndex <= 4 then
                    frame:ClearAllPoints()
                    local step = GetPartyStep()
                    local yOffset = (frameIndex - 1) * -step
                    frame:SetPoint("TOPLEFT", PartyFrames.anchor, "TOPLEFT", 0, yOffset)
                end
            end

            -- Re-hide textures (always needed)
            local texture = _G[frame:GetName() .. 'Texture']
            if texture then
                texture:SetTexture()
                texture:Hide()
            end

            local bg = _G[frame:GetName() .. 'Background']
            if bg then
                bg:Hide()
            end

            -- Maintain only clipping configuration (ACE3 handles colors)
            local healthbar = _G[frame:GetName() .. 'HealthBar']
            local manabar = _G[frame:GetName() .. 'ManaBar']

            if healthbar then
                SetupHealthBarClipping(frame)
            end

            if manabar then
                manabar:SetStatusBarColor(1, 1, 1, 1)
                SetupManaBarClipping(frame)
            end

            -- Update power bar texture
            UpdateManaBarTexture(frame)
            -- Disconnected state
            UpdateDisconnectedState(frame)
            
            -- Always hide Blizzard texts and ensure our custom texts exist
            HideBlizzardTexts(frame)
            CreateCustomTexts(frame)
            
            -- Force reparent icons to icon container (for dynamic PvP icons)
            if frame.DragonUI_IconContainer then
                local pvpIcon = _G[frame:GetName() .. 'PVPIcon']
                local leaderIcon = _G[frame:GetName() .. 'LeaderIcon']
                local masterIcon = _G[frame:GetName() .. 'MasterIcon']
                local statusIcon = _G[frame:GetName() .. 'StatusIcon']
                local guideIcon = _G[frame:GetName() .. 'GuideIcon']
                local roleIcon = _G[frame:GetName() .. 'RoleIcon']
                
                if pvpIcon then
                    pvpIcon:SetParent(frame.DragonUI_IconContainer)
                    pvpIcon:SetDrawLayer('OVERLAY', 1)
                end
                if statusIcon then
                    statusIcon:SetParent(frame.DragonUI_IconContainer)
                    statusIcon:SetDrawLayer('OVERLAY', 1)
                end
                if guideIcon then
                    guideIcon:SetParent(frame.DragonUI_IconContainer)
                    guideIcon:SetDrawLayer('OVERLAY', 1)
                end
                if roleIcon then
                    roleIcon:SetParent(frame.DragonUI_IconContainer)
                    roleIcon:SetDrawLayer('OVERLAY', 1)
                end
            end
            
            -- Update our custom texts - AÑADIDA ACTUALIZACIÓN AQUÍ
            local healthbar = _G[frame:GetName() .. 'HealthBar']
            local manabar = _G[frame:GetName() .. 'ManaBar']
            if healthbar then UpdateHealthText(healthbar, false) end
            if manabar then UpdateManaText(manabar, false) end
        end
    end)

    -- Hook adicional para party member updates (compatible con 3.3.5a)
    hooksecurefunc("PartyMemberFrame_OnEvent", function(frame, event)
        if frame and frame:GetName() and frame:GetName():match("^PartyMemberFrame%d+$") then
            if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
                local healthbar = _G[frame:GetName() .. 'HealthBar']
                if healthbar then
                    UpdateHealthText(healthbar, false)
                end
            elseif event == "UNIT_POWER" or event == "UNIT_MAXPOWER" or event == "UNIT_DISPLAYPOWER" then
                local manabar = _G[frame:GetName() .. 'ManaBar']
                if manabar then
                    UpdateManaText(manabar, false)
                end
            end
        end
    end)

    -- Main hook for class color (simplified)
    hooksecurefunc("UnitFrameHealthBar_Update", function(statusbar, unit)
        if statusbar and statusbar:GetName() and statusbar:GetName():find('PartyMemberFrame') then
            -- Only maintain dynamic clipping - Ace3 handles color
            local texture = statusbar:GetStatusBarTexture()
            if texture then
                local min, max = statusbar:GetMinMaxValues()
                local current = statusbar:GetValue()
                if max > 0 and current then
                    local percentage = current / max
                    texture:SetTexCoord(0, percentage, 0, 1)
                end
            end
            
            -- Update health text with DragonUI formatting
            UpdateHealthText(statusbar, false)
        end
    end)

    -- Hook for mana bar (without touching health)
    hooksecurefunc("UnitFrameManaBar_Update", function(statusbar, unit)
        if statusbar and statusbar:GetName() and statusbar:GetName():find('PartyMemberFrame') then
            statusbar:SetStatusBarColor(1, 1, 1, 1) -- Only mana in white

            local frameName = statusbar:GetParent():GetName()
            local frameIndex = frameName:match("PartyMemberFrame(%d+)")
            if frameIndex then
                local partyUnit = "party" .. frameIndex
                local powerTexture = GetPowerBarTexture(partyUnit)
                statusbar:SetStatusBarTexture(powerTexture)

                -- Maintain dynamic clipping
                local texture = statusbar:GetStatusBarTexture()
                if texture then
                    local min, max = statusbar:GetMinMaxValues()
                    local current = statusbar:GetValue()
                    if max > 0 and current then
                        local percentage = current / max
                        texture:SetTexCoord(0, percentage, 0, 1)
                        texture:SetTexture(powerTexture)
                    end
                end
            end
            
            -- Update mana text with DragonUI formatting
            UpdateManaText(statusbar, false)
        end
    end)
    
    -- Handle hover text display with persistent state (portrait hover - shows both texts)
    hooksecurefunc("UnitFrame_OnEnter", function(self)
        if self and self:GetName() and self:GetName():match("^PartyMemberFrame%d+$") then
            local frameIndex = tonumber(self:GetID())
            if frameIndex and hoverStates[frameIndex] then
                hoverStates[frameIndex].portrait = true  -- Mark portrait as hovering
            end
            
            -- Immediately hide Blizzard texts after hover
            HideBlizzardTexts(self)
            
            -- Show both custom texts during portrait hover (even if always show is off)
            local healthbar = _G[self:GetName() .. 'HealthBar']
            local manabar = _G[self:GetName() .. 'ManaBar']
            if healthbar then UpdateHealthText(healthbar, true) end -- forceShow = true
            if manabar then UpdateManaText(manabar, true) end -- forceShow = true
        end
    end)
    
    hooksecurefunc("UnitFrame_OnLeave", function(self)
        if self and self:GetName() and self:GetName():match("^PartyMemberFrame%d+$") then
            local frameIndex = tonumber(self:GetID())
            if frameIndex and hoverStates[frameIndex] then
                hoverStates[frameIndex].portrait = false  -- Clear portrait hover state
            end
            
            -- Ensure Blizzard texts stay hidden after hover ends
            HideBlizzardTexts(self)
            
            -- Return to normal text visibility (respect always show setting)
            local healthbar = _G[self:GetName() .. 'HealthBar']
            local manabar = _G[self:GetName() .. 'ManaBar']
            if healthbar then UpdateHealthText(healthbar, false) end -- forceShow = false
            if manabar then UpdateManaText(manabar, false) end -- forceShow = false
        end
    end)
end

-- ===============================================================
-- MODULE INTERFACE FUNCTIONS (SIMPLIFIED FOR ACE3)
-- ===============================================================

-- Simplified function compatible with Ace3
function PartyFrames:UpdateSettings()
    -- Check initial configuration
    if not addon.db or not addon.db.profile or not addon.db.profile.widgets or not addon.db.profile.widgets.party then
        self:LoadDefaultSettings()
    end

    -- Apply widget position first
    ApplyWidgetPosition()
    
    -- Only apply base styles - ACE3 handles class color
    StylePartyFrames()
    
    -- Reposition buffs
    RepositionBlizzardBuffs()
    
    -- Refresh all texts with new settings
    for i = 1, MAX_PARTY_MEMBERS do
        local frame = _G['PartyMemberFrame' .. i]
        if frame then
            HideBlizzardTexts(frame)
            CreateCustomTexts(frame)
            
            local healthbar = _G[frame:GetName() .. 'HealthBar']
            local manabar = _G[frame:GetName() .. 'ManaBar']
            
            if healthbar then UpdateHealthText(healthbar, false) end
            if manabar then UpdateManaText(manabar, false) end
        end
    end
end

-- ===============================================================
-- EXPORTS FOR OPTIONS.LUA
-- ===============================================================

-- Export for options.lua refresh functions
addon.RefreshPartyFrames = function()
    if PartyFrames.UpdateSettings then
        PartyFrames:UpdateSettings()
    end
end

-- New function: Refresh called from core.lua
function addon:RefreshPartyFrames()
    if PartyFrames and PartyFrames.UpdateSettings then
        PartyFrames:UpdateSettings()
    end
end

-- ===============================================================
-- CENTRALIZED SYSTEM REGISTRATION AND INITIALIZATION
-- ===============================================================

local function InitializePartyFramesForEditor()
    if PartyFrames.initialized then
        return
    end

    -- Create anchor frame
    CreatePartyAnchorFrame()

    -- Always ensure configuration exists
    PartyFrames:LoadDefaultSettings()

    -- Apply initial position
    ApplyWidgetPosition()

    -- Register with centralized system
    if addon and addon.RegisterEditableFrame then
        addon:RegisterEditableFrame({
            name = "party",
            frame = PartyFrames.anchor,
            configPath = {"widgets", "party"}, -- Add configPath required by core.lua
            showTest = ShowPartyFramesTest,
            hideTest = HidePartyFramesTest,
            hasTarget = ShouldPartyFramesBeVisible -- Use hasTarget instead of shouldShow
        })
    end

    PartyFrames.initialized = true
end

-- ===============================================================
-- INITIALIZATION
-- ===============================================================

-- Initialize everything in correct order
InitializePartyFramesForEditor() -- First: register with centralized system
StylePartyFrames() -- Second: visual properties and positioning
SetupPartyHooks() -- Third: safe hooks only

-- Listener for when the addon is fully loaded
local readyFrame = CreateFrame("Frame")
readyFrame:RegisterEvent("ADDON_LOADED")
readyFrame:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "DragonUI" then
        -- Apply position after the addon is fully loaded
        if PartyFrames and PartyFrames.UpdateSettings then
            PartyFrames:UpdateSettings()
        end
        self:UnregisterEvent("ADDON_LOADED")
    end
end)

local connectionFrame = CreateFrame("Frame")
connectionFrame:RegisterEvent("PARTY_MEMBER_DISABLE")
connectionFrame:RegisterEvent("PARTY_MEMBER_ENABLE")
connectionFrame:SetScript("OnEvent", function(self, event)
    for i = 1, MAX_PARTY_MEMBERS do
        local frame = _G['PartyMemberFrame' .. i]
        if frame then
            UpdateDisconnectedState(frame)
        end
    end
end)


-- ===============================================================
-- MODULE LOADED CONFIRMATION
-- ===============================================================

