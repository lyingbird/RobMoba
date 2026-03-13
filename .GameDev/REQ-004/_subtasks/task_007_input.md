# 子任务卡片

## 基本信息
| 属性 | 值 |
|------|-----|
| 任务ID | TASK-007 |
| 父需求 | REQ-004 自由大厅+匹配对决 |
| 子任务名称 | 匹配区域物理检测 |
| 执行者 | 程序 Agent |
| 优先级 | 3 |

## 任务描述
在出生点旁创建匹配区域的物理检测和视觉效果：
1. 创建透明 Part 作为检测区域 (半径15 studs圆柱)
2. Touched/TouchEnded 检测玩家进出
3. 进入区域 → FireServer MatchmakingEvent {action="join"}
4. 离开区域 → FireServer MatchmakingEvent {action="leave"}
5. 防抖: 0.5秒内不重复处理
6. 视觉效果: 地面发光圆环 + 上方悬浮文字 "⚔️ PvP 匹配"
7. 同步匹配按钮状态 (进入区域→按钮变为取消状态)

注意: 此功能集成到 LobbyManager 服务端（区域检测在服务端），或作为客户端脚本。推荐服务端检测更安全。

## 技术要求
- 集成到: `src/ServerScriptService/LobbyManager.server.lua` (在T2基础上追加)
- 或新建: 客户端检测脚本
- 预估行数: ~60行

## 输入依赖
- 依赖: T2(LobbyManager的匹配API)
- 依赖: Workspace中的匹配区域Part (需手动放置或代码创建)

## 输出要求
- 在LobbyManager中新增区域检测逻辑
- 或新建独立检测脚本

## 接口约定
```lua
-- 匹配区域参数
local ZONE_RADIUS = 15  -- studs
local ZONE_CENTER = Vector3.new(-180, 62, 180)  -- 出生点旁 (需根据地图调整)
local DEBOUNCE_TIME = 0.5  -- 防抖间隔

-- 服务端: 创建检测区域Part
local zonePart = Instance.new("Part")
zonePart.Shape = Enum.PartType.Cylinder
zonePart.Size = Vector3.new(2, ZONE_RADIUS * 2, ZONE_RADIUS * 2)
zonePart.Transparency = 0.8
zonePart.CanCollide = false
zonePart.Anchored = true

-- Touched/TouchEnded 检测
zonePart.Touched:Connect(function(hit) ... end)
zonePart.TouchEnded:Connect(function(hit) ... end)
```

## 与其他模块的关系
- 被依赖: 无
- 依赖: T2(LobbyManager匹配API)
