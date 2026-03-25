# 03-C — 全局常量配置 GlobalConfig

> **文件路径**: `ReplicatedStorage/SkillSystem/Config/GlobalConfig.lua`  
> **HOK 来源**: `RES_GLOBAL_CONF_TYPE_XXX` 枚举系列 + `RES_GAMECORE_CONF_TYPE_XXX` + 各模块硬编码值

---

## 设计说明

HOK 的全局配置分散在多个系统中（全局配置表、GameCore配置表、代码硬编码）。Roblox 版集中到一个文件，每个常量标注 HOK 来源，方便调参。

---

## 完整实现

```lua
-- 文件: ReplicatedStorage/SkillSystem/Config/GlobalConfig.lua
--
-- 所有影响手感的可调参数集中在此。
-- 修改这些值可以直接影响操作体验，无需改代码。
-- 每个值标注了 HOK 来源，方便追溯。

return {

    -- ================================================================
    -- 缓冲区 (SkillCacheManager)
    -- ================================================================

    -- 技能缓冲队列最大长度
    -- HOK: RES_GLOBAL_CONF_TYPE_SKILL_CACHE_LIST_MAX_COUNT (枚举值1197)
    -- HOK 默认值: 配置不存在时回退到 1
    -- 含义: 当前技能释放中，最多允许缓存几个后续技能
    SKILL_CACHE_MAX_COUNT = 1,

    -- 技能缓存过期时间（秒）
    -- HOK: RES_GLOBAL_CONF_TYPE_SKILL_CACHE_LIST_EXPIRED_TIME (枚举值1198)
    -- 含义: 缓存的技能超过此时间未触发则清空
    SKILL_CACHE_EXPIRED_TIME = 2.0,

    -- ================================================================
    -- 连续普攻窗口 (SkillCacheManager)
    -- ================================================================

    -- 连续普攻窗口开始百分比
    -- HOK: RES_GAMECORE_CONF_TYPE_CONTINUE_CACHEATTACK_WINDOW_BEGIN (枚举值3)
    -- 公式: windowBegin = curTime + attackCD × (此值/100)
    -- 含义: 普攻CD进度到70%后按普攻 → 缓存并在CD结束后立即续接
    CONTINUE_ATTACK_WINDOW_BEGIN_PCT = 70,

    -- 追击窗口开始百分比
    -- HOK: RES_GAMECORE_CONF_TYPE_CONTINUE_CACHEnPURSUE_WINDOW_BEGIN (枚举值14)
    -- 含义: 普攻CD进度到50%后按普攻 → 角色提前移向目标
    CONTINUE_PURSUE_WINDOW_BEGIN_PCT = 50,

    -- ================================================================
    -- 取消区域 (CancelAreaDetector)
    -- ================================================================

    -- 取消区域停留阈值（秒）
    -- HOK: CSkillButtonManager 中 m_SkillInCancelAreaTimeInterval 默认 0.15
    -- 含义: 手指在取消区域停留超过此时间 → 抬手时判定为取消
    --        防止手指快速划过取消区域时误取消
    CANCEL_AREA_STAY_THRESHOLD = 0.15,

    -- 距离取消阈值（像素）
    -- HOK: c_skillICancleRadius = 270
    -- 含义: 手指从按钮中心拖动超过 270 像素 → 进入取消状态
    CANCEL_DISTANCE_THRESHOLD = 270,

    -- ================================================================
    -- 防误触 (SkillController._IsAllowUseSkill)
    -- ================================================================

    -- Pos 型按压时间阈值（秒）
    -- HOK: IsAllowUseSkill() 硬编码 pressTime <= 1000ms
    -- 含义: Pos 型技能，未拖动且按压不到1秒 → 判为误触不释放
    --        迫使玩家至少拖动一下或长按1秒才能释放 Pos 技能
    POS_PRESS_TIME_THRESHOLD = 1.0,

    -- Directional 型快速点击阈值（秒）
    -- HOK: OnSkillButtonUp() 中 pressDuration <= 400ms
    -- 含义: Directional 型，按下后 ≤0.4秒即放手 → 按角色当前朝向释放
    --        忽略最小拖动距离阈值，允许"快速点按即放"
    DIR_QUICK_TAP_THRESHOLD = 0.4,

    -- ================================================================
    -- 指示器 (SkillController / SkillIndicator)
    -- ================================================================

    -- 拖动判定阈值（像素）
    -- 含义: 手指从按下位置移动超过此距离 → 状态从 Pressing 切为 Dragging
    DRAG_THRESHOLD = 10,

    -- 指示器更新节流（每N帧更新一次）
    -- 含义: 降低 Heartbeat 中 Tick 的调用频率，减少性能开销
    -- 值为 2 表示每隔1帧更新一次（60FPS下约30次/秒）
    INDICATOR_UPDATE_INTERVAL = 2,

    -- ================================================================
    -- 受控保护 (SkillCacheManager)
    -- ================================================================

    -- 受控保护窗口（秒）
    -- HOK: SkillInputCacheDuration Enter() 中设置 getControlProtectExpire
    -- 含义: 技能释放中被硬控（眩晕/击飞等），如果在此窗口内解控
    --        → 自动释放缓存的技能（保证操作连贯性）
    --        超过此窗口解控 → 清空缓存
    CONTROL_PROTECT_DURATION = 0.5,

    -- ================================================================
    -- 指示器平滑参数
    -- ================================================================

    -- 位置插值速度因子
    -- Lerp: currentPos = currentPos:Lerp(targetPos, dt * 此值)
    -- 值越大跟手越紧，值越小越平滑但有延迟
    INDICATOR_LERP_SPEED = 15,

    -- 方向插值速度因子（同上）
    DIRECTION_LERP_SPEED = 15,

    -- ================================================================
    -- Track 型参数（预留）
    -- ================================================================

    -- 轨迹点最小间距（studs）
    -- 含义: Track 型技能拖动时，相邻两个记录点的最小距离
    TRACK_MIN_POINT_DISTANCE = 1.0,

    -- 轨迹点最大数量
    TRACK_MAX_POINTS = 50,
}
```

