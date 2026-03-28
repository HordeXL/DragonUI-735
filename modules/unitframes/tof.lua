local addon = select(2, ...)

-- ============================================================================
-- DRAGONUI FOCUS OF TARGET FRAME MODULE - WoW 3.3.5a
-- CLONADO EXACTO DE TOT.LUA PERO PARA FOCUS
-- ============================================================================

local Module = {
    totFrame = nil,
    textSystem = nil,
    initialized = false,
    configured = false,
    eventsFrame = nil
}

-- ============================================================================
-- CONFIGURATION & CONSTANTS (IGUAL QUE TOT)
-- ============================================================================

-- Cache Blizzard frames (FOCUS EN LUGAR DE TARGET)
local FocusFrameToT = _G.FocusFrameToT

-- Texture paths (IGUAL que ToT)
local TEXTURES = {
    BACKGROUND = "Interface\\AddOns\\DragonUI\\Textures\\UI-HUD-UnitFrame-TargetofTarget-PortraitOn-BACKGROUND",
    BORDER = "Interface\\AddOns\\DragonUI\\Textures\\UI-HUD-UnitFrame-TargetofTarget-PortraitOn-BORDER",
    BAR_PREFIX = "Interface\\AddOns\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-TargetofTarget-PortraitOn-Bar-",
    BOSS = "Interface\\AddOns\\DragonUI\\Textures\\uiunitframeboss2x"
}

-- Boss classifications (IGUAL que ToT)
local BOSS_COORDS = {
    elite = {0.001953125, 0.314453125, 0.322265625, 0.630859375, 60, 59, 3, 1},
    rare = {0.00390625, 0.31640625, 0.64453125, 0.953125, 60, 59, 3, 1},
    rareelite = {0.001953125, 0.388671875, 0.001953125, 0.31835937, 74, 61, 10, 1}
}

-- Power types (IGUAL que ToT)
local POWER_MAP = {
    [0] = "Mana",
    [1] = "Rage",
    [2] = "Focus",
    [3] = "Energy",
    [6] = "RunicPower"
}

-- Frame elements storage (IGUAL que ToT)
local frameElements = {
    background = nil,
    border = nil,
    elite = nil
}

-- Update throttling (IGUAL que ToT)
local updateCache = {
    lastHealthUpdate = 0,
    lastPowerUpdate = 0
}

-- ============================================================================
-- UTILITY FUNCTIONS (IGUAL QUE TOT)
-- ============================================================================

local function GetConfig()
    return addon:GetConfigValue("unitframe", "fot") or {}
end

-- ============================================================================
-- BAR MANAGEMENT (IGUAL QUE TOT PERO PARA FOCUS)
-- ============================================================================

