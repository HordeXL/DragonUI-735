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
    
    -- 初始化widgets配置（如果不存在）
    if not addon.db.profile.widgets then
        addon.db.profile.widgets = {}
    end
    if not addon.db.profile.widgets.buffs then
        -- 使用database.lua中的默认值
        addon.db.profile.widgets.buffs = {
            anchor = "TOPRIGHT",
            posX = -260,
            posY = -20
        }
        addon:DebugInfo("BuffFrame", "初始化widgets.buffs配置为默认值")
    end
    
    local widgetOptions = addon.db.profile.widgets.buffs
    dragonUIBuffFrame:ClearAllPoints()
    dragonUIBuffFrame:SetPoint(widgetOptions.anchor, widgetOptions.posX, widgetOptions.posY)
    
    -- 输出定位后的坐标
    local frameX, frameY = dragonUIBuffFrame:GetCenter()
    addon:DebugInfo("BuffFrame", string.format("UpdatePosition完成 - dragonUIBuffFrame锚定: %s (%.1f, %.1f), 中心坐标: (%.1f, %.1f)", 
        widgetOptions.anchor, widgetOptions.posX, widgetOptions.posY, frameX or 0, frameY or 0))
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
    
    --  CONFIGURAR EVENTOS (IGUAL QUE RETAILUI)
    if not buffFrame then
        buffFrame = CreateFrame("Frame")
        buffFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        buffFrame:RegisterEvent("UNIT_AURA")
        buffFrame:RegisterEvent("UNIT_ENTERED_VEHICLE")
        buffFrame:RegisterEvent("UNIT_EXITED_VEHICLE")
        
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
            end
        end)
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