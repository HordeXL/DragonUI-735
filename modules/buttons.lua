local addon = select(2,...);
local config = addon.config;
local action = addon.functions;
local unpack = unpack;
local select = select;
local format = string.format;
local match = string.match;
-- 7.3.5 compatibility: Localize global variables for safe nil checks
local NUM_PET_ACTION_SLOTS = NUM_PET_ACTION_SLOTS;
local NUM_SHAPESHIFT_SLOTS = NUM_SHAPESHIFT_SLOTS;  -- May be nil in 7.3.5
local NUM_POSSESS_SLOTS = NUM_POSSESS_SLOTS;
local VEHICLE_MAX_ACTIONBUTTONS = VEHICLE_MAX_ACTIONBUTTONS;
local hooksecurefunc = hooksecurefunc;
local GetName = GetName;
local GetNumShapeshiftForms = GetNumShapeshiftForms;  -- Safe alternative for 7.3.5
local _G = getfenv(0);

-- ============================================================================
-- BUTTONS MODULE FOR DRAGONUI
-- ============================================================================

-- RANGE_INDICATOR = "•";

local actionbars = {
	'ActionButton',
	'MultiBarBottomLeftButton',
	'MultiBarBottomRightButton',
	'MultiBarRightButton',
	'MultiBarLeftButton',
};

-- Module state tracking
local ButtonsModule = {
    initialized = false,
    applied = false,
    originalValues = {},  -- Store original button states for restoration
    hooked = false,
    pendingRefresh = false  -- Flag to indicate pending refresh after combat
}

-- ============================================================================
-- CONFIGURATION FUNCTIONS
-- ============================================================================

local function GetModuleConfig()
    return addon.db and addon.db.profile and addon.db.profile.modules and addon.db.profile.modules.buttons
end

local function IsModuleEnabled()
    local cfg = GetModuleConfig()
    return cfg and cfg.enabled
end

local function GetButtonsConfig()
    return addon.db and addon.db.profile and addon.db.profile.buttons
end

-- ============================================================================
-- BUTTON ITERATOR
-- ============================================================================

addon.buttons_iterator = function()
	local index = 0
	local barIndex = 1
	return function()
		index = index + 1
		if index > 12 then
			index = 1
			barIndex = barIndex + 1
		end
		if actionbars[barIndex] then
			return _G[actionbars[barIndex]..index]
		end
	end
end

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

-- Helper function to detect if text contains CJK (Chinese, Japanese, Korean) characters
local function ContainsCJKCharacters(text)
    if not text or type(text) ~= "string" then return false end
    
    -- 检查常见的中文字符范围（UTF-8编码）
    -- 中文常用字符范围：U+4E00-U+9FFF (\xE4-\xE9 开头)
    -- 扩展A区：U+3400-U+4DBF
    -- 扩展B区及更高：U+20000+
    -- 日文平假名/片假名：U+3040-U+30FF
    -- 韩文：U+AC00-U+D7AF
    
    -- 更可靠的检测方法：查找任何非ASCII字符
    for i = 1, #text do
        local byte = text:byte(i)
        -- UTF-8多字节字符的第一个字节 >= 128
        if byte and byte >= 192 then
            return true
        end
    end
    
    return false
end

-- helper function to handle action button grid logic
-- 强制显示：只要模块启用，始终显示所有按钮的grid边框，不调用ActionButton_HideGrid
local function handleActionButton(button, wowAlwaysShow)
    if not IsModuleEnabled() then return end
    
    -- CRITICAL: Avoid taint during combat by not modifying protected frames
    if InCombatLockdown() then return end
    
    -- 强制显示所有按钮边框，无论是否有action或alwaysShowActionBars设置
    button:SetAttribute('showgrid', 1)
    ActionButton_ShowGrid(button)
end