local function SetupBarHooks()
    -- Health bar hooks (IGUAL que ToT pero para "focustarget")
    if not FocusFrameToTHealthBar.DragonUI_Setup then
        local healthTexture = FocusFrameToTHealthBar:GetStatusBarTexture()
        if healthTexture then
            healthTexture:SetDrawLayer("ARTWORK", 1)
        end

        hooksecurefunc(FocusFrameToTHealthBar, "SetValue", function(self)
            if not UnitExists("focustarget") then
                return
            end

            local now = GetTime()
            if now - updateCache.lastHealthUpdate < 0.05 then
                return
            end
            updateCache.lastHealthUpdate = now

            local texture = self:GetStatusBarTexture()
            if not texture then
                return
            end

            local config = GetConfig()
            local texturePath

            -- NUEVO: Decidir qué textura usar basado en classcolor
            if config.classcolor and UnitIsPlayer("focustarget") then
                texturePath = TEXTURES.BAR_PREFIX .. "Health-Status" -- Versión Status para colores de clase
            else
                texturePath = TEXTURES.BAR_PREFIX .. "Health" -- Versión normal
            end

            -- Update texture
            if texture:GetTexture() ~= texturePath then
                texture:SetTexture(texturePath)
                texture:SetDrawLayer("ARTWORK", 1)
            end

            -- Update coords
            local min, max = self:GetMinMaxValues()
            local current = self:GetValue()
            if max > 0 and current then
                texture:SetTexCoord(0, current / max, 0, 1)
            end

            -- Update color
            if config.classcolor and UnitIsPlayer("focustarget") then
                local _, class = UnitClass("focustarget")
                local color = RAID_CLASS_COLORS[class]
                if color then
                    texture:SetVertexColor(color.r, color.g, color.b)
                else
                    texture:SetVertexColor(1, 1, 1)
                end
            else
                texture:SetVertexColor(1, 1, 1)
            end
        end)

        FocusFrameToTHealthBar.DragonUI_Setup = true
    end

    -- Power bar hooks (IGUAL que ToT pero para "focustarget")
    if not FocusFrameToTManaBar.DragonUI_Setup then
        local powerTexture = FocusFrameToTManaBar:GetStatusBarTexture()
        if powerTexture then
            powerTexture:SetDrawLayer("ARTWORK", 1)
        end

        hooksecurefunc(FocusFrameToTManaBar, "SetValue", function(self)
            if not UnitExists("focustarget") then
                return
            end

            local now = GetTime()
            if now - updateCache.lastPowerUpdate < 0.05 then
                return
            end
            updateCache.lastPowerUpdate = now

            local texture = self:GetStatusBarTexture()
            if not texture then
                return
            end

            -- Update texture based on power type
            local powerType = UnitPowerType("focustarget")
            local powerName = POWER_MAP[powerType] or "Mana"
            local texturePath = TEXTURES.BAR_PREFIX .. powerName

            if texture:GetTexture() ~= texturePath then
                texture:SetTexture(texturePath)
                texture:SetDrawLayer("ARTWORK", 1)
            end

            -- Update coords
            local min, max = self:GetMinMaxValues()
            local current = self:GetValue()
            if max > 0 and current then
                texture:SetTexCoord(0, current / max, 0, 1)
            end

            -- Force white color
            texture:SetVertexColor(1, 1, 1)
        end)

        FocusFrameToTManaBar.DragonUI_Setup = true
    end
end

-- ============================================================================
-- CLASSIFICATION SYSTEM (IGUAL QUE TOT PERO PARA FOCUS)
-- ============================================================================

local function UpdateClassification()
    if not UnitExists("focustarget") or not frameElements.elite then
        if frameElements.elite then
            frameElements.elite:Hide()
        end
        return
    end

    local classification = UnitClassification("focustarget")
    local coords = nil

    -- Check vehicle first
    if UnitVehicleSeatCount and UnitVehicleSeatCount("focustarget") > 0 then
        frameElements.elite:Hide()
        return
    end

    -- Determine classification
    if classification == "worldboss" or classification == "elite" then
        coords = BOSS_COORDS.elite
    elseif classification == "rareelite" then
        coords = BOSS_COORDS.rareelite
    elseif classification == "rare" then
        coords = BOSS_COORDS.rare
    else
        local name = UnitName("focustarget")
        if name and addon.unitframe and addon.unitframe.famous and addon.unitframe.famous[name] then
            coords = BOSS_COORDS.elite
        end
    end

    if coords then
        frameElements.elite:SetTexture(TEXTURES.BOSS)

        -- APLICAR FLIP HORIZONTAL A TODAS LAS DECORACIONES
        local left, right, top, bottom = coords[1], coords[2], coords[3], coords[4]
        frameElements.elite:SetTexCoord(right, left, top, bottom) -- FLIPPED

        -- USAR VALORES CORREGIDOS DEL DEBUG
        frameElements.elite:SetSize(51, 51)
        frameElements.elite:SetPoint("CENTER", FocusFrameToTPortrait, "CENTER", -4, -2)
        frameElements.elite:SetDrawLayer("OVERLAY", 11)
        frameElements.elite:Show()
        frameElements.elite:SetAlpha(1)
    else
        frameElements.elite:Hide()
    end
end

-- ============================================================================
-- FRAME INITIALIZATION (IGUAL QUE TOT PERO PARA FOCUS)
-- ============================================================================

