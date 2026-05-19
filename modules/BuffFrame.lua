--[[
    Original code by Dmitriy (RetailUI) - Licensed under MIT License
    Adapted for DragonUI
]]

local addon = select(2, ...);

--  CREAR MÓDULO USANDO EL SISTEMA DE DRAGONUI
local BuffFrameModule = {}
addon.BuffFrameModule = BuffFrameModule

--  VARIABLES LOCALES
local buffFrame = nil
local toggleButton = nil
local dragonUIBuffFrame = nil  --  NUESTRO FRAME CUSTOM COMO RETAILUI

--  Asegurar que addon._noop existe
if not addon._noop then
    addon._noop = function() return end
end

--  FUNCIÓN PARA REEMPLAZAR BUFFFRAME (IGUAL QUE RETAILUI)
local function ReplaceBlizzardFrame(frame)
    -- 让暴雪BuffFrame成为dragonUIBuffFrame的子框架，并锚定到左上角
    BuffFrame:SetParent(frame)
    BuffFrame:ClearAllPoints()
    BuffFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    addon:DebugInfo("BuffFrame", "暴雪BuffFrame已设置为dragonUIBuffFrame的子框架")
    
    frame.toggleButton = frame.toggleButton or CreateFrame('Button', nil, UIParent)
    toggleButton = frame.toggleButton
    toggleButton.toggle = true
    -- 按钮锚定在dragonUIBuffFrame的右边，这样BUFF在按钮左边
    toggleButton:SetPoint("LEFT", frame, "RIGHT", 3, 0)
    toggleButton:SetSize(9, 17)
    toggleButton:SetHitRectInsets(0, 0, 0, 0)
    
    addon:DebugInfo("BuffFrame", string.format("折叠按钮锚定: LEFT to dragonUIBuffFrame/RIGHT, offset: (3, 0)"))
    
    -- 输出dragonUIBuffFrame和暴雪BuffFrame的位置信息
    local frameX, frameY = frame:GetCenter()
    addon:DebugInfo("BuffFrame", string.format("dragonUIBuffFrame中心坐标: (%.1f, %.1f)", frameX or 0, frameY or 0))
    
    local buffX, buffY = BuffFrame:GetCenter()
    addon:DebugInfo("BuffFrame", string.format("暴雪BuffFrame中心坐标: (%.1f, %.1f)", buffX or 0, buffY or 0))
    
    -- 输出BuffButton1的位置
    local buff1 = _G["BuffButton1"]
    if buff1 then
        local b1X, b1Y = buff1:GetCenter()
        addon:DebugInfo("BuffFrame", string.format("BuffButton1中心坐标: (%.1f, %.1f)", b1X or 0, b1Y or 0))
    end

    local normalTexture = toggleButton:GetNormalTexture() or toggleButton:CreateTexture(nil, "BORDER")
    normalTexture:SetAllPoints(toggleButton)
    SetAtlasTexture(normalTexture, 'CollapseButton-Right')
    toggleButton:SetNormalTexture(normalTexture)

    local highlightTexture = toggleButton:GetHighlightTexture() or toggleButton:CreateTexture(nil, "HIGHLIGHT")
    highlightTexture:SetAllPoints(toggleButton)
    SetAtlasTexture(highlightTexture, 'CollapseButton-Right')
    toggleButton:SetHighlightTexture(highlightTexture)

    toggleButton:SetScript("OnClick", function(self)
        if self.toggle then
            local normalTexture = self:GetNormalTexture()
            SetAtlasTexture(normalTexture, 'CollapseButton-Left')
            local highlightTexture = toggleButton:GetHighlightTexture()
            SetAtlasTexture(highlightTexture, 'CollapseButton-Left')

            for index = 1, BUFF_ACTUAL_DISPLAY do
                local button = _G['BuffButton' .. index]
                if button then
                    button:Hide()
                end
            end
        else
            local normalTexture = self:GetNormalTexture()
            SetAtlasTexture(normalTexture, 'CollapseButton-Right')
            local highlightTexture = toggleButton:GetHighlightTexture()
            SetAtlasTexture(highlightTexture, 'CollapseButton-Right')

            for index = 1, BUFF_ACTUAL_DISPLAY do
                local button = _G['BuffButton' .. index]
                if button then
                    button:Show()
                end
            end
        end

        self.toggle = not self.toggle
    end)

    -- 7.3.5 compatibility: ConsolidatedBuffs may not exist
    if ConsolidatedBuffs then
        local consolidatedBuffFrame = ConsolidatedBuffs
        consolidatedBuffFrame:SetMovable(true)
        consolidatedBuffFrame:SetUserPlaced(true)
        consolidatedBuffFrame:ClearAllPoints()
        consolidatedBuffFrame:SetPoint("LEFT", toggleButton, "LEFT", -6, 0)
        
        --  Hook SetPoint to prevent external modifications
        local origConsolidatedSetPoint = consolidatedBuffFrame.SetPoint
        consolidatedBuffFrame.SetPoint = function(self, ...)
            -- Allow internal calls but block external ones
            local point, relativeTo = ...
            if relativeTo == toggleButton then
                return origConsolidatedSetPoint(self, ...)
            end
            addon:DebugInfo("BuffFrame", "Blocked ConsolidatedBuffs.SetPoint call")
        end
    end

    --  阻止暴雪代码在进出职业大厅时将 BuffFrame 重定父级回 UIParent
    --  和 vehicle.lua 的车辆座位指示器处理方法一致
    BuffFrame.SetParent = addon._noop

    --  同时阻止暴雪修改 BuffFrame 的锚点
    --  进出职业大厅时暴雪会尝试重新锚定 BuffFrame，导致 Buff 图标偏移到折叠按钮右侧
    local origBuffSetPoint = BuffFrame.SetPoint
    BuffFrame.SetPoint = function(self, ...)
        local arg1 = ...
        -- 允许无参调用（安全）和相对于 dragonUIBuffFrame 的锚点设置
        if arg1 == nil or arg1 == "TOPLEFT" then
            local _, relativeTo = ...
            if relativeTo == nil or relativeTo == dragonUIBuffFrame then
                return origBuffSetPoint(self, ...)
            end
        end
        addon:DebugInfo("BuffFrame", string.format("Blocked BuffFrame.SetPoint - args: %s", tostring(arg1)))
    end

    BuffFrame.ClearAllPoints = function(self)
        addon:DebugInfo("BuffFrame", "Blocked BuffFrame.ClearAllPoints")
        -- Don't allow clearing points, keep original anchor
    end
    
    --  Hook toggleButton methods to maintain correct positioning
    local origToggleSetPoint = toggleButton.SetPoint
    local origToggleClearAllPoints = toggleButton.ClearAllPoints
    local origToggleSetParent = toggleButton.SetParent
    
    toggleButton.SetParent = function(self, parent)
        -- Only allow UIParent as parent (initial setup)
        if parent == UIParent then
            return origToggleSetParent(self, parent)
        end
        addon:DebugInfo("BuffFrame", "Blocked toggleButton.SetParent call")
    end
    
    toggleButton.SetPoint = function(self, ...)
        local point, relativeTo = ...
        -- Only allow setting point relative to dragonUIBuffFrame
        if relativeTo == frame or relativeTo == dragonUIBuffFrame then
            return origToggleSetPoint(self, ...)
        end
        addon:DebugInfo("BuffFrame", string.format("Blocked toggleButton.SetPoint call - point: %s, relativeTo: %s", tostring(point), tostring(relativeTo)))
    end
    
    toggleButton.ClearAllPoints = function(self)
        addon:DebugInfo("BuffFrame", "Blocked toggleButton.ClearAllPoints call")
        -- Don't allow clearing points, keep original anchor
    end
