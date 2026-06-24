local addon = select(2, ...);

-- Create addon object using AceAddon
addon.core = LibStub("AceAddon-3.0"):NewAddon("DragonUI", "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0");

-- ============================================================================
-- TEXTURE ATLAS SYSTEM (7.3.5 Compatibility)
-- ============================================================================
-- Atlas data is defined in utils/atlas.lua → addon.atlasinfo
-- Atlas data structure: {texture_path, width, height, left, right, top, bottom, horizTile, vertTile}

-- SetAtlas method for textures (mimics WoW 7.3.5+ SetAtlas API)
local function SetAtlas(texture, atlasName, useAtlasSize)
    local atlas = addon.atlasinfo and addon.atlasinfo[atlasName]
    if not atlasName or not atlas then
        texture:SetTexture(nil)
        return
    end

    local texPath, width, height, left, right, top, bottom, horizTile, vertTile = unpack(atlas)

    texture:SetTexture(texPath)
    texture:SetTexCoord(left, right, top, bottom)
    texture:SetHorizTile(horizTile or false)
    texture:SetVertTile(vertTile or false)

    if useAtlasSize and width and height then
        texture:SetWidth(width)
        texture:SetHeight(height)
    end
end

-- Add SetAtlas method to all texture objects
local textureMetatable = getmetatable(UIParent:CreateTexture()).__index
if textureMetatable and not textureMetatable.set_atlas then
    textureMetatable.set_atlas = SetAtlas
end
addon.SetAtlas = SetAtlas

-- Order hall area IDs for Legion class halls (used by multiple modules)
addon.ORDER_HALL_AREA_IDS = {
    [7272] = true, [7572] = true,  -- Mage - Hall of the Guardian
    [7871] = true,                  -- Hunter - The Lodge
    [7872] = true,                  -- Druid - The Dreamgrove
    [7874] = true,                  -- Shaman - The Grand Hall
    [7875] = true,                  -- Paladin - Sanctum of Light
    [7876] = true,                  -- Monk - The Hall of Preservation
    [7877] = true,                  -- Warlock - The Fel Hammer
    [7878] = true,                  -- Priest - Netherlight Temple
    [7879] = true,                  -- Warrior - Skyhold
    [7880] = true,                  -- Death Knight - Acherus: The Ebon Hold
    [7881] = true,                  -- Demon Hunter - Mardum
    [7917] = true,                  -- Rogue - Hall of Shadows
}
function addon:IsInClassHall(areaID)
    areaID = areaID or GetCurrentMapAreaID()
    return addon.ORDER_HALL_AREA_IDS[areaID] == true
end

-- ===============================================================
-- UNIFIED ORDER HALL COMMAND BAR MANAGER
-- Ensures the bar only shows inside actual class halls, and
-- provides a single point of control for all modules.
-- Fixes hunter/rogue "walking out" cases where sub-zone changes
-- don't trigger a loading screen and the bar can get stuck.
-- ===============================================================
local orderHallManager = {
    initialized = false,
    hideTimerHandle = nil,
}

local function CheckAndHideBarIfNeeded(source)
    if not OrderHallCommandBar then return end
    if not OrderHallCommandBar:IsShown() then return end

    -- If we haven't hooked :Show() yet, do it now
    -- (the bar might have been created after our init ran)
    if not orderHallManager.hookedShow then
        hooksecurefunc(OrderHallCommandBar, "Show", function()
            C_Timer.After(0, function()
                CheckAndHideBarIfNeeded("ShowHook")
                addon.core:SendMessage("DRAGONUI_ORDER_HALL_CHANGED")
            end)
        end)
        orderHallManager.hookedShow = true
    end

    local areaID = GetCurrentMapAreaID()
    if not addon:IsInClassHall(areaID) then
        OrderHallCommandBar:Hide()
        if addon.DebugInfo then
            addon:DebugInfo("OrderHallManager", string.format("资源条已隐藏 (来源: %s, areaID: %d)", source or "unknown", areaID or 0))
        end
        return true
    end
    return false
end

-- Schedules multiple retries to catch delayed bar shows (hunter/rogue fix)
local function ScheduleBarChecks(source)
    local delays = {0.1, 0.3, 0.5, 1.0, 1.5, 2.0}
    for i, delay in ipairs(delays) do
        C_Timer.After(delay, function()
            CheckAndHideBarIfNeeded(source .. "[" .. i .. "]")
            addon.core:SendMessage("DRAGONUI_ORDER_HALL_CHANGED")
        end)
    end
