local addon = select(2, ...);

-- ============================================================================
-- DRAGONUI DEBUG SYSTEM - 7.3.5 Compatibility Debugging
-- ============================================================================
-- 这个系统提供详细的调试信息,帮助追踪7.3.5兼容性问题
-- ============================================================================

-- Debug Configuration
local DEBUG_CONFIG = {
    enabled = false,  -- 主开关
    verboseMode = true,  -- 详细模式
    logToFile = true,  -- 记录到SavedVariables (永久保存)
    showInChat = false,  -- 在聊天框显示 (已禁用,仅记录到日志文件)
    trackAPIErrors = true,  -- 追踪API调用失败
    trackModuleLoading = true,  -- 追踪模块加载
    trackFrameCreation = true,  -- 追踪框架创建
    trackEventRegistration = true,  -- 追踪事件注册
    maxLogSize = 500,  -- 最大日志条目数(减小以避免文件过大)
    saveSessionLogs = true  -- 保存会话日志
}

-- Global debug log storage (will be saved to DragonUIDebugLog.lua)
if not DragonUIDebugLog then
    DragonUIDebugLog = {
        sessions = {},  -- 历史会话
        currentSession = nil,  -- 当前会话
        lastError = nil,  -- 最后的错误
        quickReport = {},  -- 快速诊断报告
        luaErrors = {}  -- ⭐ 新增: LUA错误日志
    }
end

-- Debug Storage (will be saved to DragonUIDB)
addon.debugLog = addon.debugLog or {}
addon.debugStats = addon.debugStats or {
    apiErrors = {},
    moduleStatus = {},
    frameStatus = {},
    eventStatus = {},
    sessionStart = time()
}

-- Color codes for chat output
local COLOR = {
    ERROR = "|cffff0000",  -- Red
    WARNING = "|cffffa500",  -- Orange
    SUCCESS = "|cff00ff00",  -- Green
    INFO = "|cff00bfff",  -- Blue
    DEBUG = "|cffcccccc",  -- Gray
    RESET = "|r"
}

-- ============================================================================
-- CORE DEBUG FUNCTIONS
-- ============================================================================

-- LUA错误捕获器
local function CaptureError(errorMessage, errorStack)
    if not DragonUIDebugLog then return end
    
    -- 初始化luaErrors表
    if not DragonUIDebugLog.luaErrors then
        DragonUIDebugLog.luaErrors = {}
    end
    
    -- 创建错误条目
    local errorEntry = {
        time = date("%Y-%m-%d %H:%M:%S"),
        realTime = time(),
        message = tostring(errorMessage),
        stack = tostring(errorStack or debugstack(3, 10, 0)),
        count = 1  -- 错误发生次数
    }
    
    -- 检查是否是重复错误
    local isDuplicate = false
    for i, err in ipairs(DragonUIDebugLog.luaErrors) do
        if err.message == errorEntry.message then
            err.count = err.count + 1
            err.lastTime = errorEntry.time
            isDuplicate = true
            break
        end
    end
    
    -- 如果不是重复错误，添加新条目
    if not isDuplicate then
        table.insert(DragonUIDebugLog.luaErrors, errorEntry)
        
        -- 限制错误日志大小（保留最近50个不同的错误）
        if #DragonUIDebugLog.luaErrors > 50 then
            table.remove(DragonUIDebugLog.luaErrors, 1)
        end
    end
    
    -- 同时记录到当前会话
    if DragonUIDebugLog.currentSession then
        if not DragonUIDebugLog.currentSession.luaErrors then
            DragonUIDebugLog.currentSession.luaErrors = {}
        end
        table.insert(DragonUIDebugLog.currentSession.luaErrors, errorEntry)
    end
end

-- Hook到WoW的错误处理系统
local function SetupErrorCapture()
    -- 方法1: Hook UIErrorsFrame
    if UIErrorsFrame then
        local original_AddMessage = UIErrorsFrame.AddMessage
        UIErrorsFrame.AddMessage = function(self, text, ...)
            if text and string.find(text, "Interface") then
                CaptureError(text, debugstack(2, 5, 0))
            end
            return original_AddMessage(self, text, ...)
        end
    end
    
    -- 方法2: 使用seterrorhandler (如果可用)
    if seterrorhandler then
        local originalHandler = geterrorhandler()
        seterrorhandler(function(msg)
            CaptureError(msg, debugstack(2, 10, 0))
            if originalHandler then
                return originalHandler(msg)
            end
        end)
    end
