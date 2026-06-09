local addon = select(2, ...);

-- ============================================================================
-- EXTRA ACTION BUTTON MODULE FOR DRAGONUI
-- Controls the large quest special ability icon (ExtraActionButton1)
-- and Legion ZoneAbilityFrame (world quest bonus abilities)
-- ============================================================================

-- Module state tracking
local ExtraActionModule = {
    initialized = false,
    applied = false,
    originalStates = {},     -- Store original states for restoration
    registeredEvents = {},   -- Track registered events
    hooks = {},              -- Track hooked functions
    anchor = nil,            -- DragonUI anchor frame
    extraBar = nil           -- Child frame for ExtraActionBarFrame content
}

-- ============================================================================
-- CONFIGURATION FUNCTIONS
-- ============================================================================

local function GetModuleConfig()
    return addon.db and addon.db.profile and addon.db.profile.modules and addon.db.profile.modules.extraaction
end

local function IsModuleEnabled()
    local cfg = GetModuleConfig()
    return cfg and cfg.enabled
end

-- ============================================================================
-- ANCHOR FRAME CREATION
-- ============================================================================

local function CreateAnchorFrame()
    if ExtraActionModule.anchor then return ExtraActionModule.anchor end

    -- Use the widgets system for editor mode drag support
    local anchor = addon.CreateUIFrame(64, 64, "extraaction")
    ExtraActionModule.anchor = anchor

    -- Apply position from widgets config or use defaults
    local widgetConfig = addon.db and addon.db.profile and addon.db.profile.widgets and addon.db.profile.widgets.extraaction
    if widgetConfig and (widgetConfig.anchor or widgetConfig.posX ~= nil or widgetConfig.posY ~= nil) then
        local anchorPoint = widgetConfig.anchor or "CENTER"
        local posX = widgetConfig.posX or 0
        local posY = widgetConfig.posY or 0
        anchor:ClearAllPoints()
        anchor:SetPoint(anchorPoint, UIParent, anchorPoint, posX, posY)
    else
        -- Default: center of screen
        anchor:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end

    -- Create child frame to hold ExtraActionButton1
    local extraBar = CreateFrame('Frame', 'DragonUI_ExtraActionBar', UIParent, 'SecureHandlerStateTemplate')
    extraBar:SetAllPoints(anchor)
    ExtraActionModule.extraBar = extraBar

    return anchor
end

-- ============================================================================
-- POSITION FUNCTIONS
-- ============================================================================

local function UpdateAnchorPosition()
    if not IsModuleEnabled() then return end
    if not ExtraActionModule.anchor then return end

    local widgetConfig = addon.db and addon.db.profile and addon.db.profile.widgets and addon.db.profile.widgets.extraaction
    if widgetConfig and (widgetConfig.anchor or widgetConfig.posX ~= nil or widgetConfig.posY ~= nil) then
        local anchorPoint = widgetConfig.anchor or "CENTER"
        local posX = widgetConfig.posX or 0
        local posY = widgetConfig.posY or 0

        if not InCombatLockdown() then
            ExtraActionModule.anchor:ClearAllPoints()
            ExtraActionModule.anchor:SetPoint(anchorPoint, UIParent, anchorPoint, posX, posY)
        end
    else
        -- Fallback to default center position
        if not InCombatLockdown() then
            ExtraActionModule.anchor:ClearAllPoints()
            ExtraActionModule.anchor:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        end
    end
end

-- ============================================================================
-- EXTRA ACTION BUTTON SETUP
-- ============================================================================

local function ReparentExtraActionButton()
    if not IsModuleEnabled() then return end
    if not ExtraActionModule.anchor then return end
    if not ExtraActionButton1 then return end

    -- Store original state for restoration
    if not ExtraActionModule.originalStates.extraActionButton then
        ExtraActionModule.originalStates.extraActionButton = {
            parent = ExtraActionButton1:GetParent(),
            points = {}
        }
        for i = 1, ExtraActionButton1:GetNumPoints() do
            local point, relativeTo, relativePoint, x, y = ExtraActionButton1:GetPoint(i)
            table.insert(ExtraActionModule.originalStates.extraActionButton.points,
                {point, relativeTo, relativePoint, x, y})
        end
    end

    -- Reparent to our anchor
    if ExtraActionButton1:GetParent() ~= ExtraActionModule.extraBar then
        ExtraActionButton1:ClearAllPoints()
        ExtraActionButton1:SetParent(ExtraActionModule.extraBar)
        ExtraActionButton1:SetPoint("CENTER", ExtraActionModule.extraBar, "CENTER", 0, 0)
        ExtraActionButton1:SetFrameLevel(ExtraActionModule.extraBar:GetFrameLevel() + 1)
    end
end

-- ============================================================================
-- ZONE ABILITY FRAME SETUP (Legion 7.3.5)
-- ============================================================================

