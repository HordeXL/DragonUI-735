local addon = select(2, ...)

-- ============================================================================
-- 独立神器能量条模块（神器武器经验值）
-- 与 mainbars 模块解耦，不依赖其启用状态
-- ============================================================================

local SPELL_POWER_ARTIFACT_POWER = SPELL_POWER_ARTIFACT_POWER or 10

local function FormatLargeNumber(num)
    if not num or num == 0 then return "0" end
    num = tonumber(num) or 0
    if num >= 100000000 then
        return string.format("%.1f亿", num / 100000000)
    elseif num >= 10000 then
        return string.format("%.1f万", num / 10000)
    else
        return string.format("%.0f", num)
    end
end

-- 缓存最后有效值
local ArtifactCache = { current = 0, max = 1, name = nil }

-- 确保 Blizzard_ArtifactUI 加载（仅在 ADDON_LOADED 后可调用，不在模块加载时）
local function EnsureArtifactUILoaded()
    if not IsAddOnLoaded("Blizzard_ArtifactUI") then
        pcall(LoadAddOn, "Blizzard_ArtifactUI")
    end
end

-- ============================================================================
-- 数据源
-- Legion 7.3.5: 唯一可靠的数据源是 C_ArtifactUI.GetArtifactInfo()
-- 它需要先打开一次神器面板（或等数据同步）才返回有效值
-- 在数据就绪前不隐藏条，而是显示 0/0 等待后续事件更新
-- ============================================================================
local function GetArtifactPowerValues()
    -- 1️⃣ C_ArtifactUI.GetEquippedArtifactInfo
    -- 返回值顺序: itemID, altItemID, name, icon, xp, pointsSpent, quality,
    --           artifactAppearanceID, appearanceModID, itemAppearanceID,
    --           altItemAppearanceID, altOnTop, artifactTier
    if C_ArtifactUI and C_ArtifactUI.GetEquippedArtifactInfo then
        local _, _, name, _, xp, pointsSpent, _, _, _, _, _, _, artifactTier = C_ArtifactUI.GetEquippedArtifactInfo()
        if HasArtifactEquipped and HasArtifactEquipped() and name then
            xp = tonumber(xp) or 0
            pointsSpent = tonumber(pointsSpent) or 0

            -- 获取升级到下一级所需的经验（使用正确的 artifactTier 参数）
            local xpNeeded = 0
            if C_ArtifactUI and C_ArtifactUI.GetCostForPointAtRank then
                xpNeeded = C_ArtifactUI.GetCostForPointAtRank(pointsSpent + 1, artifactTier or 1) or 0
            end

            ArtifactCache.current = xp
            ArtifactCache.max = xpNeeded
            ArtifactCache.name = name
            return xp, xpNeeded, name
        end
    end

    -- 2️⃣ 检查是否为满级神器
    if C_ArtifactUI and C_ArtifactUI.IsEquippedArtifactMaxed then
        local isMaxed = C_ArtifactUI.IsEquippedArtifactMaxed()
        if isMaxed then
            ArtifactCache.current = 0
            ArtifactCache.max = 0
            return 0, 0, ArtifactCache.name or "神器"
        end
    end

    -- 3️⃣ 从主手物品获取神器名称（作为 fallback）
    if not ArtifactCache.name then
        local link = GetInventoryItemLink("player", 16)
        if link then
            local itemID = tonumber(link:match("item:(%d+)"))
            if itemID then
                local itemName = GetItemInfo(itemID)
                if itemName then
                    ArtifactCache.name = itemName
                end
            end
        end
    end

    return nil, nil
end

