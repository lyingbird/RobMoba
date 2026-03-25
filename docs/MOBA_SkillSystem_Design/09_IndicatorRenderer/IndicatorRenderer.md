# 09 — 指示器渲染器 IndicatorRenderer

> **文件路径**: `StarterPlayerScripts/SkillSystem/IndicatorRenderer.lua`  
> **职责**: Part 创建/回收/缩放/显隐/颜色 — 纯渲染层，不含游戏逻辑

---

## 设计说明

的指示器渲染涉及：
- **指示器工具** — 1161行工具类：缩放计算、显隐控制（Layer切换）、颜色设置、Prefab创建
- **指示器基类** — 351行：三层资源创建/销毁/位置设置

Roblox 版合并为 `IndicatorRenderer`，用 Part 原语替代 Prefab：
- 圆形 = Cylinder Part（Y轴极扁）
- 扇形 = Cylinder Part + SectorAngle 属性
- 矩形/箭头 = Block Part
- 线 = 极细 Block Part 或 Beam

### 显隐 vs Roblox 显隐

| | Roblox | 说明 |
|---|---|---|
| Layer 切换 Actor↔Hide | Transparency 0.5↔1 | 通过修改 GameObject.layer 实现，摄像机只渲染 Actor 层 |
| SetActive(false) | Transparency = 1 | 推荐 Transparency 而非 part.Parent = nil，避免频繁创建/销毁 |

### 缩放公式（来源: 指示器工具.GetIndicatorScaleLength）

```
新配置表: scaleLength = guideDistance / effectResLength
旧配置表: scaleLength = guideDistance / 10000.0f
宽度:     scaleWidth  = expectWidth / resWidth
```

## 完整伪代码

```lua
-- 文件: StarterPlayerScripts/SkillSystem/IndicatorRenderer.lua

local Enums = require(game.ReplicatedStorage.SkillSystem.Enums.SkillEnums)

local IR = {}; IR.__index = IR

-- 预定义颜色
local COLORS = {
    Default      = Color3.fromRGB(100, 180, 255),  -- 蓝色: 默认技能范围
    Warn         = Color3.fromRGB(255, 80, 80),     -- 红色: 警告/取消
    Guide        = Color3.fromRGB(255, 255, 255),   -- 白色: Guide 层
    DelayConfirm = Color3.fromRGB(255, 200, 50),    -- 黄色: 延迟确认
}

-- 默认半透明度
local ALPHA_VISIBLE = 0.5
local ALPHA_HIDDEN  = 1.0  -- Transparency = 1 → 完全透明

function IR.new()
    local self = setmetatable({}, IR)
    -- 创建统一的容器 Folder
    self._folder = Instance.new("Folder")
    self._folder.Name = "SkillIndicators"
    self._folder.Parent = workspace
    return self
end
```

### Create — 创建 Part

```lua

-- 根据资源类型创建对应形状的 Part
--
-- 参数:
--   layer: IndicatorLayer 枚举 (Guide=1, Effect=2, Fixed=3)
--   resType: IndicatorResType 枚举 (Arrow=0, Sector=1, Circle=2, ...)
--   p: 参数表 {radius?, angle?, width?, length?}
--
-- 返回: BasePart

function IR:Create(layer, resType, p): BasePart
    local part
    local RT = Enums.IndicatorResType
    
    if resType == RT.Circle or resType == RT.Ring then
        -- 圆形/圆环: Cylinder Part
        -- Y 轴极扁(0.05)放平在地面
        part = Instance.new("Part")
        part.Shape = Enum.PartType.Cylinder
        local d = (p.radius or 3) * 2
        part.Size = Vector3.new(0.05, d, d)
        
    elseif resType == RT.Sector or resType == RT.HalfCircle then
        -- 扇形/半圆: 用 Cylinder 近似，附加 SectorAngle 属性
        -- 实际扇形效果需要用 SurfaceGui + 自定义绘制 或 MeshPart
        -- 这里用 Cylinder 作为占位，通过属性标记角度
        part = Instance.new("Part")
        part.Shape = Enum.PartType.Cylinder
        local d = (p.radius or 3) * 2
        part.Size = Vector3.new(0.05, d, d)
        part:SetAttribute("SectorAngle", p.angle or 60)
        
    elseif resType == RT.Arrow or resType == RT.Rectangle then
        -- 箭头/矩形: Block Part
        part = Instance.new("Part")
        part.Shape = Enum.PartType.Block
        part.Size = Vector3.new(p.width or 2, 0.05, p.length or 10)
        
    elseif resType == RT.Line then
        -- 线型: 极细 Block Part
        part = Instance.new("Part")
        part.Shape = Enum.PartType.Block
        part.Size = Vector3.new(0.2, 0.05, p.length or 10)
        
    else
        -- 默认: 圆形
        part = Instance.new("Part")
        part.Shape = Enum.PartType.Cylinder
        local d = (p.radius or 3) * 2
        part.Size = Vector3.new(0.05, d, d)
    end
    
    -- 通用属性
    part.Color = (layer == 1) and COLORS.Guide or COLORS.Default
    part.Transparency = ALPHA_VISIBLE
    part.CanCollide = false    -- 不参与物理碰撞
    part.Anchored = true       -- 不受物理影响
    part.CastShadow = false    -- 不投射阴影
    part.Material = Enum.Material.Neon  -- 自发光材质
    part.Parent = self._folder
    
    return part
end
```