local function ReparentZoneAbilityFrame()
    if not IsModuleEnabled() then return end
    if not ExtraActionModule.anchor then return end

    -- ZoneAbilityFrame was added in Legion 7.0 for world quest bonuses
    local zoneFrame = _G["ZoneAbilityFrame"]
    local zoneButton = _G["ZoneAbilityButton"]
    if not zoneFrame and not zoneButton then return end

    -- Store original state for restoration
    if not ExtraActionModule.originalStates.zoneAbilityFrame and zoneFrame then
        ExtraActionModule.originalStates.zoneAbilityFrame = {
            parent = zoneFrame:GetParent(),
            points = {}
        }
        for i = 1, zoneFrame:GetNumPoints() do
            local point, relativeTo, relativePoint, x, y = zoneFrame:GetPoint(i)
            table.insert(ExtraActionModule.originalStates.zoneAbilityFrame.points,
                {point, relativeTo, relativePoint, x, y})
        end
    end

    -- Position ZoneAbilityFrame above the ExtraActionButton
    if zoneFrame and zoneFrame:GetParent() ~= ExtraActionModule.extraBar then
        zoneFrame:ClearAllPoints()
        zoneFrame:SetParent(ExtraActionModule.extraBar)
        zoneFrame:SetPoint("BOTTOM", ExtraActionModule.extraBar, "TOP", 0, 10)
    end
end

-- ============================================================================
-- VISIBILITY TRACKING
-- Watch ExtraActionBarFrame's show/hide to sync our anchor visibility
-- ============================================================================

local function UpdateVisibilityFromBlizzard()
    if not IsModuleEnabled() or not ExtraActionModule.anchor then return end
    if not ExtraActionModule.extraBar then return end

    local extraBarFrame = _G["ExtraActionBarFrame"]
    if not extraBarFrame then
        -- No ExtraActionBarFrame at all in this WoW version; hide our frame
        ExtraActionModule.anchor:Hide()
        ExtraActionModule.extraBar:Hide()
        return
    end

    -- Mirror ExtraActionBarFrame visibility to our anchor
    if extraBarFrame:IsShown() then
        if not ExtraActionModule.anchor:IsShown() then
            ExtraActionModule.anchor:Show()
            ExtraActionModule.extraBar:Show()
        end
    else
        if ExtraActionModule.anchor:IsShown() then
            ExtraActionModule.anchor:Hide()
            ExtraActionModule.extraBar:Hide()
        end
    end
end

local visibilityUpdateFrame = nil
local function StartVisibilityWatcher()
    if visibilityUpdateFrame then return end

    visibilityUpdateFrame = CreateFrame("Frame")
    visibilityUpdateFrame:SetScript("OnUpdate", function(self, elapsed)
        self.nextCheck = (self.nextCheck or 0) + elapsed
        -- Check every 0.5 seconds to avoid performance issues
        if self.nextCheck < 0.5 then return end
        self.nextCheck = 0
        UpdateVisibilityFromBlizzard()
    end)
end

local function StopVisibilityWatcher()
    if visibilityUpdateFrame then
        visibilityUpdateFrame:SetScript("OnUpdate", nil)
        visibilityUpdateFrame = nil
    end
end

-- ============================================================================
-- HOOK EXTRA ACTION BAR UPDATES
-- ============================================================================

local function HookExtraActionUpdates()
    if ExtraActionModule.hooks.extraActionBarUpdate then return end

    -- Hook ExtraActionBar_Update to ensure our reparenting is maintained
    if _G["ExtraActionBar_Update"] then
        hooksecurefunc("ExtraActionBar_Update", function()
            if IsModuleEnabled() and ExtraActionModule.extraBar then
                ReparentExtraActionButton()
                -- Immediately sync visibility after Blizzard's update
                UpdateVisibilityFromBlizzard()
            end
        end)
        ExtraActionModule.hooks.extraActionBarUpdate = true
    end
end

-- ============================================================================
-- APPLY / RESTORE FUNCTIONS
-- ============================================================================

local function ApplyExtraActionSystem()
    if ExtraActionModule.applied or not IsModuleEnabled() then return end

    -- Don't touch protected frames during combat
    if InCombatLockdown() then
        local frame = CreateFrame("Frame")
        frame:RegisterEvent("PLAYER_REGEN_ENABLED")
        frame:SetScript("OnEvent", function(self)
            self:UnregisterEvent("PLAYER_REGEN_ENABLED")
            ApplyExtraActionSystem()
        end)
        return
    end

    -- Create anchor frame
    CreateAnchorFrame()
    if not ExtraActionModule.anchor then return end

    -- Reparent ExtraActionButton1 to our anchor
    -- NOTE: We do NOT reparent ExtraActionBarFrame — Blizzard manages its own
    -- show/hide. Instead we watch its visibility via OnUpdate.
    ReparentExtraActionButton()
    ReparentZoneAbilityFrame()

    -- Hook updates so reparenting is maintained after Blizzard updates
    HookExtraActionUpdates()

    -- Start watching ExtraActionBarFrame visibility to sync our anchor
    StartVisibilityWatcher()
    UpdateVisibilityFromBlizzard()

    ExtraActionModule.applied = true
end

