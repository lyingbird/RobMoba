# 07 — 技能目标选择 SelectSkillTarget

> **文件路径**: `StarterPlayerScripts/SkillSystem/SkillController.lua`（内部方法）

---

## 设计说明

`SelectSkillTarget` 是每次 Drag 时调用的核心方法，根据技能类型将屏幕空间的拖动信息转换为世界空间的目标位置/方向。它不是独立文件，而是 `SkillController` 的内部方法集合。

## 总入口

```lua

function SC:_SelectSkillTarget(rt, axis, normOff)
    local R = Enums.SkillRangeType
    if     rt == R.Target      then self:_ST_Target(axis, normOff)
    elseif rt == R.Pos         then self:_ST_Pos(axis, normOff)
    elseif rt == R.Directional then self:_ST_Dir(axis, normOff)
    elseif rt == R.Track       then self:_ST_Track(axis, normOff)
    end
    self:_RefreshIndicatorShow(normOff)
end
```

### 参数说明

| 参数 | 类型 | 来源 | 含义 |
|---|---|---|---|
| `rt` | number | `self._rangeType` | 技能范围指定类型 |
| `axis` | Vector2 | `(screenPos - btnCenter).Unit` | 屏幕空间归一化拖动方向 |
| `normOff` | number (0~1) | `clamp(mag/120, 0, 1)` | 拖动距离占最大半径的比例 |

### 输出（写入 self 成员）

| 成员 | Target | Pos | Directional | Track |
|---|---|---|---|---|
| `_targetPos` | 角色+偏移 | 角色+偏移 | 角色位置 | 角色+偏移 |
| `_targetDir` | 偏移方向 | 偏移方向 | 拖动方向 | 轨迹末段方向 |
| `_targetActor` | 敌方ID/0 | 0 | 0 | 0 |
| `_moveFlag` | false | **true** | false | true |
| `_rotateFlag` | **true** | true | **true** | false |

---

## 7.1 Target 型（指定目标）

> 来源: `SelectSkillTarget()` 第3583-3634行

```lua
-- 逻辑说明:
--   Target 型技能（如"一技能锁人"）的拖动交互分两种模式：
--   · 简易模式 (normOff ≤ 0.5): 不精确选择，锁定角色周围最近的敌方
--   · 高级模式 (normOff > 0.5): 精确选择，以拖动落点为中心搜索敌方
--
-- 原文分界线: offset.magnitude <= guideDistance * 0.5f
-- 对应: normOff * guideDistance <= guideDistance * 0.5 → normOff <= 0.5

function SC:_ST_Target(axis, normOff)
    local gd = self._indCfg.guideDistance
    local wDir = self:_AxisToWorld(axis)        -- Vector3: 世界XZ方向
    local offset = wDir * (gd * normOff)        -- Vector3: 世界空间偏移
    local cPos = self:_CharPos()                -- Vector3: 角色当前位置
    
    -- 目标位置 = 角色位置 + 偏移
    self._targetPos = cPos + offset
    self._rotateFlag = true
    self._moveFlag = false
    
    -- 方向 = 偏移方向（用于指示器旋转）
    if offset.Magnitude > 0.01 then
        self._targetDir = offset.Unit
    end

    -- 简易 vs 高级 模式
    local advanced = normOff > 0.5
    
    if advanced then
        -- 高级模式: 以 targetPos 为圆心，effectRadius 为半径搜索
        -- 玩家拖得远 → 可以精确选择特定敌方
        self._targetActor = self:_FindEnemy(
            self._targetPos,
            self._indCfg.effectRadius or 3
        )
    else
        -- 简易模式: 以角色位置为圆心，guideDistance 为半径搜索最近目标
        -- 玩家拖得近/没拖 → 自动锁定最近的敌方
        self._targetActor = self:_FindEnemy(cPos, gd)
        if self._targetActor > 0 then
            -- 如果找到目标，让 targetPos 跟踪到目标位置（而不是拖动位置）
            self._targetPos = self:_ActorPos(self._targetActor)
        end
    end
end
```

### Target 型交互图