function addon.actionbuttons_grid()
    if not IsModuleEnabled() then return end
    
    -- CRITICAL: Don't modify action buttons during combat to avoid taint
    if InCombatLockdown() then 
        ButtonsModule.pendingRefresh = true
        return 
    end
    
    local wowAlwaysShow = GetCVar("alwaysShowActionBars") == "1"
    local db = GetButtonsConfig()
    local hideMainBg = db and db.hide_main_bar_background
    
    -- 遍历所有动作条按钮（主动作条 + MultiBar系列），强制显示边框
    for button in addon.buttons_iterator() do
        if button then
            handleActionButton(button, wowAlwaysShow)
        end
    end
end

local function is_petaction(self, name)
	local spec = self:GetName():match(name)
	if (spec) then return true else return false end
end

local function fix_texture(self, texture)
    if not IsModuleEnabled() then return end
    
	if texture and texture ~= config.assets.normal then
		self:SetNormalTexture(config.assets.normal)
	end
end

local function setup_background(button, anchor, shadow)
    if not IsModuleEnabled() then return nil end
    
	if not button or button.shadow then return; end
	if shadow and not button.shadow then
		local shadow = button:CreateTexture(nil, 'ARTWORK', nil, 1)
		shadow:SetPoint('TOPRIGHT', anchor, 3.8, 3.8)
		shadow:SetPoint('BOTTOMLEFT', anchor, -3.8, -3.8)
		shadow:set_atlas('ui-hud-actionbar-iconframe-flyoutbordershadow', true)
		button.shadow = shadow;
	end

	local background = button:CreateTexture(nil, 'BACKGROUND');
	background:SetAllPoints(anchor);
	background:set_atlas('ui-hud-actionbar-iconframe-slot');
	background:Show();
	
	return background;
end

-- ============================================================================
-- KEY FORMATTING SYSTEM (Control total desde DragonUI)
-- ============================================================================

local GetKeyText
do
    local keyButton = string.gsub(KEY_BUTTON4 or "Button 4", '%d', '')
    local keyNumpad = string.gsub(KEY_NUMPAD1 or "NumPad 1", '%d', '')
    local displaySubs = {
        { '('..keyButton..')', 'M' },
        { '('..keyNumpad..')', 'N' },
        { '(a%-)', 'a' },           -- alt- -> a (minúscula)
        { '(c%-)', 'c' },           -- ctrl- -> c (minúscula)
        { '(s%-)', 's' },           -- shift- -> s (minúscula)
        { KEY_BUTTON3 or "Middle Mouse", 'M3' },
        { KEY_MOUSEWHEELUP or "Mouse Wheel Up", 'MU' },
        { KEY_MOUSEWHEELDOWN or "Mouse Wheel Down", 'MD' },
        { KEY_SPACE or "Space", 'BAR' },
        { CAPSLOCK_KEY_TEXT or "Caps Lock", 'CL' },
        { KEY_NUMLOCK or "Num Lock", 'NL' },
        { 'BUTTON', 'M' },
        { 'NUMPAD', 'N' },
        { '(ALT%-)', 'a' },         -- ALT- -> a (versión mayúscula)
        { '(CTRL%-)', 'c' },        -- CTRL- -> c 
        { '(SHIFT%-)', 's' },       -- SHIFT- -> s
        { 'MOUSEWHEELUP', 'MU' },
        { 'MOUSEWHEELDOWN', 'MD' },
        { 'SPACE', 'BAR' },
    }

    -- returns formatted key for text.
    -- @param key - a hotkey name
    function GetKeyText(key)
        if not key then return '' end
        for _, value in pairs(displaySubs) do
            key = string.gsub(key, value[1], value[2])
        end
        return key or error('invalid key string: '..tostring(key))
    end
end

-- Asignar a addon para acceso global
addon.GetKeyText = GetKeyText

-- ============================================================================
-- BUTTON STYLING FUNCTIONS
-- ============================================================================