### Destroy — 销毁 Part

```lua

-- 使用对象池回收，Roblox 简化为直接销毁
-- 高级优化: 可改为对象池模式

function IR:Destroy(part)
    if part then part:Destroy() end
end
```

### SetPos — 设置位置（无旋转）

```lua
-- 用于 Guide 层和 Fixed 层（不需要朝向）
-- Cylinder 需要额外旋转 90° 放平

function IR:SetPos(part, pos: Vector3)
    if not part then return end
    
    -- Y 轴偏移 0.1 避免与地面 Z-fighting
    local elevated = pos + Vector3.new(0, 0.1, 0)
    
    if part.Shape == Enum.PartType.Cylinder then
        -- Cylinder 默认沿 X 轴，需旋转 90° 让圆面朝上
        part.CFrame = CFrame.new(elevated) * CFrame.Angles(0, 0, math.rad(90))
    else
        part.CFrame = CFrame.new(elevated)
    end
end
```

### SetPosRot — 设置位置和朝向

```lua
-- 用于 Effect 层（需要朝向，如箭头/扇形）


function IR:SetPosRot(part, pos: Vector3, dir: Vector3)
    if not part then return end
    
    local elevated = pos + Vector3.new(0, 0.1, 0)
    local cf = CFrame.lookAt(elevated, elevated + dir)
    
    if part.Shape == Enum.PartType.Cylinder then
        -- 扇形 Cylinder 需要朝向 + 放平
        if part:GetAttribute("SectorAngle") then
            part.CFrame = cf * CFrame.Angles(0, 0, math.rad(90))
        else
            -- 普通圆形不需要朝向
            part.CFrame = CFrame.new(elevated) * CFrame.Angles(0, 0, math.rad(90))
        end
    else
        -- Block Part: lookAt 直接给出正确朝向
        part.CFrame = cf
    end
end
```

### Show — 显隐切换

```lua

-- 通过 Layer 切换 (Actor↔Hide)
-- Roblox 通过 Transparency 切换

function IR:Show(part, vis)
    if part then
        part.Transparency = vis and ALPHA_VISIBLE or ALPHA_HIDDEN
    end
end
```

### SetColor — 颜色切换（可选）

```lua

-- 用于取消区域红色提示、延迟确认黄色等

function IR:SetColor(part, colorKey: string)
    if part and COLORS[colorKey] then
        part.Color = COLORS[colorKey]
    end
end
```

---

## 进阶优化建议

### 1. 对象池

使用 `CreatePrefab` 从对象池获取，`UnInitIndicatePrefab` 回收到池。高频创建/销毁 Part 会有性能开销，建议实现简单的对象池：

```lua
-- 示例对象池
local pool = {}
function IR:_GetFromPool(shape)
    local key = tostring(shape)
    if pool[key] and #pool[key] > 0 then
        return table.remove(pool[key])
    end
    return nil  -- 没有缓存，需要新建
end

function IR:_ReturnToPool(part)
    local key = tostring(part.Shape)
    pool[key] = pool[key] or {}
    table.insert(pool[key], part)
    part.Transparency = 1  -- 隐藏
end
```

### 2. 扇形 MeshPart

Cylinder Part 无法真正显示扇形。正式实现建议：
- 使用 `EditableMesh`（如果 Roblox 支持）
- 或预制 MeshPart 资源（30°/60°/90°/120°/180° 等常用角度）
- 或 SurfaceGui + UIGradient 方案

### 3. Beam 指示器

对于 Line/Arrow 型，`Beam` 对象可能比 Block Part 更美观：
- 支持纹理、渐变、弯曲
- 挂在两个 Attachment 之间
- 适合长距离方向指示

---

> **下一步**: `10_CancelAreaDetector/`
