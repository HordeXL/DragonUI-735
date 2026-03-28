local addon = select(2, ...)
local unpack = unpack
local ceil = math.ceil
local GetTime = GetTime
local hooksecurefunc = hooksecurefunc

-- Create a table within the main addon object to hold our functions
addon.cooldownMixin = {}

function addon.cooldownMixin:update_cooldown(elapsed)
    if not self:GetParent().action then
        return
    end
    if not self.remain then
        return
    end

    local text = self.text
    local remaining = self.remain - GetTime()

    if remaining > 0 then
        local moduleDb = addon.db.profile.modules.cooldowns
        local db = addon.db.profile.buttons.cooldown
        if not db then return end
        
        if remaining <= 5 then
            -- Red alert for critical time (hardcoded)
            text:SetTextColor(1, 0, .2)
            text:SetFormattedText('%.1f', remaining)
        elseif remaining <= 60 then
            -- Orange/yellow alert for short time (hardcoded) - show seconds
            text:SetTextColor(1, 1, 0)
            text:SetText(ceil(remaining))
        elseif remaining <= 3600 then
            -- 1-60 minutes: Use user color and show minutes
            text:SetText(ceil(remaining / 60) .. 'm')
            text:SetTextColor(unpack(db.color))
        else
            -- > 1 hour: Use user color but dimmed
            text:SetText(ceil(remaining / 3600) .. 'h')
            local r, g, b, a = unpack(db.color)
            text:SetTextColor(r * 0.7, g * 0.7, b * 0.7, a)
        end
    else
        self.remain = nil
        text:Hide()
        text:SetText ''
    end
end

function addon.cooldownMixin:create_string()
    local text = self:CreateFontString(nil, 'OVERLAY')
    text:SetPoint('CENTER')
    self.text = text
    self:SetScript('OnUpdate', addon.cooldownMixin.update_cooldown)
    return text
end

function addon.cooldownMixin:set_cooldown(start, duration)
    local moduleDb = addon.db.profile.modules.cooldowns
    local db = addon.db.profile.buttons.cooldown
    if not db then
        return
    end

    if moduleDb.enabled and start > 0 and duration > db.min_duration then
        self.remain = start + duration

        local text = self.text or addon.cooldownMixin.create_string(self)
        -- Use font_size if available, otherwise fallback to font array
        local fontPath = db.font[1]
        local fontSize = db.font_size or db.font[2]
        local fontFlags = db.font[3]
        text:SetFont(fontPath, fontSize, fontFlags)
        text:SetPoint(unpack(db.position))
        text:Show()
    else
        if self.text then
            self.text:Hide()
        end
        self.remain = nil
    end
end

function addon.RefreshCooldowns()
    if not addon.buttons_iterator then
        return
    end
    local moduleDb = addon.db.profile.modules.cooldowns
    local db = addon.db.profile.buttons.cooldown
    if not db then
        return
    end

    for button in addon.buttons_iterator() do
        if button then
            local cooldown = _G[button:GetName() .. 'Cooldown']
            if cooldown then
                -- Update existing text font settings
                if cooldown.text then
                    local fontPath = db.font[1]
                    local fontSize = db.font_size or db.font[2]
                    local fontFlags = db.font[3]
                    cooldown.text:SetFont(fontPath, fontSize, fontFlags)

                    -- If cooldowns are disabled, hide the text
                    if not moduleDb.enabled then
                        cooldown.text:Hide()
                    end
                end

                -- Refresh active cooldowns or force check if cooldowns are enabled
                if cooldown.GetCooldown then
                    local start, duration = cooldown:GetCooldown()
                    if start and start > 0 then
                        -- Always reapply cooldown to update settings
                        addon.cooldownMixin.set_cooldown(cooldown, start, duration)
                    elseif moduleDb.enabled and cooldown.text then
                        -- If cooldowns are enabled but no active cooldown, ensure text is hidden
                        cooldown.text:Hide()
                        cooldown.remain = nil
                    end
                end
            end
        end
    end
end

-- Force update all cooldowns (useful when enabling cooldowns for the first time)
function addon.ForceRefreshCooldowns()
    if not addon.buttons_iterator then
        return
    end
    local moduleDb = addon.db.profile.modules.cooldowns
    local db = addon.db.profile.buttons.cooldown
    if not moduleDb or not moduleDb.enabled or not db then
        return
    end

    for button in addon.buttons_iterator() do
        if button then
            local cooldown = _G[button:GetName() .. 'Cooldown']
            if cooldown and cooldown.GetCooldown then
                local start, duration = cooldown:GetCooldown()
                -- Force check even if start is 0 to ensure proper initialization
                addon.cooldownMixin.set_cooldown(cooldown, start, duration)
            end
        end
    end
end

-- This function will be called from core.lua to ensure the hook is applied only once and at the right time.
local isHooked = false
function addon.InitializeCooldowns()
    if isHooked then return end
    
    -- MEJORAR: Verificar que el botón existe antes de hookear
    if not _G.ActionButton1Cooldown then

        return
    end
    
    local methods = getmetatable(_G.ActionButton1Cooldown).__index
    if methods and methods.SetCooldown then
        hooksecurefunc(methods, 'SetCooldown', addon.cooldownMixin.set_cooldown)
        isHooked = true

    else

    end
end

