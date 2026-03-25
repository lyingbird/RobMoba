# 02 — 数据结构类型标注 SkillTypes

> **文件路径**: `ReplicatedStorage/SkillSystem/Types/SkillTypes.lua`  
> **HOK 来源**: `FrameCommand.h`（SkillParam 参数）、`SkillCache.h`（CacheEntry）、`SkillControlIndicator.cs`（IndicatorState 内部变量）

---

## 完整实现

```lua
-- 文件: ReplicatedStorage/SkillSystem/Types/SkillTypes.lua
--
-- Luau type annotation，供所有模块引用。
-- 这些类型不产生运行时开销，仅用于 Luau 类型检查和文档说明。

--------------------------------------------------------------------------------
-- 1. SkillSlot — 技能槽位运行时数据
--------------------------------------------------------------------------------
-- 由角色初始化时从配置表创建，CD/蓝量等字段实时更新。
-- HOK 等价: C# SkillSlotLinker + C++ SkillSlot
export type SkillSlot = {
    slotType: number,           -- SlotType 枚举值
    skillId: number,            -- 技能ID，对应 SkillConfig 的 key
    skillLevel: number,         -- 技能等级（影响伤害/CD等，非此模块关注）
    isEnabled: boolean,         -- 是否可用（被沉默/未学习时 false）
    cooldownEndTime: number,    -- CD结束时刻，os.clock() 基准
    cooldownTotal: number,      -- CD总时长（秒）
    manaCost: number,           -- 蓝量消耗
    rangeType: number,          -- SkillRangeType 枚举值
}

--------------------------------------------------------------------------------
-- 2. SkillParam — 技能释放参数（客户端→服务端）
--------------------------------------------------------------------------------
-- 由 SkillController 在 OnButtonUp 时构建，通过 RemoteEvent 发给服务端。
-- HOK 等价: UseDirectionSkillCmd / UsePositionSkillCmd / UseObjectiveSkillCmd
--
-- 不同 rangeType 使用不同字段:
--   Auto        → 只需 slotType + skillId
--   Target      → targetActorId（目标实体ID）+ targetPosition（锁定位置）
--   Pos         → targetPosition（落点）
--   Directional → targetDirection（方向向量）
--   Track       → trackPoints（路径点列表）
export type SkillParam = {
    slotType: number,
    skillId: number,
    rangeType: number,
    targetPosition: Vector3?,    -- Pos/Target 使用
    targetDirection: Vector3?,   -- Directional 使用（单位向量）
    targetActorId: number?,      -- Target 使用（目标的唯一ID）
    trackPoints: {Vector3}?,     -- Track 使用（有序路径点数组）
}

--------------------------------------------------------------------------------
-- 3. CacheEntry — 缓冲队列条目
--------------------------------------------------------------------------------
-- SkillCacheManager 内部使用。
-- HOK 等价: SkillCache.cacheSkillCommandList[i] + cacheSkillParamList[i]
export type CacheEntry = {
    skillParam: SkillParam,      -- 完整的技能参数
    timestamp: number,           -- 入队时刻，os.clock() 基准
    isCommonAttack: boolean,     -- 是否为普攻（普攻走独立标记，不占队列）
}

--------------------------------------------------------------------------------
-- 4. IndicatorState — 指示器运行时状态
--------------------------------------------------------------------------------
-- SkillIndicator 内部维护。
-- HOK 等价: SkillControlIndicator 的成员变量子集
export type IndicatorState = {
    isActive: boolean,           -- 是否正在显示
    slotType: number,            -- 当前激活的槽位
    guidePart: BasePart?,        -- Guide 层 Part 引用
    effectPart: BasePart?,       -- Effect 层 Part 引用
    fixedPart: BasePart?,        -- Fixed 层 Part 引用
    currentTargetPos: Vector3,   -- 当前平滑插值后的位置
    currentTargetDir: Vector3,   -- 当前平滑插值后的方向
}

--------------------------------------------------------------------------------
-- 5. CancelState — 取消区域检测状态
--------------------------------------------------------------------------------
-- CancelAreaDetector:GetState() 返回值。
-- HOK 等价: CSkillButtonManager 中的 m_currentSkillIndicatorInCancelArea + m_timeInCancelArea
export type CancelState = {
    isInCancelArea: boolean,     -- 当前是否在取消区域内
    timeInCancelArea: number,    -- 在取消区域内累计停留时间（秒）
    hasTriggeredVibration: boolean,  -- 是否已触发震动反馈
}

--------------------------------------------------------------------------------
-- 6. IndicatorConfig — 指示器配置条目
--------------------------------------------------------------------------------
-- 来源: HOK ResSkillIndicatorCfgInfo（48字节）精简
export type IndicatorConfig = {
    cfgId: number,
    rangeType: number,
    -- Guide 层
    guideEnabled: boolean,
    guideDistance: number,        -- 最大引导距离 (studs)
    guideResType: number,        -- IndicatorResType 枚举值
    -- Effect 层
    effectEnabled: boolean,
    effectRadius: number,        -- 作用半径 (studs)
    effectAngle: number,         -- 扇形角度 (°)，360=圆形
    effectWidth: number,         -- 矩形宽度 (studs)，0=非矩形
    effectLength: number,        -- 矩形长度 (studs)，0=非矩形
    effectResType: number,       -- IndicatorResType 枚举值
    effectResSize: number,       -- 资源原始尺寸（缩放用）
    effectResLength: number,     -- 资源原始长度（缩放用）
    -- Fixed 层
    fixedEnabled: boolean,
    fixedResType: number,        -- IndicatorResType 枚举值
}

--------------------------------------------------------------------------------
-- 7. SkillConfigEntry — 技能配置条目
--------------------------------------------------------------------------------
export type SkillConfigEntry = {
    skillId: number,
    skillName: string,
    slotType: number,
    rangeType: number,           -- SkillRangeType 枚举值
    cooldown: number,            -- CD 秒数
    manaCost: number,
    castRange: number,           -- 施法范围 (studs)
    indicatorCfgId: number,      -- 对应 IndicatorConfig 的 cfgId
}

return nil  -- 本文件仅提供类型标注，不导出运行时值
```

---

## 类型关系图

```
SkillConfigEntry ──(indicatorCfgId)──▶ IndicatorConfig
       │
       │ (skillId, rangeType)
       ▼
   SkillSlot ──(运行时)──▶ SkillParam ──(缓冲)──▶ CacheEntry
                                │
                                │ (RemoteEvent)
                                ▼
                           Server 校验
```

---

## 缩放公式速查

```
-- 指示器 Effect 层缩放（来源 HOK IndicatorHelper.GetIndicatorScaleLength）
scaleLength = guideDistance / effectResLength   -- 新配置（effectResLength > 0）
scaleLength = guideDistance / 10000            -- 旧配置（effectResLength == 0）
scaleWidth  = expectWidth  / effectResSize     -- 宽度缩放
```
