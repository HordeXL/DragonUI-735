local addon = select(2, ...)

-- ============================================================================
-- DRAGONUI TARGET OF TARGET FRAME MODULE - WoW 7.3.5
-- ============================================================================
-- Crea un frame ToT independiente en lugar de depender de TargetFrameToT,
-- que es un secure frame en 7.3.5 y causa problemas de visibilidad.

local Module = {
    frame = nil,
    healthBar = nil,
    powerBar = nil,
    nameText = nil,
    background = nil,
    border = nil,
    elite = nil,
    textSystem = nil,
    initialized = false,
    configured = false,
    eventsFrame = nil,
    updateThrottle = 0,
}

-- Cache frequently accessed globals
local TargetFrameToT = _G.TargetFrameToT

local TEXTURES = {
    BACKGROUND = "Interface\\AddOns\\DragonUI\\Textures\\UI-HUD-UnitFrame-TargetofTarget-PortraitOn-BACKGROUND",
    BORDER = "Interface\\AddOns\\DragonUI\\Textures\\UI-HUD-UnitFrame-TargetofTarget-PortraitOn-BORDER",
    BAR_PREFIX = "Interface\\AddOns\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-TargetofTarget-PortraitOn-Bar-",
}

local BOSS_COORDS = {
    elite = {0.001953125, 0.314453125, 0.322265625, 0.630859375},
    rare = {0.00390625, 0.31640625, 0.64453125, 0.953125},
    rareelite = {0.001953125, 0.388671875, 0.001953125, 0.31835937},
}

local POWER_MAP = {
    [0] = "Mana",
    [1] = "Rage",
    [2] = "Focus",
    [3] = "Energy",
    [6] = "RunicPower",
}

-- ============================================================================
-- UTILITY
-- ============================================================================

local function GetConfig()
    return addon:GetConfigValue("unitframe", "tot") or {}
end

-- ============================================================================
-- HIDE BLIZZARD NATIVE TOT FRAME
-- ============================================================================

local function HideBlizzardToT()
    if TargetFrameToT then
        -- Permanently hide all elements of the native ToT frame
        TargetFrameToT:Hide()
        TargetFrameToT:SetAlpha(0)
        
        -- Hide all child elements to prevent any rendering
        local children = {TargetFrameToT:GetChildren()}
        for _, child in ipairs(children) do
            if child and child.Hide then
                child:Hide()
            end
        end
        
        -- Hide specific known elements
        if TargetFrameToTHealthBar then TargetFrameToTHealthBar:Hide() end
        if TargetFrameToTManaBar then TargetFrameToTManaBar:Hide() end
        if TargetFrameToTPortrait then TargetFrameToTPortrait:Hide() end
        if TargetFrameToTNameBackground then TargetFrameToTNameBackground:Hide() end
        if TargetFrameToTTextureFrameTexture then TargetFrameToTTextureFrameTexture:Hide() end
        if TargetFrameToTBackground then TargetFrameToTBackground:Hide() end
        
        -- Unregister all events to prevent any updates
        TargetFrameToT:UnregisterAllEvents()
    end
end

-- Hook the Show method of TargetFrameToT to prevent it from ever showing
local function SetupBlizzardToTHooks()
    if TargetFrameToT and not TargetFrameToT.DragonUI_Hooked then
        -- Hook the Show method to prevent showing
        hooksecurefunc(TargetFrameToT, "Show", function()
            -- Immediately hide again
            TargetFrameToT:Hide()
            TargetFrameToT:SetAlpha(0)
        end)
        
        -- Also hook SetAlpha to prevent alpha changes
        hooksecurefunc(TargetFrameToT, "SetAlpha", function(self, alpha)
            if type(alpha) ~= "number" then return end
            if alpha > 0 then
                TargetFrameToT:SetAlpha(0)
            end
        end)
        
        TargetFrameToT.DragonUI_Hooked = true
    end
end

-- ============================================================================
-- SYNC CVAR WITH CUSTOM FRAME VISIBILITY
-- ============================================================================

local function SyncToTVisibility()
    -- Check the current CVar value for showing target of target
    local showToT = GetCVarBool("showTargetOfTarget")
    
    if Module.frame then
        if showToT then
            -- Only show if there's a valid target of target
            if UnitExists("targettarget") then
                Module.frame:Show()
            else
                Module.frame:Hide()
            end
        else
            -- Hide when CVar is disabled
            Module.frame:Hide()
        end
    end
end

-- ============================================================================
-- ANCHOR FRAME POSITIONING (derived from unitframe.tot)
-- ============================================================================

