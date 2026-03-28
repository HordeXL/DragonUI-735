local addon = select(2, ...)

-- ===============================================================
-- DRAGONUI TEXT SYSTEM - SISTEMA HÍBRIDO MEJORADO
-- ===============================================================

local TextSystem = {}
addon.TextSystem = TextSystem

-- ===============================================================
-- CONSTANTES Y CONFIGURACIÓN
-- ===============================================================

-- Formatos de texto disponibles
TextSystem.TEXT_FORMATS = {
    numeric = "numeric", -- Solo números actuales
    percentage = "percentage", -- Solo porcentaje  
    both = "both", -- Números + porcentaje (dual)
    formatted = "formatted" -- Formato "current / max"
}

-- ===============================================================
-- FUNCIONES DE FORMATEO CORE
-- ===============================================================

-- Función para abreviar números grandes
function TextSystem.AbbreviateLargeNumbers(value)
    if not value or type(value) ~= "number" then
        return "0"
    end
    if value < 1000 then
        return tostring(value)
    end

    if value >= 1000000 then
        return string.format("%.1fM", value / 1000000)
    elseif value >= 1000 then
        return string.format("%.1fk", value / 1000)
    end
end

-- Función principal de formateo de texto
function TextSystem.FormatStatusText(current, maximum, textFormat, useBreakup, frameType)
    if not current or not maximum or maximum == 0 then
        return ""
    end

    local currentText, maxText
    if useBreakup then
        currentText = TextSystem.AbbreviateLargeNumbers(current)
        maxText = TextSystem.AbbreviateLargeNumbers(maximum)
    else
        currentText = tostring(current)
        maxText = tostring(maximum)
    end

    local percent = math.floor((current / maximum) * 100)

    if textFormat == TextSystem.TEXT_FORMATS.numeric then
        return currentText
    elseif textFormat == TextSystem.TEXT_FORMATS.percentage then
        return percent .. "%"
    elseif textFormat == TextSystem.TEXT_FORMATS.both then
        return {
            left = percent .. "%",
            right = currentText
        }
    elseif textFormat == TextSystem.TEXT_FORMATS.formatted then
        return currentText .. " / " .. maxText
    else
        -- Default fallback
        return currentText .. " / " .. maxText
    end
end

-- ===============================================================
-- SISTEMA DE ELEMENTOS DE TEXTO (MEJORADO)
-- ===============================================================

-- Función para crear elementos de texto duales (para formato "both")
function TextSystem.CreateDualTextElements(parentFrame, barFrame, prefix, layer, font)
    layer = layer or "OVERLAY"
    font = font or "TextStatusBarText"

    local elements = {}

    -- Texto central (para formatos numeric, percentage, formatted)
    if not parentFrame[prefix .. "Text"] then
        local centerText = barFrame:CreateFontString(nil, layer, font)
        local fontPath, originalSize, flags = centerText:GetFont()
        if fontPath and originalSize then
            centerText:SetFont(fontPath, originalSize + 1, flags) --  FUENTE MÁS GRANDE
        end
        centerText:SetPoint("CENTER", barFrame, "CENTER", 0, 0)
        centerText:SetJustifyH("CENTER")
        parentFrame[prefix .. "Text"] = centerText
        elements.center = centerText
    end

    -- Texto izquierdo (para formato "both")
    if not parentFrame[prefix .. "TextLeft"] then
        local leftText = barFrame:CreateFontString(nil, layer, font)
        local fontPath, originalSize, flags = leftText:GetFont()
        if fontPath and originalSize then
            leftText:SetFont(fontPath, originalSize + 1, flags) --  FUENTE MÁS GRANDE
        end
        leftText:SetPoint("LEFT", barFrame, "LEFT", 6, 0)
        leftText:SetJustifyH("LEFT")
        parentFrame[prefix .. "TextLeft"] = leftText
        elements.left = leftText
    end

    -- Texto derecho (para formato "both")
    if not parentFrame[prefix .. "TextRight"] then
        local rightText = barFrame:CreateFontString(nil, layer, font)
        local fontPath, originalSize, flags = rightText:GetFont()
        if fontPath and originalSize then
            rightText:SetFont(fontPath, originalSize + 1, flags) --  FUENTE MÁS GRANDE
        end

        --  POSICIÓN ESPECIAL PARA TARGET Y FOCUS MANA TEXT
        if prefix == "TargetFrameMana" then
            rightText:SetPoint("RIGHT", barFrame, "RIGHT", -13, 0) --  MÁS A LA IZQUIERDA
        elseif prefix == "FocusFrameMana" then
            rightText:SetPoint("RIGHT", barFrame, "RIGHT", -13, 0) --  MÁS A LA IZQUIERDA
        else
            rightText:SetPoint("RIGHT", barFrame, "RIGHT", -6, 0) --  POSICIÓN NORMAL
        end

        rightText:SetJustifyH("RIGHT")
        parentFrame[prefix .. "TextRight"] = rightText
        elements.right = rightText
    end

    return elements