local function actionbuttons_hotkey(button)
    if not IsModuleEnabled() then return end
    
	if not button then return end
	local buttonName = button:GetName()
	if not buttonName then return end
	
	local hotkey = _G[buttonName..'HotKey']
	if not hotkey then return end
	
	local text = hotkey:GetText()
	if not text then return end
	
	local db = GetButtonsConfig()
	if not db or not db.hotkey then return end
	
	if RANGE_INDICATOR and text == RANGE_INDICATOR then
		if db.hotkey.range then
			hotkey:SetText(RANGE_INDICATOR)
		else
			hotkey:SetText('')
		end
	else
		hotkey:SetAlpha(db.hotkey.show and 1 or 0)
		
		-- CONTROL TOTAL: Usar nuestro sistema de formato personalizado
		local formattedText = GetKeyText(text)
		hotkey:SetText(formattedText)
		
		if db.hotkey.font then
			-- Apply font with smart CJK detection for Chinese character support
			local fontToUse = db.hotkey.font
			
			-- If text contains CJK characters, use Chinese-compatible font
			if ContainsCJKCharacters(formattedText) then
				fontToUse = {'Fonts\\ARKai_T.ttf', 12, 'OUTLINE'}
			end
			
			local success = pcall(function()
				hotkey:SetFont(unpack(fontToUse))
			end)
			if not success then
				hotkey:SetFont('Fonts\\ARKai_T.ttf', 12, 'OUTLINE')
			end
		end
		
		hotkey:SetShadowOffset(-1.3, -1.1)
		
		if db.hotkey.shadow then
			hotkey:SetShadowColor(unpack(db.hotkey.shadow))
		end
	end
end

local function StoreOriginalButtonState(button)
    if not button or ButtonsModule.originalValues[button] then return end
    
    local name = button:GetName()
    if not name then return end
    
    local normal = _G[name..'NormalTexture'] or button:GetNormalTexture()
    
    ButtonsModule.originalValues[button] = {
        normalTexture = normal and normal:GetTexture(),
        normalPoints = {},
        normalVertexColor = normal and {normal:GetVertexColor()},
        normalDrawLayer = normal and normal:GetDrawLayer(),
        size = {button:GetSize()},
        checkedTexture = button:GetCheckedTexture() and button:GetCheckedTexture():GetTexture(),
        pushedTexture = button:GetPushedTexture() and button:GetPushedTexture():GetTexture(),
        highlightTexture = button:GetHighlightTexture() and button:GetHighlightTexture():GetTexture(),
    }
    
    -- Store normal texture points
    if normal then
        for i = 1, normal:GetNumPoints() do
            local point, relativeTo, relativePoint, xOfs, yOfs = normal:GetPoint(i)
            table.insert(ButtonsModule.originalValues[button].normalPoints, {point, relativeTo, relativePoint, xOfs, yOfs})
        end
    end
end

local function main_buttons(button)
    if not IsModuleEnabled() then return end
    
    -- CRITICAL: Don't style buttons during combat to avoid taint
    if InCombatLockdown() then return end
    
	if not button or button.__styled then return; end

    -- Store original state before styling
    StoreOriginalButtonState(button)

	local name = button:GetName();
	local normal = _G[name..'NormalTexture'] or button:GetNormalTexture();
	local icon = _G[name..'Icon']
	local flash = _G[name..'Flash']
	local cooldown = _G[name..'Cooldown']
	local border = _G[name..'Border']
	
	normal:ClearAllPoints()
	normal:SetPoint('TOPRIGHT', button, 2.2, 2.3)
	normal:SetPoint('BOTTOMLEFT', button, -2.2, -2.2)
	normal:SetVertexColor(1, 1, 1, 1)
	normal:SetDrawLayer('OVERLAY')

	if flash then
		flash:set_atlas('ui-hud-actionbar-iconframe-flash')
	end

	if icon then
		icon:SetTexCoord(.05, .95, .05, .95)
		icon:SetDrawLayer('BORDER')
	end

	if cooldown then
		cooldown:ClearAllPoints()
		cooldown:SetAllPoints(button)
		cooldown:SetFrameLevel(button:GetParent():GetFrameLevel() +1)
	end
	
	if border then
		border:set_atlas('_ui-hud-actionbar-iconborder-checked')
		border:SetAllPoints(normal)
	end
	
	-- apply button textures
	button:GetCheckedTexture():set_atlas('_ui-hud-actionbar-iconborder-checked')
	button:GetPushedTexture():set_atlas('_ui-hud-actionbar-iconborder-pushed')
	button:SetHighlightTexture(config.assets.highlight)
	button:GetCheckedTexture():SetAllPoints(normal)
	button:GetPushedTexture():SetAllPoints(normal)
	button:GetHighlightTexture():SetAllPoints(normal)
	button:GetCheckedTexture():SetDrawLayer('OVERLAY')
	button:GetPushedTexture():SetDrawLayer('OVERLAY')

	button.background = setup_background(button, normal, true)
	
	button.__styled = true