end

-- Main debug print function
function addon:DebugPrint(level, category, message, ...)
    if not DEBUG_CONFIG.enabled then return end
    
    local timestamp = date("%H:%M:%S")
    local args = {...}
    local fullMessage = string.format(message, unpack(args))
    
    -- Format log entry
    local logEntry = {
        time = timestamp,
        realTime = time(),  -- Unix时间戳
        level = level,
        category = category,
        message = fullMessage,
        stackTrace = debugstack(2, 3, 0)  -- 获取调用栈
    }
    
    -- Add to DragonUIDebugLog (permanent storage)
    if DEBUG_CONFIG.logToFile and DragonUIDebugLog then
        if not DragonUIDebugLog.currentSession then
            DragonUIDebugLog.currentSession = {
                startTime = time(),
                startDate = date("%Y-%m-%d %H:%M:%S"),
                logs = {},
                errors = {},
                warnings = {}
            }
        end
        
        table.insert(DragonUIDebugLog.currentSession.logs, logEntry)
        
        -- 特别记录错误和警告
        if level == "ERROR" then
            table.insert(DragonUIDebugLog.currentSession.errors, logEntry)
            DragonUIDebugLog.lastError = logEntry
        elseif level == "WARNING" then
            table.insert(DragonUIDebugLog.currentSession.warnings, logEntry)
        end
        
        -- 限制当前会话日志大小
        if #DragonUIDebugLog.currentSession.logs > DEBUG_CONFIG.maxLogSize then
            table.remove(DragonUIDebugLog.currentSession.logs, 1)
        end
    end
    
    -- Add to addon.debugLog (for in-game display)
    table.insert(addon.debugLog, logEntry)
    if #addon.debugLog > DEBUG_CONFIG.maxLogSize then
        table.remove(addon.debugLog, 1)
    end
    
    -- Print to chat
    if DEBUG_CONFIG.showInChat then
        local color = COLOR[level] or COLOR.DEBUG
        local prefix = color .. "[DragonUI-" .. level .. "]" .. COLOR.RESET
        print(prefix .. " [" .. category .. "] " .. fullMessage)
    end
end

-- Shorthand functions
function addon:DebugError(category, message, ...)
    self:DebugPrint("ERROR", category, message, ...)
    
    -- Track error stats
    if not addon.debugStats.apiErrors[category] then
        addon.debugStats.apiErrors[category] = {}
    end
    table.insert(addon.debugStats.apiErrors[category], {
        time = time(),
        message = string.format(message, ...)
    })
end

function addon:DebugWarning(category, message, ...)
    self:DebugPrint("WARNING", category, message, ...)
end

function addon:DebugSuccess(category, message, ...)
    self:DebugPrint("SUCCESS", category, message, ...)
end

function addon:DebugInfo(category, message, ...)
    if DEBUG_CONFIG.verboseMode then
        self:DebugPrint("INFO", category, message, ...)
    end
end

-- ============================================================================
-- API COMPATIBILITY CHECKING
-- ============================================================================

-- Check if a global API exists
function addon:CheckAPI(apiName, category)
    local exists = _G[apiName] ~= nil
    
    if not exists then
        self:DebugWarning("API-Check", "%s: API '%s' 不存在 (在7.3.5中可能已被移除)", category, apiName)
        
        if not addon.debugStats.apiErrors[category] then
            addon.debugStats.apiErrors[category] = {}
        end
        addon.debugStats.apiErrors[category][apiName] = "不存在"
    else
        self:DebugInfo("API-Check", "%s: API '%s' 可用", category, apiName)
    end
    
    return exists
end

-- Safe API call with error tracking
function addon:SafeAPICall(func, funcName, category, ...)
    if type(func) ~= "function" then
        self:DebugError("API-Call", "%s: '%s' 不是一个函数", category, funcName)
        return false, "Not a function"
    end
    
    local success, result = pcall(func, ...)
    
    if not success then
        self:DebugError("API-Call", "%s: '%s' 调用失败: %s", category, funcName, tostring(result))
        return false, result
    end
    
    self:DebugInfo("API-Call", "%s: '%s' 调用成功", category, funcName)
    return true, result