local function RestoreExtraActionSystem()
    if not ExtraActionModule.applied then return end

    if InCombatLockdown() then
        local frame = CreateFrame("Frame")
        frame:RegisterEvent("PLAYER_REGEN_ENABLED")
        frame:SetScript("OnEvent", function(self)
            self:UnregisterEvent("PLAYER_REGEN_ENABLED")
            RestoreExtraActionSystem()
        end)
        return
    end

    -- Stop visibility watcher
    StopVisibilityWatcher()

    -- Restore ExtraActionButton1 to original state
    if ExtraActionModule.originalStates.extraActionButton and ExtraActionButton1 then
        local original = ExtraActionModule.originalStates.extraActionButton
        ExtraActionButton1:SetParent(original.parent or UIParent)
        ExtraActionButton1:ClearAllPoints()
        for _, pointData in ipairs(original.points) do
            local point, relativeTo, relativePoint, x, y = unpack(pointData)
            if relativeTo then
                ExtraActionButton1:SetPoint(point, relativeTo, relativePoint, x, y)
            end
        end
    end

    -- Restore ZoneAbilityFrame to original state
    local zoneFrame = _G["ZoneAbilityFrame"]
    if ExtraActionModule.originalStates.zoneAbilityFrame and zoneFrame then
        local original = ExtraActionModule.originalStates.zoneAbilityFrame
        zoneFrame:SetParent(original.parent or UIParent)
        zoneFrame:ClearAllPoints()
        for _, pointData in ipairs(original.points) do
            local point, relativeTo, relativePoint, x, y = unpack(pointData)
            if relativeTo then
                zoneFrame:SetPoint(point, relativeTo, relativePoint, x, y)
            end
        end
    end

    -- Hide DragonUI frames
    if ExtraActionModule.anchor then
        ExtraActionModule.anchor:Hide()
    end
    if ExtraActionModule.extraBar then
        ExtraActionModule.extraBar:Hide()
    end

    ExtraActionModule.anchor = nil
    ExtraActionModule.extraBar = nil
    ExtraActionModule.applied = false
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

-- Enhanced refresh function with module on/off control
function addon.RefreshExtraActionSystem()
    if IsModuleEnabled() then
        ApplyExtraActionSystem()
        if addon.RefreshExtraAction then
            addon.RefreshExtraAction()
        end
    else
        RestoreExtraActionSystem()
    end
end

-- Refresh function for position changes
function addon.RefreshExtraAction()
    if not IsModuleEnabled() or not ExtraActionModule.anchor then return end

    if InCombatLockdown() or UnitAffectingCombat("player") then return end

    UpdateAnchorPosition()
end

-- ============================================================================
-- EDITOR MODE INTEGRATION
-- ============================================================================

local function ShowExtraActionEditor()
    if not ExtraActionModule.anchor then return end
    -- Enable drag for editor mode
    ExtraActionModule.anchor:SetMovable(true)
    ExtraActionModule.anchor:EnableMouse(true)

    -- Show editor overlay
    if ExtraActionModule.anchor.editorTexture then
        ExtraActionModule.anchor.editorTexture:Show()
    end
    if ExtraActionModule.anchor.editorText then
        ExtraActionModule.anchor.editorText:Show()
    end
end

local function HideExtraActionEditor()
    if not ExtraActionModule.anchor then return end
    ExtraActionModule.anchor:SetMovable(false)
    ExtraActionModule.anchor:EnableMouse(false)

    if ExtraActionModule.anchor.editorTexture then
        ExtraActionModule.anchor.editorTexture:Hide()
    end
    if ExtraActionModule.anchor.editorText then
        ExtraActionModule.anchor.editorText:Hide()
    end

    -- Save position to widgets config
    if addon.SaveUIFramePosition then
        addon.SaveUIFramePosition(ExtraActionModule.anchor, "widgets", "extraaction")
    end
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

-- Register with editor system (before module is applied, frame will be set later)
if addon.RegisterEditableFrame then
    addon:RegisterEditableFrame({
        name = "extraaction",
        frame = nil,  -- Will be set when module applies
        configPath = {"widgets", "extraaction"},
        showTest = ShowExtraActionEditor,
        hideTest = HideExtraActionEditor
    })
end

-- Set up profile callbacks
if addon.db and addon.db.RegisterCallback then
    addon.db.RegisterCallback(addon, "OnProfileChanged", function()
        addon.RefreshExtraActionSystem()
    end)
    addon.db.RegisterCallback(addon, "OnProfileCopied", function()
        addon.RefreshExtraActionSystem()
    end)
    addon.db.RegisterCallback(addon, "OnProfileReset", function()
        addon.RefreshExtraActionSystem()
    end)
end

-- Auto-initialize when addon loads and player logs in
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self, event, addonName)
    if event == "ADDON_LOADED" and addonName == "DragonUI" then
        self.addonLoaded = true
    elseif event == "PLAYER_LOGIN" and self.addonLoaded then
        if IsModuleEnabled() then
            ApplyExtraActionSystem()
            -- Update editor frame registration with actual anchor
            if addon.EditableFrames and addon.EditableFrames.extraaction then
                addon.EditableFrames.extraaction.frame = ExtraActionModule.anchor
            end
        end
        self:UnregisterAllEvents()
    end
end)
