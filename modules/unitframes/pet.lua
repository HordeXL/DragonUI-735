-- ===============================================================
-- DRAGONUI PET FRAME MODULE - OPTIMIZED WITH TEXT SYSTEM
-- ===============================================================
local addon = select(2, ...)
local PetFrameModule = {}
addon.PetFrameModule = PetFrameModule

-- ===============================================================
-- LOCALIZED API REFERENCES
-- ===============================================================
local _G = _G
local CreateFrame = CreateFrame
local UIParent = UIParent
local UnitExists = UnitExists
local UnitPowerType = UnitPowerType
local hooksecurefunc = hooksecurefunc
local PlayerFrame = _G.PlayerFrame

-- ===============================================================
-- MODULE CONSTANTS
-- ===============================================================
local TEXTURE_PATH = 'Interface\\Addons\\DragonUI\\Textures\\'
local UNITFRAME_PATH = TEXTURE_PATH .. 'Unitframe\\'
local ATLAS_TEXTURE = TEXTURE_PATH .. 'uiunitframe'
local TOT_BASE = 'UI-HUD-UnitFrame-TargetofTarget-PortraitOn-'

local POWER_TEXTURES = {
    MANA = UNITFRAME_PATH .. TOT_BASE .. 'Bar-Mana',
    FOCUS = UNITFRAME_PATH .. TOT_BASE .. 'Bar-Focus',
    RAGE = UNITFRAME_PATH .. TOT_BASE .. 'Bar-Rage',
    ENERGY = UNITFRAME_PATH .. TOT_BASE .. 'Bar-Energy',
    RUNIC_POWER = UNITFRAME_PATH .. TOT_BASE .. 'Bar-RunicPower'
}

local COMBAT_TEX_COORDS = {0.3095703125, 0.4208984375, 0.3125, 0.404296875}

-- ===============================================================
-- ANIMACIONES COMBAT PULSE
-- ===============================================================

--  CONFIGURACIÓN PARA PULSO DE COLOR
local COMBAT_PULSE_SETTINGS = {
    speed = 9,              -- Velocidad del latido
    minIntensity = 0.3,     -- Intensidad mínima del rojo (0.4 = rojo oscuro)
    maxIntensity = 0.7,     -- Intensidad máxima del rojo (1.0 = rojo brillante)
    enabled = true          -- Activar/desactivar animación
}

--  VARIABLE DE ESTADO
local combatPulseTimer = 0


-- ===============================================================
-- NUEVA FUNCIÓN DE ANIMACIÓN CON CAMBIO DE COLOR
-- ===============================================================
local function AnimatePetCombatPulse(elapsed)
    if not COMBAT_PULSE_SETTINGS.enabled then
        return
    end
    
    local texture = _G.PetAttackModeTexture
    if not texture or not texture:IsVisible() then
        return
    end
    
    -- Incrementar timer
    combatPulseTimer = combatPulseTimer + (elapsed * COMBAT_PULSE_SETTINGS.speed)
    
    -- Calcular intensidad del rojo usando función seno
    local intensity = COMBAT_PULSE_SETTINGS.minIntensity + 
                     (COMBAT_PULSE_SETTINGS.maxIntensity - COMBAT_PULSE_SETTINGS.minIntensity) * 
                     (math.sin(combatPulseTimer) * 0.5 + 0.5)
    
    --  CAMBIAR COLOR EN LUGAR DE ALPHA
    texture:SetVertexColor(intensity, 0.0, 0.0, 1.0)
end

-- ===============================================================
-- MODULE STATE
-- ===============================================================
local moduleState = {
    frame = {},
    hooks = {},
    textSystem = nil
}

-- ===============================================================
-- UTILITY FUNCTIONS
-- ===============================================================
local function noop() end
-- Oculta de forma persistente los textos vanilla del PetFrame (vida/poder)
local function HideBlizzardPetTexts()
    local petTexts = {
        _G.PetFrameHealthBar and _G.PetFrameHealthBar.TextString,
        _G.PetFrameManaBar and _G.PetFrameManaBar.TextString,
        _G.PetFrameHealthBarText,
        _G.PetFrameManaBarText
    }
    for _, t in pairs(petTexts) do
        if t and not t.DragonUIHidden then
            t:SetAlpha(0)
            t.DragonUIShow = t.Show
            t.Show = function(self)
                self:SetAlpha(0)
                -- opcional: no llamar al Show original para evitar parpadeos
            end
            t:Hide()
            t.DragonUIHidden = true
        end
    end
end

