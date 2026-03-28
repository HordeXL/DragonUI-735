local addon = select(2,...);

-- =================================================================
-- DRAGONUI GAME MENU BUTTON MODULE (WOW 3.3.5A)
-- =================================================================

-- Variables locales para compatibilidad WoW 3.3.5a
local CreateFrame = CreateFrame
local GameMenuFrame = GameMenuFrame
local HideUIPanel = HideUIPanel

-- Estado del botón
local dragonUIButton = nil
local buttonAdded = false
local buttonPositioned = false -- Nuevo flag para evitar reposicionamiento múltiple

-- Lista de todos los botones del game menu en orden de aparición (WoW 3.3.5a)
local GAME_MENU_BUTTONS = {
    "GameMenuButtonHelp",
    "GameMenuButtonWhatsNew", 
    "GameMenuButtonStore",
    "GameMenuButtonOptions",
    "GameMenuButtonUIOptions", 
    "GameMenuButtonKeybindings",
    "GameMenuButtonMacros",
    "GameMenuButtonAddons",
    "GameMenuButtonLogout",
    "GameMenuButtonQuit",
    "GameMenuButtonContinue"
}

-- Función para encontrar la posición correcta del botón DragonUI
local function FindInsertPosition()
    -- Insertar SIEMPRE después del botón "Return to Game" (Continue) al final del menú
    local afterButton = _G["GameMenuButtonContinue"]
    
    -- Si Continue no existe, insertar después de Quit
    if not afterButton then
        afterButton = _G["GameMenuButtonQuit"]
    end
    
    -- Si tampoco existe Quit, insertar después de Logout
    if not afterButton then
        afterButton = _G["GameMenuButtonLogout"]
    end
    
    return afterButton, nil -- No hay beforeButton ya que va al final
end

-- Función para obtener todos los botones visibles del game menu
local function GetVisibleGameMenuButtons()
    local visibleButtons = {}
    
    for _, buttonName in ipairs(GAME_MENU_BUTTONS) do
        local button = _G[buttonName]
        if button and button:IsVisible() then
            table.insert(visibleButtons, button)
        end
    end
    
    return visibleButtons
end

-- Función para posicionar el botón DragonUI de forma muy conservadora
local function PositionDragonUIButton()
    if not dragonUIButton then return end
    
    -- IMPORTANTE: Solo posicionar una vez para evitar acumulación de desplazamientos
    if buttonPositioned then 
        return 
    end
    
    local afterButton, beforeButton = FindInsertPosition()
    
    if not afterButton then
        -- Fallback: posicionar al final del menú
        dragonUIButton:ClearAllPoints()
        dragonUIButton:SetPoint("TOP", GameMenuFrame, "TOP", 0, -200)
        buttonPositioned = true
        return
    end
    
    -- Posicionar SOLO el botón DragonUI inmediatamente después del botón de referencia
    dragonUIButton:ClearAllPoints()
    dragonUIButton:SetPoint("TOP", afterButton, "BOTTOM", 0, -1)
    
    -- 标记为已定位
    buttonPositioned = true
end

-- Función para abrir la interfaz de configuración de DragonUI
local function OpenDragonUIConfig()
    -- Cerrar el game menu primero
    HideUIPanel(GameMenuFrame)
    
    -- Intentar múltiples métodos para abrir la configuración
    
    -- Método 1: Comando slash directo
    if SlashCmdList and SlashCmdList["DRAGONUI"] then
        SlashCmdList["DRAGONUI"]("")
        return
    end
    
    -- Método 2: Función del addon directamente
    if addon and addon.OpenConfigDialog then
        addon.OpenConfigDialog()
        return
    end
    
    -- Método 3: A través de AceConfigDialog
    if addon and addon.core then
        local AceConfigDialog = LibStub and LibStub("AceConfigDialog-3.0", true)
        if AceConfigDialog then
            AceConfigDialog:Open("DragonUI")
            return
        end
    end
    
    -- Método 4: Simular comando slash manualmente
    if ChatFrameEditBox then
        ChatFrameEditBox:SetText("/dragonui")
        ChatEdit_SendText(ChatFrameEditBox, 0)
        return
    end
    
    
    
end