end

--  FUNCIÓN PARA MOSTRAR/OCULTAR EL BOTÓN SEGÚN BUFFS (IGUAL QUE RETAILUI)
local function ShowToggleButtonIf(condition)
    if condition then
        dragonUIBuffFrame.toggleButton:Show()
    else
        dragonUIBuffFrame.toggleButton:Hide()
    end
end

--  FUNCIÓN PARA CONTAR BUFFS (IGUAL QUE RETAILUI)
local function GetUnitBuffCount(unit, range)
    local count = 0
    for index = 1, range do
        local name = UnitBuff(unit, index)
        if name then
            count = count + 1
        end
    end
    return count
end

--  FUNCIÓN PARA POSICIONAR EL BUFF FRAME (SIMPLIFICADA COMO RETAILUI)
function BuffFrameModule:UpdatePosition()
    if not dragonUIBuffFrame then
        addon:DebugInfo("BuffFrame", "UpdatePosition: dragonUIBuffFrame不存在")
        return
    end
    
    if not addon.db.profile.widgets then
        addon.db.profile.widgets = {}
    end
    if not addon.db.profile.widgets.buffs then
        addon.db.profile.widgets.buffs = {
            anchor = "TOPRIGHT",
            posX = -250,
            posY = -10
        }
    end

    local widgetOptions = addon.db.profile.widgets.buffs
    local defaultPosX = widgetOptions.posX or -250
    local defaultPosY = widgetOptions.posY or -20

    local inOrderHall = OrderHallCommandBar and OrderHallCommandBar:IsShown()

    local function ShouldShiftForOrderHall(frame, anchor, posY)
        if not inOrderHall then return false end
        local screenHeight = UIParent:GetHeight()
        local _, frameHeight = frame:GetSize()
        local barHeight = OrderHallCommandBar:GetHeight() or 0
        local frameTop = screenHeight + posY
        local barBottom = screenHeight - barHeight
        return (barBottom - frameTop) < 0
    end

    if ShouldShiftForOrderHall(dragonUIBuffFrame, widgetOptions.anchor, defaultPosY) then
        local barHeight = OrderHallCommandBar:GetHeight() or 0
        local adjustedPosY = defaultPosY - barHeight
        dragonUIBuffFrame:ClearAllPoints()
        dragonUIBuffFrame:SetPoint(widgetOptions.anchor, defaultPosX, adjustedPosY)
        addon:DebugInfo("BuffFrame", string.format("职业大厅模式 - 资源条高度: %.1f, buff Y偏移: %.1f (默认: %.1f)", barHeight, adjustedPosY, defaultPosY))
    else
        dragonUIBuffFrame:ClearAllPoints()
        dragonUIBuffFrame:SetPoint(widgetOptions.anchor, defaultPosX, defaultPosY)
        addon:DebugInfo("BuffFrame", string.format("野外模式 - buff复位到默认坐标: (%.1f, %.1f)", defaultPosX, defaultPosY))
    end
    
    local frameX, frameY = dragonUIBuffFrame:GetCenter()
    addon:DebugInfo("BuffFrame", string.format("UpdatePosition完成 - 中心坐标: (%.1f, %.1f)", frameX or 0, frameY or 0))