-- ===============================================================
-- FRAME POSITIONING
-- ===============================================================
local function ApplyFramePositioning()
    local config = addon.db and addon.db.profile.unitframe.pet
    if not config or not PetFrame then return end
    
    PetFrame:SetScale(config.scale or 1.0)
    
    --  PRIORIDAD: Usar anchor frame si existe (sistema centralizado)
    if PetFrameModule.anchor then
        PetFrame:ClearAllPoints()
        PetFrame:SetPoint("CENTER", PetFrameModule.anchor, "CENTER", 0, 0)
        
    elseif config.override then
        --  FALLBACK: Sistema legacy de configuración manual
        PetFrame:ClearAllPoints()
        local anchor = config.anchorFrame and _G[config.anchorFrame] or UIParent
        PetFrame:SetPoint(
            config.anchor or "TOPRIGHT",
            anchor,
            config.anchorParent or "BOTTOMRIGHT",
            config.x or 0,
            config.y or 0
        )
        PetFrame:SetMovable(true)
        PetFrame:EnableMouse(true)

    else
        -- 相对玩家框体定位：宠物框体左上角对齐玩家框体右上角，带小偏移
        PetFrame:ClearAllPoints()
        PetFrame:SetPoint("TOPLEFT", PlayerFrame, "TOPRIGHT", 5, 0)
    end
end

-- ===============================================================
-- POWER BAR MANAGEMENT
-- ===============================================================
local function UpdatePowerBarTexture()
    if not UnitExists("pet") or not PetFrameManaBar then return end
    
    local _, powerType = UnitPowerType('pet')
    local texture = POWER_TEXTURES[powerType]
    
    if texture then
        local statusBar = PetFrameManaBar:GetStatusBarTexture()
        statusBar:SetTexture(texture)
        statusBar:SetVertexColor(1, 1, 1, 1)
    end
end

-- ===============================================================
-- COMBAT MODE TEXTURE
-- ===============================================================
local function ConfigureCombatMode()
    local texture = _G.PetAttackModeTexture
    if not texture then return end
    
    texture:SetTexture(ATLAS_TEXTURE)
    texture:SetTexCoord(unpack(COMBAT_TEX_COORDS))
    texture:SetVertexColor(1.0, 0.0, 0.0, 1.0)  -- Color inicial
    texture:SetBlendMode("ADD")
    texture:SetAlpha(0.8)  -- Alpha fijo
    -- 7.3.5 compatibility: SetDrawLayer sublevel must be between -8 and 7
    texture:SetDrawLayer("OVERLAY", 7)
    texture:ClearAllPoints()
    texture:SetPoint('CENTER', PetFrame, 'CENTER', -7, -2)
    texture:SetSize(114, 47)
    
    --  REINICIAR TIMER
    combatPulseTimer = 0
end

-- ===============================================================
-- FUNCIÓN OnUpdate PARA EL PET FRAME
-- ===============================================================
local function PetFrame_OnUpdate(self, elapsed)
    local success, err = pcall(function()
        AnimatePetCombatPulse(elapsed)
    end)
    
    if not success then
        
    end
end

-- ===============================================================
-- THREAT GLOW SYSTEM 
-- ===============================================================
local function ConfigurePetThreatGlow()
    --  El pet frame usa PetFrameFlash para el threat glow
    local threatFlash = _G.PetFrameFlash
    if not threatFlash then return end
    
    --  APLICAR TU TEXTURA PERSONALIZADA
    threatFlash:SetTexture(ATLAS_TEXTURE)  
    threatFlash:SetTexCoord(unpack(COMBAT_TEX_COORDS))
    --  COORDENADAS DE TEXTURA (ajustar según tu textura)
    -- Formato: left, right, top, bottom (valores entre 0 y 1)
   
    
    --  CONFIGURACIÓN VISUAL
    threatFlash:SetBlendMode("ADD")  -- Efecto luminoso
    threatFlash:SetAlpha(0.7)  -- Transparencia
    -- 7.3.5 compatibility: SetDrawLayer sublevel must be between -8 and 7
    threatFlash:SetDrawLayer("OVERLAY", 7)  -- Por encima de todo
    
    --  POSICIONAMIENTO PARA PET FRAME
    threatFlash:ClearAllPoints()
    threatFlash:SetPoint("CENTER", PetFrame, "CENTER", -7, -2)  
    threatFlash:SetSize(114, 47)  
end
-- ===============================================================
-- FRAME SETUP
-- ===============================================================
local function SetupFrameElement(parent, name, layer, texture, point, size)
    local element = parent:CreateTexture(name)
    element:SetDrawLayer(layer[1], layer[2])
    element:SetTexture(texture)
    element:SetPoint(unpack(point))
    if size then element:SetSize(unpack(size)) end
    element:Show()
    return element