local function UpdateAnchorFromTotConfig(config)
    if not Module.totFrame or not Module.frame then
        return
    end
    local targetFrame = _G.TargetFrame
    if not targetFrame then
        return
    end
    local tfWidth, tfHeight = targetFrame:GetSize()
    local tfCenterX, tfCenterY = targetFrame:GetCenter()
    if not tfCenterX or not tfCenterY then
        return
    end
    -- TargetFrame BOTTOMLEFT absolute position
    local tfBLX = tfCenterX - (tfWidth / 2)
    local tfBLY = tfCenterY - (tfHeight / 2)
    -- ToT BOTTOMLEFT = TargetFrame BOTTOMLEFT + relative offset
    local totBLX = tfBLX + (config.x or 150)
    local totBLY = tfBLY + (config.y or -30)
    -- Anchor frame center = ToT frame center
    local totWidth, totHeight = Module.frame:GetSize()
    local centerX = totBLX + (totWidth / 2)
    local centerY = totBLY + (totHeight / 2)
    -- Position anchor frame
    Module.totFrame:ClearAllPoints()
    Module.totFrame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", centerX, centerY)
end

-- ============================================================================
-- CREATE FRAME (called once)
-- ============================================================================

local function CreateToTFrame()
    if Module.configured then
        return
    end

    -- Setup hooks to prevent Blizzard ToT from showing (do this first)
    SetupBlizzardToTHooks()
    -- Hide Blizzard native ToT frame
    HideBlizzardToT()

    local f = CreateFrame("Frame", "DragonUI_ToT", UIParent)
    f:SetSize(128, 64)
    f:SetFrameLevel(50)
    f:Hide()

    -- Background (BACKGROUND layer, lowest)
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture(TEXTURES.BACKGROUND)
    bg:SetAllPoints(f)
    Module.background = bg

    -- Border (BORDER layer — below ARTWORK bars, so it doesn't cover them)
    local border = f:CreateTexture(nil, "BORDER")
    border:SetTexture(TEXTURES.BORDER)
    border:SetAllPoints(f)
    Module.border = border

    -- 头像（ARTWORK 层，位于边框和覆盖层之间）
    local portrait = f:CreateTexture(nil, "ARTWORK")
    portrait:SetSize(33, 33)
    portrait:SetPoint("LEFT", f, "LEFT", 8, 8)
    Module.portrait = portrait

    -- Health bar
    local hb = CreateFrame("StatusBar", nil, f)
    hb:SetSize(70, 10)
    hb:SetPoint("LEFT", portrait, "RIGHT", 3, 2)
    hb:SetStatusBarTexture(TEXTURES.BAR_PREFIX .. "Health")
    hb:GetStatusBarTexture():SetDrawLayer("ARTWORK", 1)
    hb:SetMinMaxValues(0, 100)
    hb:SetValue(100)
    hb.SetStatusBarColor = function() end
    Module.healthBar = hb

    -- Power bar
    local pb = CreateFrame("StatusBar", nil, f)
    pb:SetSize(70, 8)
    pb:SetPoint("LEFT", portrait, "RIGHT", 2, -8)
    pb:SetStatusBarTexture(TEXTURES.BAR_PREFIX .. "Mana")
    pb:GetStatusBarTexture():SetDrawLayer("ARTWORK", 1)
    pb:SetMinMaxValues(0, 100)
    pb:SetValue(100)
    pb.SetStatusBarColor = function() end
    Module.powerBar = pb

    -- Name text (OVERLAY, on top of everything)
    local nt = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nt:SetPoint("BOTTOMLEFT", portrait, "TOPLEFT", 35, -10)
    nt:SetWidth(90)
    nt:SetJustifyH("LEFT")
    nt:SetTextColor(1.0, 0.82, 0.0, 1.0)
    Module.nameText = nt

    -- Elite decoration
    local eliteFrame = CreateFrame("Frame", nil, f)
    eliteFrame:SetSize(54, 54)
    eliteFrame:SetPoint("CENTER", portrait, "CENTER", 0, 0)
    local eliteTex = eliteFrame:CreateTexture(nil, "OVERLAY")
    eliteTex:Hide()
    Module.elite = eliteTex

    -- Position relative to TargetFrame (anchored to BOTTOMLEFT)
    local config = GetConfig()
    f:ClearAllPoints()
    f:SetPoint(config.anchor or "BOTTOMLEFT", _G.TargetFrame or UIParent, config.anchorParent or "BOTTOMLEFT", config.x or -50, config.y or -30)
    f:SetScale(config.scale or 1.0)

    Module.frame = f

    -- Setup text system
    if addon.TextSystem then
        Module.textSystem = addon.TextSystem.SetupFrameTextSystem("targettarget", "targettarget", f, hb, pb, "TargetFrameToT")
    end

    Module.configured = true
end

-- ============================================================================
-- UPDATE
-- ============================================================================

local function UpdateToT()
    local f = Module.frame
    if not f then
        return
    end

    -- Check CVar first - if disabled, hide the frame regardless of target existence
    local showToT = GetCVarBool("showTargetOfTarget")
    if not showToT then
        if f:IsShown() then
            f:Hide()
        end
        return
    end

    local isInEditMode = addon.EditorMode and addon.EditorMode:IsActive()

    if not UnitExists("targettarget") then
        if isInEditMode then
            -- 编辑模式：保留 showTest 设置的假数据，不更新
            return
        else
            if f:IsShown() then
                f:Hide()
            end
            return
        end
    end

    -- Position relative to TargetFrame
    local config = GetConfig()
    local targetFrame = _G.TargetFrame

    -- 检查是否在编辑模式（再次获取，确保一致性）
    -- isInEditMode 已在上方定义
    
    if isInEditMode and Module.totFrame then
        -- 编辑模式：根据编辑锚点帧的位置来定位实际 ToT 框体
        local point, relativeTo, relativePoint, xOfs, yOfs = Module.totFrame:GetPoint(1)
        if relativeTo then
            f:ClearAllPoints()
            f:SetPoint("CENTER", Module.totFrame, "CENTER", 0, 0)
            f:SetScale(config.scale or 1.0)
        end
    elseif targetFrame then
        -- 正常模式：相对于 TargetFrame 定位
        f:ClearAllPoints()
        f:SetPoint(config.anchor or "BOTTOMLEFT", targetFrame, config.anchorParent or "BOTTOMLEFT", config.x or 150, config.y or -30)
        f:SetScale(config.scale or 1.0)
    end

    -- Show
    if not f:IsShown() then
        f:Show()
    end

    -- Update portrait
    if Module.portrait then
        SetPortraitTexture(Module.portrait, "targettarget")
    end

    -- Update health bar (StatusBar handles SetTexCoord automatically)
    if Module.healthBar then
        local cur = UnitHealth("targettarget")
        local max = UnitHealthMax("targettarget")
        Module.healthBar:SetMinMaxValues(0, max > 0 and max or 100)
        Module.healthBar:SetValue(cur)

        local tex = Module.healthBar:GetStatusBarTexture()
        if tex then
            local texPath
            local config2 = GetConfig()
            if config2.classcolor and UnitIsPlayer("targettarget") then
                texPath = TEXTURES.BAR_PREFIX .. "Health-Status"
            else
                texPath = TEXTURES.BAR_PREFIX .. "Health"
            end
            if tex:GetTexture() ~= texPath then
                tex:SetTexture(texPath)
            end
            if config2.classcolor and UnitIsPlayer("targettarget") then
                local _, class = UnitClass("targettarget")
                local color = RAID_CLASS_COLORS[class]
                if color then
                    tex:SetVertexColor(color.r, color.g, color.b, 1)
                else
                    tex:SetVertexColor(1, 1, 1, 1)
                end
            else
                tex:SetVertexColor(1, 1, 1, 1)
            end
        end
    end

    -- Update power bar (StatusBar handles SetTexCoord automatically)
    if Module.powerBar then
        local powerType = UnitPowerType("targettarget")
        local cur = UnitPower("targettarget", powerType)
        local max = UnitPowerMax("targettarget", powerType)
        Module.powerBar:SetMinMaxValues(0, max > 0 and max or 100)
        Module.powerBar:SetValue(cur)

        local tex = Module.powerBar:GetStatusBarTexture()
        if tex then
            local powerName = POWER_MAP[powerType] or "Mana"
            tex:SetTexture(TEXTURES.BAR_PREFIX .. powerName)
            tex:SetVertexColor(1, 1, 1, 1)
        end
    end

    -- Update name
    if Module.nameText then
        local name = UnitName("targettarget")
        Module.nameText:SetText(name or "")
        local font, _, flags = Module.nameText:GetFont()
        if font then
            Module.nameText:SetFont(font, 11, flags)
        end
    end

    -- Update classification
    if Module.elite then
        local classification = UnitClassification("targettarget")
        local coords = nil
        if classification == "worldboss" or classification == "elite" then
            coords = BOSS_COORDS.elite
        elseif classification == "rareelite" then
            coords = BOSS_COORDS.rareelite
        elseif classification == "rare" then
            coords = BOSS_COORDS.rare
        end

        if coords then
            Module.elite:SetTexture("Interface\\AddOns\\DragonUI\\Textures\\uiunitframeboss2x")
            local left, right, top, bottom = coords[1], coords[2], coords[3], coords[4]
            Module.elite:SetTexCoord(right, left, top, bottom)
            Module.elite:SetSize(51, 51)
            Module.elite:SetPoint("CENTER", f, "LEFT", 28, 0)
            Module.elite:SetDrawLayer("OVERLAY", 11)
            Module.elite:Show()
        else
            Module.elite:Hide()
        end
    end

    -- Update text system (health/power text)
    if Module.textSystem then
        Module.textSystem.update()
    end
end

-- ============================================================================
-- ONUPDATE (throttled)
-- ============================================================================

local function OnUpdate(self, elapsed)
    Module.updateThrottle = Module.updateThrottle + elapsed
    if Module.updateThrottle < 0.2 then
        return
    end
    Module.updateThrottle = 0
    UpdateToT()
end

-- ============================================================================
-- EVENTS
-- ============================================================================

local function OnEvent(self, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name == "DragonUI" and not Module.initialized then
            -- Create anchor frame for editor mode using addon.CreateUIFrame (enables dragging)
            Module.totFrame = addon.CreateUIFrame(128, 64, "ToT_Anchor")
            Module.initialized = true
            
            -- Hide Blizzard native ToT frame immediately
            HideBlizzardToT()

            -- Register with centralized system
            addon:RegisterEditableFrame({
                name = "tot",
                frame = Module.totFrame,
                configPath = {"widgets", "tot"},
                -- 移除 hasTarget 限制，让编辑框始终可见
                -- 添加 showTest/hideTest 来显示/隐藏假数据
                showTest = function()
                    -- 在编辑模式下强制显示 ToT 框体（即使没有目标）
                    if Module.frame and not UnitExists("targettarget") then
                        Module.frame:Show()
                        -- 设置假数据用于预览
                        if Module.portrait then
                            SetPortraitTexture(Module.portrait, "player")  -- 使用玩家头像作为示例
                        end
                        if Module.nameText then
                            Module.nameText:SetText("")
                        end
                        if Module.healthBar then
                            Module.healthBar:SetMinMaxValues(0, 100)
                            Module.healthBar:SetValue(75)
                        end
                        if Module.powerBar then
                            Module.powerBar:SetMinMaxValues(0, 100)
                            Module.powerBar:SetValue(50)
                        end
                    end
                end,
                hideTest = function()
                    -- 退出编辑模式时，如果没有真实目标则隐藏
                    if Module.frame and not UnitExists("targettarget") then
                        Module.frame:Hide()
                    end
                end,
                -- 进入编辑模式时，根据 unitframe.tot 的相对偏移定位锚点帧
                onShow = function()
                    UpdateAnchorFromTotConfig(GetConfig())
                end,
                -- 自定义 onHide 来处理位置同步
                onHide = function()
                    -- 当退出编辑模式时，将编辑锚点帧的位置转换回 unitframe.tot 配置
                    if Module.totFrame and Module.frame then
                        -- 获取编辑锚点帧的中心坐标（相对于 UIParent BOTTOMLEFT）
                        local totCenterX, totCenterY = Module.totFrame:GetCenter()
                        
                        if totCenterX and totCenterY then
                            -- 获取 TargetFrame 的位置
                            local targetFrame = _G.TargetFrame
                            if targetFrame and targetFrame:IsShown() then
                                -- TargetFrame 的 BOTTOMLEFT 坐标
                                local tfWidth, tfHeight = targetFrame:GetSize()
                                local tfCenterX, tfCenterY = targetFrame:GetCenter()
                                
                                if tfCenterX and tfCenterY then
                                    local tfBLX = tfCenterX - (tfWidth / 2)
                                    local tfBLY = tfCenterY - (tfHeight / 2)
                                    
                                    -- ToT 框体的尺寸
                                    local totWidth, totHeight = Module.frame:GetSize()
                                    
                                    -- ToT 的 BOTTOMLEFT 坐标（因为编辑锚点帧中心对齐 ToT 中心）
                                    local totBLX = totCenterX - (totWidth / 2)
                                    local totBLY = totCenterY - (totHeight / 2)
                                    
                                    -- 计算相对于 TargetFrame BOTTOMLEFT 的偏移
                                    local relX = totBLX - tfBLX
                                    local relY = totBLY - tfBLY
                                    
                                    -- 保存到 unitframe.tot 配置
                                    addon:SetConfigValue("unitframe", "tot", "x", math.floor(relX))
                                    addon:SetConfigValue("unitframe", "tot", "y", math.floor(relY))
                                    addon:SetConfigValue("unitframe", "tot", "anchor", "BOTTOMLEFT")
                                    addon:SetConfigValue("unitframe", "tot", "anchorParent", "BOTTOMLEFT")
                                    
                                    print(string.format("[DragonUI] ToT 位置已保存: x=%.0f, y=%.0f (相对于 TargetFrame BOTTOMLEFT)", relX, relY))
                                end
                            else
                                -- 如果 TargetFrame 不可见，保存为相对于 UIParent 的位置
                                print("[DragonUI] 警告: TargetFrame 不可见，ToT 位置可能不准确")
                            end
                        end
                    end
                end,
                module = Module,
            })
        end

    elseif event == "PLAYER_ENTERING_WORLD" then
        CreateToTFrame()
        -- Hide Blizzard native ToT frame again to ensure it stays hidden
        HideBlizzardToT()
        -- Setup hooks to prevent Blizzard ToT from showing
        SetupBlizzardToTHooks()
        -- Sync visibility based on CVar
        SyncToTVisibility()
        UpdateToT()

    elseif event == "PLAYER_TARGET_CHANGED" then
        -- Target changed, force immediate update
        Module.updateThrottle = 99 -- force update on next OnUpdate tick
        -- Also sync visibility based on CVar
        SyncToTVisibility()
        
    elseif event == "CVAR_UPDATE" then
        local cvarName, value = ...
        if cvarName == "SHOW_TARGET_OF_TARGET" or cvarName == "showTargetOfTarget" then
            -- Sync custom frame visibility with CVar change
            SyncToTVisibility()
        end
    end
end

-- init
if not Module.eventsFrame then
    Module.eventsFrame = CreateFrame("Frame")
    Module.eventsFrame:RegisterEvent("ADDON_LOADED")
    Module.eventsFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    Module.eventsFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    Module.eventsFrame:RegisterEvent("CVAR_UPDATE")
    Module.eventsFrame:SetScript("OnEvent", OnEvent)

    -- OnUpdate for continuous monitoring
    Module.eventsFrame:SetScript("OnUpdate", OnUpdate)
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

local function RefreshFrame()
    if not Module.configured then
        CreateToTFrame()
    end
    
    -- Ensure Blizzard ToT is still hidden
    HideBlizzardToT()
    SetupBlizzardToTHooks()
    
    -- Sync visibility based on CVar
    SyncToTVisibility()
    UpdateToT()
end

local function ResetFrame()
    local ufDefaults = addon.defaults.profile.unitframe.tot

    -- 重置 unitframe.tot 配置
    addon:SetConfigValue("unitframe", "tot", "x", ufDefaults.x)
    addon:SetConfigValue("unitframe", "tot", "y", ufDefaults.y)
    addon:SetConfigValue("unitframe", "tot", "scale", ufDefaults.scale)
    addon:SetConfigValue("unitframe", "tot", "anchor", ufDefaults.anchor)
    addon:SetConfigValue("unitframe", "tot", "anchorParent", ufDefaults.anchorParent)

    -- 更新实际 ToT 框体的位置
    if Module.frame then
        Module.frame:ClearAllPoints()
        Module.frame:SetPoint(ufDefaults.anchor, _G.TargetFrame, ufDefaults.anchorParent, ufDefaults.x, ufDefaults.y)
        Module.frame:SetScale(ufDefaults.scale)
    end

    -- 更新编辑锚点帧的位置（从 unitframe.tot 推算）
    UpdateAnchorFromTotConfig(ufDefaults)

    print("[DragonUI] ToT 位置已重置为默认值")
end

-- Export API
addon.TargetOfTarget = {
    Refresh = RefreshFrame,
    RefreshToTFrame = RefreshFrame,
    Reset = ResetFrame,
    anchor = function() return Module.totFrame end,
    ChangeToTFrame = RefreshFrame,
}

addon.unitframe = addon.unitframe or {}
addon.unitframe.ChangeToT = RefreshFrame
addon.unitframe.ReApplyToTFrame = RefreshFrame
addon.unitframe.StyleToTFrame = CreateToTFrame

function addon:RefreshToTFrame()
    RefreshFrame()
end