end

--  FUNCIÓN PARA HABILITAR/DESHABILITAR EL MÓDULO
function BuffFrameModule:Toggle(enabled)
    if not addon.db or not addon.db.profile then return end
    
    addon.db.profile.buffs.enabled = enabled
    
    if enabled then
        self:Enable()
    else
        self:Disable()
    end
end

--  FUNCIÓN PARA HABILITAR EL MÓDULO (IGUAL QUE RETAILUI)
function BuffFrameModule:Enable()
    -- 如果配置不存在，使用默认值true
    local enabled = true
    if addon.db.profile.buffs and addon.db.profile.buffs.enabled ~= nil then
        enabled = addon.db.profile.buffs.enabled
    end
    if not enabled then return end
    
    addon:DebugInfo("BuffFrame", "BUFF模块开始启用")
    
    --  CREAR BUFFFRAME USANDO CreateUIFrame (IGUAL QUE RETAILUI)
    dragonUIBuffFrame = addon.CreateUIFrame(BuffFrame:GetWidth(), BuffFrame:GetHeight(), "Auras")
    
    --  REGISTRAR EN SISTEMA CENTRALIZADO
    addon:RegisterEditableFrame({
        name = "buffs",
        frame = dragonUIBuffFrame,
        blizzardFrame = BuffFrame,
        configPath = {"widgets", "buffs"},
        onHide = function()
            self:UpdatePosition()
        end,
        module = self
    })

    --  POSICIONAR INMEDIATAMENTE (no esperar PLAYER_ENTERING_WORLD)
    BuffFrameModule:UpdatePosition()

    --  CONFIGURAR EVENTOS (IGUAL QUE RETAILUI)
    if not buffFrame then
        buffFrame = CreateFrame("Frame")
        buffFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        buffFrame:RegisterEvent("UNIT_AURA")
        buffFrame:RegisterEvent("UNIT_ENTERED_VEHICLE")
        buffFrame:RegisterEvent("UNIT_EXITED_VEHICLE")
        buffFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
        buffFrame:RegisterEvent("ORDER_HALL_LANDING_PAGE_SHOWN")
        buffFrame:RegisterEvent("ORDER_HALL_LANDING_PAGE_CLOSED")
        
        buffFrame:SetScript("OnEvent", function(self, event, unit)
            if event == "PLAYER_ENTERING_WORLD" then
                addon:DebugInfo("BuffFrame", "PLAYER_ENTERING_WORLD - 开始替换BuffFrame")
                ReplaceBlizzardFrame(dragonUIBuffFrame)
                addon:DebugInfo("BuffFrame", "折叠按钮已创建并锚定")
                ShowToggleButtonIf(GetUnitBuffCount("player", 16) > 0)
                BuffFrameModule:UpdatePosition()
            elseif event == "UNIT_AURA" then
                if unit == 'vehicle' then
                    ShowToggleButtonIf(GetUnitBuffCount("vehicle", 16) > 0)
                elseif unit == 'player' then
                    ShowToggleButtonIf(GetUnitBuffCount("player", 16) > 0)
                end
            elseif event == "UNIT_ENTERED_VEHICLE" then
                if unit == 'player' then
                    ShowToggleButtonIf(GetUnitBuffCount("vehicle", 16) > 0)
                end
            elseif event == "UNIT_EXITED_VEHICLE" then
                if unit == 'player' then
                    ShowToggleButtonIf(GetUnitBuffCount("player", 16) > 0)
                end
            elseif event == "ZONE_CHANGED_NEW_AREA" then
                addon:DebugInfo("BuffFrame", "ZONE_CHANGED_NEW_AREA - 强制重新应用锚点")
                BuffFrameModule:UpdatePosition()
                C_Timer.After(0.5, function()
                    BuffFrameModule:UpdatePosition()
                end)
                C_Timer.After(1.0, function()
                    BuffFrameModule:UpdatePosition()
                end)
                if toggleButton and dragonUIBuffFrame then
                    -- 使用 hook 前的原始方法强制设置锚点
                    local origSetPoint = getmetatable(toggleButton).__index.SetPoint
                    local origClearAllPoints = getmetatable(toggleButton).__index.ClearAllPoints
                    
                    origClearAllPoints(toggleButton)
                    origSetPoint(toggleButton, "LEFT", dragonUIBuffFrame, "RIGHT", 3, 0)
                    addon:DebugInfo("BuffFrame", "toggleButton 锚点已强制重新应用")

                    -- 重新设置 ConsolidatedBuffs 的锚点
                    if ConsolidatedBuffs then
                        local origConsolidatedSetPoint = getmetatable(ConsolidatedBuffs).__index.SetPoint
                        local origConsolidatedClearAllPoints = getmetatable(ConsolidatedBuffs).__index.ClearAllPoints

                        origConsolidatedClearAllPoints(ConsolidatedBuffs)
                        origConsolidatedSetPoint(ConsolidatedBuffs, "LEFT", toggleButton, "LEFT", -6, 0)
                        addon:DebugInfo("BuffFrame", "ConsolidatedBuffs 锚点已强制重新应用")
                    end

                    -- 重新设置 BuffFrame 锚点到 dragonUIBuffFrame 左上角
                    -- 暴雪在区域切换时会修改 BuffFrame 的锚点，导致 Buff 图标偏移
                    local origBuffSetPoint = getmetatable(BuffFrame).__index.SetPoint
                    local origBuffClearAllPoints = getmetatable(BuffFrame).__index.ClearAllPoints

                    origBuffClearAllPoints(BuffFrame)
                    origBuffSetPoint(BuffFrame, "TOPLEFT", dragonUIBuffFrame, "TOPLEFT", 0, 0)
                    addon:DebugInfo("BuffFrame", "BuffFrame 锚点已强制重新应用到 dragonUIBuffFrame 左上角")

                    -- 延迟重试，防止暴雪的异步布局更新覆盖我们的设置
                    addon.core:ScheduleTimer(function()
                        if not toggleButton or not dragonUIBuffFrame then return end
                        addon:DebugInfo("BuffFrame", "ZONE_CHANGED_NEW_AREA - 延迟重试重新应用锚点")

                        -- 重新应用 toggleButton 锚点
                        local tOrigSetPoint = getmetatable(toggleButton).__index.SetPoint
                        local tOrigClearAllPoints = getmetatable(toggleButton).__index.ClearAllPoints
                        tOrigClearAllPoints(toggleButton)
                        tOrigSetPoint(toggleButton, "LEFT", dragonUIBuffFrame, "RIGHT", 3, 0)

                        -- 重新应用 BuffFrame 锚点
                        local bfOrigSetPoint = getmetatable(BuffFrame).__index.SetPoint
                        local bfOrigClearAllPoints = getmetatable(BuffFrame).__index.ClearAllPoints
                        bfOrigClearAllPoints(BuffFrame)
                        bfOrigSetPoint(BuffFrame, "TOPLEFT", dragonUIBuffFrame, "TOPLEFT", 0, 0)

                        -- 重新应用 ConsolidatedBuffs 锚点
                        if ConsolidatedBuffs then
                            local cbOrigSetPoint = getmetatable(ConsolidatedBuffs).__index.SetPoint
                            local cbOrigClearAllPoints = getmetatable(ConsolidatedBuffs).__index.ClearAllPoints
                            cbOrigClearAllPoints(ConsolidatedBuffs)
                            cbOrigSetPoint(ConsolidatedBuffs, "LEFT", toggleButton, "LEFT", -6, 0)
                        end

                        addon:DebugInfo("BuffFrame", "ZONE_CHANGED_NEW_AREA - 延迟重试完成")
                    end, 0.5)
                end
            elseif event == "ORDER_HALL_LANDING_PAGE_SHOWN" then
                C_Timer.After(0.5, function()
                    BuffFrameModule:UpdatePosition()
                    C_Timer.After(0.3, function()
                        BuffFrameModule:UpdatePosition()
                    end)
                    C_Timer.After(0.8, function()
                        BuffFrameModule:UpdatePosition()
                    end)
                end)
            elseif event == "ORDER_HALL_LANDING_PAGE_CLOSED" then
                C_Timer.After(0.3, function()
                    BuffFrameModule:UpdatePosition()
                end)
            end
        end)
    end

    if _G.UIParent_UpdateTopFramePositions and not BuffFrameModule.orderHallHooked then
        hooksecurefunc("UIParent_UpdateTopFramePositions", function()
            if not InCombatLockdown() and dragonUIBuffFrame then
                C_Timer.After(0.1, function()
                    BuffFrameModule:UpdatePosition()
                end)
            end
        end)
        BuffFrameModule.orderHallHooked = true
        addon:DebugInfo("BuffFrame", "已注册 UIParent_UpdateTopFramePositions hook")
    end
    