end

local function additional_buttons(button)
    if not IsModuleEnabled() then return end
    
    -- CRITICAL: Don't style buttons during combat to avoid taint
    if InCombatLockdown() then return end
    
	if not button then return; end
	
    -- Store original state before styling
    StoreOriginalButtonState(button)
    
	button:SetNormalTexture(config.assets.normal)
	if button.background then return; end

	local name = button:GetName();
	local icon = _G[name..'Icon']
	local flash = _G[name..'Flash']
	local normal = _G[name..'NormalTexture2'] or _G[name..'NormalTexture']
	local cooldown = _G[name..'Cooldown']
	local castable = _G[name..'AutoCastable']

	normal:ClearAllPoints()
	normal:SetPoint('TOPRIGHT', button, 2.2, 2.3)
	normal:SetPoint('BOTTOMLEFT', button, -2.2, -2.2)

	-- apply button textures
	button:GetCheckedTexture():set_atlas('_ui-hud-actionbar-iconborder-checked')
	button:GetPushedTexture():set_atlas('_ui-hud-actionbar-iconborder-pushed')
	button:SetHighlightTexture(config.assets.highlight)
	button:GetCheckedTexture():SetAllPoints(normal)
	button:GetPushedTexture():SetAllPoints(normal)
	button:GetHighlightTexture():SetAllPoints(normal)

	if cooldown then
		cooldown:ClearAllPoints()
		cooldown:SetAllPoints(button)
		cooldown:SetFrameLevel(button:GetParent():GetFrameLevel() +1)
	end

	if icon then
		icon:SetTexCoord(.05, .95, .05, .95)
		icon:SetPoint('TOPRIGHT', button, 1, 1)
		icon:SetPoint('BOTTOMLEFT', button, -1, -1)
		icon:SetDrawLayer('BORDER')
	end

	if flash then
		flash:set_atlas('ui-hud-actionbar-iconframe-flash')
	end
	
	if castable then
		castable:ClearAllPoints()
		castable:SetPoint('TOP', 0, 14)
		castable:SetPoint('BOTTOM', 0, -15)
	end

	if is_petaction(button, 'PetActionButton') then
		hooksecurefunc(button, "SetNormalTexture", fix_texture)
	end
	button.background = setup_background(button, normal, false)
end

-- ============================================================================
-- RESTORATION FUNCTIONS
-- ============================================================================

local function RestoreButtonToOriginal(button)
    if not button or not ButtonsModule.originalValues[button] then return end
    
    local original = ButtonsModule.originalValues[button]
    local name = button:GetName()
    if not name then return end
    
    local normal = _G[name..'NormalTexture'] or button:GetNormalTexture()
    
    -- Restore normal texture
    if normal and original.normalTexture then
        normal:SetTexture(original.normalTexture)
        
        -- Restore points
        normal:ClearAllPoints()
        for _, point in ipairs(original.normalPoints) do
            normal:SetPoint(unpack(point))
        end
        
        -- Restore vertex color
        if original.normalVertexColor then
            normal:SetVertexColor(unpack(original.normalVertexColor))
        end
        
        -- Restore draw layer
        if original.normalDrawLayer then
            normal:SetDrawLayer(original.normalDrawLayer)
        end
    end
    
    -- Restore size
    if original.size then
        button:SetSize(unpack(original.size))
    end
    
    -- Remove custom backgrounds and shadows
    if button.background then
        button.background:Hide()
        button.background = nil
    end
    
    if button.shadow then
        button.shadow:Hide()
        button.shadow = nil
    end
    
    -- Reset styled flag
    button.__styled = nil
    
    -- Clear original values
    ButtonsModule.originalValues[button] = nil