-- ============================================================================
-- StatusBar 创建（仅首次加载）
-- ============================================================================
if not addon.ArtifactBar then
    local bar = CreateFrame("StatusBar", "DragonUIArtifactBar", UIParent)
    bar:SetSize(526, 10)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetStatusBarColor(0.90, 0.55, 0.35, 0.85)
    bar:SetFrameStrata("MEDIUM")
    bar:SetFrameLevel(1)
    bar:Hide()

    -- 边框
    local border = bar:CreateTexture(nil, "ARTWORK")
    border:SetTexture(addon._dir .. "uiexperiencebar")
    border:SetSize(537, 18)
    border:SetPoint("CENTER")
    border:SetTexCoord(1/2048, 572/2048, 1/64, 18/64)

    -- 文字覆盖
    local text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("CENTER")
    text:SetJustifyH("CENTER")
    text:Hide()
    bar.text = text

    -- Tooltip
    bar:SetScript("OnEnter", function(self)
        local current, max, name = GetArtifactPowerValues()
        if not current then
            current = self.currentPower or ArtifactCache.current
            max = self.maxPower or ArtifactCache.max
        end
        if not name then
            name = ArtifactCache.name
        end
        self.currentPower = current
        self.maxPower = max

        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT", 0, 8)
        GameTooltip:AddLine(name or "神器能量", 1, 0.82, 0)
        GameTooltip:AddLine(" ")

        if max > 0 and current < max then
            self.text:SetText(string.format("神器能量：%s/%s", FormatLargeNumber(current), FormatLargeNumber(max)))
            GameTooltip:AddDoubleLine("当前能量", string.format("%s / %s", FormatLargeNumber(current), FormatLargeNumber(max)), 1, 1, 1, 1, 1, 1)
            GameTooltip:AddDoubleLine("完成百分比", string.format("%.2f%%", current / max * 100), 1, 1, 1, 1, 1, 1)
            GameTooltip:AddDoubleLine("升级所需", FormatLargeNumber(max - current), 1, 1, 1, 1, 1, 1)
        elseif max == 0 then
            self.text:SetText("神器能量：已满级")
            GameTooltip:AddLine("神器已满级", 0, 1, 0)
        else
            self.text:SetText("")
            GameTooltip:AddLine("装备了神器武器", 0.7, 0.7, 0.7)
        end

        self.text:Show()
        GameTooltip:Show()
    end)

    bar:SetScript("OnLeave", function(self)
        self.text:Hide()
        GameTooltip:Hide()
    end)

    addon.ArtifactBar = bar
    addon.ArtifactBarBorder = border
end

-- ============================================================================
-- 容器框架 & 编辑器注册（确保独立于 mainbars 的启用状态）
-- ============================================================================
if not addon.ActionBarFrames then
    addon.ActionBarFrames = {}
end
if not addon.ActionBarFrames.artifactbar then
    addon.ActionBarFrames.artifactbar = addon.CreateUIFrame(526, 10, "ArtifactBar")
    -- 应用数据库中的默认位置
    local cfg = addon.db and addon.db.profile and addon.db.profile.widgets and addon.db.profile.widgets.artifactbar
    if cfg then
        addon.ActionBarFrames.artifactbar:ClearAllPoints()
        addon.ActionBarFrames.artifactbar:SetPoint(cfg.anchor or "BOTTOM", cfg.posX or 0, cfg.posY or 15)
    end
end
if not addon.EditableFrames or not addon.EditableFrames["artifactbar"] then
    addon:RegisterEditableFrame({
        name = "artifactbar",
        frame = addon.ActionBarFrames.artifactbar,
        blizzardFrame = nil,
        configPath = {"widgets", "artifactbar"}
    })
end

-- ============================================================================
-- API
-- ============================================================================

local function ApplyValuesToBar(bar, current, max)
    if not bar then return end
    bar.currentPower = tonumber(current) or 0
    bar.maxPower = tonumber(max) or 0
    local displayMax = (tonumber(max) or 0) > 0 and max or 1
    bar:SetMinMaxValues(0, tonumber(displayMax) or 1)
    bar:SetValue(tonumber(current) or 0)
end

function addon.UpdateArtifactBar()
    local bar = addon.ArtifactBar
    if not bar then return end

    local current, max = GetArtifactPowerValues()
    if not current then
        current = ArtifactCache.current
        max = ArtifactCache.max
    end

    ApplyValuesToBar(bar, current, max)
end