end

--  FUNCIÓN PARA DESHABILITAR EL MÓDULO (SIMPLIFICADA)
function BuffFrameModule:Disable()
    if buffFrame then
        buffFrame:UnregisterAllEvents()
        buffFrame:SetScript("OnEvent", nil)
        buffFrame = nil
    end
    
    if toggleButton then
        toggleButton:Hide()
        toggleButton = nil
    end
    
    if dragonUIBuffFrame then
        dragonUIBuffFrame:Hide()
        dragonUIBuffFrame = nil
    end
    
    
end

--  INICIALIZACIÓN AUTOMÁTICA
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "DragonUI" then
        -- 初始化buffs配置（如果不存在）
        if not addon.db.profile.buffs then
            addon.db.profile.buffs = {
                enabled = true,
                show_toggle_button = true
            }
            addon:DebugInfo("BuffFrame", "初始化buffs配置为默认值")
        end
        
        -- 启用模块（现在配置肯定存在了）
        BuffFrameModule:Enable()
        self:UnregisterEvent("ADDON_LOADED")
    end
end)

--  FUNCIÓN PARA SER LLAMADA DESDE OPTIONS.LUA
function addon:RefreshBuffFrame()
    if BuffFrameModule and addon.db.profile.buffs.enabled then
        BuffFrameModule:UpdatePosition()
    end
end