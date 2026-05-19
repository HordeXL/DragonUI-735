local addon = select(2, ...)

-- ============================================================================
-- DRAGONUI TARGET FRAME MODULE - Optimized for WoW 7.3.5
-- ============================================================================

-- Module namespace
local Module = {
    targetFrame = nil,
    textSystem = nil,
    initialized = false,
    configured = false,
    eventsFrame = nil
}

-- ============================================================================
-- UTILITY FUNCTIONS FOR CENTRALIZED SYSTEM
-- ============================================================================

--  FUNCIÓN PARA APLICAR POSICIÓN DESDE WIDGETS (COMO PLAYER.LUA)
local function IsInOrderHall()
    return OrderHallCommandBar and OrderHallCommandBar:IsShown()
end

local function ApplyWidgetPosition()
    if not Module.targetFrame then
        return
    end

    local widgetConfig = addon.db and addon.db.profile.widgets and addon.db.profile.widgets.target
    local defaultPosX = (widgetConfig and widgetConfig.posX) or 240
    local defaultPosY = (widgetConfig and widgetConfig.posY) or -10
    local savedAnchor = (widgetConfig and widgetConfig.anchor) or "TOPLEFT"
    local posX = defaultPosX
    local posY = defaultPosY

    if IsInOrderHall() and OrderHallCommandBar then
        local barHeight = OrderHallCommandBar:GetHeight() or 0
        posY = defaultPosY - barHeight
        addon:DebugInfo("TargetFrame", "职业大厅模式 - 资源条高度: %.1f, Y偏移: %.1f (默认: %.1f)", barHeight, posY, defaultPosY)
    else
        addon:DebugInfo("TargetFrame", "野外模式 - 复位到默认坐标: anchor=%s (%.1f, %.1f)", savedAnchor, posX, posY)
    end

    Module.targetFrame:ClearAllPoints()
    -- 使用保存的锚点而非硬编码"TOPLEFT"，避免拖动后锚点类型变化导致位置偏移
    Module.targetFrame:SetPoint(savedAnchor, UIParent, savedAnchor, posX, posY)

    if not InCombatLockdown() then
        TargetFrame:ClearAllPoints()
        TargetFrame:SetPoint("CENTER", Module.targetFrame, "CENTER", 20, -7)
    end
end

--  FUNCIÓN PARA VERIFICAR SI EL TARGET FRAME DEBE ESTAR VISIBLE
local function ShouldTargetFrameBeVisible()
    return UnitExists("target")
end

--  FUNCIONES DE TESTEO SIMPLIFICADAS (estilo RetailUI)
local function ShowTargetFrameTest()
    --  SISTEMA SIMPLE: Solo llamar al método ShowTest del frame
    if TargetFrame and TargetFrame.ShowTest then
        --  ASEGURAR POSICIÓN ANTES DE MOSTRAR
        ApplyWidgetPosition()
        TargetFrame:ShowTest()
    end
end

local function HideTargetFrameTest()
    --  SISTEMA SIMPLE: Solo llamar al método HideTest del frame
    if TargetFrame and TargetFrame.HideTest then
        TargetFrame:HideTest()
    end
end

-- Famous NPCs list 
local FAMOUS_NPCS = {
    -- Developer character
    ["Patufet"] = true
}

-- ============================================================================
-- CONFIGURATION & CONSTANTS
-- ============================================================================

-- Cache frequently accessed globals
local TargetFrame = _G.TargetFrame
local TargetFrameHealthBar = _G.TargetFrameHealthBar
local TargetFrameManaBar = _G.TargetFrameManaBar
local TargetFramePortrait = _G.TargetFramePortrait
local TargetFrameTextureFrameName = _G.TargetFrameTextureFrameName
local TargetFrameTextureFrameLevelText = _G.TargetFrameTextureFrameLevelText
local TargetFrameNameBackground = _G.TargetFrameNameBackground

-- Texture paths
local TEXTURES = {
    BACKGROUND = "Interface\\AddOns\\DragonUI\\Textures\\UI-HUD-UnitFrame-Target-PortraitOn-BACKGROUND",
    BORDER = "Interface\\AddOns\\DragonUI\\Textures\\UI-HUD-UnitFrame-Target-PortraitOn-BORDER",
    BAR_PREFIX = "Interface\\AddOns\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-Target-PortraitOn-Bar-",
    NAME_BACKGROUND = "Interface\\AddOns\\DragonUI\\Textures\\TargetFrame\\NameBackground",
    BOSS = "Interface\\AddOns\\DragonUI\\Textures\\uiunitframeboss2x",
    THREAT = "Interface\\AddOns\\DragonUI\\Textures\\Unitframe2x\\ui-hud-unitframe-target-portraiton-incombat-2x",
    THREAT_NUMERIC = "Interface\\AddOns\\DragonUI\\Textures\\uiunitframe"
}

-- Boss classifications
local BOSS_COORDS = {
    elite = {0.001953125, 0.314453125, 0.322265625, 0.630859375, 80, 79, 4, 1},
    rare = {0.00390625, 0.31640625, 0.64453125, 0.953125, 80, 79, 4, 1},
    rareelite = {0.001953125, 0.388671875, 0.001953125, 0.31835937, 99, 81, 13, 1}
}

