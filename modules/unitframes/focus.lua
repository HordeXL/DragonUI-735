local addon = select(2, ...)

-- ============================================================================
-- DRAGONUI FOCUS FRAME MODULE - WoW 3.3.5a
-- ============================================================================

local Module = {
    focusFrame = nil,
    textSystem = nil,
    initialized = false,
    configured = false,
    eventsFrame = nil
}

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

local function GetConfig()
    local config = addon:GetConfigValue("unitframe", "focus") or {}
    local defaults = addon.defaults and addon.defaults.profile.unitframe.focus or {}
    return setmetatable(config, {__index = defaults})
end


-- ============================================================================
-- UTILITY FUNCTIONS FOR CENTRALIZED SYSTEM
-- ============================================================================

-- Function to apply position from widgets (like player.lua)
local function ApplyWidgetPosition()
    if not Module.focusFrame then
        return
    end

    local widgetConfig = addon.db and addon.db.profile.widgets and addon.db.profile.widgets.focus
    
    if widgetConfig then
        Module.focusFrame:ClearAllPoints()
        Module.focusFrame:SetPoint(widgetConfig.anchor or "TOPLEFT", UIParent, widgetConfig.anchor or "TOPLEFT", 
                                   widgetConfig.posX or 250, widgetConfig.posY or -170)
        
        -- Also apply to Blizzard frame
        FocusFrame:ClearAllPoints()
        FocusFrame:SetPoint("CENTER", Module.focusFrame, "CENTER", 20, -7)
        
    else
        -- Fallback to default position
        Module.focusFrame:ClearAllPoints()
        Module.focusFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 250, -170)
        FocusFrame:ClearAllPoints()
        FocusFrame:SetPoint("CENTER", Module.focusFrame, "CENTER", 0, 0)
    end
end

-- Function to check if the focus frame should be visible
local function ShouldFocusFrameBeVisible()
    return UnitExists("focus")
end

-- Simplified test functions
local function ShowFocusFrameTest()
    -- Simple system: Just call the frame's ShowTest method
    if FocusFrame and FocusFrame.ShowTest then
        FocusFrame:ShowTest()
    end
end

local function HideFocusFrameTest()
    -- Simple system: Just call the frame's HideTest method
    if FocusFrame and FocusFrame.HideTest then
        FocusFrame:HideTest()
    end
end

-- ============================================================================
-- CONFIGURATION & CONSTANTS
-- ============================================================================

-- Cache Blizzard frames
local FocusFrame = _G.FocusFrame
local FocusFrameHealthBar = _G.FocusFrameHealthBar
local FocusFrameManaBar = _G.FocusFrameManaBar
local FocusFramePortrait = _G.FocusFramePortrait
local FocusFrameTextureFrameName = _G.FocusFrameTextureFrameName
local FocusFrameTextureFrameLevelText = _G.FocusFrameTextureFrameLevelText
local FocusFrameNameBackground = _G.FocusFrameNameBackground

-- Texture paths (reused from target)
local TEXTURES = {
    BACKGROUND = "Interface\\AddOns\\DragonUI\\Textures\\UI-HUD-UnitFrame-Target-PortraitOn-BACKGROUND",
    BORDER = "Interface\\AddOns\\DragonUI\\Textures\\UI-HUD-UnitFrame-Target-PortraitOn-BORDER",
    BAR_PREFIX = "Interface\\AddOns\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-Target-PortraitOn-Bar-",
    NAME_BACKGROUND = "Interface\\AddOns\\DragonUI\\Textures\\TargetFrame\\NameBackground",
    BOSS = "Interface\\AddOns\\DragonUI\\Textures\\uiunitframeboss2x",
    THREAT = "Interface\\AddOns\\DragonUI\\Textures\\Unitframe2x\\ui-hud-unitframe-target-portraiton-incombat-2x",
    THREAT_NUMERIC = "Interface\\AddOns\\DragonUI\\Textures\\uiunitframe"
}