end

function addon:CheckOrderHallBar(source)
    CheckAndHideBarIfNeeded(source or "api")
    addon.core:SendMessage("DRAGONUI_ORDER_HALL_CHANGED")
end

function addon:ScheduleOrderHallChecks(source)
    ScheduleBarChecks(source or "api")
end

local function InitializeOrderHallManager()
    if orderHallManager.initialized then return end

    local f = CreateFrame("Frame")
    f:RegisterEvent("ZONE_CHANGED")
    f:RegisterEvent("ZONE_CHANGED_INDOORS")
    f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:RegisterEvent("ORDER_HALL_LANDING_PAGE_CLOSED")
    f:RegisterEvent("ORDER_HALL_LANDING_PAGE_SHOWN")

    f:SetScript("OnEvent", function(self, event, arg1)
        if event == "ZONE_CHANGED" or event == "ZONE_CHANGED_INDOORS" then
            -- Hunter / Rogue: sub-zone change with no loading screen
            CheckAndHideBarIfNeeded(event)
            ScheduleBarChecks(event)
        elseif event == "ZONE_CHANGED_NEW_AREA" or event == "PLAYER_ENTERING_WORLD" then
            -- Full zone change with loading screen
            ScheduleBarChecks(event)
        elseif event == "ORDER_HALL_LANDING_PAGE_CLOSED" or event == "ORDER_HALL_LANDING_PAGE_SHOWN" then
            -- After interacting with the landing page
            ScheduleBarChecks(event)
        end
    end)

    -- Also hook if the bar already exists (e.g. reload inside order hall)
    if OrderHallCommandBar and not orderHallManager.hookedShow then
        hooksecurefunc(OrderHallCommandBar, "Show", function()
            C_Timer.After(0, function()
                CheckAndHideBarIfNeeded("ShowHook")
                addon.core:SendMessage("DRAGONUI_ORDER_HALL_CHANGED")
            end)
        end)
        orderHallManager.hookedShow = true
    end

    -- Initial cleanup for /reload cases
    C_Timer.After(0.5, function()
        CheckAndHideBarIfNeeded("init")
        addon.core:SendMessage("DRAGONUI_ORDER_HALL_CHANGED")
    end)

    orderHallManager.initialized = true
end

addon.InitializeOrderHallManager = InitializeOrderHallManager

-- Function to recursively copy tables
local function deepCopy(source, target)
    for key, value in pairs(source) do
        if type(value) == "table" then
            if not target[key] then
                target[key] = {}
            end
            deepCopy(value, target[key])
        else
            target[key] = value
        end
    end
end

function addon.core:OnInitialize()
    -- Replace the temporary addon.db with the real AceDB
    addon.db = LibStub("AceDB-3.0"):New("DragonUIDB", addon.defaults);

    -- Force defaults to be written to profile for new/missing widgets
    if addon.defaults and addon.defaults.profile and addon.defaults.profile.widgets then
        for widgetName, widgetDefaults in pairs(addon.defaults.profile.widgets) do
            if not addon.db.profile.widgets or not addon.db.profile.widgets[widgetName] then
                if not addon.db.profile.widgets then
                    addon.db.profile.widgets = {}
                end
                addon.db.profile.widgets[widgetName] = {}
                deepCopy(widgetDefaults, addon.db.profile.widgets[widgetName])
            end
        end
    end

    -- Register callbacks for configuration changes
    addon.db.RegisterCallback(addon, "OnProfileChanged", "RefreshConfig");
    addon.db.RegisterCallback(addon, "OnProfileCopied", "RefreshConfig");
    addon.db.RegisterCallback(addon, "OnProfileReset", "RefreshConfig");

    -- Apply current profile configuration immediately
    -- This ensures the profile is loaded when the addon starts
    addon:RefreshConfig();
end

