-- DragonUI 声望条和神器能量条测试脚本
-- 在游戏内使用 /run 命令执行这些测试
-- 使用方法：/load test_reputation_artifact.lua 或复制内容到聊天框

-- ========================================
-- 测试1：检查容器框体是否创建成功
-- ========================================
print("=== 测试1：检查容器框体 ===")
if addon.ActionBarFrames then
    print("✅ ActionBarFrames 存在")
    
    if addon.ActionBarFrames.reputationbar then
        print("✅ 声望条容器已创建:", addon.ActionBarFrames.reputationbar:GetName())
        print("   - 大小:", addon.ActionBarFrames.reputationbar:GetSize())
        local point, relativeTo, relativePoint, xOfs, yOfs = addon.ActionBarFrames.reputationbar:GetPoint()
        print(string.format("   - 位置: %s, %.1f, %.1f", point or "N/A", xOfs or 0, yOfs or 0))
    else
        print("❌ 声望条容器未创建")
    end
    
    if addon.ActionBarFrames.artifactbar then
        print("✅ 神器能量条容器已创建:", addon.ActionBarFrames.artifactbar:GetName())
        print("   - 大小:", addon.ActionBarFrames.artifactbar:GetSize())
        local point, relativeTo, relativePoint, xOfs, yOfs = addon.ActionBarFrames.artifactbar:GetPoint()
        print(string.format("   - 位置: %s, %.1f, %.1f", point or "N/A", xOfs or 0, yOfs or 0))
    else
        print("❌ 神器能量条容器未创建")
    end
    
    if addon.ActionBarFrames.repexpbar then
        print("✅ 经验条容器已创建:", addon.ActionBarFrames.repexpbar:GetName())
    end
else
    print("❌ ActionBarFrames 不存在")
end

-- ========================================
-- 测试2：检查声望条连接状态
-- ========================================
print("\n=== 测试2：检查声望条 ===")
if ReputationWatchBar then
    print("✅ ReputationWatchBar 存在")
    local parent = ReputationWatchBar:GetParent()
    print("   - 父级:", parent and parent:GetName() or "nil")
    
    -- ⭐ 新增：检查父级是否正确
    if parent == addon.ActionBarFrames.reputationbar then
        print("   ✅ 父级正确（reputationbar容器）")
    else
        print("   ❌ 父级错误！应该是 reputationbar 容器")
    end
    
    print("   - 大小:", ReputationWatchBar:GetSize())
    print("   - 可见性:", ReputationWatchBar:IsShown())
    
    local watchedFaction = GetWatchedFactionInfo()
    if watchedFaction then
        print("   - 当前监视声望:", watchedFaction)
    else
        print("   - 当前没有监视的声望")
    end
else
    print("❌ ReputationWatchBar 不存在")
end

-- ========================================
-- 测试3：检查神器能量条连接状态
-- ========================================
print("\n=== 测试3：检查神器能量条 ===")
if MainMenuBarMaxLevelBar then
    print("✅ MainMenuBarMaxLevelBar 存在")
    print("   - 父级:", MainMenuBarMaxLevelBar:GetParent():GetName())
    print("   - 大小:", MainMenuBarMaxLevelBar:GetSize())
    print("   - 可见性:", MainMenuBarMaxLevelBar:IsShown())
    
    -- 检查是否在职业大厅
    if OrderHallLandingPage then
        print("   - OrderHallLandingPage 可见性:", OrderHallLandingPage:IsShown())
    end
else
    print("❌ MainMenuBarMaxLevelBar 不存在")
end

-- ========================================
-- 测试4：检查编辑器注册状态
-- ========================================
print("\n=== 测试4：检查编辑器注册 ===")
if addon.EditableFrames then
    print("✅ EditableFrames 存在")
    
    local repBarRegistered = false
    local artifactBarRegistered = false
    
    for name, data in pairs(addon.EditableFrames) do
        if name == "reputationbar" then
            print("✅ 声望条已注册到编辑器")
            repBarRegistered = true
        elseif name == "artifactbar" then
            print("✅ 神器能量条已注册到编辑器")
            artifactBarRegistered = true
        end
    end
    
    if not repBarRegistered then
        print("❌ 声望条未注册到编辑器")
    end
    if not artifactBarRegistered then
        print("❌ 神器能量条未注册到编辑器")
    end
else
    print("❌ EditableFrames 不存在")
end

-- ========================================
-- 测试5：检查数据库配置
-- ========================================
print("\n=== 测试5：检查数据库配置 ===")
if addon.db and addon.db.profile and addon.db.profile.widgets then
    local widgets = addon.db.profile.widgets
    
    if widgets.reputationbar then
        print("✅ 声望条配置存在")
        print("   - 锚点:", widgets.reputationbar.anchor)
        print("   - X:", widgets.reputationbar.posX)
        print("   - Y:", widgets.reputationbar.posY)
    else
        print("❌ 声望条配置不存在")
    end
    
    if widgets.artifactbar then
        print("✅ 神器能量条配置存在")
        print("   - 锚点:", widgets.artifactbar.anchor)
        print("   - X:", widgets.artifactbar.posX)
        print("   - Y:", widgets.artifactbar.posY)
    else
        print("❌ 神器能量条配置不存在")
    end
else
    print("❌ 数据库配置不可用")
end

-- ========================================
-- 测试6：手动刷新测试
-- ========================================
print("\n=== 测试6：手动刷新测试 ===")
if addon.RefreshArtifactBarPosition then
    print("✅ RefreshArtifactBarPosition 函数存在")
    print("   可以使用 /run addon.RefreshArtifactBarPosition() 手动刷新")
else
    print("❌ RefreshArtifactBarPosition 函数不存在")
end

if addon.RefreshXpRepBarPosition then
    print("✅ RefreshXpRepBarPosition 函数存在")
    print("   可以使用 /run addon.RefreshXpRepBarPosition() 手动刷新")
else
    print("❌ RefreshXpRepBarPosition 函数不存在")
end

if addon.RefreshRepBarPosition then
    print("✅ RefreshRepBarPosition 函数存在")
    print("   可以使用 /run addon.RefreshRepBarPosition() 手动刷新")
else
    print("❌ RefreshRepBarPosition 函数不存在")
end

-- ========================================
-- 测试7：位置稳定性测试（新增）
-- ========================================
print("\n=== 测试7：位置稳定性检查 ===")
if ReputationWatchBar and addon.ActionBarFrames.reputationbar then
    local currentParent = ReputationWatchBar:GetParent()
    if currentParent == addon.ActionBarFrames.reputationbar then
        print("✅ 声望条父级稳定（在 reputationbar 容器中）")
        print("   提示：切换地图后运行此测试，确认父级未被重置")
    else
        print("❌ 声望条父级不稳定！")
        print("   当前父级:", currentParent and currentParent:GetName() or "nil")
        print("   期望父级:", addon.ActionBarFrames.reputationbar:GetName())
        print("   建议：运行 /run addon.RefreshRepBarPosition() 修复")
    end
else
    print("⚠️ 无法检查（声望条或容器不存在）")
end

print("\n=== 测试完成 ===")
print("提示：")
print("1. 如果看到 ❌ 错误，请重新加载插件 /reload")
print("2. 切换地图后再次运行此测试，检查声望条位置是否稳定")
print("3. 使用 /run addon.DebugInfo('ExpRepBar', true) 启用详细日志")