-- Boss classifications (same as target)
local BOSS_COORDS = {
    elite = {0.001953125, 0.314453125, 0.322265625, 0.630859375, 80, 79, 4, 1},
    rare = {0.00390625, 0.31640625, 0.64453125, 0.953125, 80, 79, 4, 1},
    rareelite = {0.001953125, 0.388671875, 0.001953125, 0.31835937, 99, 81, 13, 1}
}

-- Power types
local POWER_MAP = {
    [0] = "Mana", [1] = "Rage", [2] = "Focus", [3] = "Energy", [6] = "RunicPower"
}

-- Frame elements storage
local frameElements = {
    background = nil,
    border = nil,
    elite = nil,
    threatNumeric = nil 
}

-- Update throttling
local updateCache = {
    lastHealthUpdate = 0,
    lastPowerUpdate = 0,
    lastThreatUpdate = 0
}
-- ============================================================================
-- THREAT SYSTEM (NUEVO - COPIADO DE TARGET)
-- ============================================================================

local function UpdateThreat()
    if not UnitExists("focus") then
        if frameElements.threatNumeric then
            frameElements.threatNumeric:Hide()
        end
        return
    end

    local status = UnitThreatSituation("player", "focus")
    local level = status and math.min(status, 3) or 0

    if level > 0 then
        -- Solo numerical threat
        local _, _, _, pct = UnitDetailedThreatSituation("player", "focus")

        if frameElements.threatNumeric and pct and pct > 0 then
            local displayPct = math.floor(math.min(100, math.max(0, pct)))
            frameElements.threatNumeric.text:SetText(displayPct .. "%")
            -- Color basado en level de threat
            if level == 1 then
                frameElements.threatNumeric.text:SetTextColor(1.0, 1.0, 0.47) -- Amarillo
            elseif level == 2 then
                frameElements.threatNumeric.text:SetTextColor(1.0, 0.6, 0.0) -- Naranja
            else
                frameElements.threatNumeric.text:SetTextColor(1.0, 0.0, 0.0) -- Rojo
            end
            frameElements.threatNumeric:Show()
        else
            if frameElements.threatNumeric then
                frameElements.threatNumeric:Hide()
            end
        end
    else
        -- Ocultar numeric
        if frameElements.threatNumeric then
            frameElements.threatNumeric:Hide()
        end
    end
end

-- ============================================================================
-- BAR MANAGEMENT
-- ============================================================================

-- Función para actualizar la barra de poder inmediatamente
local function UpdatePowerBar()
    if not UnitExists("focus") or not FocusFrameManaBar then return end
    
    local texture = FocusFrameManaBar:GetStatusBarTexture()
    if not texture then return end
    
    -- Update texture based on power type
    local powerType = UnitPowerType("focus")
    local powerName = POWER_MAP[powerType] or "Mana"
    local texturePath = TEXTURES.BAR_PREFIX .. powerName
    
    -- Forzar cambio de textura inmediatamente
    texture:SetTexture(texturePath)
    texture:SetDrawLayer("ARTWORK", 1)
    
    -- Update coords
    local min, max = FocusFrameManaBar:GetMinMaxValues()
    local current = FocusFrameManaBar:GetValue()
    if max > 0 and current then
        texture:SetTexCoord(0, current/max, 0, 1)
    end
    
    -- Forzar color blanco inmediatamente (múltiples métodos para asegurar que se aplique)
    texture:SetVertexColor(1, 1, 1)
    FocusFrameManaBar:SetStatusBarColor(1, 1, 1) -- Método alternativo
end

