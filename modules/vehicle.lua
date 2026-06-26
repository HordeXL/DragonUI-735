local addon = select(2,...);
local config = addon.config;

-- ============================================================================
-- VEHICLE MODULE FOR DRAGONUI
-- Let Blizzard's native UI handle all vehicle/override bar display.
-- ============================================================================

-- Module state tracking
local VehicleModule = {
    applied = false,
}

-- ============================================================================
-- CONFIGURATION FUNCTIONS
-- ============================================================================

local function GetModuleConfig()
    return addon.db and addon.db.profile and addon.db.profile.modules and addon.db.profile.modules.vehicle
end

local function IsModuleEnabled()
    local cfg = GetModuleConfig()
    return cfg and cfg.enabled
end

-- ============================================================================
-- APPLY/RESTORE FUNCTIONS
-- ============================================================================

local function ApplyVehicleSystem()
    if VehicleModule.applied or not IsModuleEnabled() then return end
    -- Let Blizzard's native UI handle vehicle/override bar display
    VehicleModule.applied = true
end

local function RestoreVehicleSystem()
    if not VehicleModule.applied then return end
    VehicleModule.applied = false
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

function addon.RefreshVehicleSystem()
    if IsModuleEnabled() then
        if not VehicleModule.applied then
            ApplyVehicleSystem()
        end
    else
        RestoreVehicleSystem()
    end
end

function addon.RefreshVehicle()
    -- no-op, vehicles handled by Blizzard
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

-- Auto-initialize when addon loads
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self, event, addonName)
    if event == "ADDON_LOADED" and addonName == "DragonUI" then
        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_LOGIN" then
        if IsModuleEnabled() then
            ApplyVehicleSystem()
        end

        -- Set up profile callbacks
        if addon.db then
            addon.db.RegisterCallback(addon, "OnProfileChanged", function()
                addon.core:ScheduleTimer(function()
                    addon.RefreshVehicleSystem()
                end, 0.1)
            end)
            addon.db.RegisterCallback(addon, "OnProfileCopied", function()
                addon.core:ScheduleTimer(function()
                    addon.RefreshVehicleSystem()
                end, 0.1)
            end)
        end
    end
end)