end

local function SetupStatusBar(bar, point, size, texture)
    bar:ClearAllPoints()
    bar:SetPoint(unpack(point))
    bar:SetSize(unpack(size))
    if texture then
        bar:GetStatusBarTexture():SetTexture(texture)
        bar:SetStatusBarColor(1, 1, 1, 1)
        bar.SetStatusBarColor = noop
    end
end

-- ===============================================================
-- VEHICLE SYSTEM INTEGRATION FOR PET FRAME
-- ===============================================================

-- Function to update PetFrame textSystem unit based on vehicle state
local function UpdatePetTextSystemUnit()
    if not moduleState.textSystem then
        return
    end
    
    local hasVehicleUI = UnitHasVehicleUI("player")
    -- LÓGICA CORRECTA: Cuando estás en vehículo, PetFrame debe mostrar al JUGADOR como "mascota"
    local targetUnit = hasVehicleUI and "player" or "pet"
    
    -- Update both the public unit field and internal reference
    moduleState.textSystem.unit = targetUnit
    if moduleState.textSystem._unitRef then
        moduleState.textSystem._unitRef.unit = targetUnit
    end
    
    -- Force immediate update
    if moduleState.textSystem.update then
        moduleState.textSystem.update()
    end
end

-- ===============================================================
-- MAIN FRAME REPLACEMENT
-- ===============================================================
local function ReplaceBlizzardPetFrame()
    local petFrame = PetFrame
    if not petFrame then return end

    -- Force show the pet frame if a pet exists (fixes tamed pet frame not showing)
    if UnitExists("pet") then
        petFrame:Show()
    end

    if not moduleState.hooks.onUpdate then
        petFrame:SetScript("OnUpdate", PetFrame_OnUpdate)
        moduleState.hooks.onUpdate = true
    end

    if not moduleState.hooks.onShow then
        -- Hook :Show so every time Blizzard shows the pet frame,
        -- our custom styling gets re-applied
        hooksecurefunc(petFrame, "Show", function(self)
            -- Re-apply all custom styling on the next frame update
            C_Timer.After(0, function()
                if UnitExists("pet") and self then
                    PetFrameTexture:SetTexture('')
                    PetFrameTexture:Hide()
                    if PetPortrait then
                        PetPortrait:ClearAllPoints()
                        PetPortrait:SetPoint("LEFT", 6, 0)
                        PetPortrait:SetSize(34, 34)
                        PetPortrait:SetDrawLayer('ARTWORK', 0)
                        PetPortrait:Show()
                    end
                    if moduleState.frame.background then
                        moduleState.frame.background:ClearAllPoints()
                        if PetPortrait then
                            moduleState.frame.background:SetPoint('LEFT', PetPortrait, 'CENTER', -24, -10)
                        end
                        moduleState.frame.background:Show()
                    end
                    if moduleState.frame.border then
                        moduleState.frame.border:ClearAllPoints()
                        if PetPortrait then
                            moduleState.frame.border:SetPoint('LEFT', PetPortrait, 'CENTER', -24, -10)
                        end
                        moduleState.frame.border:Show()
                    end
                    HideBlizzardPetTexts()
                end
            end)
        end)
        moduleState.hooks.onShow = true
    end
    
    ApplyFramePositioning()
    
    -- Hide original Blizzard texture
    PetFrameTexture:SetTexture('')
    PetFrameTexture:Hide()
    
    -- Hide original text elements to avoid conflicts
    HideBlizzardPetTexts()
    
    -- Setup portrait
    local portrait = PetPortrait
    if portrait then
        portrait:ClearAllPoints()
        portrait:SetPoint("LEFT", 6, 0)
        portrait:SetSize(34, 34)
        portrait:SetDrawLayer('ARTWORK', 0)
        portrait:Show()
        -- Use SetPortraitTexture (global, native Legion API) as primary,
        -- and SetPortraitToUnit as fallback for newer clients
        if SetPortraitTexture then
            SetPortraitTexture(PetPortrait, "pet")
        elseif portrait.SetPortraitToUnit then
            portrait:SetPortraitToUnit("pet")
        end
    end
    
    -- Always re-create DragonUI elements (fixes tamed pet frame not showing -
    -- Blizzard may reset/re-create child textures of PetFrame)
    if moduleState.frame.background then
        moduleState.frame.background:Hide()
    end
    moduleState.frame.background = SetupFrameElement(
        petFrame,
        'DragonUIPetFrameBackground',
        {'BACKGROUND', 1},
        TEXTURE_PATH .. TOT_BASE .. 'BACKGROUND',
        {'LEFT', portrait, 'CENTER', -24, -10}
    )
    
    if moduleState.frame.border then
        moduleState.frame.border:Hide()
    end
    moduleState.frame.border = SetupFrameElement(
        PetFrameHealthBar,
        'DragonUIPetFrameBorder',
        {'OVERLAY', 6},
        TEXTURE_PATH .. TOT_BASE .. 'BORDER',
        {'LEFT', portrait, 'CENTER', -24, -10}
    )
    
    -- Setup health bar
    SetupStatusBar(
        PetFrameHealthBar,
        {'LEFT', portrait, 'RIGHT', 2, 0},
        {70.5, 10},
        UNITFRAME_PATH .. TOT_BASE .. 'Bar-Health'
    )
    
    -- Setup mana bar
    SetupStatusBar(
        PetFrameManaBar,
        {'LEFT', portrait, 'RIGHT', -1, -10},
        {74, 7.5}
    )
    UpdatePowerBarTexture()
    
    -- Configure combat mode
    ConfigureCombatMode()
    if not moduleState.hooks.combatMode then
        hooksecurefunc(_G.PetAttackModeTexture, "Show", function(self)
            ConfigureCombatMode()
        end)
        
        --  MODIFICAR EL HOOK DE SetVertexColor PARA NO INTERFERIR
        hooksecurefunc(_G.PetAttackModeTexture, "SetVertexColor", function(self, r, g, b, a)
            -- Solo intervenir si no es nuestro rango de colores del pulso
            if not COMBAT_PULSE_SETTINGS.enabled then
                if r ~= 1.0 or g ~= 0.0 or b ~= 0.0 then
                    self:SetVertexColor(1.0, 0.0, 0.0, 1.0)
                end
            end
            -- Si el pulso está activo, dejamos que la animación controle el color
        end)
        
        moduleState.hooks.combatMode = true
    end

    -- Configurar threat glow personalizado
    if not moduleState.hooks.threatGlow then
        ConfigurePetThreatGlow()
        
        --  HOOK para mantener la configuración
        hooksecurefunc(_G.PetFrameFlash, "Show", ConfigurePetThreatGlow)
        
        moduleState.hooks.threatGlow = true
    end
    
    -- Setup pet name positioning
    if PetName then
        PetName:ClearAllPoints()
        PetName:SetPoint("CENTER", petFrame, "CENTER", 10, 13)
        PetName:SetJustifyH("LEFT")
        PetName:SetWidth(65)
        PetName:SetDrawLayer("OVERLAY")
    end
    
    -- Position happiness icon
    local happiness = _G[petFrame:GetName() .. 'Happiness']
    if happiness then
        happiness:ClearAllPoints()
        happiness:SetPoint("LEFT", petFrame, "RIGHT", -10, -5)
    end

    -- ===============================================================
    -- INTEGRATE TEXT SYSTEM
    -- ===============================================================
    if addon.TextSystem then
        
        
        -- Setup the advanced text system for pet frame with dynamic unit
        local hasVehicleUI = UnitHasVehicleUI("player")
        local initialUnit = hasVehicleUI and "player" or "pet"
        
        moduleState.textSystem = addon.TextSystem.SetupFrameTextSystem(
            "pet",                 -- frameType
            initialUnit,           -- unit (dynamic based on vehicle state)
            petFrame,              -- parentFrame
            PetFrameHealthBar,     -- healthBar
            PetFrameManaBar,       -- manaBar
            "PetFrame"             -- prefix
        )
        
        -- Ensure we have the correct unit after setup
        UpdatePetTextSystemUnit()
        
    else
        
    end