---

## 调参指南

| 想调整的体验 | 修改哪个常量 | 调大效果 | 调小效果 |
|---|---|---|---|
| 缓冲手感更灵敏 | `SKILL_CACHE_MAX_COUNT` | 允许更多连招缓冲 | 减少缓冲，操作更精确 |
| 连续普攻更流畅 | `CONTINUE_ATTACK_WINDOW_BEGIN_PCT` | 更早开始接受缓冲 | 更晚（接近CD结束才接受） |
| 取消更容易触发 | `CANCEL_AREA_STAY_THRESHOLD` | 需要停留更久 | 更快触发取消 |
| Pos技能更难误触 | `POS_PRESS_TIME_THRESHOLD` | 必须按更久 | 更容易释放 |
| 指示器更跟手 | `INDICATOR_LERP_SPEED` | 几乎无延迟 | 更平滑有拖尾感 |
| 受控后操作延续 | `CONTROL_PROTECT_DURATION` | 更宽容的保护窗口 | 更严格（稍微卡一下就清缓存） |

---

## HOK 枚举值速查

| 常量 | HOK 枚举 | HOK 枚举值 |
|---|---|---|
| SKILL_CACHE_MAX_COUNT | `RES_GLOBAL_CONF_TYPE_SKILL_CACHE_LIST_MAX_COUNT` | 1197 |
| SKILL_CACHE_EXPIRED_TIME | `RES_GLOBAL_CONF_TYPE_SKILL_CACHE_LIST_EXPIRED_TIME` | 1198 |
| CONTINUE_ATTACK_WINDOW_BEGIN_PCT | `RES_GAMECORE_CONF_TYPE_CONTINUE_CACHEATTACK_WINDOW_BEGIN` | 3 |
| CONTINUE_PURSUE_WINDOW_BEGIN_PCT | `RES_GAMECORE_CONF_TYPE_CONTINUE_CACHEnPURSUE_WINDOW_BEGIN` | 14 |