```
简易模式 (normOff ≤ 0.5):

  [角色]──────◎最近敌方
          ↑
    自动锁定最近目标
    指示器显示在目标位置

高级模式 (normOff > 0.5):

  [角色]─────────────────⊕落点
                         │
                    以落点为中心
                    搜索 effectRadius 内的敌方

  手指拖得越远，选择越精确
```

---

## 7.2 Pos 型（指定位置）

> 来源: `SelectSkillTarget()` 第3636-3706行

```lua
-- 逻辑说明:
--   Pos 型技能（如"二技能指定落点"）允许玩家将技能释放到地图上任意位置
--   关键区别于 Target 型:
--   · 不搜索敌方目标（落点可以是空地）
--   · moveFlag = true → 指示器跟随拖动移动
--   · controlMove → 记录是否产生了有效拖动（用于防误触判定）
--
-- 原文: bMoveFlag = true; bControlMove = true

function SC:_ST_Pos(axis, normOff)
    local gd = self._indCfg.guideDistance
    local wDir = self:_AxisToWorld(axis)
    local offset = wDir * (gd * normOff)
    local cPos = self:_CharPos()
    
    self._targetPos = cPos + offset
    self._moveFlag = true           -- ← 关键区别！指示器会跟着拖动移动
    self._rotateFlag = true
    
    -- controlMove: 一旦拖动超过 5%，标记为有效拖动
    -- 这是防误触的关键：如果 controlMove 始终为 false，说明用户只是点了一下没拖
    if normOff > 0.05 then
        self._controlMove = true
    end
    
    if offset.Magnitude > 0.01 then
        self._targetDir = offset.Unit
    end
end
```

### Pos 型交互图

```
  [角色]─ ─ ─ ─ ─ ─ ─⊕技能落点
    │                    ↑
    │              指示器跟随拖动
    │              (moveFlag=true)
    │
    ◎ Guide层(最大范围圆)
```

---

## 7.3 Directional 型（指定方向）

> 来源: `SelectSkillTarget()` 第3708-3740行

```lua
-- 逻辑说明:
--   Directional 型技能（如"大招向某方向释放"）只关心方向，不关心距离
--   关键区别:
--   · 不计算位置偏移 → targetPos 始终是角色脚下
--   · moveFlag = false → 指示器固定在角色脚下
--   · 只设置 targetDir（方向）
--
-- 原文:
--   dir.x = axis.x; dir.z = axis.y
--   bRotateFlag = true; bMoveFlag 不设置(保持false)
--
-- 方向插值:
--   有4种旋转插值模式 (RotateLerpMode 0/1/2/3)
--   Roblox 精简为 CFrame:Lerp 在 SkillIndicator.Tick() 中处理

function SC:_ST_Dir(axis, normOff)
    local wDir = self:_AxisToWorld(axis)
    
    -- 只设方向，不设位置偏移
    if wDir.Magnitude > 0.01 then
        self._targetDir = wDir.Unit
    end
    
    -- 位置始终是角色脚下
    self._targetPos = self:_CharPos()
    
    self._rotateFlag = true
    self._moveFlag = false
end
```

### Directional 型交互图

```
              指示器方向跟随拖动旋转
                    ↗
  ╱╱╱╱╱╱╱╱╱╱╱╱╱╱  ← 矩形/箭头指示器
  [角色]              ← 固定在角色脚下
  ╲╲╲╲╲╲╲╲╲╲╲╲╲╲

  注意: 拖动距离不影响技能范围
  只有拖动方向决定释放朝向
```

### 四种旋转插值模式（参考）

| 模式 | 算法 | 适用场景 |
|---|---|---|
| 0 | Euler 角速度限制 | 默认 |
| 1 | Slerp 球面插值 | 平滑旋转 |
| 2 | SmoothDamp | 带阻尼 |
| 3 | AngleSmoothDamp | 角度阻尼 |

Roblox 版统一用 `CFrame:Lerp(target, t)` 实现，`t = dt * 15`（在 `SkillIndicator:Tick()` 中）。

---

## 7.4 Track 型（指定轨迹）

> **注意**: 中此类型**已完全废弃/未实现**。枚举值 `Track=4` 保留但无实际逻辑。以下为合理推断设计。