end

local function RestoreAllButtons()
    -- Restore main action buttons
    for button in addon.buttons_iterator() do
        if button then
            RestoreButtonToOriginal(button)
        end
    end
    
    -- Restore vehicle buttons
    for index=1, VEHICLE_MAX_ACTIONBUTTONS do
        local button = _G['OverrideActionBarButton'..index]
        if button then
            RestoreButtonToOriginal(button)
        end
    end
    
    -- Restore possess buttons
    for index=1, NUM_POSSESS_SLOTS do
        local button = _G['PossessButton'..index]
        if button then
            RestoreButtonToOriginal(button)
        end
    end
    
    -- Restore pet buttons
    for index=1, NUM_PET_ACTION_SLOTS do
        local button = _G['PetActionButton'..index]
        if button then
            RestoreButtonToOriginal(button)
        end
    end
    
    -- Restore stance buttons
    for index=1, NUM_SHAPESHIFT_SLOTS do
        local button = _G['ShapeshiftButton'..index]
        if button then
            RestoreButtonToOriginal(button)
        end
    end
    
    ButtonsModule.applied = false
end

-- ============================================================================
-- APPLY STYLING
-- ============================================================================

local function ApplyButtonStyling()
    if ButtonsModule.applied then 
        return
    end
    
    -- Setup main action buttons
    for button in addon.buttons_iterator() do
        if button then
            main_buttons(button)
            button:SetSize(37, 37)
        end
    end
    
    ButtonsModule.applied = true
end

-- ============================================================================
-- UPDATE HANDLERS
-- ============================================================================

local function actionbuttons_update(button)
    if not IsModuleEnabled() then return end
    
    -- CRITICAL: Don't interfere with LibKeyBound during keybind mode
    if addon.KeyBindingModule and addon.KeyBindingModule.enabled and LibStub and LibStub("LibKeyBound-1.0") then
        local LibKeyBound = LibStub("LibKeyBound-1.0")
        if LibKeyBound:IsShown() then
            return -- Skip updates during keybinding mode
        end
    end
    
	if not button then return; end
	local name = button:GetName();
	if name:find('MultiCast') then return; end
	button:SetNormalTexture(config.assets.normal);
	
	-- 强制显示边框纹理颜色（不依赖alwaysShowActionBars或ShowGrid触发）
	local normalTexture = _G[name..'NormalTexture']
	if normalTexture then
		local borderColor = config.buttons.border_color
		if borderColor then
			normalTexture:SetVertexColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
		end
	end
end