local function InitializeFrame()
    if Module.configured then
        return
    end

    -- Verificar que FoT existe
    if not FocusFrameToT then

        return
    end

    -- Get configuration
    local config = GetConfig()

    -- Position and scale (ANCLADO AL FOCUS FRAME)
    FocusFrameToT:ClearAllPoints()
    FocusFrameToT:SetPoint(config.anchor or "BOTTOMRIGHT", FocusFrame, config.anchorParent or "BOTTOMRIGHT",
        config.x or -8, config.y or -30)
    FocusFrameToT:SetScale(config.scale or 1.0)

    -- Hide Blizzard elements
    local toHide = {FocusFrameToTTextureFrameTexture, FocusFrameToTBackground}

    for _, element in ipairs(toHide) do
        if element then
            element:SetAlpha(0)
            element:Hide()
        end
    end

    -- Create background texture
    if not frameElements.background then
        frameElements.background = FocusFrameToT:CreateTexture("DragonUI_FoTBG", "BACKGROUND", nil, 0)
        frameElements.background:SetTexture(TEXTURES.BACKGROUND)
        frameElements.background:SetPoint('LEFT', FocusFrameToTPortrait, 'CENTER', -25 + 1, -10)
    end

    -- Create border texture
    if not frameElements.border then
        frameElements.border = FocusFrameToTHealthBar:CreateTexture("DragonUI_FoTBorder", "OVERLAY", nil, 1)
        frameElements.border:SetTexture(TEXTURES.BORDER)
        frameElements.border:SetPoint('LEFT', FocusFrameToTPortrait, 'CENTER', -25 + 1, -10)
        frameElements.border:Show()
        frameElements.border:SetAlpha(1)
    end

    -- Create elite decoration
    if not frameElements.elite then
        local eliteFrame = CreateFrame("Frame", "DragonUI_FoTEliteFrame", FocusFrameToT)
        eliteFrame:SetFrameStrata("MEDIUM")
        eliteFrame:SetAllPoints(FocusFrameToTPortrait)

        frameElements.elite = eliteFrame:CreateTexture("DragonUI_FoTElite", "OVERLAY", nil, 1)
        frameElements.elite:SetTexture(TEXTURES.BOSS)
        frameElements.elite:Hide()
    end

    -- Configure health bar (IGUAL que ToT)
    FocusFrameToTHealthBar:Hide()
    FocusFrameToTHealthBar:ClearAllPoints()
    FocusFrameToTHealthBar:SetParent(FocusFrameToT)
    FocusFrameToTHealthBar:SetFrameStrata("LOW")
    FocusFrameToTHealthBar:GetStatusBarTexture():SetDrawLayer("ARTWORK", 1)
    FocusFrameToTHealthBar:GetStatusBarTexture():SetTexture(TEXTURES.BAR_PREFIX .. "Health")
    FocusFrameToTHealthBar.SetStatusBarColor = function()
    end -- noop
    FocusFrameToTHealthBar:GetStatusBarTexture():SetVertexColor(1, 1, 1, 1)
    FocusFrameToTHealthBar:SetSize(70.5, 10)
    FocusFrameToTHealthBar:SetPoint('LEFT', FocusFrameToTPortrait, 'RIGHT', 1 + 1, 0)
    FocusFrameToTHealthBar:Show()

    -- Configure power bar (IGUAL que ToT)
    FocusFrameToTManaBar:Hide()
    FocusFrameToTManaBar:ClearAllPoints()
    FocusFrameToTManaBar:SetParent(FocusFrameToT)
    FocusFrameToTManaBar:SetFrameStrata("LOW")
    FocusFrameToTManaBar:GetStatusBarTexture():SetDrawLayer("ARTWORK", 1)
    FocusFrameToTManaBar:GetStatusBarTexture():SetTexture(TEXTURES.BAR_PREFIX .. "Mana")
    FocusFrameToTManaBar.SetStatusBarColor = function()
    end -- noop
    FocusFrameToTManaBar:GetStatusBarTexture():SetVertexColor(1, 1, 1, 1)
    FocusFrameToTManaBar:SetSize(74, 7.5)
    FocusFrameToTManaBar:SetPoint('LEFT', FocusFrameToTPortrait, 'RIGHT', 1 - 2 - 1.5 + 1, 2 - 10 - 1)
    FocusFrameToTManaBar:Show()

    -- Configure name text (IGUAL que ToT)
    if FocusFrameToTTextureFrameName then
        FocusFrameToTTextureFrameName:ClearAllPoints()
        FocusFrameToTTextureFrameName:SetPoint('LEFT', FocusFrameToTPortrait, 'RIGHT', 3, 13)
        FocusFrameToTTextureFrameName:SetParent(FocusFrameToT)
        FocusFrameToTTextureFrameName:Show()
        local font, size, flags = FocusFrameToTTextureFrameName:GetFont()
        if font and size then
            FocusFrameToTTextureFrameName:SetFont(font, math.max(size, 10), flags)
        end
        FocusFrameToTTextureFrameName:SetTextColor(1.0, 0.82, 0.0, 1.0)
        FocusFrameToTTextureFrameName:SetDrawLayer("BORDER", 1)

        -- TRUNCADO AUTOMÁTICO COMO RETAILUI
        FocusFrameToTTextureFrameName:SetWidth(65)
        FocusFrameToTTextureFrameName:SetJustifyH("LEFT")
    end

    -- Force debuff positions if needed
    if FocusFrameToTDebuff1 then
        FocusFrameToTDebuff1:ClearAllPoints()
        FocusFrameToTDebuff1:SetPoint("TOPLEFT", FocusFrameToT, "BOTTOMLEFT", 120, 35)
    end

    -- Setup bar hooks
    SetupBarHooks()

    Module.configured = true