function addon.ShowArtifactBar()
    local bar = addon.ArtifactBar
    if not bar then return end

    -- 没装备神器 → 隐藏
    if HasArtifactEquipped and not HasArtifactEquipped() then
        bar:Hide()
        bar.text:Hide()
        return
    end

    -- 数据
    local current, max, name = GetArtifactPowerValues()

    -- name 为空表示 C_ArtifactUI 数据尚未就绪，使用缓存
    if not name then
        current = ArtifactCache.current
        max = ArtifactCache.max
    end

    ApplyValuesToBar(bar, current, max)

    -- 定位
    bar:ClearAllPoints()
    local container = addon.ActionBarFrames and addon.ActionBarFrames.artifactbar
    if container then
        bar:SetPoint("CENTER", container, "CENTER")
    else
        bar:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 15)
    end

    -- 缩放（与经验条共享）
    local scale = 0.9
    if addon.db and addon.db.profile and addon.db.profile.xprepbar and addon.db.profile.xprepbar.expbar_scale then
        scale = addon.db.profile.xprepbar.expbar_scale
    end

    bar:SetScale(scale)
    bar:SetAlpha(1)
    bar:Show()
end

function addon.HideArtifactBar()
    local bar = addon.ArtifactBar
    if bar then
        bar:Hide()
        bar:SetAlpha(0)
    end
end

-- ============================================================================
-- 配置刷新回调
-- ============================================================================
function addon.RefreshArtifactBarPosition()
    if InCombatLockdown() then return end
    addon.ShowArtifactBar()
end

-- ============================================================================
-- 事件监听
-- ============================================================================
do
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:RegisterEvent("UNIT_POWER_UPDATE")
    f:RegisterEvent("ARTIFACT_XP_UPDATE")
    f:RegisterEvent("ARTIFACT_UPDATE")
    f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    f:RegisterEvent("UPDATE_FACTION")
    f:RegisterEvent("UNIT_INVENTORY_CHANGED")
    -- OnUpdate 重试帧（每 2 秒检查一次，最多 30 次 = 60 秒）
    local retryFrame
    local retryElapsed = 0
    local retryMax = 30

    f:SetScript("OnEvent", function(self, event, arg1, arg2)
        if event == "PLAYER_ENTERING_WORLD" then
            C_Timer.After(1, function()
                EnsureArtifactUILoaded()
                addon.ShowArtifactBar()
                -- 启动 OnUpdate 重试
                if not retryFrame then
                    retryFrame = CreateFrame("Frame")
                    retryFrame:SetScript("OnUpdate", function(_, step)
                        retryElapsed = retryElapsed + step
                        if retryElapsed < 2 then return end
                        retryElapsed = 0
                        retryMax = retryMax - 1
                        if retryMax <= 0 then
                            retryFrame:SetScript("OnUpdate", nil)
                            retryFrame = nil
                            return
                        end
                        if HasArtifactEquipped and not HasArtifactEquipped() then
                            retryFrame:SetScript("OnUpdate", nil)
                            retryFrame = nil
                            return
                        end
                        EnsureArtifactUILoaded()
                        local _, _, name = GetArtifactPowerValues()
                        if name then
                            addon.ShowArtifactBar()
                            retryFrame:SetScript("OnUpdate", nil)
                            retryFrame = nil
                        end
                    end)
                end
            end)
        elseif event == "UNIT_POWER_UPDATE" then
            if arg1 == "player" and (not arg2 or arg2 == "ARTIFACT_POWER" or arg2 == 10) then
                addon.UpdateArtifactBar()
                addon.ShowArtifactBar()
            end
        elseif event == "ARTIFACT_XP_UPDATE" or event == "ARTIFACT_UPDATE" then
            addon.ShowArtifactBar()
        elseif event == "ZONE_CHANGED_NEW_AREA" then
            C_Timer.After(1, addon.ShowArtifactBar)
        elseif event == "UPDATE_FACTION" then
            C_Timer.After(0.5, addon.ShowArtifactBar)
        elseif event == "UNIT_INVENTORY_CHANGED" then
            if arg1 == "player" then
                C_Timer.After(0.5, addon.ShowArtifactBar)
            end
        end
    end)
end