end


-- ===============================================================
-- UPDATE HANDLER
-- ===============================================================
local function OnPetFrameUpdate()
    -- PetFrame_Update re-applies Blizzard textures; re-hide them
    if PetFrameTexture then
        PetFrameTexture:SetTexture('')
        PetFrameTexture:Hide()
    end

    -- Force PetPortrait to show and position correctly (fixes tamed pet portrait not showing)
    local portrait = PetPortrait
    if portrait then
        portrait:ClearAllPoints()
        portrait:SetPoint("LEFT", 6, 0)
        portrait:SetSize(34, 34)
        portrait:SetDrawLayer('ARTWORK', 0)
        portrait:Show()
        -- Use SetPortraitTexture (global, native Legion API) as primary,
        -- and SetPortraitToUnit as fallback for newer clients
        if SetPortraitTexture then
            SetPortraitTexture(PetPortrait, "pet")
        elseif portrait.SetPortraitToUnit then
            portrait:SetPortraitToUnit("pet")
        end
    end

    -- Refresh textures
    if moduleState.frame.background then
        moduleState.frame.background:SetTexture(TEXTURE_PATH .. TOT_BASE .. 'BACKGROUND')
        moduleState.frame.background:ClearAllPoints()
        if PetPortrait then
            moduleState.frame.background:SetPoint('LEFT', PetPortrait, 'CENTER', -24, -10)
        end
        moduleState.frame.background:Show()
    end
    if moduleState.frame.border then
        moduleState.frame.border:SetTexture(TEXTURE_PATH .. TOT_BASE .. 'BORDER')
        moduleState.frame.border:ClearAllPoints()
        if PetPortrait then
            moduleState.frame.border:SetPoint('LEFT', PetPortrait, 'CENTER', -24, -10)
        end
        moduleState.frame.border:Show()
    end
    
    UpdatePowerBarTexture()
    ConfigureCombatMode()
    ConfigurePetThreatGlow()
    
    -- Update text system unit for vehicle support
    UpdatePetTextSystemUnit()
    
    -- Update text system if available
    if moduleState.textSystem and moduleState.textSystem.update then
        moduleState.textSystem.update()
    end

    -- Asegurar que los textos vanilla sigan ocultos
    HideBlizzardPetTexts()