end

-- ============================================================================
-- MODULE TRACKING
-- ============================================================================

function addon:TrackModuleLoad(moduleName, status, error)
    if not DEBUG_CONFIG.trackModuleLoading then return end
    
    addon.debugStats.moduleStatus[moduleName] = {
        loaded = status,
        error = error,
        time = time()
    }
    
    if status then
        self:DebugSuccess("Module", "模块 '%s' 加载成功", moduleName)
    else
        self:DebugError("Module", "模块 '%s' 加载失败: %s", moduleName, tostring(error))
    end
end

-- ============================================================================
-- FRAME TRACKING
-- ============================================================================

function addon:TrackFrameCreation(frameName, frameType, parent)
    if not DEBUG_CONFIG.trackFrameCreation then return end
    
    local parentName = parent and parent:GetName() or "UIParent"
    
    addon.debugStats.frameStatus[frameName] = {
        type = frameType,
        parent = parentName,
        created = time()
    }
    
    self:DebugInfo("Frame", "创建框架 '%s' (类型: %s, 父级: %s)", frameName, frameType, parentName)
end

function addon:TrackFrameError(frameName, errorMsg)
    self:DebugError("Frame", "框架 '%s' 错误: %s", frameName, errorMsg)
    
    if addon.debugStats.frameStatus[frameName] then
        addon.debugStats.frameStatus[frameName].error = errorMsg
    end
end

-- ============================================================================
-- EVENT TRACKING
-- ============================================================================

function addon:TrackEventRegistration(frame, eventName, status)
    if not DEBUG_CONFIG.trackEventRegistration then return end
    
    local frameName = frame:GetName() or "UnnamedFrame"
    
    if not addon.debugStats.eventStatus[frameName] then
        addon.debugStats.eventStatus[frameName] = {}
    end
    
    addon.debugStats.eventStatus[frameName][eventName] = {
        registered = status,
        time = time()
    }
    
    if status then
        self:DebugInfo("Event", "框架 '%s' 注册事件 '%s'", frameName, eventName)
    else
        self:DebugWarning("Event", "框架 '%s' 取消注册事件 '%s'", frameName, eventName)
    end
end

-- ============================================================================
-- COMPATIBILITY REPORT
-- ============================================================================

function addon:GenerateCompatibilityReport()
    local report = {
        "=== DragonUI 7.3.5 兼容性报告 ===",
        "生成时间: " .. date("%Y-%m-%d %H:%M:%S"),
        "",
        "=== 关键API状态 ===",
    }
    
    -- Check critical APIs
    local criticalAPIs = {
        -- Shapeshift Bar
        {name = "ShapeshiftBarFrame", category = "姿态栏"},
        {name = "StanceBar", category = "姿态栏"},
        {name = "NUM_SHAPESHIFT_SLOTS", category = "姿态栏"},
        {name = "GetNumShapeshiftForms", category = "姿态栏"},
        
        -- Bonus Action Bar
        {name = "BonusActionBarFrame", category = "额外动作条"},
        
        -- Key Ring
        {name = "KeyRingButton", category = "钥匙链"},
        {name = "ToggleKeyRing", category = "钥匙链"},
        {name = "IsBagOpen", category = "钥匙链"},
        
        -- Minimap
        {name = "MinimapBattlefieldFrame", category = "小地图"},
        
        -- Unit Functions
        {name = "GetNumRaidMembers", category = "团队"},
        {name = "GetNumGroupMembers", category = "团队"},
        
        -- UI Templates
        {name = "UIPanelButtonTemplate", category = "UI模板"},
        {name = "UIPanelButtonTemplate2", category = "UI模板"},
    }
    
    -- Store API check results for log file
    local apiCheckResults = {}
    
    for _, api in ipairs(criticalAPIs) do
        local exists = _G[api.name] ~= nil
        local status = exists and "✓ 可用" or "✗ 不存在"
        table.insert(report, string.format("[%s] %s - %s", api.category, api.name, status))
        apiCheckResults[api.name] = exists
    end
    
    table.insert(report, "")
    table.insert(report, "=== 模块加载状态 ===")
    for moduleName, status in pairs(addon.debugStats.moduleStatus) do
        local statusText = status.loaded and "✓ 成功" or "✗ 失败"
        table.insert(report, string.format("%s - %s", moduleName, statusText))
        if status.error then
            table.insert(report, "  错误: " .. tostring(status.error))
        end
    end
    
    table.insert(report, "")
    table.insert(report, "=== 已创建的框架 ===")
    for frameName, info in pairs(addon.debugStats.frameStatus) do
        table.insert(report, string.format("%s (类型: %s)", frameName, info.type))
        if info.error then
            table.insert(report, "  错误: " .. info.error)
        end
    end
    
    table.insert(report, "")
    table.insert(report, "=== API错误统计 ===")
    for category, errors in pairs(addon.debugStats.apiErrors) do
        table.insert(report, category .. ":")
        if type(errors) == "table" then
            if #errors > 0 then
                for _, err in ipairs(errors) do
                    table.insert(report, "  - " .. err.message)
                end
            else
                for apiName, status in pairs(errors) do
                    table.insert(report, "  - " .. apiName .. ": " .. status)
                end
            end
        end
    end
    
    -- Save quick report to log file
    if DragonUIDebugLog then
        DragonUIDebugLog.quickReport = {
            generated = date("%Y-%m-%d %H:%M:%S"),
            apiStatus = apiCheckResults,
            moduleStatus = addon.debugStats.moduleStatus,
            frameStatus = addon.debugStats.frameStatus,
            errorCount = #(DragonUIDebugLog.currentSession and DragonUIDebugLog.currentSession.errors or {}),
            warningCount = #(DragonUIDebugLog.currentSession and DragonUIDebugLog.currentSession.warnings or {})
        }
    end
    
    return table.concat(report, "\n")
