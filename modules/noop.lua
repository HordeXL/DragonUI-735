local addon = select(2,...);
local pairs = pairs;
local hooksecurefunc = hooksecurefunc;

-- Function to apply all noop changes
local function ApplyNoopChanges()
    MainMenuBar:EnableMouse(false)
    PetActionBarFrame:EnableMouse(false)
    -- 7.3.5 compatibility: ShapeshiftBarFrame was removed, replaced with StanceBar
    if ShapeshiftBarFrame then
        ShapeshiftBarFrame:EnableMouse(false)
    end
    if StanceBar then
        StanceBar:EnableMouse(false)
    end
    PossessBarFrame:EnableMouse(false)
    -- 7.3.5 compatibility: BonusActionBarFrame was removed
    if BonusActionBarFrame then
        BonusActionBarFrame:EnableMouse(false)
        BonusActionBarFrame:SetScale(0.001)
    end
    
    local elements_texture = {
        MainMenuXPBarTexture0,
        MainMenuXPBarTexture1,
        MainMenuXPBarTexture2,
        MainMenuXPBarTexture3,
        ReputationXPBarTexture0,
        ReputationXPBarTexture1,
        ReputationXPBarTexture2,
        ReputationXPBarTexture3,
        ReputationWatchBarTexture0,
        ReputationWatchBarTexture1,
        ReputationWatchBarTexture2,
        ReputationWatchBarTexture3,
    };for _,tex in pairs(elements_texture) do
        tex:SetTexture(nil)
    end;

    local elements = {
        MainMenuBar,
        MainMenuBarArtFrame,
        MainMenuBarOverlayFrame,
        VehicleMenuBar,
        -- VehicleMenuBarArtFrame,
        -- PossessBarFrame,
        PossessBackground1,
        PossessBackground2,
        PetActionBarFrame,
    }
    
    -- 7.3.5 compatibility: Add frames only if they exist
    if BonusActionBarFrame then
        table.insert(elements, BonusActionBarFrame)
    end
    if ShapeshiftBarFrame then
        table.insert(elements, ShapeshiftBarFrame)
    end
    if ShapeshiftBarLeft then
        table.insert(elements, ShapeshiftBarLeft)
    end
    if ShapeshiftBarMiddle then
        table.insert(elements, ShapeshiftBarMiddle)
    end
    if ShapeshiftBarRight then
        table.insert(elements, ShapeshiftBarRight)
    end
    if StanceBar then
        table.insert(elements, StanceBar)
    end
    
    for _,element in pairs(elements) do
        if element and element:GetObjectType() == 'Frame' then
            element:UnregisterAllEvents()
            if element == MainMenuBarArtFrame then
                element:RegisterEvent('CURRENCY_DISPLAY_UPDATE');
            end
        end
        if element and element ~= MainMenuBar then
            element:Hide()
        end
        if element then
            -- ⚠️ 关键修复：MainMenuBar 不能用 SetAlpha(0)
            -- 因为 ExtraActionButton1 等动态创建的子框架会继承父框架 alpha 而透明
            -- 改为只隐藏 MainMenuBar 自身的纹理，不影响后代子框架
            if element == MainMenuBar then
                for i = 1, element:GetNumRegions() do
                    local region = select(i, element:GetRegions())
                    if region and region:GetObjectType() == "Texture" then
                        region:SetAlpha(0)
                    end
                end
            else
                element:SetAlpha(0)
            end
        end
    end
    elements = nil
    
    local uiManagedFrames = {
        'MultiBarLeft',
        'MultiBarRight',
        'MultiBarBottomLeft',
        'MultiBarBottomRight',
        'ShapeshiftBarFrame',
        'PossessBarFrame',
        'PETACTIONBAR_YPOS',
        'MultiCastActionBarFrame',
        'MULTICASTACTIONBAR_YPOS',
    }
    local UIPARENT_MANAGED_FRAME_POSITIONS = UIPARENT_MANAGED_FRAME_POSITIONS;
    for _, frame in pairs(uiManagedFrames) do
        UIPARENT_MANAGED_FRAME_POSITIONS[frame] = nil
    end
    uiManagedFrames = nil

    if PlayerTalentFrame then
        PlayerTalentFrame:UnregisterEvent('ACTIVE_TALENT_GROUP_CHANGED')
    else
        hooksecurefunc('TalentFrame_LoadUI', function()
            PlayerTalentFrame:UnregisterEvent('ACTIVE_TALENT_GROUP_CHANGED')
        end)
    end
end

-- Check if noop module is enabled
local function IsNoopEnabled()
    return addon.db and addon.db.profile and addon.db.profile.modules and 
           addon.db.profile.modules.noop and addon.db.profile.modules.noop.enabled
end

-- Initialize noop when addon and config are ready
local function InitializeNoop()
    if IsNoopEnabled() then
        ApplyNoopChanges()
    end
end

-- Event frame to handle initialization
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self, event, addonName)
    if event == "ADDON_LOADED" and addonName == "DragonUI" then
        -- Config should be available now
        InitializeNoop()
        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_LOGIN" then
        -- Backup check in case config wasn't ready before
        InitializeNoop()
        self:UnregisterEvent("PLAYER_LOGIN")
    end
end)

-- Public API for options
function addon.RefreshNoopSystem()
    -- Since this requires reload, just inform the user
    
end