function addon.core:OnEnable()
    -- Now we can safely create and register options (after all modules are loaded)
    
    addon.options = addon:CreateOptionsTable();
    

    -- Inject AceDBOptions into the profiles section
    local profilesOptions = LibStub("AceDBOptions-3.0"):GetOptionsTable(addon.db);
    addon.options.args.profiles = profilesOptions;
    addon.options.args.profiles.order = 10;

    LibStub("AceConfig-3.0"):RegisterOptionsTable("DragonUI", addon.options);
    LibStub("AceConfigDialog-3.0"):AddToBlizOptions("DragonUI", "DragonUI");

    -- Setup custom window size that's resistant to refreshes
    local AceConfigDialog = LibStub("AceConfigDialog-3.0")
    if AceConfigDialog then
        -- Track if user has manually resized the window
        local userHasResized = false
        local defaultWidth, defaultHeight = 900, 600

        -- Hook into the status table system that manages window state
        local function setupDragonUIWindowSize()
            local configFrame = AceConfigDialog.OpenFrames["DragonUI"]
            if configFrame and configFrame.frame then
                -- Check if user has manually resized (status table contains user's size)
                local statusWidth = configFrame.status.width
                local statusHeight = configFrame.status.height

                -- If status has size and it's different from our default, user has resized
                if statusWidth and statusHeight then
                    if statusWidth ~= defaultWidth or statusHeight ~= defaultHeight then
                        userHasResized = true
                    end
                end

                -- Only apply our custom size if user hasn't manually resized
                if not userHasResized then
                    configFrame.frame:SetWidth(defaultWidth)
                    configFrame.frame:SetHeight(defaultHeight)
                    configFrame.frame:ClearAllPoints()
                    configFrame.frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)

                    -- Update AceGUI's internal size tracking
                    configFrame.status.width = defaultWidth
                    configFrame.status.height = defaultHeight
                else
                    -- User has resized, just maintain their size and center position
                    configFrame.frame:ClearAllPoints()
                    configFrame.frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
                end
            end
        end

        -- Hook the status table application (runs on every refresh)
        local originalSetStatusTable = AceConfigDialog.SetStatusTable
        AceConfigDialog.SetStatusTable = function(self, appName, statusTable)
            local result = originalSetStatusTable(self, appName, statusTable)

            if appName == "DragonUI" then
                -- Apply our custom size after status is set
                setupDragonUIWindowSize()
            end

            return result
        end

        -- Hook the initial Open to set size immediately
        local originalOpen = AceConfigDialog.Open
        AceConfigDialog.Open = function(self, appName, ...)
            local result = originalOpen(self, appName, ...)

            if appName == "DragonUI" then
                -- Reset user resize flag on new window opening
                userHasResized = false
                -- Apply size IMMEDIATELY without delay
                setupDragonUIWindowSize()
            end

            return result
        end
    end

    -- Register slash commands
    self:RegisterChatCommand("dragonui", "SlashCommand");
    self:RegisterChatCommand("pi", "SlashCommand");

    -- Initialize unified Order Hall Command Bar manager
    -- (replaces the old per-module logic with a single robust system
    --  that properly handles hunter/rogue sub-zone transitions)
    if addon.InitializeOrderHallManager then
        addon.InitializeOrderHallManager()
    end

    -- Fire custom event to signal that DragonUI is fully initialized
    -- This ensures modules get the correct config values
    self:SendMessage("DRAGONUI_READY");
end