end

-- ===============================================================
-- MODULE INTERFACE
-- ===============================================================
function PetFrameModule:OnEnable()
    if not moduleState.hooks.petUpdate then
        hooksecurefunc('PetFrame_Update', OnPetFrameUpdate)
        moduleState.hooks.petUpdate = true
    end
    if not moduleState.hooks.petHide then
        -- Prevent Blizzard from hiding the pet frame while a pet exists
        hooksecurefunc(PetFrame, "Hide", function(self)
            if UnitExists("pet") then
                C_Timer.After(0, function()
                    if UnitExists("pet") and self then
                        self:Show()
                    end
                end)
            end
        end)
        moduleState.hooks.petHide = true
    end
    HideBlizzardPetTexts()
end

function PetFrameModule:OnDisable()
    if moduleState.textSystem and moduleState.textSystem.clear then
        moduleState.textSystem.clear()
    end
end

function PetFrameModule:PLAYER_ENTERING_WORLD()
    ReplaceBlizzardPetFrame()
    -- Redundancia defensiva por si Blizzard re-activa los textos
    HideBlizzardPetTexts()
end

-- ===============================================================
-- REFRESH FUNCTION FOR OPTIONS
-- ===============================================================
function addon.RefreshPetFrame()
    -- 重新应用定位（无论是否有宠物，确保框体位置正确）
    if PetFrameModule.UpdateWidgets then
        PetFrameModule:UpdateWidgets()
    end
    
    if UnitExists("pet") then
        OnPetFrameUpdate()
    end
end



-- ===============================================================
-- FORCE-SHOW HELPER: ensures all custom pet frame elements are visible
-- (used on tame, reload, re-summon, and delayed retries)
-- ===============================================================
local function ForceShowPetFrame()
    if not UnitExists("pet") or not PetFrame then return end

    -- Try to load pet UI if it hasn't been created yet
    if not PetPortrait then
        if PetFrame_LoadUI then
            PetFrame_LoadUI()
        end
    end

    -- Force show the main pet frame
    PetFrame:Show()

    -- Re-apply custom styling
    ReplaceBlizzardPetFrame()

    -- Force PetFrame_Update to trigger our hooked OnPetFrameUpdate
    if PetFrame_Update then
        PetFrame_Update(PetFrame)
    end

    -- Final pass: override any state Blizzard may have restored
    if PetFrameTexture then
        PetFrameTexture:SetTexture('')
        PetFrameTexture:Hide()
    end

    if PetPortrait then
        PetPortrait:ClearAllPoints()
        PetPortrait:SetPoint("LEFT", 6, 0)
        PetPortrait:SetSize(34, 34)
        PetPortrait:SetDrawLayer('ARTWORK', 0)
        PetPortrait:Show()
        if SetPortraitTexture then
            SetPortraitTexture(PetPortrait, "pet")
        elseif PetPortrait.SetPortraitToUnit then
            PetPortrait:SetPortraitToUnit("pet")
        end
    end

    if moduleState.frame.background then
        moduleState.frame.background:ClearAllPoints()
        if PetPortrait then
            moduleState.frame.background:SetPoint('LEFT', PetPortrait, 'CENTER', -24, -10)
        end
        moduleState.frame.background:Show()
    end

    if moduleState.frame.border then
        moduleState.frame.border:ClearAllPoints()
        if PetPortrait then
            moduleState.frame.border:SetPoint('LEFT', PetPortrait, 'CENTER', -24, -10)
        end
        moduleState.frame.border:Show()
    end

    HideBlizzardPetTexts()