end

-- ===============================================================
-- SISTEMA DE ACTUALIZACIÓN DE TEXTO (HÍBRIDO)
-- ===============================================================

-- Función para actualizar texto en elementos duales
function TextSystem.UpdateDualText(parentFrame, prefix, formattedText, textFormat, shouldShow)
    local centerText = parentFrame[prefix .. "Text"]
    local leftText = parentFrame[prefix .. "TextLeft"]
    local rightText = parentFrame[prefix .. "TextRight"]

    if not shouldShow then
        -- Ocultar todos los textos
        if centerText then
            centerText:Hide()
        end
        if leftText then
            leftText:Hide()
        end
        if rightText then
            rightText:Hide()
        end
        return
    end

    if textFormat == TextSystem.TEXT_FORMATS.both and type(formattedText) == "table" then
        -- Formato dual: mostrar left y right, ocultar center
        if centerText then
            centerText:Hide()
        end
        if leftText then
            leftText:SetText(formattedText.left or "")
            leftText:Show()
        end
        if rightText then
            rightText:SetText(formattedText.right or "")
            rightText:Show()
        end
    else
        -- Formato simple: mostrar center, ocultar left y right
        if leftText then
            leftText:Hide()
        end
        if rightText then
            rightText:Hide()
        end
        if centerText then
            centerText:SetText(formattedText or "")
            centerText:Show()
        end
    end
end

-- ===============================================================
-- FUNCIONES DE UTILIDAD (MEJORADO)
-- ===============================================================

-- Función para detectar hover sobre una barra específica (MEJOR DETECCIÓN)
function TextSystem.IsMouseOverFrame(frame)
    if not frame or not frame:IsVisible() then
        return false
    end

    --  USAR IsMouseOver() QUE ES MÁS CONFIABLE
    return frame:IsMouseOver()
end

-- Función para obtener configuración de texto de un unitframe
function TextSystem.GetFrameTextConfig(frameType, configKey)
    if not addon.db or not addon.db.profile or not addon.db.profile.unitframe then
        return {}
    end

    local config = addon.db.profile.unitframe[frameType] or {}
    return {
        textFormat = config.textFormat or "both",
        breakUpLargeNumbers = config.breakUpLargeNumbers or false,
        showHealthTextAlways = config.showHealthTextAlways or false,
        showManaTextAlways = config.showManaTextAlways or false
    }
end

-- ===============================================================
-- SISTEMA HÍBRIDO - HOOK + HOVER + EVENTOS
-- ===============================================================

--  FUNCIÓN: HookearStatusBar para actualización automática
function TextSystem.HookStatusBar(statusBar, parentFrame, prefix, frameType, unit, updateCallback)
    if not statusBar or not parentFrame then
        return
    end

    --  HOOKEAR LA FUNCIÓN NATIVA SetValue
    if not statusBar.DragonUIHooked then
        statusBar.DragonUIOriginalSetValue = statusBar.SetValue
        statusBar.SetValue = function(self, value)
            -- Llamar función original
            statusBar.DragonUIOriginalSetValue(self, value)

            -- Actualizar nuestro texto inmediatamente
            if updateCallback then
                updateCallback()
            end
        end
        statusBar.DragonUIHooked = true

    end
