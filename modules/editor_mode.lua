local addon = select(2, ...);

local EditorMode = {};
addon.EditorMode = EditorMode;

local gridOverlay = nil;
local exitEditorButton = nil;
local resetAllButton = nil;

-- StaticPopup para reiniciar UI después de salir del modo editor
StaticPopupDialogs["DRAGONUI_RELOAD_UI"] = {
    text = "UI elements have been repositioned. Reload UI to ensure all graphics display correctly?",
    button1 = "Reload Now",
    button2 = "Later",
    OnAccept = function()
        ReloadUI()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

--  BOTÓN DE SALIDA DEL MODO EDITOR
local function createExitButton()
    if exitEditorButton then return; end

    -- Crear el botón con estilo profesional
    exitEditorButton = CreateFrame("Button", "DragonUIExitEditorButton", UIParent, "UIPanelButtonTemplate");
    exitEditorButton:SetText("Exit Edit Mode");
    exitEditorButton:SetSize(140, 28); -- Mismo tamaño que Reset button
    exitEditorButton:SetPoint("CENTER", UIParent, "CENTER", 0, 200); -- Posición flotante centrada
    exitEditorButton:SetFrameStrata("DIALOG"); -- Asegura que esté por encima de otros elementos
    exitEditorButton:SetFrameLevel(100);

    
    -- Estilo profesional: Mismo color rojo que Reset button
    local normalTexture = exitEditorButton:GetNormalTexture()
    if normalTexture then
        normalTexture:SetVertexColor(0.8, 0.3, 0.3, 1) -- Rojo profesional (igual que Reset)
    end
    
    local highlightTexture = exitEditorButton:GetHighlightTexture()
    if highlightTexture then
        highlightTexture:SetVertexColor(1, 0.4, 0.4, 1) -- Rojo claro al pasar ratón (igual que Reset)
    end
    
    local pushedTexture = exitEditorButton:GetPushedTexture()
    if pushedTexture then
        pushedTexture:SetVertexColor(0.6, 0.2, 0.2, 1) -- Rojo oscuro al presionar (igual que Reset)
    end
    
    -- Texto en blanco para contraste
    local fontString = exitEditorButton:GetFontString()
    if fontString then
        fontString:SetTextColor(1, 1, 1, 1) -- Texto blanco
        fontString:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE") -- Fuente profesional
    end

    -- Asignar la acción de salida
    exitEditorButton:SetScript("OnClick", function()
        EditorMode:Toggle();
    end);

    exitEditorButton:Hide(); -- Oculto por defecto
end

--  BOTÓN DE RESET ALL POSITIONS - ESTILO PROFESIONAL
local function createResetAllButton()
    if resetAllButton then return; end

    -- Crear el botón con estilo profesional sincronizado
    resetAllButton = CreateFrame("Button", "DragonUIResetAllButton", UIParent, "UIPanelButtonTemplate");
    resetAllButton:SetText("Reset All Positions");
    resetAllButton:SetSize(140, 28); -- Mismo tamaño que Exit button
    resetAllButton:SetPoint("CENTER", UIParent, "CENTER", 0, 165); -- Separación uniforme
    resetAllButton:SetFrameStrata("DIALOG");
    resetAllButton:SetFrameLevel(100);

    -- Estilo profesional: Rojo elegante para acción destructiva
    local normalTexture = resetAllButton:GetNormalTexture()
    if normalTexture then
        normalTexture:SetVertexColor(0.8, 0.3, 0.3, 1) -- Rojo profesional (menos saturado)
    end
    
    local highlightTexture = resetAllButton:GetHighlightTexture()
    if highlightTexture then
        highlightTexture:SetVertexColor(1, 0.4, 0.4, 1) -- Rojo claro al pasar ratón
    end
    
    local pushedTexture = resetAllButton:GetPushedTexture()
    if pushedTexture then
        pushedTexture:SetVertexColor(0.6, 0.2, 0.2, 1) -- Rojo oscuro al presionar
    end
    
    -- Texto en blanco para contraste perfecto
    local fontString = resetAllButton:GetFontString()
    if fontString then
        fontString:SetTextColor(1, 1, 1, 1) -- Texto blanco
        fontString:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE") -- Fuente profesional
    end

    -- ESTRATEGIA: Mostrar confirmación directamente sin salir del editor mode
    resetAllButton:SetScript("OnClick", function()
        -- Mostrar solo el popup de confirmación específico para reset
        EditorMode:ShowResetConfirmation()
    end);

    resetAllButton:Hide(); -- Oculto por defecto
end

--  TU GRID MEJORADO - AHORA CUADRADOS SIMÉTRICOS
local function createGridOverlay()
    if gridOverlay then return; end

    --  CAMBIO: Hacer cuadrados SIMÉTRICOS con línea central EXACTA
    local screenWidth = GetScreenWidth()
    local screenHeight = GetScreenHeight()
    
    --  ALGORITMO SIMÉTRICO: Partir desde el centro hacia afuera
    local cellSize = 32  -- Tamaño base de celda
    
    -- Calcular cuántas celdas completas caben desde el centro hacia cada lado
    local halfCellsHorizontal = math.floor((screenWidth / 2) / cellSize)
    local halfCellsVertical = math.floor((screenHeight / 2) / cellSize)
    
    -- Total de celdas (siempre par para que el centro sea exacto)
    local totalHorizontalCells = halfCellsHorizontal * 2
    local totalVerticalCells = halfCellsVertical * 2
    
    -- Recalcular el tamaño real de celda para que sea perfectamente simétrico
    local actualCellWidth = screenWidth / totalHorizontalCells
    local actualCellHeight = screenHeight / totalVerticalCells
    
    -- Posición exacta del centro
    local centerX = screenWidth / 2
    local centerY = screenHeight / 2
    
    gridOverlay = CreateFrame('Frame', "DragonUIGridOverlay", UIParent)
    gridOverlay:SetAllPoints(UIParent)
    gridOverlay:SetFrameStrata("BACKGROUND")
    gridOverlay:SetFrameLevel(0)

    --  AÑADIR CAPA DE FONDO OSCURA SEMI-TRANSPARENTE
    local background = gridOverlay:CreateTexture("DragonUIGridBackground", 'BACKGROUND')
    background:SetAllPoints(gridOverlay)
    background:SetTexture(0, 0, 0, 0.3)  -- Negro semi-transparente
    background:SetDrawLayer('BACKGROUND', -1)  -- Detrás de todo

    local lineThickness = 1

    -- === LÍNEAS VERTICALES SIMÉTRICAS ===
    for i = 0, totalHorizontalCells do
        local line = gridOverlay:CreateTexture("DragonUIGridV"..i, 'BACKGROUND')
        
        -- La línea central es exactamente en halfCellsHorizontal
        if i == halfCellsHorizontal then
            line:SetTexture(1, 0, 0, 0.8)  -- Línea central roja EXACTA
        else
            line:SetTexture(1, 1, 1, 0.3)  -- Líneas blancas simétricas
        end
        
        local x = i * actualCellWidth
        line:SetPoint("TOPLEFT", gridOverlay, "TOPLEFT", x - (lineThickness / 2), 0)
        line:SetPoint('BOTTOMRIGHT', gridOverlay, 'BOTTOMLEFT', x + (lineThickness / 2), 0)
    end

    -- === LÍNEAS HORIZONTALES SIMÉTRICAS ===
    for i = 0, totalVerticalCells do
        local line = gridOverlay:CreateTexture("DragonUIGridH"..i, 'BACKGROUND')
        
        -- La línea central es exactamente en halfCellsVertical
        if i == halfCellsVertical then
            line:SetTexture(1, 0, 0, 0.8)  -- Línea central roja EXACTA
        else
            line:SetTexture(1, 1, 1, 0.3)  -- Líneas blancas simétricas
        end
        
        local y = i * actualCellHeight
        line:SetPoint("TOPLEFT", gridOverlay, "TOPLEFT", 0, -y + (lineThickness / 2))
        line:SetPoint('BOTTOMRIGHT', gridOverlay, 'TOPRIGHT', 0, -y - (lineThickness / 2))
    end
    
    --  DEBUG: Mostrar información de simetría
    
    
    
    
    gridOverlay:Hide()
end

function EditorMode:Show()
    if InCombatLockdown() then
        
        return
    end

    createGridOverlay()
    createExitButton()
    createResetAllButton()
    gridOverlay:Show()
    exitEditorButton:Show()
    resetAllButton:Show()

    --  NUEVO: USAR SISTEMA CENTRALIZADO - UNA SOLA LÍNEA
    addon:ShowAllEditableFrames()
    
    --  NEW: Enable action bar overlays for mouse blocking during editor mode
    if addon.EnableActionBarOverlays then
        addon.EnableActionBarOverlays()
    end
    
    --  HOOK: Mantener escalas configuradas durante editor mode
    EditorMode:InstallScaleHooks()
    
    -- Update overlay sizes after showing
    if addon.UpdateOverlaySizes then
        addon.UpdateOverlaySizes()
    end
    
    -- Refresh AceConfig to update button state
    self:RefreshOptionsUI()
    
    
end


function EditorMode:Hide(showReloadPopup)
    if gridOverlay then gridOverlay:Hide() end
    if exitEditorButton then exitEditorButton:Hide() end
    if resetAllButton then resetAllButton:Hide() end

    --  NUEVO: USAR SISTEMA CENTRALIZADO - UNA SOLA LÍNEA
    addon:HideAllEditableFrames(true) -- true = refresh and save positions
    
    --  NEW: Disable action bar overlays to allow normal interaction with action buttons
    if addon.DisableActionBarOverlays then
        addon.DisableActionBarOverlays()
    end
    
    --  UNHOOK: Remover hooks de escala cuando se sale del editor mode
    EditorMode:RemoveScaleHooks()
    
    -- Refresh AceConfig to update button state
    self:RefreshOptionsUI()
    
    -- NUEVO: Solo mostrar popup de reload UI si no viene desde reset positions
    if showReloadPopup ~= false then
        StaticPopup_Show("DRAGONUI_RELOAD_UI")
    end
    
    
end

function EditorMode:RefreshOptionsUI()
    -- Refresh AceConfig interface to update button states
    -- Use scheduler to ensure it happens after state changes are complete
    addon.core:ScheduleTimer(function()
        local AceConfigRegistry = LibStub("AceConfigRegistry-3.0", true)
        if AceConfigRegistry then
            AceConfigRegistry:NotifyChange("DragonUI")
        end
    end, 0.1)
end

function EditorMode:Toggle()
    if self:IsActive() then 
        self:Hide(true) -- true = mostrar popup de reload UI (salida normal)
    else 
        self:Show() 
    end
end

function EditorMode:IsActive()
    -- Use grid visibility as the true indicator of editor state
    return gridOverlay and gridOverlay:IsShown()
end

--  COMANDO SLASH
SLASH_DRAGONUI_EDITOR1 = "/duiedit"
SLASH_DRAGONUI_EDITOR2 = "/dragonedit"
SlashCmdList["DRAGONUI_EDITOR"] = function()
    EditorMode:Toggle()
end

--  HOOKS PARA MANTENER ESCALAS DURANTE EDITOR MODE
local scaleHooks = {}

function EditorMode:InstallScaleHooks()
    --  DISABLED: Conflicting with RetailUI pattern in mainbars.lua
    -- Hook para MainMenuExpBar
    --[[ 
    if MainMenuExpBar and not scaleHooks.xpbar then
        scaleHooks.xpbar = function()
            if addon.db and addon.db.profile.xprepbar and addon.db.profile.xprepbar.expbar_scale then
                MainMenuExpBar:SetScale(addon.db.profile.xprepbar.expbar_scale)
            end
        end
        
        -- Hook a los eventos que pueden cambiar la escala
        hooksecurefunc(MainMenuExpBar, "SetScale", scaleHooks.xpbar)
        hooksecurefunc(MainMenuExpBar, "SetPoint", scaleHooks.xpbar)
        hooksecurefunc(MainMenuExpBar, "ClearAllPoints", scaleHooks.xpbar)
    end
    ]]--
    
    --  DISABLED: Conflicting with RetailUI pattern in mainbars.lua
    -- Hook para ReputationWatchBar
    --[[
    if ReputationWatchBar and not scaleHooks.repbar then
        scaleHooks.repbar = function()
            if addon.db and addon.db.profile.xprepbar and addon.db.profile.xprepbar.repbar_scale then
                ReputationWatchBar:SetScale(addon.db.profile.xprepbar.repbar_scale)
            end
        end
        
        -- Hook a los eventos que pueden cambiar la escala
        hooksecurefunc(ReputationWatchBar, "SetScale", scaleHooks.repbar)
        hooksecurefunc(ReputationWatchBar, "SetPoint", scaleHooks.repbar)
        hooksecurefunc(ReputationWatchBar, "ClearAllPoints", scaleHooks.repbar)
    end
    ]]--
end

function EditorMode:RemoveScaleHooks()
    -- Los hooks securefunc no se pueden remover directamente,
    -- así que simplemente marcamos como removidos para que no se ejecuten
    scaleHooks.xpbar = nil
    scaleHooks.repbar = nil
end

--  FUNCIÓN DE CONFIRMACIÓN PARA RESET ALL POSITIONS
function EditorMode:ShowResetConfirmation()
    StaticPopup_Show("DRAGONUI_RESET_ALL_POSITIONS")
end

--  FUNCIÓN PARA RESETEAR SOLO WIDGETS USANDO ACE3 (FUERA DEL EDITOR MODE)
function EditorMode:ResetAllPositions()
    if not addon.db or not addon.db.profile then
        return
    end
    
    -- Ocultar el editor mode sin mostrar el popup genérico
    if self:IsActive() then
        self:Hide(false) -- false = no mostrar popup de reload UI
    end
    
    -- Resetear solo la sección widgets usando los defaults de Ace3
    if addon.defaults and addon.defaults.profile and addon.defaults.profile.widgets then
        addon.db.profile.widgets = addon:CopyTable(addon.defaults.profile.widgets)
    else
        return
    end
    
    -- NUEVO: Resetear también additional.totem para multicast
    if addon.defaults and addon.defaults.profile and addon.defaults.profile.additional then
        if not addon.db.profile.additional then
            addon.db.profile.additional = {}
        end
        addon.db.profile.additional.totem = addon:CopyTable(addon.defaults.profile.additional.totem)
    end
    
    -- Usar ReloadUI para aplicar completamente los cambios
    ReloadUI()
end

--  FUNCIÓN HELPER PARA DEEP COPY (si no existe ya en addon)
if not addon.CopyTable then
    function addon:CopyTable(orig)
        local orig_type = type(orig)
        local copy
        if orig_type == 'table' then
            copy = {}
            for orig_key, orig_value in next, orig, nil do
                copy[addon:CopyTable(orig_key)] = addon:CopyTable(orig_value)
            end
            setmetatable(copy, addon:CopyTable(getmetatable(orig)))
        else -- number, string, boolean, etc
            copy = orig
        end
        return copy
    end
end

--  DEFINIR EL POPUP DE CONFIRMACIÓN
StaticPopupDialogs["DRAGONUI_RESET_ALL_POSITIONS"] = {
    text = "Are you sure you want to reset all interface elements to their default positions?",
    button1 = "Yes",
    button2 = "No",
    OnAccept = function()
        EditorMode:ResetAllPositions()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}