-- ============================================================================
-- 调试
-- ============================================================================
_G["TestArtifact"] = function()
    local bar = addon.ArtifactBar
    if not bar then print("ArtifactBar 不存在") return end
    local has = HasArtifactEquipped and HasArtifactEquipped()
    local engCur = UnitPower("player", SPELL_POWER_ARTIFACT_POWER)
    local engMax = UnitPowerMax("player", SPELL_POWER_ARTIFACT_POWER)
    local cur, max = GetArtifactPowerValues()
    print(string.format("装备:%s UnitPower:%d/%d GetValues:%s/%.0f 缓存:%.0f/%.0f 条:%.0f/%.0f IsShown:%s",
        tostring(has),
        engCur or 0, engMax or 0,
        tostring(cur), max or 0,
        ArtifactCache.current, ArtifactCache.max,
        bar:GetValue() or 0, select(2, bar:GetMinMaxValues()) or 0,
        bar:IsShown() and "是" or "否"))
end

_G["TestArtifactAPI"] = function()
    print("--- 神器 API 测试 ---")
    print(string.format("HasArtifactEquipped: %s", tostring(HasArtifactEquipped and HasArtifactEquipped())))
    print(string.format("UnitPower(10): %d / %d", UnitPower("player", SPELL_POWER_ARTIFACT_POWER) or 0, UnitPowerMax("player", SPELL_POWER_ARTIFACT_POWER) or 0))

    -- 检查 GetEquippedArtifactInfo（当前位置 [3]=name [4]=? [5]=? [6]=等级）
    if C_ArtifactUI and C_ArtifactUI.GetEquippedArtifactInfo then
        print("GetEquippedArtifactInfo:")
        for i = 1, 16 do
            local v = select(i, C_ArtifactUI.GetEquippedArtifactInfo())
            local t = type(v)
            if t == "number" then
                print(i .. " = number " .. string.format("%.0f", v))
            elseif t == "string" then
                print(i .. " = string " .. v)
            elseif t == "boolean" then
                print(i .. " = boolean " .. tostring(v))
            elseif v == nil then
                -- nil could be end of values, keep going
            end
        end
    end

    -- 检查 MainMenuBarMaxLevelBar 的子框架
    if MainMenuBarMaxLevelBar then
        print("MainMenuBarMaxLevelBar 子框架:")
        local numChildren = MainMenuBarMaxLevelBar:GetNumChildren()
        for i = 1, numChildren do
            local child = select(i, MainMenuBarMaxLevelBar:GetChildren())
            if child then
                local name = child.GetName and child:GetName() or "无名"
                local objType = child:GetObjectType()
                if objType == "StatusBar" then
                    local _, max = child:GetMinMaxValues()
                    local val = child:GetValue() or 0
                    print(string.format("  [%d] %s %s val=%.0f/%.0f", i, name, objType, val, max or 0))
                elseif objType == "FontString" then
                    print(string.format("  [%d] %s %s text=%s", i, name, objType, child:GetText() or ""))
                else
                    print(string.format("  [%d] %s %s", i, name, objType))
                end
            end
        end
    else
        print("MainMenuBarMaxLevelBar: 不存在")
    end

    -- 测试 GetTotalPowerCost 计算最大经验值
    if C_ArtifactUI and C_ArtifactUI.GetTotalPowerCost then
        print("GetTotalPowerCost:")
        local total1 = C_ArtifactUI.GetTotalPowerCost(0, 67, 1)
        print("  (0, 67, 1) total to lv67: " .. string.format("%.0f", total1 or 0))
        local total2 = C_ArtifactUI.GetTotalPowerCost(0, 68, 1)
        print("  (0, 68, 1) total to lv68: " .. string.format("%.0f", total2 or 0))
        local needed = total2 - total1
        print("  needed for lv67->68: " .. string.format("%.0f", needed or 0))
    end
    -- 按不同等级测试每点成本
    if C_ArtifactUI and C_ArtifactUI.GetCostForPointAtRank then
        print("GetCostForPointAtRank (tier=1):")
        for r = 65, 70 do
            local cost = C_ArtifactUI.GetCostForPointAtRank(r, 1)
            print("  rank " .. r .. " = " .. string.format("%.0f", cost or 0))
        end
    end

    if C_ArtifactUI and C_ArtifactUI.IsEquippedArtifactMaxed then
        print("IsEquippedArtifactMaxed: " .. tostring(C_ArtifactUI.IsEquippedArtifactMaxed()))
    end
    print("ArtifactCache: name=" .. tostring(ArtifactCache.name) .. " cur=" .. string.format("%.0f", ArtifactCache.current) .. " max=" .. string.format("%.0f", ArtifactCache.max))
end