function addon.RefreshButtons()
    if not IsModuleEnabled() then return end
    
    -- CRITICAL: Don't refresh buttons during combat to avoid taint
    if InCombatLockdown() then 
        ButtonsModule.pendingRefresh = true
        return 
    end
    
    local db = GetButtonsConfig()
    if not db then 
        addon:DebugInfo("Buttons", "警告：RefreshButtons - 无法获取按钮配置")
        return 
    end

    for button in addon.buttons_iterator() do
        if button then
            -- 确保背景已创建（如果不存在则重新创建）
            if not button.background then
                local name = button:GetName()
                if name then
                    local normal = _G[name..'NormalTexture'] or button:GetNormalTexture()
                    if normal then
                        button.background = setup_background(button, normal, true)
                    end
                end
            end
            
            -- 处理背景显示/隐藏
            if button.background then
                local buttonName = button:GetName()
                if buttonName then
                    local isMainActionButton = buttonName:match("^ActionButton%d+$")

                    -- show/hide action backgrounds
                    if db.only_actionbackground and not isMainActionButton then
                        button.background:Hide()
                    else
                        button.background:Show()
                    end
                end
            end
            
            -- 关键修复：宏名称、快捷键等文本处理不应该依赖背景是否存在
            local buttonName = button:GetName()
            if buttonName then
                -- update hotkeys and range indicators
                pcall(actionbuttons_hotkey, button)

                -- handle macro text - 独立于背景处理
                local macros = _G[buttonName .. 'Name']
                if macros then
                    if db.macros then
                        addon:DebugInfo("Buttons", string.format("处理按钮 %s 的宏名称", buttonName))
                        
                        if db.macros.show then
                            macros:Show()
                            addon:DebugInfo("Buttons", string.format("  - 显示宏名称文本框"))
                        else
                            macros:Hide()
                            addon:DebugInfo("Buttons", string.format("  - 隐藏宏名称文本框（配置）"))
                        end
                        if db.macros.color then 
                            macros:SetVertexColor(unpack(db.macros.color)) 
                        end
                        if db.macros.font then 
                            -- Apply font with smart CJK detection for Chinese character support
                            local macroText = macros:GetText() or ""
                            local fontToUse = db.macros.font
                            
                            addon:DebugInfo("Buttons", string.format("  - 宏名称文本: '%s'", macroText))
                            
                            -- If text contains CJK characters, use Chinese-compatible font
                            if ContainsCJKCharacters(macroText) then
                                fontToUse = {'Fonts\\ARKai_T.ttf', 12, 'OUTLINE'}
                                addon:DebugInfo("Buttons", string.format("  - 检测到中文，使用ARKai字体"))
                            end
                            
                            local success, err = pcall(function()
                                macros:SetFont(unpack(fontToUse))
                            end)
                            if not success then
                                -- Fallback to default WoW Chinese font if custom font fails
                                macros:SetFont('Fonts\\ARKai_T.ttf', 12, 'OUTLINE')
                                addon:DebugInfo("Buttons", "  - 字体设置失败，使用备用中文字体")
                            else
                                addon:DebugInfo("Buttons", string.format("  - 字体设置成功"))
                            end
                        end
                        
                        -- 确保宏名称文本框的层级正确
                        macros:SetDrawLayer("OVERLAY", 2)
                        addon:DebugInfo("Buttons", string.format("  - 设置DrawLayer为OVERLAY, 2"))
                    else
                        -- 如果没有macros配置，默认隐藏
                        macros:Hide()
                        addon:DebugInfo("Buttons", string.format("  - 无macros配置，隐藏"))
                    end
                else
                    addon:DebugInfo("Buttons", string.format("警告：按钮 %s 的宏名称文本框不存在", buttonName))
                end

                -- handle count text
                local count = _G[buttonName .. 'Count']
                if count and db.count then
                    count:SetAlpha(db.count.show and 1 or 0)
                end

                -- handle border styling and equipped state
                local border = _G[buttonName .. 'Border']
                if border then
                    if db.border_color then
                        border:SetVertexColor(unpack(db.border_color))
                    end
                    border:SetAlpha(IsEquippedAction(button.action) and 1 or 0)
                end

                ActionButton_Update(button)
            end
        end
    end
end

-- ============================================================================
-- TEMPLATE FUNCTIONS
-- ============================================================================

-- setup vehicle action buttons
function addon.vehiclebuttons_template()
    if not IsModuleEnabled() then return end
    
	if UnitHasVehicleUI('player') then
		local maxButtons = VEHICLE_MAX_ACTIONBUTTONS or 6
		for index=1, maxButtons do
			local button = _G['OverrideActionBarButton'..index]
			if button then
				main_buttons(button)
				-- Aplicar formato de hotkeys también a vehicle buttons
				actionbuttons_hotkey(button)
			end
		end
	end
end

-- setup possess buttons
function addon.possessbuttons_template()
    if not IsModuleEnabled() then return end
    
	for index=1, NUM_POSSESS_SLOTS do
		additional_buttons(_G['PossessButton'..index])
	end
end