-- Power types
local POWER_MAP = {
    [0] = "Mana",
    [1] = "Rage",
    [2] = "Focus",
    [3] = "Energy",
    [6] = "RunicPower"
}

-- Threat colors
local THREAT_COLORS = {{1.0, 1.0, 0.47}, -- Low
{1.0, 0.6, 0.0}, -- Medium
{1.0, 0.0, 0.0} -- High
}

-- Frame elements storage
local frameElements = {
    background = nil,
    border = nil,
    elite = nil,
    threatNumeric = nil
}

-- Cache for update throttling
local updateCache = {
    lastHealthUpdate = 0,
    lastPowerUpdate = 0,
    lastThreatUpdate = 0,
    lastFamousMessage = 0,
    lastFamousTarget = nil
}

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

local function GetConfig()
    local config = addon:GetConfigValue("unitframe", "target") or {}
    local defaults = addon.defaults and addon.defaults.profile.unitframe.target or {}
    return setmetatable(config, {
        __index = defaults
    })
end

local function SafeCall(func, ...)
    if not func then
        return
    end
    local success, result = pcall(func, ...)
    if not success then
        
    end
    return success, result
end

-- ============================================================================
-- FIX: REAPPLY ELEMENT POSITIONS
-- ============================================================================
-- Tato funkce násilně znovu aplikuje pozice všech prvků, aby přepsala
-- jakékoli změny provedené výchozím UI, zejména u speciálních jednotek.
local function ReapplyElementPositions()
    --  ASEGURAR QUE EL FRAME ESTÉ EN SU SITIO (Anclado al auxiliar)
    ApplyWidgetPosition()

    if not UnitExists("target") then return end

    -- Portrait
    if TargetFramePortrait then
        TargetFramePortrait:ClearAllPoints()
        TargetFramePortrait:SetSize(56, 56)
        TargetFramePortrait:SetPoint("TOPRIGHT", TargetFrame, "TOPRIGHT", -47, -15)
    end

    -- Health Bar
    if TargetFrameHealthBar then
        TargetFrameHealthBar:ClearAllPoints()
        TargetFrameHealthBar:SetSize(125, 20)
        TargetFrameHealthBar:SetPoint("RIGHT", TargetFramePortrait, "LEFT", -1, 0)
    end

    -- Power Bar
    if TargetFrameManaBar then
        TargetFrameManaBar:ClearAllPoints()
        TargetFrameManaBar:SetSize(132, 9)
        TargetFrameManaBar:SetPoint("RIGHT", TargetFramePortrait, "LEFT", 6.5, -16.5)
    end

    -- Name Text
    if TargetFrameTextureFrameName then
        TargetFrameTextureFrameName:ClearAllPoints()
        TargetFrameTextureFrameName:SetPoint("BOTTOM", TargetFrameHealthBar, "TOP", 10, 3)
    end

    -- Level Text
    if TargetFrameTextureFrameLevelText then
        TargetFrameTextureFrameLevelText:ClearAllPoints()
        TargetFrameTextureFrameLevelText:SetPoint("BOTTOMRIGHT", TargetFrameHealthBar, "TOPLEFT", 18, 3)
    end

    -- Name Background
    if TargetFrameNameBackground then
        TargetFrameNameBackground:ClearAllPoints()
        TargetFrameNameBackground:SetPoint("BOTTOMLEFT", TargetFrameHealthBar, "TOPLEFT", -2, -5)
    end
end

-- SOLUCIÓN ANTI-PARPADEO: Hook SetPoint del TargetFrame para interceptar movimientos no deseados
local originalTargetFrameSetPoint = TargetFrame.SetPoint
TargetFrame.SetPoint = function(self, point, relativeTo, relativePoint, x, y)
    -- SEGURO: Verificar combat lockdown antes de modificar
    if InCombatLockdown() then
        -- En combate, usar el SetPoint original sin modificaciones
        originalTargetFrameSetPoint(self, point, relativeTo, relativePoint, x, y)
        return
    end

    -- Si es un movimiento automático de Blizzard durante transiciones o cambios de escenario,
    -- aplicar nuestra posición personalizada en su lugar
    if point and relativeTo == UIParent and (point == "TOPLEFT" or point == "CENTER") then
        -- SEGURO: Usar pcall para proteger contra errores
        local success, err = pcall(ApplyWidgetPosition)
        if not success then
            -- Fallback al comportamiento original si hay error
            originalTargetFrameSetPoint(self, point, relativeTo, relativePoint, x, y)
        end
    else
        -- Llamar al SetPoint original para otros casos
        originalTargetFrameSetPoint(self, point, relativeTo, relativePoint, x, y)
    end
end


-- ============================================================================
-- CLASS COLORS
-- ============================================================================