-- Callback function that refreshes all modules when configuration changes
function addon:RefreshConfig()
    -- Initialize cooldown system if it hasn't been already
    if addon.InitializeCooldowns then
        addon.InitializeCooldowns()
    end

    local failed = {};

    -- Try to apply each configuration and track failures
    if addon.RefreshMainbars then
        local success, err = pcall(addon.RefreshMainbars);
        if not success then
            table.insert(failed, "RefreshMainbars")
            if addon.DebugError then
                addon:DebugError("Core", "RefreshMainbars 失败: %s", tostring(err))
            end
        elseif addon.DebugSuccess then
            addon:DebugSuccess("Core", "RefreshMainbars 成功")
        end
    end

    if addon.RefreshButtons then
        local success, err = pcall(addon.RefreshButtons);
        if not success then
            table.insert(failed, "RefreshButtons")
        end
    end

    if addon.RefreshMicromenu then
        local success, err = pcall(addon.RefreshMicromenu);
        if not success then
            table.insert(failed, "RefreshMicromenu")
        end
    end

    if addon.RefreshMinimap then
        local success, err = pcall(addon.RefreshMinimap);
        if not success then
            table.insert(failed, "RefreshMinimap")
        end
    end

    if addon.RefreshTargetFrame then
        local success, err = pcall(addon.RefreshTargetFrame);
        if not success then
            table.insert(failed, "RefreshTargetFrame")
        end
    end

    if addon.RefreshFocusFrame then
        local success, err = pcall(addon.RefreshFocusFrame);
        if not success then
            table.insert(failed, "RefreshFocusFrame")
        end
    end

    if addon.RefreshToTFrame then
        local success, err = pcall(addon.RefreshToTFrame);
        if not success then
            table.insert(failed, "RefreshToTFrame")
        end
    end

    if addon.RefreshToFFrame then
        local success, err = pcall(addon.RefreshToFFrame);
        if not success then
            table.insert(failed, "RefreshToFFrame")
        end
    end

    if addon.RefreshPartyFrames then
        local success, err = pcall(addon.RefreshPartyFrames);
        if not success then
            table.insert(failed, "RefreshPartyFrames")
        end
    end

    if addon.RefreshStance then
        local success, err = pcall(addon.RefreshStance);
        if not success then
            table.insert(failed, "RefreshStance")
        end
    end

    if addon.RefreshPetbar then
        local success, err = pcall(addon.RefreshPetbar);
        if not success then
            table.insert(failed, "RefreshPetbar")
        end
    end

    if addon.RefreshVehicle then
        local success, err = pcall(addon.RefreshVehicle);
        if not success then
            table.insert(failed, "RefreshVehicle")
        end
    end

    if addon.RefreshMulticast then
        local success, err = pcall(addon.RefreshMulticast);
        if not success then
            table.insert(failed, "RefreshMulticast")
        end
    end

    if addon.RefreshExtraAction then
        local success, err = pcall(addon.RefreshExtraAction);
        if not success then
            table.insert(failed, "RefreshExtraAction")
        end
    end

    if addon.RefreshCooldowns then
        local success, err = pcall(addon.RefreshCooldowns);
        if not success then
            table.insert(failed, "RefreshCooldowns")
        end
    end

    if addon.RefreshXpBarPosition then
        pcall(addon.RefreshXpBarPosition)
    end

    if addon.RefreshRepBarPosition then
        pcall(addon.RefreshRepBarPosition)
    end

    if addon.RefreshArtifactBarPosition then
        pcall(addon.RefreshArtifactBarPosition)
    end

    if addon.RefreshMinimapTime then
        local success, err = pcall(addon.RefreshMinimapTime);
        if not success then
            table.insert(failed, "RefreshMinimapTime")
        end
    end

    if addon.RefreshBuffFrame then
        local success, err = pcall(addon.RefreshBuffFrame);
        if not success then
            table.insert(failed, "RefreshBuffFrame")
        end
    end

    -- If some configurations failed, retry them after 2 seconds (max 3 retries)
    if #failed > 0 then
        local retryCount = addon._refreshRetryCount or 0
        retryCount = retryCount + 1
        addon._refreshRetryCount = retryCount
        if retryCount <= 3 then
            addon.core:ScheduleTimer(function()
                for _, funcName in ipairs(failed) do
                    if addon[funcName] then
                        pcall(addon[funcName]);
                    end
                end
            end, 2);
        end
    else
        addon._refreshRetryCount = nil
    end
end

function addon.core:SlashCommand(input)
    if not input or input:trim() == "" then
        LibStub("AceConfigDialog-3.0"):Open("DragonUI");
    elseif input:lower() == "config" then
        LibStub("AceConfigDialog-3.0"):Open("DragonUI");
    elseif input:lower() == "edit" or input:lower() == "editor" then
        if addon.EditorMode then
            addon.EditorMode:Toggle();
        else
            self:Print("Editor mode not available. Make sure the editor_mode module is loaded.");
        end
    else
        self:Print("Commands:");
        self:Print("/dragonui config - Open configuration");
        self:Print("/dragonui edit - Toggle editor mode for moving UI elements");

    end
end

---------------------------------------------------
-- FUNCIONES GLOBALES PARA EL SISTEMA DE MOVILIDAD 
---------------------------------------------------

--  FUNCIÓN AUXILIAR PARA CONTAR ELEMENTOS EN TABLA
function addon:tcount(tbl)
    local count = 0
    for _ in pairs(tbl) do count = count + 1 end
    return count
end