```lua
-- 逻辑说明:
--   Track 型技能允许玩家绘制一条路径作为技能参数
--   按下开始记录，每次 Drag 追加一个轨迹点（间距≥1 stud），抬起时整条轨迹作为参数
--
-- 这是 中没有实际实现的类型，以下为参考设计
-- 实现者可根据需要决定是否支持

function SC:_ST_Track(axis, normOff)
    local gd = self._indCfg.guideDistance
    local wDir = self:_AxisToWorld(axis)
    local cPos = self:_CharPos()
    local pt = cPos + wDir * (gd * normOff)
    
    self._targetPos = pt
    
    -- 初始化轨迹列表
    if not self._trackPts then
        self._trackPts = {}
        self._lastTrackPt = cPos
    end
    
    -- 间距≥1 stud 才记录（避免点过密）
    if (pt - self._lastTrackPt).Magnitude >= 1.0 then
        table.insert(self._trackPts, pt)
        self._lastTrackPt = pt
    end
    
    self._moveFlag = true
    self._rotateFlag = false
    
    -- 方向 = 轨迹末两点的连线方向
    local n = #self._trackPts
    if n >= 2 then
        local d = self._trackPts[n] - self._trackPts[n - 1]
        if d.Magnitude > 0.01 then
            self._targetDir = d.Unit
        end
    end
end
```

### Track 型交互图

```
  [角色]──→⊙──→⊙──→⊙──→⊙──→⊙  ← 轨迹点列表
                                    每次 Drag 追加
                                    间距≥1 stud

  最终参数: trackPoints = {pt1, pt2, pt3, pt4, pt5}
  服务端可沿此轨迹移动弹道/角色
```

---

## 7.5 辅助方法：_AxisToWorld

```lua
-- 将屏幕空间2D方向转换为世界空间XZ方向
-- 核心问题: 屏幕的"上"不一定对应世界的"北"
-- 解法: 用摄像机的 LookVector 投影到 XZ 平面作为"前方"
--


function SC:_AxisToWorld(axis: Vector2): Vector3
    local cam = workspace.CurrentCamera
    if not cam then
        -- 无摄像机时的回退: 直接映射
        return Vector3.new(axis.X, 0, -axis.Y)
    end
    
    -- 摄像机前方向投影到 XZ 平面
    local look = cam.CFrame.LookVector
    local fwd = Vector3.new(look.X, 0, look.Z).Unit   -- 前
    local rt  = Vector3.new(fwd.Z, 0, -fwd.X)         -- 右（逆时针90°）
    
    -- 组合: 屏幕X → 世界右方，屏幕Y(取反) → 世界前方
    -- 取反原因: 屏幕 Y 轴向下为正，世界中"向前"对应屏幕"向上"
    local w = rt * axis.X + fwd * (-axis.Y)
    
    return w.Magnitude > 0.01 and w.Unit or Vector3.zero
end
```

### 坐标映射图解

```
屏幕空间:                世界空间 (俯视):
   Y↑                       Z↑ (fwd)
   │                        │
   │                        │
   ○──→ X              ←────○────→ X (rt)
                            │
                            ↓

axis = (1, 0)  → 世界 rt 方向 (右)
axis = (0, -1) → 世界 fwd 方向 (前)  ← 注意取反
axis = (0, 1)  → 世界 -fwd 方向 (后)
```

---

## 四种类型总对比

| 维度 | Target | Pos | Directional | Track |
|---|---|---|---|---|
| **核心输出** | 目标位置+敌方ID | 目标位置 | 目标方向 | 轨迹点列表 |
| **normOff 含义** | 简易/高级分界 | 落点距离 | 不使用 | 落点距离 |
| **moveFlag** | ✗ | ✔ | ✗ | ✔ |
| **rotateFlag** | ✔ | ✔ | ✔ | ✗ |
| **指示器行为** | 锁定目标位置 | 跟随拖动 | 固定脚下旋转 | 沿轨迹线 |
| **需要索敌** | ✔ | ✗ | ✗ | ✗ |
| **状态** | 完整实现 | 完整实现 | 完整实现 | 已废弃 |
| **建议优先级** | P0 | P0 | P0 | P2(可跳过) |

---

> **下一步**: `08_SkillIndicator/`