local function UpdateTargetHealthBarColor()
    if not UnitExists("target") or not TargetFrameHealthBar then
        return
    end

    local config = GetConfig()
    local texture = TargetFrameHealthBar:GetStatusBarTexture()
    
    if not texture then
        return
    end

    if config.classcolor and UnitIsPlayer("target") then
        --  USAR TEXTURA BLANCA (STATUS) PARA CLASS COLOR
        local statusTexturePath = "Interface\\AddOns\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-Target-PortraitOn-Bar-Health-Status"
        if texture:GetTexture() ~= statusTexturePath then
            texture:SetTexture(statusTexturePath)
        end
        
        --  APLICAR COLOR DE CLASE
        local _, class = UnitClass("target")
        local color = RAID_CLASS_COLORS[class]
        if color then
            texture:SetVertexColor(color.r, color.g, color.b, 1)
        else
            texture:SetVertexColor(1, 1, 1, 1)
        end
    else
        --  USAR TEXTURA NORMAL (COLORED) SIN CLASS COLOR
        local normalTexturePath = "Interface\\AddOns\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-Target-PortraitOn-Bar-Health"
        if texture:GetTexture() ~= normalTexturePath then
            texture:SetTexture(normalTexturePath)
        end
        
        --  COLOR BLANCO (la textura ya tiene color)
        texture:SetVertexColor(1, 1, 1, 1)
    end
end
-- ============================================================================
-- BAR MANAGEMENT (Optimized)
-- ============================================================================

local function SetupBarHooks()
    -- Setup health bar hooks ONCE
    if not TargetFrameHealthBar.DragonUI_Setup then
        local healthTexture = TargetFrameHealthBar:GetStatusBarTexture()
        if healthTexture then
            healthTexture:SetDrawLayer("ARTWORK", 1)
        end

        --  HOOK PRINCIPAL: Actualizar color cuando cambie el valor
        hooksecurefunc(TargetFrameHealthBar, "SetValue", function(self)
            if not UnitExists("target") then
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

            --  APLICAR CLASS COLOR SI ESTÁ HABILITADO
            UpdateTargetHealthBarColor()

            -- Update texture coords
            local min, max = self:GetMinMaxValues()
            local current = self:GetValue()
            if max > 0 and current then
                texture:SetTexCoord(0, current / max, 0, 1)
            end
        end)

        TargetFrameHealthBar.DragonUI_Setup = true
    end

    -- Setup power bar hooks ONCE (sin cambios)
    if not TargetFrameManaBar.DragonUI_Setup then
        local powerTexture = TargetFrameManaBar:GetStatusBarTexture()
        if powerTexture then
            powerTexture:SetDrawLayer("ARTWORK", 1)
        end

        local origSetColor = TargetFrameManaBar.SetStatusBarColor
        TargetFrameManaBar.SetStatusBarColor = function(self, r, g, b, a)
            origSetColor(self, 1, 1, 1, 1)
        end

        hooksecurefunc(TargetFrameManaBar, "SetValue", function(self)
            if not UnitExists("target") then
                return
            end

            -- ELIMINAR THROTTLING: Actualización inmediata para formas de druida
            -- local now = GetTime()
            -- if now - updateCache.lastPowerUpdate < 0.05 then
            --     return
            -- end
            -- updateCache.lastPowerUpdate = now

            local texture = self:GetStatusBarTexture()
            if not texture then
                return
            end

            -- Update texture path based on power type - INMEDIATO
            local powerType = UnitPowerType("target")
            local powerName = POWER_MAP[powerType] or "Mana"
            local texturePath = TEXTURES.BAR_PREFIX .. powerName

            -- FORZAR TEXTURA INMEDIATAMENTE (como en focus.lua)
            texture:SetTexture(texturePath)
            texture:SetDrawLayer("ARTWORK", 1)
            
            -- FORZAR COLOR INMEDIATAMENTE
            texture:SetVertexColor(1,1,1)
            TargetFrameManaBar:SetStatusBarColor(1,1,1)

            -- Update texture coords
            local min, max = self:GetMinMaxValues()
            local current = self:GetValue()
            if max > 0 and current then
                texture:SetTexCoord(0, current / max, 0, 1)
            end
        end)

        TargetFrameManaBar.DragonUI_Setup = true
    end
end

-- ============================================================================
-- THREAT SYSTEM (Optimized)
-- ============================================================================

local function UpdateThreat()
    if not UnitExists("target") then
        if frameElements.threatNumeric then
            frameElements.threatNumeric:Hide()
        end
        return
    end

    local status = UnitThreatSituation("player", "target")
    local level = status and math.min(status, 3) or 0

    if level > 0 then
        -- Solo numerical threat
        local _, _, _, pct = UnitDetailedThreatSituation("player", "target")

        if frameElements.threatNumeric and pct and pct > 0 then
            local displayPct = math.floor(math.min(100, math.max(0, pct)))
            frameElements.threatNumeric.text:SetText(displayPct .. "%")
            -- Color fijo o basado en level
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
-- CLASSIFICATION SYSTEM (Optimized)
-- ============================================================================

