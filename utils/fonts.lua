local addon = select(2, ...)

-- ============================================================================
-- DRAGONUI FONT SYSTEM - 智能中文字体支持
-- ============================================================================

local FontSystem = {}
addon.FontSystem = FontSystem

-- 中文字符检测函数（UTF-8 多字节字符检测）
local function ContainsCJKCharacters(text)
    if not text or type(text) ~= "string" then 
        return false 
    end
    
    -- 检查常见的中文字符范围（UTF-8编码）
    -- 中文常用字符范围：U+4E00-U+9FFF (\xE4-\xE9 开头)
    -- 扩展A区：U+3400-U+4DBF
    -- 扩展B区及更高：U+20000+
    -- 日文平假名/片假名：U+3040-U+30FF
    -- 韩文：U+AC00-U+D7AF
    
    -- 更可靠的检测方法：查找任何非ASCII字符
    for i = 1, #text do
        local byte = text:byte(i)
        -- UTF-8多字节字符的第一个字节 >= 192
        if byte and byte >= 192 then
            return true
        end
    end
    
    return false
end

-- 获取智能字体（根据文本内容自动选择中文字体或默认字体）
function FontSystem.GetSmartFont(text, defaultFont)
    if not text or type(text) ~= "string" then
        return defaultFont or {'Fonts\\FRIZQT__.TTF', 12, 'OUTLINE'}
    end
    
    -- 检测 CJK 字符
    if ContainsCJKCharacters(text) then
        -- 包含中文字符，使用中文兼容字体
        return {'Fonts\\ARKai_T.ttf', 12, 'OUTLINE'}
    end
    
    return defaultFont or {'Fonts\\FRIZQT__.TTF', 12, 'OUTLINE'}
end

-- 应用智能字体到 FontString
function FontSystem.ApplySmartFont(fontString, text, defaultFont)
    if not fontString then
        return
    end
    
    local smartFont = FontSystem.GetSmartFont(text, defaultFont)
    
    local success, err = pcall(function()
        fontString:SetFont(unpack(smartFont))
    end)
    
    if not success then
        -- Fallback to default WoW Chinese font if custom font fails
        fontString:SetFont('Fonts\\ARKai_T.ttf', 12, 'OUTLINE')
    end
end

-- 更新现有 FontString 的字体（如果文本包含中文则切换）
function FontSystem.UpdateFontForText(fontString, text, originalFont)
    if not fontString or not text then
        return
    end
    
    -- 检查当前是否已包含中文
    if ContainsCJKCharacters(text) then
        -- 切换到中文字体
        FontSystem.ApplySmartFont(fontString, text, originalFont)
    else
        -- 恢复原始字体（如果之前是中文字体）
        if originalFont then
            local success = pcall(function()
                fontString:SetFont(unpack(originalFont))
            end)
        end
    end
end

-- 导出检测函数供其他模块使用
FontSystem.ContainsCJKCharacters = ContainsCJKCharacters

return FontSystem