end

-- Polling frame for responsive portrait detection (checks every frame)
local portraitPollFrame = CreateFrame("Frame")
local POLL_TIMEOUT = 10.0

-- Check if portrait texture is actually loaded (not just a green square)
local function IsPortraitLoaded()
    if not PetPortrait then return false end
    local texture = PetPortrait:GetTexture()
    if not texture then return false end
    -- If texture is a file path, check it's not the default unknown texture
    if type(texture) == "string" then
        -- Green texture or missing texture indicators
        if texture:find("TempPortrait") or texture:find("Unknown") then
            return false
        end
    end
    return true
end

-- Pre-load portrait texture to speed up async loading
local function PreloadPetPortrait()
    if not PetPortrait then return end
    -- Force texture load by setting it multiple times
    if SetPortraitTexture then
        SetPortraitTexture(PetPortrait, "pet")
    elseif PetPortrait.SetPortraitToUnit then
        PetPortrait:SetPortraitToUnit("pet")
    end
    -- Also try to trigger the game to load pet data
    if PetFrame_Update then
        PetFrame_Update(PetFrame)
    end
end

local function StartPortraitPolling()
    if not UnitExists("pet") or portraitPollFrame.polling then return end
    portraitPollFrame.elapsed = 0
    portraitPollFrame.lastTick = 0
    portraitPollFrame.polling = true
    portraitPollFrame.portraitLoaded = false
    portraitPollFrame:Show()
    ForceShowPetFrame()
    PreloadPetPortrait()
end

local function StopPortraitPolling()
    portraitPollFrame.polling = false
    portraitPollFrame.portraitLoaded = false
    portraitPollFrame:Hide()
end

portraitPollFrame:Hide()
portraitPollFrame:SetScript("OnUpdate", function(self, elapsed)
    if not portraitPollFrame.polling then
        self:Hide()
        return
    end

    if not UnitExists("pet") then
        StopPortraitPolling()
        return
    end

    self.elapsed = self.elapsed + elapsed
    if self.elapsed > POLL_TIMEOUT then
        StopPortraitPolling()
        return
    end

    -- Dynamic tick rate: faster at start, slower after portrait loads
    local tick
    if self.portraitLoaded then
        tick = 0.5  -- Slow down once loaded
    elseif self.elapsed < 1.0 then
        tick = 0.03  -- Very frequent in first second
    elseif self.elapsed < 3.0 then
        tick = 0.08  -- Moderate frequency
    else
        tick = 0.2   -- Slower after 3 seconds
    end

    local nextTick = (self.lastTick or 0) + tick
    if self.elapsed >= nextTick then
        self.lastTick = nextTick
        ForceShowPetFrame()
        PreloadPetPortrait()

        -- Check if portrait is fully loaded
        if not self.portraitLoaded and IsPortraitLoaded() then
            self.portraitLoaded = true
            -- One final refresh after a short delay to ensure everything is ready
            C_Timer.After(0.1, ForceShowPetFrame)
        end
    end
end)

-- Keep the public name for external callers
local function SchedulePetFrameRetries()
    StartPortraitPolling()
end

-- ===============================================================
-- EVENT HANDLING
-- ===============================================================
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
-- Pet spawn/despawn tracking: ensures custom frame appears immediately on tame
-- (Blizzard's PetFrame_Update hook alone may not fire reliably for hunter taming)
eventFrame:RegisterEvent("UNIT_PET")
-- Vehicle events for proper unit switching in PetFrame
eventFrame:RegisterEvent("UNIT_ENTERED_VEHICLE")
eventFrame:RegisterEvent("UNIT_EXITED_VEHICLE")
-- Portrait update: fires when a unit's portrait image becomes available
-- (critical for newly tamed pets where portrait data loads asynchronously)
eventFrame:RegisterEvent("UNIT_PORTRAIT_UPDATE")
-- Name update: fires when a unit's name becomes available
eventFrame:RegisterEvent("UNIT_NAME_UPDATE")

eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "DragonUI" then
        PetFrameModule:OnEnable()
    elseif event == "PLAYER_ENTERING_WORLD" then
        PetFrameModule:PLAYER_ENTERING_WORLD()
        UpdatePetTextSystemUnit()
        if UnitExists("pet") then
            ForceShowPetFrame()
        end
    elseif event == "UNIT_PET" and arg1 == "player" then
        -- Pet was summoned, dismissed, or tamed
        if UnitExists("pet") then
            ForceShowPetFrame()
            -- Schedule multiple delayed retries to handle async
            -- portrait loading and delayed PetFrame initialization
            SchedulePetFrameRetries()
        end
    elseif (event == "UNIT_PORTRAIT_UPDATE" or event == "UNIT_NAME_UPDATE") and arg1 == "pet" then
        -- Portrait or name data became available (critical for newly tamed pets)
        ForceShowPetFrame()
        -- Schedule retries to handle async texture loading for newly tamed pets
        SchedulePetFrameRetries()
    elseif event == "UNIT_ENTERED_VEHICLE" and arg1 == "player" then
        UpdatePetTextSystemUnit()
        OnPetFrameUpdate()
    elseif event == "UNIT_EXITED_VEHICLE" and arg1 == "player" then
        UpdatePetTextSystemUnit()
        OnPetFrameUpdate()
    end
end)