local function UpdateClassification()
    if not UnitExists("target") or not frameElements.elite then
        if frameElements.elite then
            frameElements.elite:Hide()
        end
        return
    end

    local classification = UnitClassification("target")
    local name = UnitName("target")
    local coords = nil

    --  CLASIFICACIONES OFICIALES DEL JUEGO
    if classification == "worldboss" then
        coords = BOSS_COORDS.elite
    elseif classification == "elite" then
        coords = BOSS_COORDS.elite
    elseif classification == "rareelite" then
        coords = BOSS_COORDS.rareelite
    elseif classification == "rare" then
        coords = BOSS_COORDS.rare
    else
        --  FALLBACK 1: Famous NPCs (Developer & Special Characters)
        if name and FAMOUS_NPCS[name] then
            coords = BOSS_COORDS.elite

            --  THROTTLE: Solo mostrar mensaje una vez por target + cooldown
            local now = GetTime()
            if updateCache.lastFamousTarget ~= name or (now - updateCache.lastFamousMessage) > 5 then
                
                
                updateCache.lastFamousMessage = now
                updateCache.lastFamousTarget = name
            end
        else
            --  FALLBACK 2: Level -1 (Skull = Boss real)
            local level = UnitLevel("target")
            if level == -1 then
                coords = BOSS_COORDS.elite
            end
        end
    end

    if coords then
        frameElements.elite:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
        frameElements.elite:SetSize(coords[5], coords[6])
        frameElements.elite:SetPoint("CENTER", TargetFramePortrait, "CENTER", coords[7], coords[8])
        frameElements.elite:Show()
    else
        frameElements.elite:Hide()
    end

end

-- ============================================================================
-- NAME BACKGROUND (Optimized)
-- ============================================================================

local function UpdateNameBackground()
    if not TargetFrameNameBackground then
        return
    end

    if not UnitExists("target") then
        TargetFrameNameBackground:Hide()
        return
    end

    local r, g, b
    
    -- LÓGICA CORRECTA: Verificar tap-denied PRIMERO
    -- Fix: UnitIsTapped is not available in 7.3.5, use UnitIsTapDenied instead
    if UnitIsTapDenied and UnitIsTapDenied("target") then
        -- Target está tapped por otro jugador/grupo = GRIS
        r, g, b = 0.5, 0.5, 0.5
    else
        -- Target no está tap-denied = usar color normal de facción
        r, g, b = UnitSelectionColor("target")
    end
    
    TargetFrameNameBackground:SetVertexColor(r, g, b)
    TargetFrameNameBackground:Show()
end

-- ============================================================================
-- ONE-TIME INITIALIZATION
-- ============================================================================