local function SetupBarHooks()
    -- Health bar hooks
    if not FocusFrameHealthBar.DragonUI_Setup then
        local healthTexture = FocusFrameHealthBar:GetStatusBarTexture()
        if healthTexture then
            healthTexture:SetDrawLayer("ARTWORK", 1)
        end
        
        hooksecurefunc(FocusFrameHealthBar, "SetValue", function(self)
    if not UnitExists("focus") then return end
    
    local now = GetTime()
    if now - updateCache.lastHealthUpdate < 0.05 then return end
    updateCache.lastHealthUpdate = now
    
    local texture = self:GetStatusBarTexture()
    if not texture then return end
    
    local config = GetConfig()
    local texturePath
    
    -- NUEVO: Decidir qué textura usar basado en classcolor
    if config.classcolor and UnitIsPlayer("focus") then
        texturePath = TEXTURES.BAR_PREFIX .. "Health-Status"  -- Versión Status para colores de clase
    else
        texturePath = TEXTURES.BAR_PREFIX .. "Health"         -- Versión normal
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
        texture:SetTexCoord(0, current/max, 0, 1)
    end
    
    -- Update color
    if config.classcolor and UnitIsPlayer("focus") then
        local _, class = UnitClass("focus")
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
        
        FocusFrameHealthBar.DragonUI_Setup = true
    end
    
    -- Power bar hooks
    if not FocusFrameManaBar.DragonUI_Setup then
        local powerTexture = FocusFrameManaBar:GetStatusBarTexture()
        if powerTexture then
            powerTexture:SetDrawLayer("ARTWORK", 1)
        end
        
        hooksecurefunc(FocusFrameManaBar, "SetValue", function(self)
            if not UnitExists("focus") then return end
            
            local now = GetTime()
            if now - updateCache.lastPowerUpdate < 0.1 then return end
            updateCache.lastPowerUpdate = now
            
            UpdatePowerBar()
        end)
        
        -- Hook adicional para SetMinMaxValues para asegurar color blanco
        hooksecurefunc(FocusFrameManaBar, "SetMinMaxValues", function(self)
            if not UnitExists("focus") then return end
            local texture = self:GetStatusBarTexture()
            if texture then
                texture:SetVertexColor(1, 1, 1) -- Forzar blanco siempre
            end
        end)
        
        -- Hook adicional para SetStatusBarColor para prevenir cambios de color
        hooksecurefunc(FocusFrameManaBar, "SetStatusBarColor", function(self)
            if not UnitExists("focus") then return end
            local texture = self:GetStatusBarTexture()
            if texture then
                texture:SetVertexColor(1, 1, 1) -- Forzar blanco siempre
            end
        end)
        
        FocusFrameManaBar.DragonUI_Setup = true
    end
end

-- ============================================================================
-- CLASSIFICATION SYSTEM
-- ============================================================================

local function UpdateClassification()
    if not UnitExists("focus") or not frameElements.elite then
        if frameElements.elite then frameElements.elite:Hide() end
        return
    end
    
    local classification = UnitClassification("focus")
    local coords = nil
    
    -- Check vehicle first
    if UnitVehicleSeatCount and UnitVehicleSeatCount("focus") > 0 then
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
        local name = UnitName("focus")
        if name and addon.unitframe and addon.unitframe.famous and addon.unitframe.famous[name] then
            coords = BOSS_COORDS.elite
        end
    end
    
    if coords then
        frameElements.elite:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
        frameElements.elite:SetSize(coords[5], coords[6])
        frameElements.elite:SetPoint("CENTER", FocusFramePortrait, "CENTER", coords[7], coords[8])
        frameElements.elite:Show()
    else
        frameElements.elite:Hide()
    end
end

-- ============================================================================
-- NAME BACKGROUND
-- ============================================================================

local function UpdateNameBackground()
    if not FocusFrameNameBackground then return end
    
    if not UnitExists("focus") then
        FocusFrameNameBackground:Hide()
        return
    end
    
    local r, g, b = UnitSelectionColor("focus")
    FocusFrameNameBackground:SetVertexColor(r or 0.5, g or 0.5, b or 0.5, 0.8)
    FocusFrameNameBackground:Show()
end

-- ============================================================================
-- FRAME INITIALIZATION
-- ============================================================================

local function InitializeFrame()
    if Module.configured then return end
    
    -- Check that FocusFrame exists (Wrath only)
    if not FocusFrame then
        return
    end
    
    -- Create overlay frame for centralized system
    if not Module.focusFrame then
        Module.focusFrame = addon.CreateUIFrame(180, 70, "FocusFrame")
        
        -- Automatic registration in centralized system
        addon:RegisterEditableFrame({
            name = "focus",
            frame = Module.focusFrame,
            blizzardFrame = FocusFrame,
            configPath = {"widgets", "focus"},
            hasTarget = ShouldFocusFrameBeVisible, -- Only visible when there is focus
            showTest = ShowFocusFrameTest,         -- Show fake frame
            hideTest = HideFocusFrameTest,         -- Hide fake frame
            onHide = function()
                ApplyWidgetPosition() -- Apply new configuration when exiting editor
            end,
            module = Module
        })
        
    end
    
    -- Hide Blizzard elements
    local toHide = {
        FocusFrameTextureFrameTexture,
        FocusFrameBackground,
        FocusFrameFlash,
        -- NUEVO: Ocultar elementos de threat de Blizzard como en target
        _G.FocusFrameNumericalThreat,        
        FocusFrame.threatNumericIndicator,   
        FocusFrame.threatIndicator           
    }
    
    for _, element in ipairs(toHide) do
        if element then 
            element:SetAlpha(0)
            element:Hide()
        end
    end
    
    -- Create background texture
    if not frameElements.background then
        frameElements.background = FocusFrame:CreateTexture("DragonUI_FocusBG", "BACKGROUND", nil, -7)
        frameElements.background:SetTexture(TEXTURES.BACKGROUND)
        frameElements.background:SetPoint("TOPLEFT", FocusFrame, "TOPLEFT", 0, -8)
    end
    
    -- Create border texture
    if not frameElements.border then
        frameElements.border = FocusFrame:CreateTexture("DragonUI_FocusBorder", "OVERLAY", nil, 5)
        frameElements.border:SetTexture(TEXTURES.BORDER)
        frameElements.border:SetPoint("TOPLEFT", frameElements.background, "TOPLEFT", 0, 0)
    end
    
    -- Create elite decoration
    if not frameElements.elite then
        frameElements.elite = FocusFrame:CreateTexture("DragonUI_FocusElite", "OVERLAY", nil, 7)
        frameElements.elite:SetTexture(TEXTURES.BOSS)
        frameElements.elite:Hide()
    end

    -- NUEVO: Create threat numeric indicator
    if not frameElements.threatNumeric then
        local numeric = CreateFrame("Frame", "DragonUIFocusNumericalThreat", FocusFrame)
        numeric:SetFrameStrata("HIGH")
        numeric:SetFrameLevel(FocusFrame:GetFrameLevel() + 10)
        numeric:SetSize(71, 13)
        numeric:SetPoint("BOTTOM", FocusFrame, "TOP", -45, -20)  -- Posición ajustada para focus
        numeric:Hide()

        local bg = numeric:CreateTexture(nil, "ARTWORK")
        bg:SetTexture(TEXTURES.THREAT_NUMERIC)
        bg:SetTexCoord(0.927734375, 0.9970703125, 0.3125, 0.337890625)
        bg:SetAllPoints()

        numeric.text = numeric:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        numeric.text:SetPoint("CENTER",0, 1)
        numeric.text:SetFont("Fonts\\FRIZQT__.TTF", 10)
        numeric.text:SetShadowOffset(1, -1)

        frameElements.threatNumeric = numeric
    end
    
    -- Configure name background
    if FocusFrameNameBackground then
        FocusFrameNameBackground:ClearAllPoints()
        FocusFrameNameBackground:SetPoint("BOTTOMLEFT", FocusFrameHealthBar, "TOPLEFT", -2, -5)
        FocusFrameNameBackground:SetSize(135, 18)
        FocusFrameNameBackground:SetTexture(TEXTURES.NAME_BACKGROUND)
        FocusFrameNameBackground:SetDrawLayer("BORDER", 1)
        FocusFrameNameBackground:SetBlendMode("ADD")
        FocusFrameNameBackground:SetAlpha(0.9)
    end
    
    -- Configure portrait
    FocusFramePortrait:ClearAllPoints()
    FocusFramePortrait:SetSize(56, 56)
    FocusFramePortrait:SetPoint("TOPRIGHT", FocusFrame, "TOPRIGHT", -47, -15)
    FocusFramePortrait:SetDrawLayer("ARTWORK", 1)
    
    -- Configure health bar
    FocusFrameHealthBar:ClearAllPoints()
    FocusFrameHealthBar:SetSize(125, 20)
    FocusFrameHealthBar:SetPoint("RIGHT", FocusFramePortrait, "LEFT", -1, 0)
    FocusFrameHealthBar:SetFrameLevel(FocusFrame:GetFrameLevel())
    
    -- Configure power bar
    FocusFrameManaBar:ClearAllPoints()
    FocusFrameManaBar:SetSize(132, 9)
    FocusFrameManaBar:SetPoint("RIGHT", FocusFramePortrait, "LEFT", 6.5, -16.5)
    FocusFrameManaBar:SetFrameLevel(FocusFrame:GetFrameLevel())
    
    -- Configure text elements
    if FocusFrameTextureFrameName then
        FocusFrameTextureFrameName:ClearAllPoints()
        FocusFrameTextureFrameName:SetPoint("BOTTOM", FocusFrameHealthBar, "TOP", 10, 3)
        FocusFrameTextureFrameName:SetDrawLayer("OVERLAY", 2)
        
        -- NUEVO: Establecer tamaño de fuente fijo para consistencia
        local font, size, flags = FocusFrameTextureFrameName:GetFont()
        if font and flags then
            FocusFrameTextureFrameName:SetFont(font, 10, flags)  -- Tamaño fijo 11
        end
    end
    
    if FocusFrameTextureFrameLevelText then
        FocusFrameTextureFrameLevelText:ClearAllPoints()
        FocusFrameTextureFrameLevelText:SetPoint("BOTTOMRIGHT", FocusFrameHealthBar, "TOPLEFT", 18, 3)
        FocusFrameTextureFrameLevelText:SetDrawLayer("OVERLAY", 2)
        
        -- NUEVO: Establecer tamaño de fuente fijo para consistencia
        local font, size, flags = FocusFrameTextureFrameLevelText:GetFont()
        if font and flags then
            FocusFrameTextureFrameLevelText:SetFont(font, 10, flags)  -- Tamaño fijo 11
        end
    end
    
    -- Setup bar hooks
    SetupBarHooks()
    
    -- Apply configuration
    local config = GetConfig()
    
    FocusFrame:ClearAllPoints()
    FocusFrame:SetClampedToScreen(false)
    FocusFrame:SetScale(config.scale or 1)
    
    -- Always apply position from widgets
    ApplyWidgetPosition()
    
    Module.configured = true
    
    -- Critical hook: Protect against Blizzard resets
    if not Module.scaleHooked then
        -- Protect against any scale reset that Blizzard might do
        local originalSetScale = FocusFrame.SetScale
        FocusFrame.SetScale = function(self, scale)
            local config = GetConfig()
            local correctScale = config.scale or 1
            originalSetScale(self, correctScale)
        end
        Module.scaleHooked = true
    end
    
    -- ShowTest and HideTest (adapted for Focus)
    if not FocusFrame.ShowTest then
        FocusFrame.ShowTest = function(self)
            -- Show frame with player data and our custom textures
            self:Show()
            
            -- Ensure FocusFrame is in low strata so editor is on top
            self:SetFrameStrata("MEDIUM")
            self:SetFrameLevel(10) -- Low level so green frame is on top
            
            -- Ensure our custom textures are visible
            if frameElements.background then
                frameElements.background:Show()
            end
            if frameElements.border then
                frameElements.border:Show()
            end
            
            -- Player portrait 
            if FocusFramePortrait then
                SetPortraitTexture(FocusFramePortrait, "player")
            end
            
            -- Background with player color and our texture
            if FocusFrameNameBackground then
                local r, g, b = UnitSelectionColor("player")
                FocusFrameNameBackground:SetVertexColor(r, g, b, 0.8)
                FocusFrameNameBackground:Show()
            end
            
            -- Player name and level (preserve original color)
            local nameText = FocusFrameTextureFrameName
            if nameText then
                -- Save original color before changing
                if not nameText.originalColor then
                    local r, g, b, a = nameText:GetTextColor()
                    nameText.originalColor = {r, g, b, a}
                end
                nameText:SetText(UnitName("player"))
                -- Do not change color - keep original
            end
            
            local levelText = FocusFrameTextureFrameLevelText  
            if levelText then
                -- Save original color before changing
                if not levelText.originalColor then
                    local r, g, b, a = levelText:GetTextColor()
                    levelText.originalColor = {r, g, b, a}
                end
                levelText:SetText(UnitLevel("player"))
                -- Do not change color - keep original
            end
            
            -- Health bar with our class color system
            local healthBar = FocusFrameHealthBar
            if healthBar then
                local curHealth = UnitHealth("player")
                local maxHealth = UnitHealthMax("player")
                healthBar:SetMinMaxValues(0, maxHealth)
                healthBar:SetValue(curHealth)
                
                -- Apply our class color system
                local texture = healthBar:GetStatusBarTexture()
                if texture then
                    local config = GetConfig()
                    if config.classcolor then
                        -- Use status texture for class color
                        local statusTexturePath = "Interface\\AddOns\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-Target-PortraitOn-Bar-Health-Status"
                        texture:SetTexture(statusTexturePath)
                        
                        -- Apply player class color
                        local _, class = UnitClass("player")
                        local color = RAID_CLASS_COLORS[class]
                        if color then
                            texture:SetVertexColor(color.r, color.g, color.b, 1)
                        else
                            texture:SetVertexColor(1, 1, 1, 1)
                        end
                    else
                        -- Use normal texture without class color
                        local normalTexturePath = "Interface\\AddOns\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-Target-PortraitOn-Bar-Health"
                        texture:SetTexture(normalTexturePath)
                        texture:SetVertexColor(1, 1, 1, 1)
                    end
                    
                    -- Apply texture coordinates
                    texture:SetTexCoord(0, curHealth / maxHealth, 0, 1)
                end
                
                healthBar:Show()
            end
            
            -- Mana bar with our power texture system
            local manaBar = FocusFrameManaBar
            if manaBar then
                local powerType = UnitPowerType("player")
                local curMana = UnitPower("player", powerType)
                local maxMana = UnitPowerMax("player", powerType)
                manaBar:SetMinMaxValues(0, maxMana)
                manaBar:SetValue(curMana)
                
                -- Apply our custom power texture
                local texture = manaBar:GetStatusBarTexture()
                if texture then
                    local powerName = POWER_MAP[powerType] or "Mana"
                    local texturePath = TEXTURES.BAR_PREFIX .. powerName
                    texture:SetTexture(texturePath)
                    texture:SetDrawLayer("ARTWORK", 1)
                    texture:SetVertexColor(1, 1, 1, 1)
                    
                    -- Apply texture coordinates
                    if maxMana > 0 then
                        texture:SetTexCoord(0, curMana / maxMana, 0, 1)
                    end
                end
                
                manaBar:Show()
            end
            
            -- Show elite decoration if player is special (Focus doesn't have famous NPCs, but has classification)
            if frameElements.elite then
                local classification = UnitClassification("player")
                local coords = nil
                
                -- Check if player has special classification
                if classification and classification ~= "normal" then
                    coords = BOSS_COORDS[classification] or BOSS_COORDS.elite
                end
                
                if coords then
                    frameElements.elite:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
                    frameElements.elite:SetSize(coords[5], coords[6])
                    frameElements.elite:SetPoint("CENTER", FocusFramePortrait, "CENTER", coords[7], coords[8])
                    frameElements.elite:Show()
                else
                    frameElements.elite:Hide()
                end
            end
        end
        
        FocusFrame.HideTest = function(self)
            -- Restore original FocusFrame strata
            self:SetFrameStrata("LOW")
            self:SetFrameLevel(1) -- Normal level
            
            -- Restore original text colors
            local nameText = FocusFrameTextureFrameName
            if nameText and nameText.originalColor then
                nameText:SetVertexColor(nameText.originalColor[1], nameText.originalColor[2], 
                                       nameText.originalColor[3], nameText.originalColor[4])
            end
            
            local levelText = FocusFrameTextureFrameLevelText
            if levelText and levelText.originalColor then
                levelText:SetVertexColor(levelText.originalColor[1], levelText.originalColor[2], 
                                        levelText.originalColor[3], levelText.originalColor[4])
            end
            
            -- Simple: Only hide if no real focus
            if not UnitExists("focus") then
                self:Hide()
            end
        end
        
        end
        
    end
    


-- ============================================================================
-- EVENT HANDLING
-- ============================================================================

local function OnEvent(self, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name == "DragonUI" and not Module.initialized then
            Module.initialized = true
        end
        
    elseif event == "PLAYER_ENTERING_WORLD" then
        InitializeFrame()
        
        -- Configure text system here to ensure it's available
        if addon.TextSystem and not Module.textSystem and FocusFrame then
            Module.textSystem = addon.TextSystem.SetupFrameTextSystem("focus", "focus", FocusFrame, FocusFrameHealthBar,
                FocusFrameManaBar, "FocusFrame")
        end
        
        if UnitExists("focus") then
            UpdateNameBackground()
            UpdateClassification()
            if Module.textSystem then
                Module.textSystem.update()
            end
        end
        
    elseif event == "PLAYER_FOCUS_CHANGED" then
        UpdateNameBackground()
        UpdateClassification()
        UpdateThreat()
        if Module.textSystem then
            Module.textSystem.update()
        end
        
    elseif event == "UNIT_CLASSIFICATION_CHANGED" then
        local unit = ...
        if unit == "focus" then
            UpdateClassification()
        end
        
    elseif event == "UNIT_FACTION" then
        local unit = ...
        if unit == "focus" then
            UpdateNameBackground()
        end

    -- NUEVO: Eventos de threat para focus
    elseif event == "UNIT_THREAT_SITUATION_UPDATE" or event == "UNIT_THREAT_LIST_UPDATE" then
        UpdateThreat()
    
    elseif event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
        local unit = ...
        if unit == "focus" and UnitExists("focus") and Module.textSystem then
            Module.textSystem.update()
        end
    elseif event == "UNIT_POWER_UPDATE" or event == "UNIT_MAXPOWER" then
        local unit = ...
        if unit == "focus" and UnitExists("focus") then
            -- Actualizar inmediatamente la barra de poder
            UpdatePowerBar()
            if Module.textSystem then
                Module.textSystem.update()
            end
        end
    elseif event == "UNIT_DISPLAYPOWER" then
        local unit = ...
        if unit == "focus" and UnitExists("focus") then
            -- Actualización inmediata cuando cambia el tipo de poder (cambio de forma)
            updateCache.lastPowerUpdate = 0 -- Reset timer para forzar actualización
            UpdatePowerBar()
            if Module.textSystem then
                Module.textSystem.update()
            end
        end
    end
end

-- Initialize events
if not Module.eventsFrame then
    Module.eventsFrame = CreateFrame("Frame")
    Module.eventsFrame:RegisterEvent("ADDON_LOADED")
    Module.eventsFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    Module.eventsFrame:RegisterEvent("PLAYER_FOCUS_CHANGED")
    Module.eventsFrame:RegisterEvent("UNIT_CLASSIFICATION_CHANGED")
    Module.eventsFrame:RegisterEvent("UNIT_FACTION")
    -- NUEVO: Registrar eventos de threat
    Module.eventsFrame:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE")
    Module.eventsFrame:RegisterEvent("UNIT_THREAT_LIST_UPDATE")
    -- Critical events for the text system
    Module.eventsFrame:RegisterEvent("UNIT_HEALTH")
    Module.eventsFrame:RegisterEvent("UNIT_MAXHEALTH") 
    Module.eventsFrame:RegisterEvent("UNIT_POWER_UPDATE")
    Module.eventsFrame:RegisterEvent("UNIT_MAXPOWER")
    Module.eventsFrame:RegisterEvent("UNIT_DISPLAYPOWER")
    Module.eventsFrame:SetScript("OnEvent", OnEvent)
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

local function RefreshFrame()
    if not Module.configured then
        InitializeFrame()
    end
    
    -- Apply configuration immediately (including scale)
    local config = GetConfig()
    
    -- Apply scale immediately
    FocusFrame:SetScale(config.scale or 1)
    
    -- Apply position from widgets immediately
    ApplyWidgetPosition()
    
    if UnitExists("focus") then
        UpdateNameBackground()
        UpdateClassification()
        UpdateThreat()  -- NUEVO: Actualizar threat
        UpdatePowerBar() -- Actualizar barra de poder
        if Module.textSystem then
            Module.textSystem.update()
        end
    end
end

local function ResetFrame()
    local defaults = addon.defaults and addon.defaults.profile.unitframe.focus or {}
    for key, value in pairs(defaults) do
        addon:SetConfigValue("unitframe", "focus", key, value)
    end
    
    -- Reset widgets too
    if not addon.db.profile.widgets then
        addon.db.profile.widgets = {}
    end
    addon.db.profile.widgets.focus = {
        anchor = "TOPLEFT",
        posX = 250,
        posY = -170
    }
    
    -- Re-apply position using widgets system
    local config = GetConfig()
    FocusFrame:ClearAllPoints()
    FocusFrame:SetScale(config.scale or 1)
    ApplyWidgetPosition()
end

-- Export API
addon.FocusFrame = {
    Refresh = RefreshFrame,
    RefreshFocusFrame = RefreshFrame,
    Reset = ResetFrame,
    anchor = function() return Module.focusFrame end,
    ChangeFocusFrame = RefreshFrame
}

-- Legacy compatibility
addon.unitframe = addon.unitframe or {}
addon.unitframe.ChangeFocusFrame = RefreshFrame
addon.unitframe.ReApplyFocusFrame = RefreshFrame

function addon:RefreshFocusFrame()
    RefreshFrame()
end

-- ============================================================================
-- CENTRALIZED SYSTEM SUPPORT FUNCTIONS (like player.lua/target.lua)
-- ============================================================================

-- Functions required by the centralized system
function Module:LoadDefaultSettings()
    if not addon.db.profile.widgets then
        addon.db.profile.widgets = {}
    end
    addon.db.profile.widgets.focus = { 
        anchor = "TOPLEFT", 
        posX = 250, 
        posY = -170 
    }
end

function Module:UpdateWidgets()
    if not addon.db or not addon.db.profile.widgets or not addon.db.profile.widgets.focus then
        self:LoadDefaultSettings()
        return
    end
    
    ApplyWidgetPosition()
    
    local widgetOptions = addon.db.profile.widgets.focus
end