-- setup pet action buttons
function addon.petbuttons_template()
    if not IsModuleEnabled() then return end
    
	for index=1, NUM_PET_ACTION_SLOTS do
		local button = _G['PetActionButton'..index]
		if button then
			additional_buttons(button)
			-- Aplicar formato de hotkeys también a pet buttons
			actionbuttons_hotkey(button)
		end
	end
end

-- setup stance/shapeshift buttons
function addon.stancebuttons_template()
    if not IsModuleEnabled() then return end
    
	for index=1, NUM_SHAPESHIFT_SLOTS do
		local button = _G['ShapeshiftButton'..index]
		if button then
			additional_buttons(button)
			-- Aplicar formato de hotkeys también a stance buttons
			actionbuttons_hotkey(button)
		end
	end
end

-- ============================================================================
-- HOOKS MANAGEMENT
-- ============================================================================

local function SetupHooks()
    if ButtonsModule.hooked or not IsModuleEnabled() then return end
    
    hooksecurefunc('ActionButton_Update', actionbuttons_update)

    -- cache border color to avoid repeated config access
    local cachedBorderColor = nil

    hooksecurefunc('ActionButton_ShowGrid', function(button)
        if not IsModuleEnabled() then return end
        
        -- CRITICAL: Don't interfere with LibKeyBound during keybind mode
        if addon.KeyBindingModule and addon.KeyBindingModule.enabled and LibStub and LibStub("LibKeyBound-1.0") then
            local LibKeyBound = LibStub("LibKeyBound-1.0")
            if LibKeyBound:IsShown() then
                return -- Skip updates during keybinding mode
            end
        end
        
        if not button then return end
        
        local buttonName = button:GetName()
        if not buttonName then return end
        
        local db = GetButtonsConfig()
        
        -- cache border color on first access
        if not cachedBorderColor then
            cachedBorderColor = config.buttons.border_color
        end
        
        local normalTexture = _G[buttonName..'NormalTexture']
        if not normalTexture then return end
        
        if db and db.hide_main_bar_background then
            local wowAlwaysShow = GetCVar("alwaysShowActionBars") == "1"
            
            if buttonName:match("^ActionButton%d+$") then
                if wowAlwaysShow or HasAction(button.action) then
                    normalTexture:SetVertexColor(cachedBorderColor[1], cachedBorderColor[2], cachedBorderColor[3], cachedBorderColor[4])
                end
            else
                normalTexture:SetVertexColor(cachedBorderColor[1], cachedBorderColor[2], cachedBorderColor[3], cachedBorderColor[4])
            end
        else
            normalTexture:SetVertexColor(cachedBorderColor[1], cachedBorderColor[2], cachedBorderColor[3], cachedBorderColor[4])
        end
    end)
    
    ButtonsModule.hooked = true
end

-- ============================================================================
-- MODULE CONTROL FUNCTIONS
-- ============================================================================

function addon.RefreshButtonStyling()
    if IsModuleEnabled() then
        -- Apply styling
        SetupHooks()
        ApplyButtonStyling()
        
        -- Refresh all templates
        addon.vehiclebuttons_template()
        addon.possessbuttons_template()
        addon.petbuttons_template()
        addon.stancebuttons_template()
        
        -- Refresh button states
        addon.RefreshButtons()
    else
        -- Restore original buttons
        RestoreAllButtons()
    end
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

local function Initialize()
    if ButtonsModule.initialized then return end
    
    -- Only apply styling if module is enabled
    if IsModuleEnabled() then
        ApplyButtonStyling()
        SetupHooks()
    end
    
    ButtonsModule.initialized = true
end