local function InitializeFrame()
    if Module.configured then
        return
    end

    --  CREAR OVERLAY FRAME PARA EL SISTEMA CENTRALIZADO
    if not Module.targetFrame then
        Module.targetFrame = addon.CreateUIFrame(200, 75, "TargetFrame")
        
        --  REGISTRO AUTOMÁTICO EN EL SISTEMA CENTRALIZADO
        addon:RegisterEditableFrame({
            name = "target",
            frame = Module.targetFrame,
            blizzardFrame = TargetFrame,
            configPath = {"widgets", "target"},
            hasTarget = ShouldTargetFrameBeVisible, -- Solo visible cuando hay target
            showTest = ShowTargetFrameTest,         --  NUEVO: Mostrar frame fake
            hideTest = HideTargetFrameTest,         --  NUEVO: Ocultar frame fake
            onHide = function()
                ApplyWidgetPosition() -- Aplicar nueva configuración al salir del editor
            end,
            module = Module
        })
        
        
    end

    -- Hide Blizzard elements ONCE
    local toHide = {TargetFrameTextureFrameTexture, TargetFrameBackground, TargetFrameFlash,
                    _G.TargetFrameNumericalThreat, TargetFrame.threatNumericIndicator, TargetFrame.threatIndicator}

    for _, element in ipairs(toHide) do
        if element then
            element:SetAlpha(0)
            element:Hide()
        end
    end

    -- Create background texture ONCE
    if not frameElements.background then
        frameElements.background = TargetFrame:CreateTexture("DragonUI_TargetBG", "BACKGROUND", nil, -7)
        frameElements.background:SetTexture(TEXTURES.BACKGROUND)
        frameElements.background:SetTexCoord(0, 1, 0, 1)
        frameElements.background:SetSize(255, 130)
        frameElements.background:SetPoint("TOPLEFT", TargetFrame, "TOPLEFT", 0, -7)
    end

    -- Create border texture ONCE
    if not frameElements.border then
        frameElements.border = TargetFrame:CreateTexture("DragonUI_TargetBorder", "OVERLAY", nil, 5)
        frameElements.border:SetTexture(TEXTURES.BORDER)
        frameElements.border:SetTexCoord(0, 1, 0, 1)
        frameElements.border:SetSize(255, 130)
        frameElements.border:SetPoint("TOPLEFT", TargetFrame, "TOPLEFT", 0, -7)
    end

    local function TargetFrame_CheckClassification_Hook(self, forceNormalTexture)
        -- Después de que Blizzard haga su lógica, aplicamos la nuestra
        local threatFlash = _G.TargetFrameFlash
        if threatFlash then
            threatFlash:SetTexture(TEXTURES.THREAT)
            threatFlash:SetTexCoord(0, 376 / 512, 0, 134 / 256)
            threatFlash:SetBlendMode("ADD")
            threatFlash:SetAlpha(0.7)
            -- Fix: SetDrawLayer sublevel must be between -8 and 7 in 7.3.5
            threatFlash:SetDrawLayer("ARTWORK", 7)
            threatFlash:ClearAllPoints()
            threatFlash:SetPoint("BOTTOMLEFT", TargetFrame, "BOTTOMLEFT", 2, 25)
            threatFlash:SetSize(188, 67)
        end
    end
    -- Hook la función que resetea el threat indicator
    if not Module.threatHooked then
        hooksecurefunc("TargetFrame_CheckClassification", TargetFrame_CheckClassification_Hook)
        Module.threatHooked = true
    end

    -- Create elite decoration ONCE
    if not frameElements.elite then
        frameElements.elite = TargetFrame:CreateTexture("DragonUI_TargetElite", "OVERLAY", nil, 7)
        frameElements.elite:SetTexture(TEXTURES.BOSS)
        frameElements.elite:Hide()
    end

    -- Configure name background ONCE (Size, Texture, etc. Position is handled by ReapplyElementPositions)
    if TargetFrameNameBackground then
        TargetFrameNameBackground:SetSize(135, 18)
        TargetFrameNameBackground:SetTexture(TEXTURES.NAME_BACKGROUND)
        TargetFrameNameBackground:SetDrawLayer("BORDER", 1)
        TargetFrameNameBackground:SetBlendMode("ADD")
    end
    
    -- Set FrameLevels for bars
    TargetFrameHealthBar:SetFrameLevel(TargetFrame:GetFrameLevel())
    TargetFrameManaBar:SetFrameLevel(TargetFrame:GetFrameLevel())
    
    -- Set DrawLayers for texts and portrait
    TargetFramePortrait:SetDrawLayer("ARTWORK", 1)
    if TargetFrameTextureFrameName then
        TargetFrameTextureFrameName:SetDrawLayer("OVERLAY", 2)
    end
    if TargetFrameTextureFrameLevelText then
        TargetFrameTextureFrameLevelText:SetDrawLayer("OVERLAY", 2)
    end

    -- Apply initial positions for all elements
    TargetFrame:SetMovable(true) -- Permitir movimiento para que SetPoint funcione mejor
    ApplyWidgetPosition()
    ReapplyElementPositions()

    -- Setup bar hooks ONCE
    SetupBarHooks()

    if not frameElements.threatNumeric then
        local numeric = CreateFrame("Frame", "DragonUITargetNumericalThreat", TargetFrame)
        numeric:SetFrameStrata("HIGH")
        numeric:SetFrameLevel(TargetFrame:GetFrameLevel() + 10)
        numeric:SetSize(71, 13)
        numeric:SetPoint("BOTTOM", TargetFrame, "TOP", -45, -20)
        numeric:Hide()

        local bg = numeric:CreateTexture(nil, "ARTWORK")
        bg:SetTexture(TEXTURES.THREAT_NUMERIC)
        bg:SetTexCoord(0.927734375, 0.9970703125, 0.3125, 0.337890625)
        bg:SetAllPoints()

        numeric.text = numeric:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        numeric.text:SetPoint("CENTER")
        numeric.text:SetFont("Fonts\\ARKai_T.ttf", 10)
        numeric.text:SetShadowOffset(1, -1)

        frameElements.threatNumeric = numeric
    end

    -- Apply configuration
    local config = GetConfig()

    TargetFrame:ClearAllPoints()
    TargetFrame:SetClampedToScreen(false)
    TargetFrame:SetScale(config.scale or 1)

    --  APLICAR POSICIÓN DESDE WIDGETS SIEMPRE
    ApplyWidgetPosition()

    Module.configured = true
    --  HOOK CRÍTICO: Proteger contra resets de Blizzard (SIN C_Timer)
    if not Module.classificationHooked then
        -- Hook la función que Blizzard usa para cambiar clasificaciones
        if _G.TargetFrame_CheckClassification then
            hooksecurefunc("TargetFrame_CheckClassification", function()
                --  SIN C_Timer - Usar frame con OnUpdate para delay mínimo
		if UnitExists("target") then
                    local delayFrame = CreateFrame("Frame")
                    local elapsed = 0
                    delayFrame:SetScript("OnUpdate", function(self, dt)
                        elapsed = elapsed + dt
                        if elapsed >= 0.1 then -- 100ms delay
		if UnitExists("target") then
                                ApplyWidgetPosition() -- Forzar re-anclaje
                                UpdateClassification()
                            end
                            delayFrame:SetScript("OnUpdate", nil)
                            delayFrame = nil
                        end
                    end)
                end
            end)
        end

        -- Hook para actualizaciones de modelo/forma
        if _G.TargetFrame_Update then
            hooksecurefunc("TargetFrame_Update", function()
		if UnitExists("target") then
                    ApplyWidgetPosition() -- Forzar re-anclaje
                    UpdateClassification()
                end
            end)
        end

        Module.classificationHooked = true
        
    end

    --  MÉTODOS ShowTest Y HideTest EXACTAMENTE COMO RETAILUI
    if not TargetFrame.ShowTest then
        TargetFrame.ShowTest = function(self)
            --  MOSTRAR FRAME CON DATOS DEL PLAYER Y NUESTRAS TEXTURAS PERSONALIZADAS
            self:Show()
            
            --  ASEGURAR QUE EL TARGETFRAME ESTÉ EN STRATA BAJO PARA QUE EL EDITOR ESTÉ ENCIMA
            self:SetFrameStrata("MEDIUM")
            self:SetFrameLevel(10) -- Nivel bajo para que el frame verde esté encima
            
            --  ASEGURAR QUE NUESTRAS TEXTURAS PERSONALIZADAS ESTÉN VISIBLES
            if frameElements.background then
                frameElements.background:Show()
            end
            if frameElements.border then
                frameElements.border:Show()
            end
            
            --  PORTRAIT DEL PLAYER (como RetailUI)
            if TargetFramePortrait then
                SetPortraitTexture(TargetFramePortrait, "player")
            end
            
            --  BACKGROUND CON COLOR DEL PLAYER Y NUESTRA TEXTURA
            if TargetFrameNameBackground then
                local r, g, b = UnitSelectionColor("player")
                TargetFrameNameBackground:SetVertexColor(r, g, b)
                TargetFrameNameBackground:Show()
            end
            
            --  NOMBRE Y NIVEL DEL PLAYER (conservar color original)
            local nameText = TargetFrameTextureFrameName
            if nameText then
                --  GUARDAR COLOR ORIGINAL ANTES DE CAMBIAR
                if not nameText.originalColor then
                    local r, g, b, a = nameText:GetTextColor()
                    nameText.originalColor = {r, g, b, a}
                end
                nameText:SetText(UnitName("player"))
                --  NO CAMBIAR COLOR - mantener el original
            end
            
            local levelText = TargetFrameTextureFrameLevelText  
            if levelText then
                --  GUARDAR COLOR ORIGINAL ANTES DE CAMBIAR
                if not levelText.originalColor then
                    local r, g, b, a = levelText:GetTextColor()
                    levelText.originalColor = {r, g, b, a}
                end
                levelText:SetText(UnitLevel("player"))
                --  NO CAMBIAR COLOR - mantener el original
            end
            
            --  HEALTH BAR CON NUESTRO SISTEMA DE CLASS COLOR
            local healthBar = TargetFrameHealthBar
            if healthBar then
                local curHealth = UnitHealth("player")
                local maxHealth = UnitHealthMax("player")
                healthBar:SetMinMaxValues(0, maxHealth)
                healthBar:SetValue(curHealth)
                
                --  APLICAR NUESTRO SISTEMA DE CLASS COLOR
                local texture = healthBar:GetStatusBarTexture()
                if texture then
                    local config = GetConfig()
                    if config.classcolor then
                        --  USAR TEXTURA STATUS PARA CLASS COLOR
                        local statusTexturePath = "Interface\\AddOns\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-Target-PortraitOn-Bar-Health-Status"
                        texture:SetTexture(statusTexturePath)
                        
                        --  APLICAR COLOR DE CLASE DEL PLAYER
                        local _, class = UnitClass("player")
                        local color = RAID_CLASS_COLORS[class]
                        if color then
                            texture:SetVertexColor(color.r, color.g, color.b, 1)
                        else
                            texture:SetVertexColor(1, 1, 1, 1)
                        end
                    else
                        --  USAR TEXTURA NORMAL SIN CLASS COLOR
                        local normalTexturePath = "Interface\\AddOns\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-Target-PortraitOn-Bar-Health"
                        texture:SetTexture(normalTexturePath)
                        texture:SetVertexColor(1, 1, 1, 1)
                    end
                    
                    --  APLICAR COORDS DE TEXTURA
                    texture:SetTexCoord(0, curHealth / maxHealth, 0, 1)
                end
                
                healthBar:Show()
            end
            
            --  MANA BAR CON NUESTRO SISTEMA DE TEXTURAS DE PODER
            local manaBar = TargetFrameManaBar
            if manaBar then
                local powerType = UnitPowerType("player")
                local curMana = UnitPower("player", powerType)
                local maxMana = UnitPowerMax("player", powerType)
                manaBar:SetMinMaxValues(0, maxMana)
                manaBar:SetValue(curMana)
                
                --  APLICAR NUESTRA TEXTURA DE PODER PERSONALIZADA
                local texture = manaBar:GetStatusBarTexture()
                if texture then
                    local powerName = POWER_MAP[powerType] or "Mana"
                    local texturePath = TEXTURES.BAR_PREFIX .. powerName
                    texture:SetTexture(texturePath)
                    texture:SetDrawLayer("ARTWORK", 1)
                    texture:SetVertexColor(1, 1, 1, 1)
                    
                    --  APLICAR COORDS DE TEXTURA
                    if maxMana > 0 then
                        texture:SetTexCoord(0, curMana / maxMana, 0, 1)
                    end
                end
                
                manaBar:Show()
            end
            
            --  MOSTRAR DECORACIÓN ELITE SI EL PLAYER ES ESPECIAL
            if frameElements.elite then
                local classification = UnitClassification("player")
                local name = UnitName("player")
                local coords = nil
                
                --  VERIFICAR SI EL PLAYER ES FAMOSO O TIENE CLASIFICACIÓN ESPECIAL
                if name and FAMOUS_NPCS[name] then
                    coords = BOSS_COORDS.elite
                elseif classification and classification ~= "normal" then
                    coords = BOSS_COORDS[classification] or BOSS_COORDS.elite
                end
                
                if coords then
                    frameElements.elite:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
                    frameElements.elite:SetSize(coords[5], coords[6])
                    frameElements.elite:SetPoint("CENTER", TargetFramePortrait, "CENTER", coords[7], coords[8])
                    frameElements.elite:Show()
                else
                    frameElements.elite:Hide()
                end
            end
            
            --  OCULTAR THREAT INDICATORS (no aplican en fake frame)
            if frameElements.threatNumeric then
                frameElements.threatNumeric:Hide()
            end
        end
        
        TargetFrame.HideTest = function(self)
            --  RESTAURAR STRATA ORIGINAL DEL TARGETFRAME
            self:SetFrameStrata("LOW")
            self:SetFrameLevel(1) -- Nivel normal
            
            --  RESTAURAR COLORES ORIGINALES DE LOS TEXTOS
            local nameText = TargetFrameTextureFrameName
            if nameText and nameText.originalColor then
                nameText:SetVertexColor(nameText.originalColor[1], nameText.originalColor[2], 
                                       nameText.originalColor[3], nameText.originalColor[4])
            end
            
            local levelText = TargetFrameTextureFrameLevelText
            if levelText and levelText.originalColor then
                levelText:SetVertexColor(levelText.originalColor[1], levelText.originalColor[2], 
                                        levelText.originalColor[3], levelText.originalColor[4])
            end
            
            --  SIMPLE: Solo ocultar si no hay target real
            if not UnitExists("target") then
                self:Hide()
            end
        end
        
        
    end