function CreateUIFrame(width, height, frameName)
    local frame = CreateFrame("Frame", 'DragonUI_' .. frameName, UIParent)
    frame:SetSize(width, height)

    frame:RegisterForDrag("LeftButton")
    frame:EnableMouse(false)
    frame:SetMovable(false)
    frame:SetScript("OnDragStart", function(self, button)
        self:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()

        --  AUTO-SAVE: Buscar este frame en EditableFrames y guardar posición automáticamente
        for frameName, frameData in pairs(addon.EditableFrames) do
            if frameData.frame == self then
                -- Guardar posición automáticamente (isUserDrag=true → 标记edited禁用职业大厅补偿)
                if #frameData.configPath == 2 then
                    SaveUIFramePosition(frameData.frame, frameData.configPath[1], frameData.configPath[2], true)
                else
                    SaveUIFramePosition(frameData.frame, frameData.configPath[1], nil, true)
                end
                break
            end
        end
    end)

    frame:SetFrameLevel(100)
    frame:SetFrameStrata('FULLSCREEN')

    --  TEXTURA VERDE COMO RETAILUI
    do
        local texture = frame:CreateTexture(nil, 'BACKGROUND')
        texture:SetAllPoints(frame)
        --  CAMBIO: Usar textura sólida en lugar de border_buttons.tga
        texture:SetTexture(0, 1, 0, 0.3) -- Verde semi-transparente
        texture:Hide()
        frame.editorTexture = texture

        
    end

    --  TEXTO COMO RETAILUI
    do
        local fontString = frame:CreateFontString(nil, "BORDER", 'GameFontNormal')
        fontString:SetAllPoints(frame)
        fontString:SetText(frameName)
        fontString:Hide()
        frame.editorText = fontString
    end

    return frame
end

--  FRAMES REGISTRY COMO RETAILUI
addon.frames = {}

function ShowUIFrame(frame)
    frame:SetMovable(false)
    frame:EnableMouse(false)
    
    -- Safety check for editor overlay elements
    if frame.editorTexture then
        frame.editorTexture:Hide()
    end
    if frame.editorText then
        frame.editorText:Hide()
    end

    if addon.frames[frame] then
        for _, target in pairs(addon.frames[frame]) do
            target:SetAlpha(1)
        end
        addon.frames[frame] = nil
    end
end

function HideUIFrame(frame, exclude)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    
    -- Safety check for editor overlay elements
    if frame.editorTexture then
        frame.editorTexture:Show()
    end
    if frame.editorText then
        frame.editorText:Show()
    end

    addon.frames[frame] = {}
    exclude = exclude or {}

    for _, target in pairs(exclude) do
        target:SetAlpha(0)
        table.insert(addon.frames[frame], target)
    end
end

function SaveUIFramePosition(frame, configPath1, configPath2, isUserDrag)
    if not frame then

        return
    end

    local anchor, _, relativePoint, posX, posY = frame:GetPoint(1) -- Primer punto

    print("[DragonUI 保存位置] "..(configPath2 or configPath1).." anchor="..tostring(anchor).." relPt="..tostring(relativePoint).." posX="..tostring(posX).." posY="..tostring(posY).." numPoints="..tostring(frame:GetNumPoints()))

    --  MANEJAR RUTAS ANIDADAS (widgets.player)
    if configPath2 then
        -- Caso: SaveUIFramePosition(frame, "widgets", "player")
        if not addon.db.profile[configPath1] then
            addon.db.profile[configPath1] = {}
        end

        if not addon.db.profile[configPath1][configPath2] then
            addon.db.profile[configPath1][configPath2] = {}
        end

        local config = addon.db.profile[configPath1][configPath2]
        config.anchor = anchor or "CENTER"
        config.posX = posX or 0
        config.posY = posY or 0
        if isUserDrag then
            config.edited = true -- 标记为用户手动拖动，禁用职业大厅自动下移
        end


    else
        -- Caso: SaveUIFramePosition(frame, "minimap") - compatibilidad hacia atrás
        local widgetName = configPath1

        if not addon.db.profile.widgets then
            addon.db.profile.widgets = {}
        end

        if not addon.db.profile.widgets[widgetName] then
            addon.db.profile.widgets[widgetName] = {}
        end

        addon.db.profile.widgets[widgetName].anchor = anchor or "CENTER"
        addon.db.profile.widgets[widgetName].posX = posX or 0
        addon.db.profile.widgets[widgetName].posY = posY or 0
        if isUserDrag then
            addon.db.profile.widgets[widgetName].edited = true -- 标记为用户手动拖动
        end


    end
end

function CheckSettingsExists(moduleInstance, widgets)
    for _, widget in pairs(widgets) do
        if not addon.db.profile.widgets[widget] then
            moduleInstance:LoadDefaultSettings()
            break
        end
    end
    moduleInstance:UpdateWidgets()
end

function ApplyUIFramePosition(frame, configPath)
    if not frame or not configPath then
        return
    end

    local section, key = configPath:match("([^%.]+)%.([^%.]+)")
    if not section or not key then
        return
    end

    local config = addon.db.profile[section] and addon.db.profile[section][key]
    if not config or not config.override then
        return
    end

    frame:ClearAllPoints()
    frame:SetPoint(config.anchor or "CENTER", UIParent, config.anchorParent or "CENTER", config.x or 0, config.y or 0)