end

-- ============================================================================
-- SLASH COMMANDS
-- ============================================================================

function addon:SetupDebugCommands()
    SLASH_DRAGONDEBUG1 = "/dragondebug"
    SLASH_DRAGONDEBUG2 = "/duidebug"
    
    SlashCmdList["DRAGONDEBUG"] = function(msg)
        local cmd = string.lower(msg)
        
        if cmd == "report" or cmd == "报告" then
            -- Generate and print report
            local report = addon:GenerateCompatibilityReport()
            print(report)
            print(COLOR.INFO .. "日志文件位置: WTF\\Account\\[账号]\\SavedVariables\\DragonUIDebugLog.lua" .. COLOR.RESET)
            
        elseif cmd == "save" or cmd == "保存" then
            -- Save current session to history
            if DragonUIDebugLog and DragonUIDebugLog.currentSession then
                if not DragonUIDebugLog.sessions then
                    DragonUIDebugLog.sessions = {}
                end
                
                -- 添加结束时间
                DragonUIDebugLog.currentSession.endTime = time()
                DragonUIDebugLog.currentSession.endDate = date("%Y-%m-%d %H:%M:%S")
                
                table.insert(DragonUIDebugLog.sessions, DragonUIDebugLog.currentSession)
                
                -- 限制历史会话数量(保留最后10个)
                while #DragonUIDebugLog.sessions > 10 do
                    table.remove(DragonUIDebugLog.sessions, 1)
                end
                
                -- 开启新会话
                DragonUIDebugLog.currentSession = {
                    startTime = time(),
                    startDate = date("%Y-%m-%d %H:%M:%S"),
                    logs = {},
                    errors = {},
                    warnings = {}
                }
                
                print(COLOR.SUCCESS .. "[DragonUI] 当前会话已保存到历史,开启新会话" .. COLOR.RESET)
                print(COLOR.INFO .. "历史会话数: " .. #DragonUIDebugLog.sessions .. COLOR.RESET)
            end
            
        elseif cmd == "export" or cmd == "导出" then
            -- Show path to log file
            print(COLOR.INFO .. "=== DragonUI 日志文件位置 ===" .. COLOR.RESET)
            print("日志文件: WTF\\Account\\[你的账号名]\\SavedVariables\\DragonUIDebugLog.lua")
            print("使用记事本打开该文件即可查看所有调试信息")
            print("请将整个文件内容发送给我进行分析")
            if DragonUIDebugLog and DragonUIDebugLog.currentSession then
                print(COLOR.INFO .. "当前会话日志: " .. #DragonUIDebugLog.currentSession.logs .. " 条" .. COLOR.RESET)
                print(COLOR.ERROR .. "错误: " .. #DragonUIDebugLog.currentSession.errors .. " 次" .. COLOR.RESET)
                print(COLOR.WARNING .. "警告: " .. #DragonUIDebugLog.currentSession.warnings .. " 次" .. COLOR.RESET)
            end
            
        elseif cmd == "clear" or cmd == "清空" then
            -- Clear debug log
            addon.debugLog = {}
            addon.debugStats.apiErrors = {}
            if DragonUIDebugLog then
                DragonUIDebugLog.currentSession = {
                    startTime = time(),
                    startDate = date("%Y-%m-%d %H:%M:%S"),
                    logs = {},
                    errors = {},
                    warnings = {}
                }
            end
            print(COLOR.SUCCESS .. "[DragonUI] 调试日志已清空" .. COLOR.RESET)
            
        elseif cmd == "on" or cmd == "开启" then
            DEBUG_CONFIG.enabled = true
            print(COLOR.SUCCESS .. "[DragonUI] 调试模式已开启" .. COLOR.RESET)
            
        elseif cmd == "off" or cmd == "关闭" then
            DEBUG_CONFIG.enabled = false
            print(COLOR.INFO .. "[DragonUI] 调试模式已关闭" .. COLOR.RESET)
            
        elseif cmd == "verbose" or cmd == "详细" then
            DEBUG_CONFIG.verboseMode = not DEBUG_CONFIG.verboseMode
            local status = DEBUG_CONFIG.verboseMode and "开启" or "关闭"
            print(COLOR.INFO .. "[DragonUI] 详细模式已" .. status .. COLOR.RESET)
            
        elseif cmd == "stats" or cmd == "统计" then
            -- Print statistics
            print(COLOR.INFO .. "=== DragonUI 调试统计 ===" .. COLOR.RESET)
            print("日志条目数: " .. #addon.debugLog)
            print("模块数量: " .. addon:TableCount(addon.debugStats.moduleStatus))
            print("框架数量: " .. addon:TableCount(addon.debugStats.frameStatus))
            print("API错误类别: " .. addon:TableCount(addon.debugStats.apiErrors))
            if DragonUIDebugLog and DragonUIDebugLog.currentSession then
                print(COLOR.ERROR .. "错误数: " .. #DragonUIDebugLog.currentSession.errors .. COLOR.RESET)
                print(COLOR.WARNING .. "警告数: " .. #DragonUIDebugLog.currentSession.warnings .. COLOR.RESET)
            end
            -- LUA错误统计
            if DragonUIDebugLog and DragonUIDebugLog.luaErrors then
                local totalCount = 0
                for _, err in ipairs(DragonUIDebugLog.luaErrors) do
                    totalCount = totalCount + err.count
                end
                print(COLOR.ERROR .. "LUA错误: " .. #DragonUIDebugLog.luaErrors .. " 种 (总计 " .. totalCount .. " 次)" .. COLOR.RESET)
            end
            
        elseif cmd == "errors" or cmd == "错误" then
            -- 显示LUA错误
            if not DragonUIDebugLog or not DragonUIDebugLog.luaErrors or #DragonUIDebugLog.luaErrors == 0 then
                print(COLOR.SUCCESS .. "[好消息] 没有记录到LUA错误" .. COLOR.RESET)
            else
                print(COLOR.ERROR .. "=== LUA错误日志 (" .. #DragonUIDebugLog.luaErrors .. " 种错误) ===" .. COLOR.RESET)
                for i, err in ipairs(DragonUIDebugLog.luaErrors) do
                    print(string.format(COLOR.ERROR .. "[%d] 发生 %d 次 - 最后: %s" .. COLOR.RESET, i, err.count, err.lastTime or err.time))
                    print(COLOR.WARNING .. "  错误: " .. COLOR.RESET .. string.sub(err.message, 1, 100) .. "...")
                end
                print(COLOR.INFO .. "请将 DragonUIDebugLog.lua 文件发给我查看完整错误信息" .. COLOR.RESET)
            end
            
        elseif cmd == "enhanced" or cmd == "增强" then
            -- 生成增强报告
            local enhancedReport = addon:GenerateEnhancedReport()
            print(enhancedReport)
            
        else
            -- Print help
            print(COLOR.INFO .. "=== DragonUI 调试命令 ===" .. COLOR.RESET)
            print("/dragondebug report (报告) - 生成兼容性报告")
            print("/dragondebug enhanced (增强) - 生成增强调试报告 " .. COLOR.SUCCESS .. "★新功能" .. COLOR.RESET)
            print("/dragondebug errors (错误) - 显示LUA错误日志 " .. COLOR.SUCCESS .. "★新功能" .. COLOR.RESET)
            print("/dragondebug export (导出) - 显示日志文件位置")
            print("/dragondebug save (保存) - 保存当前会话到历史")
            print("/dragondebug clear (清空) - 清空调试日志")
            print("/dragondebug on (开启) - 开启调试模式")
            print("/dragondebug off (关闭) - 关闭调试模式")
            print("/dragondebug verbose (详细) - 切换详细模式")
            print("/dragondebug stats (统计) - 显示统计信息")
            print(COLOR.WARNING .. "提示: LUA错误现在会自动捕获到 DragonUIDebugLog.lua 中" .. COLOR.RESET)
        end
    end
end

-- Helper function to count table entries
function addon:TableCount(t)
    local count = 0
    for _ in pairs(t) do
        count = count + 1
    end
    return count
end

-- ============================================================================
-- ENHANCED DEBUG INFORMATION - 增强调试信息
-- ============================================================================

-- 收集系统信息
function addon:CollectSystemInfo()
    local info = {
        -- 游戏版本
        gameVersion = GetBuildInfo(),
        gameLocale = GetLocale(),
        
        -- 插件信息
        dragonuiVersion = GetAddOnMetadata("DragonUI", "Version") or "未知",
        
        -- 当前职业和专精
        playerClass = select(2, UnitClass("player")),
        playerLevel = UnitLevel("player"),
        playerName = UnitName("player"),
        
        -- 屏幕分辨率
        screenWidth = GetScreenWidth(),
        screenHeight = GetScreenHeight(),
        
        -- UI缩放
        uiScale = UIParent:GetEffectiveScale(),
        
        -- 当前区域
        zoneName = GetZoneText(),
        subZoneName = GetSubZoneText(),
        
        -- 帧率和延迟
        fps = GetFramerate(),
        latency = select(3, GetNetStats()),
        
        -- 内存使用
        memoryUsage = GetAddOnMemoryUsage("DragonUI"),
        
        -- 时间戳
        timestamp = date("%Y-%m-%d %H:%M:%S"),
        uptime = time() - (addon.debugStats.sessionStart or time())
    }
    
    return info
end

-- 收集配置信息
function addon:CollectConfigInfo()
    if not addon.db or not addon.db.profile then
        return "配置未加载"
    end
    
    local config = {
        -- 模块状态
        modules = {},
        
        -- 主要设置
        mainSettings = {
            castbarEnabled = addon.db.profile.castbar and addon.db.profile.castbar.enabled,
            minimapEnabled = addon.db.profile.modules and addon.db.profile.modules.minimap and addon.db.profile.modules.minimap.enabled,
            micromenuEnabled = addon.db.profile.modules and addon.db.profile.modules.micromenu and addon.db.profile.modules.micromenu.enabled,
        }
    }
    
    -- 收集所有模块状态
    if addon.db.profile.modules then
        for moduleName, moduleConfig in pairs(addon.db.profile.modules) do
            if type(moduleConfig) == "table" then
                config.modules[moduleName] = {
                    enabled = moduleConfig.enabled
                }
            end
        end
    end
    
    return config
end

-- 收集框架信息
function addon:CollectFrameInfo()
    local frames = {}
    
    -- 检查关键框架
    local framesToCheck = {
        "pUiStanceBar",
        "pUiStanceHolder",
        "pUiBagsBar",
        "pUiMicroMenu",
        "TargetFrame",
        "PlayerFrame",
        "MainMenuBar"
    }
    
    for _, frameName in ipairs(framesToCheck) do
        local frame = _G[frameName]
        if frame then
            frames[frameName] = {
                exists = true,
                shown = frame:IsShown(),
                visible = frame:IsVisible(),
                width = frame:GetWidth(),
                height = frame:GetHeight(),
                point = {frame:GetPoint()}
            }
        else
            frames[frameName] = {exists = false}
        end
    end
    
    return frames
end

-- 生成增强的诊断报告
function addon:GenerateEnhancedReport()
    local systemInfo = self:CollectSystemInfo()
    local configInfo = self:CollectConfigInfo()
    local frameInfo = self:CollectFrameInfo()
    
    local report = {}
    table.insert(report, "\n=== DragonUI 增强调试报告 ===")
    table.insert(report, "生成时间: " .. date("%Y-%m-%d %H:%M:%S"))
    table.insert(report, "")
    
    -- 系统信息
    table.insert(report, "=== 系统信息 ===")
    table.insert(report, string.format("游戏版本: %s", systemInfo.gameVersion))
    table.insert(report, string.format("语言: %s", systemInfo.gameLocale))
    table.insert(report, string.format("DragonUI版本: %s", systemInfo.dragonuiVersion))
    table.insert(report, string.format("玩家: %s (%s, 等级 %d)", systemInfo.playerName, systemInfo.playerClass, systemInfo.playerLevel))
    table.insert(report, string.format("分辨率: %.0fx%.0f, UI缩放: %.2f", systemInfo.screenWidth, systemInfo.screenHeight, systemInfo.uiScale))
    table.insert(report, string.format("帧率: %.1f FPS, 延迟: %d ms", systemInfo.fps, systemInfo.latency))
    table.insert(report, string.format("内存使用: %.2f MB", systemInfo.memoryUsage / 1024))
    table.insert(report, string.format("运行时间: %d 秒", systemInfo.uptime))
    table.insert(report, "")
    
    -- 配置信息
    table.insert(report, "=== 模块状态 ===")
    if type(configInfo) == "table" and configInfo.modules then
        for moduleName, moduleData in pairs(configInfo.modules) do
            local status = moduleData.enabled and "✓ 启用" or "✗ 禁用"
            table.insert(report, string.format("[%s] %s", moduleName, status))
        end
    end
    table.insert(report, "")
    
    -- 框架状态
    table.insert(report, "=== 关键框架状态 ===")
    for frameName, frameData in pairs(frameInfo) do
        if frameData.exists then
            local status = frameData.shown and "显示" or "隐藏"
            table.insert(report, string.format("[%s] %s (%.0fx%.0f)", frameName, status, frameData.width or 0, frameData.height or 0))
        else
            table.insert(report, string.format("[%s] ✗ 不存在", frameName))
        end
    end
    table.insert(report, "")
    
    -- LUA错误统计
    if DragonUIDebugLog and DragonUIDebugLog.luaErrors then
        table.insert(report, "=== LUA错误统计 ===")
        local totalErrors = #DragonUIDebugLog.luaErrors
        local totalCount = 0
        for _, err in ipairs(DragonUIDebugLog.luaErrors) do
            totalCount = totalCount + err.count
        end
        table.insert(report, string.format("不同错误数: %d", totalErrors))
        table.insert(report, string.format("总错误次数: %d", totalCount))
        table.insert(report, "")
    end
    
    return table.concat(report, "\n")
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

-- Setup debug system on load
local debugFrame = CreateFrame("Frame")
debugFrame:RegisterEvent("ADDON_LOADED")
debugFrame:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "DragonUI" then
        -- 启动错误捕获
        SetupErrorCapture()
        
        addon:SetupDebugCommands()
        addon:DebugSuccess("System", "DragonUI 调试系统已初始化")
        addon:DebugInfo("System", "使用 /dragondebug 查看调试命令")
        addon:DebugInfo("System", "使用 /dragondebug export 查看日志文件位置")
        
        -- 保存系统信息到日志
        if DragonUIDebugLog and DragonUIDebugLog.currentSession then
            DragonUIDebugLog.currentSession.systemInfo = addon:CollectSystemInfo()
        end
        
        -- Generate initial compatibility report
        if DEBUG_CONFIG.verboseMode then
            C_Timer.After(2, function()
                addon:DebugInfo("System", "正在生成初始兼容性检查...")
                local report = addon:GenerateCompatibilityReport()
                addon:DebugInfo("System", "\n" .. report)
                
                -- 生成增强报告
                local enhancedReport = addon:GenerateEnhancedReport()
                addon:DebugInfo("System", enhancedReport)
                
                -- 已删除聊天框提示,所有调试信息仅记录到日志文件
            end)
        end
    end
end)

-- Export debug config for external access
addon.debugConfig = DEBUG_CONFIG
