# 子任务卡片

## 基本信息
| 属性 | 值 |
|------|-----|
| 任务ID | TASK-09 |
| 父需求 | REQ-011 手机端MOBA UI与操控系统 |
| 子任务名称 | UI_Minimap 小地图 |
| 执行者 | 程序 Agent |
| 优先级 | 3 |
| Phase | C |
| 预估行数 | ~120行 |

## 任务描述
实现简化版小地图，显示在左上角（英雄状态区下方），展示竞技场平面缩略 + 己方蓝色圆点 + 敌方红色圆点，每0.5s更新位置标记。

## 技术要求
- 文件路径: `src/StarterPlayer/StarterPlayerScripts/UIComponents/UI_Minimap.lua`
- 类型: ModuleScript
- **纯UI方案**: 使用 Frame + ImageLabel 实现，**不使用 ViewportFrame**（性能考虑）
- 坐标映射: 世界坐标(X, Z) → 小地图像素坐标(比例映射)
- 更新频率: 0.5s (task.delay 循环)
- UI层级: ZIndex = 5

## 输入依赖
- 需要读取: `03_技术设计.md` 第3.2节(MOD-06), `02_UX设计.md` 第2.7节(小地图设计)
- 依赖的类: `MobileConfig`(常量), 竞技场地图边界数据

## 输出要求
- 产出文件: `src/StarterPlayer/StarterPlayerScripts/UIComponents/UI_Minimap.lua`
- 代码规范: 遵循项目编码规范

## 接口约定
```lua
local UI_Minimap = {}

function UI_Minimap.Init(parentFrame: Frame, mapBounds: {min: Vector2, max: Vector2}): ()
-- mapBounds: 竞技场地面的世界坐标范围 (min XZ, max XZ)
-- 创建: 背景Frame + 己方标记(蓝色圆) + 敌方标记(红色圆)
-- 启动: 0.5s 定时更新循环

function UI_Minimap.UpdatePositions(myPosition: Vector3, enemyPosition: Vector3?): ()
-- 世界坐标 → 小地图比例坐标
-- enemyPosition 为 nil 时隐藏敌方标记

function UI_Minimap.SetVisible(visible: boolean): ()

function UI_Minimap.Destroy(): ()

return UI_Minimap
```

### 核心逻辑要点
1. **坐标映射**: `mapX = (worldX - minX) / (maxX - minX) * mapWidth`
2. **定时更新**: `task.delay(0.5, updateLoop)` 循环, 读取 LocalPlayer 和敌方位置
3. **敌方位置获取**: 遍历 workspace 中的 Teams/角色, 取非己方角色的 HumanoidRootPart.Position
4. **视觉**: 灰色底色背景 + 白色边框, 蓝色圆点(己方, 直径4px), 红色圆点(敌方, 直径4px)
5. **1v1简化**: 仅显示2个标记点, 无地形/建筑细节

## 与其他模块的关系
- 被依赖: Client.client.lua (初始化)
- 依赖: MobileConfig(常量), workspace角色位置
