---
# 注意不要修改本文头文件，如修改，CodeBuddy（内网版）将按照默认逻辑设置
type: manual
---
# 技能：人机协作调试 SOP (Debug Collaboration)

> **领域**: testing / debugging
> **适用Agent**: 程序 / QA / 主程
> **加载时机**: 当用户报告 Bug、提供截图/录屏描述问题时按需加载
> **创建日期**: 2026-03-16
> **大小**: ~4KB

## 📌 核心原则

**截图 + 文字描述 > 录屏**  
AI 无法播放视频，但能像素级分析截图。配合 MCP 实时诊断工具链，效率远高于猜测。

## 🔄 标准调试流程 (4步循环)

### Step 1: 用户报告 Bug

用户提供以下信息（越全越好）：

```
【Bug 报告模板】
1. 截图/图片: (粘贴或拖入 1~3 张关键截图)
2. 现象描述: (一句话说清"什么东西"+"怎么了")
3. 复现步骤: (操作1 → 操作2 → 出现问题)
4. 预期行为: (你期望看到什么)
5. 环境: (Device Emulator / 真机iPhone / PC)
```

**最小有效报告**: 1张截图 + 1句话描述就够了，其他可以我来问。

### Step 2: AI 分析定位

AI 按优先级使用以下诊断手段：

| 优先级 | 手段 | 说明 | 适用场景 |
|--------|------|------|----------|
| P0 | 📸 截图分析 | 直接看截图判断 UI/布局/状态 | UI 不可见、位置错误、显示异常 |
| P1 | 🔍 代码走读 | 搜索/阅读相关代码文件 | 逻辑错误、回调链断裂、参数错误 |
| P2 | 🖥️ MCP execute_luau | 运行时检查 Instance 属性/状态 | 属性值不对、对象缺失、层级错误 |
| P3 | 📋 MCP get_console_output | 读取控制台日志 | 运行时错误、warn、逻辑流程追踪 |
| P4 | 🔬 注入诊断代码 | 在关键位置加 print/warn | 回调链断裂、值传递错误、时序问题 |
| P5 | 🖱️ MCP user_mouse_input | 模拟点击验证 | 交互逻辑验证（仅限瞬时点击） |

### Step 3: 修复 + 注入验证

1. AI 修改源文件（本地 src/）
2. 同步到 Studio（优先 Rojo；Rojo 不可用时用 execute_luau 写 script.Source）
3. Start Play → 自动化验证 → 读 console 确认
4. 如需用户操作（长按拖动、真机测试等），明确告知操作步骤

### Step 4: 用户二次确认

用户手动验证 → 通过则关闭 Bug → 未通过则回到 Step 1

---

## 🛠️ MCP 诊断工具链速查

### 运行时状态检查 (execute_luau)
```lua
-- 检查 GUI 元素
local gui = game.Players.LocalPlayer.PlayerGui:FindFirstChild("MobileUI")
return gui and #gui:GetDescendants() or "MobileUI not found"

-- 检查角色位置
local hrp = game.Players:GetPlayers()[1].Character.HumanoidRootPart
return string.format("%.2f, %.2f, %.2f", hrp.Position.X, hrp.Position.Y, hrp.Position.Z)

-- 检查属性值
local btn = game.Players.LocalPlayer.PlayerGui.MobileUI.MobileFrame:FindFirstChild("Btn_Q", true)
return btn and string.format("Size=%s, Visible=%s, Pos=%s", tostring(btn.AbsoluteSize), tostring(btn.Visible), tostring(btn.AbsolutePosition)) or "not found"
```

### 注入诊断代码 (execute_luau + script.Source gsub)
```lua
-- 在指定函数入口注入 print
local s = game.StarterPlayer.StarterPlayerScripts.UIComponents.UI_VirtualJoystick
local src = s.Source
s.Source = src:gsub(
    "local function onTouchBegan",
    'local function onTouchBegan\n\twarn("[DIAG] onTouchBegan fired")\n--原始: local function onTouchBegan'
)
```
**重要**: 诊断代码只在 StarterPlayer 脚本中注入 → 必须 Stop → Start 才生效（Play 中修改不影响已 clone 的运行时脚本）。

### 控制台过滤
```
get_console_output → 搜索 [DIAG] / error / warn 关键词
```

---

## ⚠️ 已知限制与应对

| 限制 | 根因 | 应对策略 |
|------|------|----------|
| 无法分析视频 | AI 不支持视频输入 | 截取关键帧截图 + 文字描述 |
| MCP 鼠标只能瞬时点击 | mouseDown+mouseUp 在同一帧 | 注入诊断 print → 用户手动长按 → 读 console |
| execute_luau 是服务端上下文 | Command Bar 运行在 Server | 不能直接读客户端 module 运行时状态；用 print 注入间接获取 |
| Play 中修改 StarterPlayer 无效 | Roblox clone 机制 | 必须 Stop → 改 Source → Start |
| multi_edit MCP 工具不稳定 | 已知 bug | 用 execute_luau + script.Source 绕过 |
| Rojo 可能崩溃 | 端口冲突/进程退出 | 检查 netstat → 重启；或 execute_luau 直接写 Source |

---

## 📋 Bug 复杂度与响应策略

| 复杂度 | 特征 | 预计轮次 | 示例 |
|--------|------|----------|------|
| 🟢 简单 | 截图一看就知道原因 | 1轮 | UI 元素不可见（Size=0）、位置偏移 |
| 🟡 中等 | 需要代码走读 + 1次诊断 | 2~3轮 | 回调未绑定、参数格式不匹配 |
| 🔴 复杂 | 多层根因链、时序问题 | 3~5轮 | 摇杆移动5层根因链、Rojo同步丢失 |

---

## 🔗 关联技能

- [Roblox Studio 测试方法](./roblox-studio-testing.md)
- [Roblox UI 模式](../roblox/ui-patterns.md)
- [Luau Nil 安全](../luau/nil-safety.md)