end

-- ============================================================================
-- EVENT HANDLING (IGUAL QUE TOT PERO PARA FOCUS)
-- ============================================================================

local function OnEvent(self, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name == "DragonUI" and not Module.initialized then
            Module.totFrame = CreateFrame("Frame", "DragonUI_FoT_Anchor", UIParent)
            Module.totFrame:SetSize(120, 47)
            Module.totFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 370, -80)
            Module.initialized = true
        end

    elseif event == "PLAYER_ENTERING_WORLD" then
        InitializeFrame()
        if UnitExists("focustarget") then
            UpdateClassification()
        end

    elseif event == "PLAYER_FOCUS_CHANGED" then
        -- Focus cambió, forzar update del FoT
        UpdateClassification()
        if Module.textSystem then
            Module.textSystem.update()
        end

    elseif event == "UNIT_TARGET" then
        local unit = ...
        if unit == "focus" then -- El target del focus cambió
            UpdateClassification()
            if Module.textSystem then
                Module.textSystem.update()
            end
        end

    elseif event == "UNIT_CLASSIFICATION_CHANGED" then
        local unit = ...
        if unit == "focustarget" then
            UpdateClassification()
        end

    elseif event == "UNIT_FACTION" then
        local unit = ...
        if unit == "focustarget" then
            -- No tenemos name background como target, pero podrías agregarlo
        end
    end
end

-- Initialize events
if not Module.eventsFrame then
    Module.eventsFrame = CreateFrame("Frame")
    Module.eventsFrame:RegisterEvent("ADDON_LOADED")
    Module.eventsFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    Module.eventsFrame:RegisterEvent("PLAYER_FOCUS_CHANGED")
    Module.eventsFrame:RegisterEvent("UNIT_TARGET") -- Crucial para FoT
    Module.eventsFrame:RegisterEvent("UNIT_CLASSIFICATION_CHANGED")
    Module.eventsFrame:RegisterEvent("UNIT_FACTION")
    Module.eventsFrame:SetScript("OnEvent", OnEvent)
end

-- ============================================================================
-- PUBLIC API (IGUAL QUE TOT)
-- ============================================================================

local function RefreshFrame()
    if not Module.configured then
        InitializeFrame()
    end

    if UnitExists("focustarget") then
        UpdateClassification()
        if Module.textSystem then
            Module.textSystem.update()
        end
    end
end

local function ResetFrame()
    -- Reset a valores por defecto de la DB
    addon:SetConfigValue("unitframe", "fot", "x", -8)
    addon:SetConfigValue("unitframe", "fot", "y", -30)
    addon:SetConfigValue("unitframe", "fot", "scale", 1.0)

    -- Aplicar inmediatamente
    local config = GetConfig()
    FocusFrameToT:ClearAllPoints()
    FocusFrameToT:SetPoint(config.anchor or "BOTTOMRIGHT", FocusFrame, config.anchorParent or "BOTTOMRIGHT", config.x,
        config.y)
    FocusFrameToT:SetScale(config.scale)
end

-- Export API (igual que target/focus)
addon.TargetOfFocus = {
    Refresh = RefreshFrame,
    RefreshToFFrame = RefreshFrame,
    Reset = ResetFrame,
    anchor = function()
        return Module.totFrame
    end,
    ChangeToFFrame = RefreshFrame
}

-- Legacy compatibility
addon.unitframe = addon.unitframe or {}
addon.unitframe.ChangeFocusToT = RefreshFrame
addon.unitframe.ReApplyFocusToTFrame = RefreshFrame
addon.unitframe.StyleFocusToTFrame = InitializeFrame

function addon:RefreshToFFrame()
    RefreshFrame()
end