end

function CheckSettingsExists(moduleTable, configPaths)
    local needsDefaults = false

    for _, configPath in pairs(configPaths) do
        local section, key = configPath:match("([^%.]+)%.([^%.]+)")
        if section and key then
            if not addon.db.profile[section] or not addon.db.profile[section][key] then
                needsDefaults = true
                break
            end
        end
    end

    if needsDefaults and moduleTable.LoadDefaultSettings then
        moduleTable:LoadDefaultSettings()
    end

    if moduleTable.UpdateWidgets then
        moduleTable:UpdateWidgets()
    end
end

---------------------------------------------------
-- SISTEMA CENTRALIZADO DE FRAMES EDITABLES (EXTENDIDO)
---------------------------------------------------

--  REGISTRO GLOBAL DE TODOS LOS FRAMES EDITABLES
addon.EditableFrames = {}

--  FUNCIÓN PARA REGISTRAR FRAMES AUTOMÁTICAMENTE
function addon:RegisterEditableFrame(frameInfo)
    local frameData = {
        name = frameInfo.name,                    -- "player", "minimap", "target"
        frame = frameInfo.frame,                  -- El frame auxiliar
        blizzardFrame = frameInfo.blizzardFrame,  --  NUEVO: Frame real de Blizzard (opcional)
        configPath = frameInfo.configPath,       -- {"widgets", "player"} o {"unitframe", "target"}
        onShow = frameInfo.onShow,               -- Función opcional al mostrar editor
        onHide = frameInfo.onHide,               -- Función opcional al ocultar editor
        --  NUEVO: Funciones para mostrar/ocultar con datos fake
        showTest = frameInfo.showTest,           -- Función para mostrar con datos fake
        hideTest = frameInfo.hideTest,           -- Función para ocultar frame fake
        hasTarget = frameInfo.hasTarget,         -- Función para verificar si debe estar visible
        module = frameInfo.module                -- Referencia al módulo
    }
    
    self.EditableFrames[frameInfo.name] = frameData

end

--  FUNCIÓN PARA MOSTRAR TODOS LOS FRAMES EN EDITOR MODE
function addon:ShowAllEditableFrames()
    for name, frameData in pairs(self.EditableFrames) do
        if frameData.frame then
            HideUIFrame(frameData.frame) -- Mostrar overlay verde
            
            --  NUEVO: Mostrar frame con datos fake si es necesario
            if frameData.showTest then
                frameData.showTest()
            end
            
            if frameData.onShow then
                frameData.onShow()
            end
        end
    end
    print("|cFF00FF00[DragonUI]|r 编辑模式已启用 - 可以拖动UI元素")
end

--  FUNCIÓN PARA OCULTAR TODOS LOS FRAMES Y GUARDAR POSICIONES
function addon:HideAllEditableFrames(refresh)
    for name, frameData in pairs(self.EditableFrames) do
        if frameData.frame then
            ShowUIFrame(frameData.frame) -- Ocultar overlay verde
            
            --  NUEVO: Ocultar frame fake si no debe estar visible
            if frameData.hideTest then
                frameData.hideTest()
            end
            
            if refresh then
                -- Guardar posición automáticamente
                if #frameData.configPath == 2 then
                    SaveUIFramePosition(frameData.frame, frameData.configPath[1], frameData.configPath[2])
                else
                    SaveUIFramePosition(frameData.frame, frameData.configPath[1])
                end
                
                if frameData.onHide then
                    frameData.onHide()
                end
            end
        end
    end
    print("|cFF00FF00[DragonUI]|r 编辑模式已关闭 - 位置已保存")
end

--  FUNCIÓN PARA VERIFICAR SI UN FRAME DEBE ESTAR VISIBLE
function addon:ShouldFrameBeVisible(frameName)
    local frameData = self.EditableFrames[frameName]
    if not frameData then return false end
    
    if frameData.hasTarget then
        return frameData.hasTarget()
    end
    
    -- Por defecto, los frames siempre están visibles (player, minimap)
    return true
end

--  FUNCIÓN PARA OBTENER INFORMACIÓN DE UN FRAME REGISTRADO
function addon:GetEditableFrameInfo(frameName)
    return self.EditableFrames[frameName]
end

--  EXPORTAR CreateUIFrame AL NAMESPACE ADDON PARA COMPATIBILIDAD
addon.CreateUIFrame = CreateUIFrame

---------------------------------------------------
---------------------------------------------------
