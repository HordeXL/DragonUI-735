# DragonUI 测试工具目录

这个目录包含 DragonUI 的调试和测试脚本，用于开发和问题排查。

## 📁 文件说明

### test_reputation_artifact.lua
**声望条和神器能量条测试脚本**

**用途**：
- 验证声望条和神器能量条容器是否正确创建
- 检查父级关系是否正确
- 确认编辑器注册状态
- 测试位置稳定性（防止暴雪重置）
- 诊断相关问题

**使用方法**：
```lua
-- 在游戏聊天框中运行
/load Interface/AddOns/DragonUI/tests/test_reputation_artifact.lua

-- 或者复制文件内容粘贴到聊天框
```

**测试场景**：
1. 开发新功能后验证实现
2. 用户报告声望条位置问题时诊断
3. 切换地图后检查位置稳定性
4. 回归测试确保修复有效

**输出示例**：
```
=== 测试1：检查容器框体 ===
✅ ActionBarFrames 存在
✅ 声望条容器已创建: DragonUI_ReputationBar
   - 大小: 526, 10
   - 位置: BOTTOM, 2.0, 220.0
...

=== 测试7：位置稳定性检查 ===
✅ 声望条父级稳定（在 reputationbar 容器中）
   提示：切换地图后运行此测试，确认父级未被重置
```

## 🔧 如何使用

### 方法1：加载文件
```lua
/load Interface/AddOns/DragonUI/tests/test_reputation_artifact.lua
```

### 方法2：启用详细日志后运行
```lua
/run addon.DebugInfo('ExpRepBar', true)
/load Interface/AddOns/DragonUI/tests/test_reputation_artifact.lua
```

### 方法3：手动刷新测试
```lua
-- 声望条
/run addon.RefreshRepBarPosition()

-- 神器能量条
/run addon.RefreshArtifactBarPosition()

-- 经验条和声望条
/run addon.RefreshXpRepBarPosition()
```

## 📝 注意事项

1. **这些文件不会自动加载** - 需要手动执行
2. **不影响插件性能** - 只在需要时运行
3. **可以安全删除** - 如果不需要调试功能
4. **建议保留** - 用于未来开发和问题排查

## 🆕 添加新测试

如果要添加新的测试脚本，请遵循以下规范：

1. **命名规范**：`test_功能名称.lua`
2. **文件头部**：添加用途说明和使用方法
3. **输出格式**：使用 ✅ ❌ ⚠️ 等符号清晰标识结果
4. **分段测试**：将测试分为多个独立部分
5. **提供建议**：如果测试失败，给出修复建议

示例：
```lua
-- test_new_feature.lua
-- 新功能测试脚本
-- 使用方法：/load Interface/AddOns/DragonUI/tests/test_new_feature.lua

print("=== 测试：新功能 ===")
-- 测试逻辑...
print("✅ 测试通过")
```

## 📊 测试覆盖的功能

- ✅ 声望条容器创建和连接
- ✅ 神器能量条容器创建和连接
- ✅ 经验条容器创建和连接
- ✅ 编辑器系统集成
- ✅ 数据库配置验证
- ✅ 位置稳定性检查
- ✅ API 函数可用性

---

**最后更新**: 2026-04-26  
**维护者**: DragonUI 开发团队