-- Función principal para crear el botón DragonUI
local function CreateDragonUIButton()
    -- Verificar que no se haya creado ya
    if dragonUIButton or buttonAdded then 
        return true 
    end
    
    -- Verificar que GameMenuFrame esté disponible
    if not GameMenuFrame then 
        return false 
    end
    
    -- Crear el botón con template apropiado para WoW 3.3.5a
    dragonUIButton = CreateFrame("Button", "DragonUIGameMenuButton", GameMenuFrame, "GameMenuButtonTemplate")
    
    -- Configurar el texto del botón
    dragonUIButton:SetText("DragonUI")
    
    -- Configurar el ancho para que coincida con otros botones
    dragonUIButton:SetWidth(144) -- Ancho estándar de botones del game menu en 3.3.5a
    
    -- Aplicar colores azulados estilo Dragonflight
    local fontString = dragonUIButton:GetFontString()
    if fontString then
        -- Color azul dragonflight para el texto: RGB(100, 180, 255) 
        fontString:SetTextColor(0.39, 0.71, 1.0, 1.0)
        
        -- Efecto de sombra azul suave
        fontString:SetShadowColor(0.2, 0.4, 0.8, 0.8)
        fontString:SetShadowOffset(1, -1)
        
        -- Fuente más pequeña
        fontString:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
    end
    
    -- Configurar colores de hover/pressed con fuente más pequeña
    if dragonUIButton.SetNormalFontObject then
        dragonUIButton:SetNormalFontObject("GameFontNormal")
        dragonUIButton:SetHighlightFontObject("GameFontHighlight") 
    end
    
    -- Intentar colorear el fondo del botón (compatible con 3.3.5a)
    local normalTexture = dragonUIButton:GetNormalTexture()
    if normalTexture then
        -- Tinte azul suave para el fondo: RGB(50, 100, 200) con alpha 0.8
        normalTexture:SetVertexColor(0.2, 0.4, 0.8, 0.8)
    end
    
    local highlightTexture = dragonUIButton:GetHighlightTexture()
    if highlightTexture then
        -- Tinte azul más brillante en hover: RGB(80, 140, 255) con alpha 0.9
        highlightTexture:SetVertexColor(0.31, 0.55, 1.0, 0.9)
    end
    
    -- Configurar efectos visuales adicionales para el hover
    dragonUIButton:SetScript("OnEnter", function(self)
        local fontString = self:GetFontString()
        if fontString then
            -- Color más brillante al hacer hover: RGB(150, 200, 255)
            fontString:SetTextColor(0.59, 0.78, 1.0, 1.0)
        end
    end)
    
    dragonUIButton:SetScript("OnLeave", function(self)
        local fontString = self:GetFontString()
        if fontString then
            -- Volver al color normal: RGB(100, 180, 255)
            fontString:SetTextColor(0.39, 0.71, 1.0, 1.0)
        end
    end)
    
    -- Configurar el click handler
    dragonUIButton:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then
            OpenDragonUIConfig()
        end
    end)
    
    -- Posicionar solo el botón DragonUI
    PositionDragonUIButton()
    
    buttonAdded = true

    return true
end

-- Función para intentar crear el botón con reintentos
local function TryCreateButton()
    local attempts = 0
    local maxAttempts = 5
    
    local function attempt()
        attempts = attempts + 1
        
        if CreateDragonUIButton() then
            return -- Éxito
        end
        
        if attempts < maxAttempts then
            -- Reintento con delay
            local frame = CreateFrame("Frame")
            local elapsed = 0
            frame:SetScript("OnUpdate", function(self, dt)
                elapsed = elapsed + dt
                if elapsed >= 0.5 then
                    self:SetScript("OnUpdate", nil)
                    attempt()
                end
            end)
        else
           
        end
    end
    
    attempt()
end

-- Event frame para manejar la inicialización
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")

eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "DragonUI" then
        -- Intentar agregar el botón después de que DragonUI se cargue
        TryCreateButton()
        
    elseif event == "PLAYER_LOGIN" then
        -- Segundo intento después del login
        local frame = CreateFrame("Frame")
        local elapsed = 0
        frame:SetScript("OnUpdate", function(self, dt)
            elapsed = elapsed + dt
            if elapsed >= 1.0 then
                self:SetScript("OnUpdate", nil)
                if not buttonAdded then
                    TryCreateButton()
                end
            end
        end)
        
        self:UnregisterEvent("PLAYER_LOGIN")
    end
end)

-- Hook al GameMenuFrame para intentar agregar el botón cuando se abre
local originalGameMenuShow = GameMenuFrame.Show
if originalGameMenuShow then
    GameMenuFrame.Show = function(self)
        originalGameMenuShow(self)
        
        -- Intentar crear el botón si no existe
        if not buttonAdded then
            CreateDragonUIButton()
        elseif dragonUIButton then
            -- Si ya existe, asegurar que esté visible
            dragonUIButton:Show()
            
            -- ⚠️ 每次打开菜单时都调整背景高度(因为ButtonPositioned防止了多次调整)
            local buttonHeight = dragonUIButton:GetHeight() or 16
            local spacing = 1
            local currentHeight = GameMenuFrame:GetHeight()
            local baseHeight = 320  -- GameMenuFrame的默认高度(3.3.5)
            
            -- 检查是否已经调整过高度
            if currentHeight < baseHeight + buttonHeight + 10 then
                local extraHeight = buttonHeight + spacing + 10  -- 底部边距改为10像素
                GameMenuFrame:SetHeight(baseHeight + extraHeight)
            end
        end
    end
end