end


-- ============================================================================
-- EVENT HANDLING (Simplified)
-- ============================================================================

local function OnEvent(self, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name == "DragonUI" and not Module.initialized then
            Module.initialized = true
        end

    elseif event == "PLAYER_ENTERING_WORLD" then
        InitializeFrame()
        
        --  CONFIGURAR TEXT SYSTEM AQUÍ PARA ASEGURAR QUE ESTÉ DISPONIBLE
        if addon.TextSystem and not Module.textSystem then
            Module.textSystem = addon.TextSystem.SetupFrameTextSystem("target", "target", TargetFrame, TargetFrameHealthBar,
                TargetFrameManaBar, "TargetFrame")
            
        end
        -- 场景切换后始终重定位锚点帧（Blizzard 可能重置了位置）
        ReapplyElementPositions()
        UpdateNameBackground()
        UpdateClassification()
        UpdateThreat()
        if Module.textSystem then
            Module.textSystem.update()
        end

    elseif event == "PLAYER_TARGET_CHANGED" then
		if UnitExists("target") then
            -- FIX: Forcefully re-apply positions to override Blizzard's repositioning.
            ApplyWidgetPosition()
            ReapplyElementPositions()
        end
        UpdateNameBackground()
        UpdateClassification()
        UpdateThreat()
        UpdateTargetHealthBarColor()
        if Module.textSystem then
            Module.textSystem.update()
        end

    elseif event == "UNIT_DISPLAYPOWER" or event == "UNIT_MODEL_CHANGED" then
    local unit = ...
    if unit == "target" and UnitExists("target") then
        UpdateClassification()
        UpdateTargetHealthBarColor() --  ACTUALIZAR COLOR TAMBIÉN
        if Module.textSystem then
            Module.textSystem.update()
        end
    end

    elseif event == "UNIT_CLASSIFICATION_CHANGED" then
        local unit = ...
        if unit == "target" then
            UpdateClassification()
        end

    elseif event == "UNIT_THREAT_SITUATION_UPDATE" or event == "UNIT_THREAT_LIST_UPDATE" then
        UpdateThreat()

    elseif event == "UNIT_FACTION" then
        local unit = ...
        if unit == "target" then
            UpdateNameBackground()
        end
    elseif event == "UNIT_MODEL_CHANGED" or event == "UNIT_DISPLAYPOWER" or event == "UNIT_LEVEL" or event ==
        "UNIT_NAME_UPDATE" then
        local unit = ...
        if unit == "target" and UnitExists("target") then
            --  SIN C_Timer - Actualización directa
            UpdateClassification()
        end
    
    elseif event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" or event == "UNIT_POWER_UPDATE" or event == "UNIT_MAXPOWER" then
        local unit = ...
        if unit == "target" and UnitExists("target") and Module.textSystem then
            Module.textSystem.update()
        end

    elseif event == "PLAYER_REGEN_ENABLED" then
        -- 战斗结束后重新定位 Blizzard TargetFrame（战斗中无法修改）
        if Module.configured then
            ApplyWidgetPosition()
		if UnitExists("target") then
                ReapplyElementPositions()
            end
        end

    elseif event == "ZONE_CHANGED_NEW_AREA" then
        -- 进入/离开职业大厅时切换位置
        C_Timer.After(0.5, function()
            if Module.configured and not InCombatLockdown() then
                ApplyWidgetPosition()
            end
        end)
    end

end

-- Initialize events
if not Module.eventsFrame then
    Module.eventsFrame = CreateFrame("Frame")
    Module.eventsFrame:RegisterEvent("ADDON_LOADED")
    Module.eventsFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    Module.eventsFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    Module.eventsFrame:RegisterEvent("UNIT_CLASSIFICATION_CHANGED")
    Module.eventsFrame:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE")
    Module.eventsFrame:RegisterEvent("UNIT_THREAT_LIST_UPDATE")
    Module.eventsFrame:RegisterEvent("UNIT_FACTION")
    Module.eventsFrame:RegisterEvent("UNIT_MODEL_CHANGED")
    Module.eventsFrame:RegisterEvent("UNIT_DISPLAYPOWER")
    Module.eventsFrame:RegisterEvent("UNIT_LEVEL")
    Module.eventsFrame:RegisterEvent("UNIT_NAME_UPDATE")
    Module.eventsFrame:RegisterEvent("UNIT_PORTRAIT_UPDATE")
    --  EVENTO PARA REAPLICAR POSICIÓN AL SALIR DE COMBATE
    Module.eventsFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    --  EVENTO PARA DETECTAR ENTRADA/SALIDA DE SALA DE ÓRDENES
    Module.eventsFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    --  EVENTOS CRÍTICOS PARA EL TEXT SYSTEM
    Module.eventsFrame:RegisterEvent("UNIT_HEALTH")
    Module.eventsFrame:RegisterEvent("UNIT_MAXHEALTH") 
    Module.eventsFrame:RegisterEvent("UNIT_POWER_UPDATE")
    Module.eventsFrame:RegisterEvent("UNIT_MAXPOWER")
    Module.eventsFrame:SetScript("OnEvent", OnEvent)
end

local function UpdateTargetHealthBarColorPublic()
		if UnitExists("target") then
        UpdateTargetHealthBarColor()
    end
end

-- ============================================================================
-- PUBLIC API (Simplified)
-- ============================================================================

local function RefreshFrame()
    if not Module.configured then
        InitializeFrame()
    end

    --  APLICAR CONFIGURACIÓN INMEDIATAMENTE (incluyendo scale)
    local config = GetConfig()
    
    --  APLICAR SCALE INMEDIATAMENTE
    TargetFrame:SetScale(config.scale or 1)
    
    --  APLICAR POSICIÓN DESDE WIDGETS INMEDIATAMENTE
    ApplyWidgetPosition()

    -- Only update dynamic content
		if UnitExists("target") then
        ReapplyElementPositions() -- Ensure correct positions on refresh
        UpdateNameBackground()
        UpdateClassification()
        UpdateThreat()
        UpdateTargetHealthBarColor() --  ASEGURAR CLASS COLOR
        if Module.textSystem then
            Module.textSystem.update()
        end
    end
end

local function ResetFrame()
    local defaults = addon.defaults and addon.defaults.profile.unitframe.target or {}
    for key, value in pairs(defaults) do
        addon:SetConfigValue("unitframe", "target", key, value)
    end

    --  RESETEAR WIDGETS TAMBIÉN
    if not addon.db.profile.widgets then
        addon.db.profile.widgets = {}
    end
    addon.db.profile.widgets.target = {
        anchor = "TOPLEFT",
        posX = 240,
        posY = -10
    }

    -- Re-apply position using widgets system
    local config = GetConfig()
    TargetFrame:ClearAllPoints()
    TargetFrame:SetScale(config.scale or 1)
    ApplyWidgetPosition()
    
    
end

-- Export API
addon.TargetFrame = {
    Refresh = RefreshFrame,
    RefreshTargetFrame = RefreshFrame,
    Reset = ResetFrame,
    anchor = function()
        return Module.targetFrame
    end,
    ChangeTargetFrame = RefreshFrame,
    UpdateTargetHealthBarColor = UpdateTargetHealthBarColorPublic  --  NUEVA FUNCIÓN PÚBLICA
}

-- Legacy compatibility
addon.unitframe = addon.unitframe or {}
addon.unitframe.ChangeTargetFrame = RefreshFrame
addon.unitframe.ReApplyTargetFrame = RefreshFrame

function addon:RefreshTargetFrame()
    RefreshFrame()
end

-- ============================================================================
-- CENTRALIZED SYSTEM SUPPORT FUNCTIONS (like player.lua)
-- ============================================================================

--  FUNCIONES REQUERIDAS POR EL SISTEMA CENTRALIZADO
function Module:LoadDefaultSettings()
    if not addon.db.profile.widgets then
        addon.db.profile.widgets = {}
    end
    addon.db.profile.widgets.target = { 
        anchor = "TOPLEFT", 
        posX = 240, 
        posY = -10 
    }
end

function Module:UpdateWidgets()
    if not addon.db or not addon.db.profile.widgets or not addon.db.profile.widgets.target then
        
        self:LoadDefaultSettings()
        return
    end
    
    ApplyWidgetPosition()
    
    local widgetOptions = addon.db.profile.widgets.target
end



--  HOOK AUTOMÁTICO PARA CLASS COLOR (compatible con Ace3)
local function SetupTargetClassColorHooks()
    if not _G.DragonUI_TargetHealthHookSetup then
        --  HOOK cuando Blizzard actualiza la health bar
        hooksecurefunc("UnitFrameHealthBar_Update", function(statusbar, unit)
            if statusbar == TargetFrameHealthBar and unit == "target" then
                UpdateTargetHealthBarColor()
            end
        end)
        
        --  HOOK cuando cambia el target
        hooksecurefunc("TargetFrame_Update", function()
		if UnitExists("target") then
                UpdateTargetHealthBarColor()
            end
        end)
        
        _G.DragonUI_TargetHealthHookSetup = true
        
    end
end

--  INICIALIZAR EL HOOK
SetupTargetClassColorHooks()