-- ===============================================================
-- CENTRALIZED SYSTEM INTEGRATION
-- ===============================================================

-- Variables para el sistema centralizado
PetFrameModule.anchor = nil
PetFrameModule.initialized = false

-- Create auxiliary frame for anchoring (como party.lua y castbar.lua)
local function CreatePetAnchorFrame()
    if PetFrameModule.anchor then
        return PetFrameModule.anchor
    end

    --  USAR FUNCIÓN CENTRALIZADA DE CORE.LUA
    PetFrameModule.anchor = addon.CreateUIFrame(130, 44, "PetFrame")
    
    --  PERSONALIZAR TEXTO PARA PET FRAME
    if PetFrameModule.anchor.editorText then
        PetFrameModule.anchor.editorText:SetText("Pet Frame")
    end
    
    return PetFrameModule.anchor
end

--  FUNCIÓN PARA APLICAR POSICIÓN DESDE WIDGETS (COMO party.lua)
local function ApplyWidgetPosition()
    if not PetFrameModule.anchor then
        
        return
    end

    --  ASEGURAR QUE EXISTE LA CONFIGURACIÓN
    if not addon.db or not addon.db.profile or not addon.db.profile.widgets then
        
        return
    end
    
    local widgetConfig = addon.db.profile.widgets.pet
    local petConfig = addon.db.profile.unitframe.pet
    
    if petConfig and not petConfig.override then
        --  "相对玩家框体定位"模式：宠物锚点跟随玩家框体位置
        --  动态计算偏移使得切换模式时屏幕位置不变
        local petLeft = PetFrameModule.anchor:GetLeft()
        local petTop = PetFrameModule.anchor:GetTop()
        local playerRight = PlayerFrame:GetRight()
        local playerTop = PlayerFrame:GetTop()

        local offsetX, offsetY
        if petLeft and petTop and playerRight and playerTop
           and (math.abs(petLeft) > 1 or math.abs(petTop) > 1) then
            -- 根据锚点当前屏幕位置和 PlayerFrame 位置计算相对偏移
            -- 使用 GetLeft/GetTop（同 SetPoint 坐标系，正Y向上）
            offsetX = petLeft - playerRight
            offsetY = petTop - playerTop
        else
            -- 回退到已保存的相对偏移或从默认绝对坐标换算
            local absX = (widgetConfig and widgetConfig.posX) or 63
            local absY = (widgetConfig and widgetConfig.posY) or -100
            -- 已保存的偏移优先
            offsetX = (widgetConfig and widgetConfig.relativeX) or (absX - 220)
            offsetY = (widgetConfig and widgetConfig.relativeY) or (absY + 10)
        end

        -- 保存计算出的偏移以便持久化
        if widgetConfig then
            widgetConfig.relativeX = offsetX
            widgetConfig.relativeY = offsetY
        end

        PetFrameModule.anchor:ClearAllPoints()
        PetFrameModule.anchor:SetPoint("TOPLEFT", PlayerFrame, "TOPRIGHT", offsetX, offsetY)
        
    elseif widgetConfig and widgetConfig.posX and widgetConfig.posY then
        local anchor = widgetConfig.anchor or "TOPRIGHT"
        PetFrameModule.anchor:ClearAllPoints()
        PetFrameModule.anchor:SetPoint(anchor, UIParent, anchor, widgetConfig.posX, widgetConfig.posY)
        
    else
        --  POSICIÓN POR DEFECTO COMO RETAILUI (esquina superior derecha)
        PetFrameModule.anchor:ClearAllPoints()
        PetFrameModule.anchor:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -50, -150)
        
    end
end