end

-- ===============================================================
-- FUNCIONES DE INTEGRACIÓN ESPECÍFICAS (COMPLETO)
-- ===============================================================

-- Función para actualizar texto de health/mana de cualquier unitframe
function TextSystem.UpdateFrameText(frameType, unit, parentFrame, healthBar, manaBar, prefix, textSystemRef)
    -- Use dynamic unit from textSystem if available, otherwise use passed unit
    local actualUnit = (textSystemRef and textSystemRef.unit) or unit
    
    --  VERIFICAR SI LA UNIDAD EXISTE Y ESTÁ VIVA
    if not UnitExists(actualUnit) or UnitIsDeadOrGhost(actualUnit) then
        return TextSystem.ClearFrameText(parentFrame, prefix)
    end

    local config = TextSystem.GetFrameTextConfig(frameType)

    -- Detectar hover específico en cada barra
    local healthHover = healthBar and TextSystem.IsMouseOverFrame(healthBar) or false
    local manaHover = manaBar and TextSystem.IsMouseOverFrame(manaBar) or false

    -- Determinar si mostrar cada tipo de texto
    local shouldShowHealth = config.showHealthTextAlways or healthHover
    local shouldShowMana = config.showManaTextAlways or manaHover

    -- Actualizar health text
    if healthBar and shouldShowHealth then
        local health = UnitHealth(actualUnit) or 0
        local maxHealth = UnitHealthMax(actualUnit) or 1
        local healthText = TextSystem.FormatStatusText(health, maxHealth, config.textFormat, config.breakUpLargeNumbers,
            frameType)
        TextSystem.UpdateDualText(parentFrame, prefix .. "Health", healthText, config.textFormat, true)
    else
        TextSystem.UpdateDualText(parentFrame, prefix .. "Health", "", config.textFormat, false)
    end

    -- Actualizar mana text
    if manaBar and shouldShowMana then
        local power = UnitPower(actualUnit) or 0
        local maxPower = UnitPowerMax(actualUnit) or 1
        local powerText = TextSystem.FormatStatusText(power, maxPower, config.textFormat, config.breakUpLargeNumbers,
            frameType)
        TextSystem.UpdateDualText(parentFrame, prefix .. "Mana", powerText, config.textFormat, true)
    else
        TextSystem.UpdateDualText(parentFrame, prefix .. "Mana", "", config.textFormat, false)
    end
end

-- Función para limpiar todos los textos de un frame
function TextSystem.ClearFrameText(parentFrame, prefix)
    TextSystem.UpdateDualText(parentFrame, prefix .. "Health", "", "numeric", false)
    TextSystem.UpdateDualText(parentFrame, prefix .. "Mana", "", "numeric", false)
end

-- ===============================================================
-- FUNCIONES DE SETUP INICIAL (HÍBRIDO)
-- ===============================================================