-- Register initialization events
addon.package:RegisterEvents(function()
    if IsModuleEnabled() then
        addon:DebugInfo("Buttons", "========== PLAYER_LOGIN 事件触发 ==========")
        
        -- 关键修复：延迟一小段时间确保数据库完全加载
        C_Timer.After(0.1, function()
            addon:DebugInfo("Buttons", "执行 actionbuttons_grid 和 RefreshButtons")
            addon.actionbuttons_grid(); 
            addon.RefreshButtons();
            
            -- 关键修复：确保所有动作条按钮的边框材质颜色被正确应用
            -- 这解决了登录时按钮边框不显示的问题（不依赖ActionButton_ShowGrid触发）
            local db = GetButtonsConfig()
            local borderColor = config.buttons.border_color
            if borderColor then
                for button in addon.buttons_iterator() do
                    if button then
                        local buttonName = button:GetName()
                        if buttonName then
                            local normalTexture = _G[buttonName..'NormalTexture']
                            if normalTexture then
                                normalTexture:SetVertexColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
                            end
                        end
                    end
                end
                addon:DebugInfo("Buttons", "已主动应用边框颜色到所有动作条按钮")
            end
            
            -- 确保主动作条背景也更新
            if MainMenuBarMixin and MainMenuBarMixin.update_main_bar_background then
                addon:DebugInfo("Buttons", "调用 update_main_bar_background")
                MainMenuBarMixin:update_main_bar_background()
            end
        end)
    end
    collectgarbage();
end,
    'PLAYER_LOGIN'
);

-- Auto-initialize when addon loads and handle post-combat refresh
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
initFrame:RegisterEvent("UPDATE_BINDINGS")  -- CLAVE: Actualizar hotkeys cuando cambien los bindings
initFrame:SetScript("OnEvent", function(self, event, addonName)
    if event == "ADDON_LOADED" and addonName == "DragonUI" then
        Initialize()
        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Execute pending refreshes after combat ends
        if IsModuleEnabled() and ButtonsModule.pendingRefresh then
            ButtonsModule.pendingRefresh = false
            addon.actionbuttons_grid()
            addon.RefreshButtons()
        end
    elseif event == "UPDATE_BINDINGS" then
        -- PATRÓN ORIGINAL: Actualizar hotkeys cuando cambien los bindings
        if IsModuleEnabled() then
            -- Main action buttons
            for button in addon.buttons_iterator() do
                if button then
                    actionbuttons_hotkey(button)
                end
            end
            
            -- Vehicle buttons
            if UnitHasVehicleUI('player') then
                for index=1, VEHICLE_MAX_ACTIONBUTTONS do
                    local button = _G['OverrideActionBarButton'..index]
                    if button then
                        actionbuttons_hotkey(button)
                    end
                end
            end
            
            -- Pet buttons
            for index=1, NUM_PET_ACTION_SLOTS do
                local button = _G['PetActionButton'..index]
                if button then
                    actionbuttons_hotkey(button)
                end
            end
            
            -- Stance buttons (7.3.5 compatibility: NUM_SHAPESHIFT_SLOTS may not exist)
            -- Use localized variable for safe nil handling (legionDF pattern)
            local numStanceSlots = NUM_SHAPESHIFT_SLOTS or (GetNumShapeshiftForms and GetNumShapeshiftForms()) or 0
            for index=1, numStanceSlots do
                local button = _G['ShapeshiftButton'..index] or _G['StanceButton'..index]
                if button then
                    actionbuttons_hotkey(button)
                end
            end
            
            -- Possess buttons
            for index=1, NUM_POSSESS_SLOTS do
                local button = _G['PossessButton'..index]
                if button then
                    actionbuttons_hotkey(button)
                end
            end
        end
    end
end)

-- Monitor alwaysShowActionBars CVar changes with proper event (no more constant timer)
local cvarFrame = CreateFrame("Frame")
cvarFrame:RegisterEvent("CVAR_UPDATE")
cvarFrame:SetScript("OnEvent", function(self, event, cvarName)
    if not IsModuleEnabled() then return end
    
    -- Only react to the specific CVar we care about
    if event == "CVAR_UPDATE" and cvarName == "alwaysShowActionBars" then
        -- Execute immediately - no timer needed
        addon.actionbuttons_grid()
        
        -- Refresh main bar background
        if MainMenuBarMixin and MainMenuBarMixin.update_main_bar_background then
            MainMenuBarMixin:update_main_bar_background()
        end
    end
end)