--  FUNCIONES REQUERIDAS POR EL SISTEMA CENTRALIZADO
function PetFrameModule:LoadDefaultSettings()
    --  ASEGURAR QUE EXISTE LA CONFIGURACIÓN EN WIDGETS
    if not addon.db.profile.widgets then
        addon.db.profile.widgets = {}
    end
    
    if not addon.db.profile.widgets.pet then
        addon.db.profile.widgets.pet = {
            anchor = "TOPRIGHT",
            posX = -50,
            posY = -150
        }
        
    end
    
    --  ASEGURAR QUE EXISTE LA CONFIGURACIÓN EN UNITFRAME.PET
    if not addon.db.profile.unitframe then
        addon.db.profile.unitframe = {}
    end
    
    if not addon.db.profile.unitframe.pet then
        -- La configuración del pet ya debería existir en database.lua
        
    end
end

function PetFrameModule:UpdateWidgets()
    ApplyWidgetPosition()
    --  REPOSICIONAR EL PET FRAME RELATIVO AL ANCHOR ACTUALIZADO
    if not InCombatLockdown() then
        -- El pet frame debería seguir al anchor
        ApplyFramePositioning()
    end
end

--  FUNCIÓN PARA VERIFICAR SI EL PET FRAME DEBE ESTAR VISIBLE
-- SIGUIENDO A RETAILUI: Siempre visible en editor, NO filtrado por clases
local function ShouldPetFrameBeVisible()
    -- RetailUI siempre permite editar el PET frame independientemente de la clase
    return true
end

--  FUNCIONES DE TESTEO PARA EL EDITOR
local function ShowPetFrameTest()
    -- Mostrar el PET frame aunque no haya mascota
    if PetFrame then
        PetFrame:Show()
        
        -- Simular que hay una mascota para el test
        if PetName then
            PetName:SetText("Test Pet")
            PetName:Show()
        end
        
        if PetPortrait then
            PetPortrait:Show()
        end
        
        if PetFrameHealthBar then
            PetFrameHealthBar:SetMinMaxValues(0, 100)
            PetFrameHealthBar:SetValue(75)
            PetFrameHealthBar:Show()
        end
        
        if PetFrameManaBar then
            PetFrameManaBar:SetMinMaxValues(0, 100)
            PetFrameManaBar:SetValue(50)
            PetFrameManaBar:Show()
        end
    end
end

local function HidePetFrameTest()
    -- Restaurar el estado normal del PET frame
    if PetFrame then
        if UnitExists("pet") then
            -- Si hay mascota real, restaurar valores reales
            if PetName then
                PetName:SetText(UnitName("pet") or "")
            end
            
            -- Forzar actualización de las barras con valores reales
            if PetFrameHealthBar then
                PetFrameHealthBar:SetMinMaxValues(0, UnitHealthMax("pet"))
                PetFrameHealthBar:SetValue(UnitHealth("pet"))
            end
            
            if PetFrameManaBar then
                PetFrameManaBar:SetMinMaxValues(0, UnitPowerMax("pet"))
                PetFrameManaBar:SetValue(UnitPower("pet"))
            end
        else
            -- Si no hay mascota real, ocultar todo
            PetFrame:Hide()
            
            -- Limpiar los valores de prueba
            if PetName then
                PetName:SetText("")
            end
        end
    end
end

--  FUNCIÓN DE INICIALIZACIÓN DEL SISTEMA CENTRALIZADO
local function InitializePetFrameForEditor()
    -- Crear el anchor frame
    CreatePetAnchorFrame()
    
    --  REGISTRO COMPLETO CON TODAS LAS FUNCIONES (COMO party.lua y castbar.lua)
    addon:RegisterEditableFrame({
        name = "PetFrame",
        frame = PetFrameModule.anchor,
        configPath = {"widgets", "pet"},  --  Array como otros módulos
        hasTarget = ShouldPetFrameBeVisible,  --  Siempre true (como RetailUI)
        showTest = ShowPetFrameTest,  --  Minúscula como party.lua
        hideTest = HidePetFrameTest,  --  Minúscula como party.lua
        onHide = function() PetFrameModule:UpdateWidgets() end,  --  Para aplicar cambios
        LoadDefaultSettings = function() PetFrameModule:LoadDefaultSettings() end,
        UpdateWidgets = function() PetFrameModule:UpdateWidgets() end
    })
    
    PetFrameModule.initialized = true
    
end

--  INICIALIZACIÓN
InitializePetFrameForEditor()

--  LISTENER PARA CUANDO EL ADDON ESTÉ COMPLETAMENTE CARGADO
local readyFrame = CreateFrame("Frame")
readyFrame:RegisterEvent("ADDON_LOADED")
readyFrame:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "DragonUI" then
        -- Aplicar posición del widget cuando el addon esté listo
        if PetFrameModule.UpdateWidgets then
            PetFrameModule:UpdateWidgets()
        end
        self:UnregisterEvent("ADDON_LOADED")
    end
end)