--  FUNCIÓN PRINCIPAL: Setup para cualquier unitframe (HÍBRIDO)
function TextSystem.SetupFrameTextSystem(frameType, unit, parentFrame, healthBar, manaBar, prefix)
    --  VALIDACIONES DE SEGURIDAD
    if not parentFrame then

        return {
            update = function()
            end,
            clear = function()
            end
        }
    end

    if not healthBar then

    end

    if not manaBar then

    end

    prefix = prefix or frameType:gsub("^%l", string.upper) .. "Frame"

    -- Store reference to returned textSystem for dynamic unit access
    local textSystemRef = { unit = unit }
    
    --  FUNCIÓN DE ACTUALIZACIÓN COMÚN
    local function updateCallback()
        TextSystem.UpdateFrameText(frameType, unit, parentFrame, healthBar, manaBar, prefix, textSystemRef)
    end

    --  CREAR ELEMENTOS DE TEXTO DUALES (CON FUENTE MÁS GRANDE)
    if healthBar then
        TextSystem.CreateDualTextElements(parentFrame, healthBar, prefix .. "Health", "OVERLAY", "TextStatusBarText")
        --  HOOKEAR STATUSBAR PARA ACTUALIZACIÓN AUTOMÁTICA
        TextSystem.HookStatusBar(healthBar, parentFrame, prefix .. "Health", frameType, unit, updateCallback)
    end
    if manaBar then
        TextSystem.CreateDualTextElements(parentFrame, manaBar, prefix .. "Mana", "OVERLAY", "TextStatusBarText")
        --  HOOKEAR STATUSBAR PARA ACTUALIZACIÓN AUTOMÁTICA
        TextSystem.HookStatusBar(manaBar, parentFrame, prefix .. "Mana", frameType, unit, updateCallback)
    end

    --  CONFIGURAR EVENTOS DE HOVER (MANTENER)
    TextSystem.SetupHoverEvents(parentFrame, healthBar, manaBar, updateCallback)

    return {
        update = updateCallback,
        clear = function()
            TextSystem.ClearFrameText(parentFrame, prefix)
        end,
        unit = unit,  -- For compatibility
        -- Internal reference that can be modified dynamically
        _unitRef = textSystemRef
    }
end

--  FUNCIÓN: Configurar eventos de hover (PLAYER CLICK-THROUGH)
function TextSystem.SetupHoverEvents(parentFrame, healthBar, manaBar, updateCallback)
    -- Detectar si es PlayerFrame para aplicar click-through
    local parentName = parentFrame:GetName() or ""
    local isPlayerFrame = (parentName:find("DragonUIUnitframeFrame") ~= nil)
    
    if healthBar then
        local healthHover = CreateFrame("Frame", nil, parentFrame)
        healthHover:SetAllPoints(healthBar)
        healthHover:SetFrameLevel(parentFrame:GetFrameLevel() + 10)
        
        if isPlayerFrame then
            -- PLAYER FRAME: Click-through habilitado
            healthHover:EnableMouse(false)  -- NO capturar clicks
            -- Configurar hover directamente en la StatusBar subyacente
            if not healthBar.DragonUIHoverSetup then
                healthBar:EnableMouse(true)
                healthBar:SetScript("OnEnter", updateCallback)
                healthBar:SetScript("OnLeave", updateCallback)
                healthBar.DragonUIHoverSetup = true
            end
        else
            -- OTROS FRAMES (Focus, Target): Comportamiento original
            healthHover:EnableMouse(true)
            healthHover:SetScript("OnEnter", updateCallback)
            healthHover:SetScript("OnLeave", updateCallback)
        end

        parentFrame.DragonUIHealthHover = healthHover
    end

    if manaBar then
        local manaHover = CreateFrame("Frame", nil, parentFrame)
        manaHover:SetAllPoints(manaBar)
        manaHover:SetFrameLevel(parentFrame:GetFrameLevel() + 10)
        
        if isPlayerFrame then
            -- PLAYER FRAME: Click-through habilitado
            manaHover:EnableMouse(false)  -- NO capturar clicks
            -- Configurar hover directamente en la StatusBar subyacente
            if not manaBar.DragonUIHoverSetup then
                manaBar:EnableMouse(true)
                manaBar:SetScript("OnEnter", updateCallback)
                manaBar:SetScript("OnLeave", updateCallback)
                manaBar.DragonUIHoverSetup = true
            end
        else
            -- OTROS FRAMES (Focus, Target): Comportamiento original
            manaHover:EnableMouse(true)
            manaHover:SetScript("OnEnter", updateCallback)
            manaHover:SetScript("OnLeave", updateCallback)
        end

        parentFrame.DragonUIManaHover = manaHover
    end
end

