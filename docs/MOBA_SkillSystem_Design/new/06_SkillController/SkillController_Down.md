# 06.1 — 阶段一：OnButtonDown（按下）

> **HOK 来源**: `SkillBtnController.OnButtonDown()` 第187-306行  
> **所属模块**: `SkillController.lua`

---

## 流程图

```
OnButtonDown(slot, screenPos, btnCenter)
    │
    ├── 校验: slot 存在 + isEnabled + CD就绪
    │   └── 不通过 → return（静默忽略）
    │
    ├── 查配置: SKCfg[skillId]
    │   └── 找不到 → return
    │
    ├── rangeType == Auto ?
    │   └── YES → 立即 _Execute() → return
    │
    ├── 当前正在释放技能 (self._casting) ?
    │   └── YES → 推入缓冲队列 → return
    │       PushToCache({slotType, skillId, rangeType})
    │
    ├── 记录上下文:
    │   · _activeSlot = slot
    │   · _rangeType = rangeType
    │   · _pressStart = os.clock()
    │   · _pressPos = screenPos
    │   · _btnCenter = btnCenter
    │   · _pressTime = 0
    │   · _hasDragged = false
    │   · _controlMove = false
    │   · _rotateFlag / _moveFlag = false
    │   · _targetPos / _targetDir = zero
    │   · _targetActor = 0
    │   · _trackPts = nil
    │
    ├── 加载指示器配置:
    │   _indCfg = IndCfg[skill.indicatorCfgId]
    │   if _indCfg then indicator:Enable(slot, _indCfg)
    │
    ├── 启动 Heartbeat (_StartHB)
    │
    ├── 启用取消区域检测:
    │   cancelDet:SetPressStart(screenPos)
    │   (HOK: EnableCancelArea() 第7019-7050行)
    │
    └── 状态 → "Pressing"
```

## 完整伪代码

```lua
-- 来源: HOK SkillBtnController.OnButtonDown() 第187-306行
-- 精简说明:
--   HOK 原版还有: 蓄力检测、JoystickMode读取、多指冲突处理、锁定框初始化
--   Roblox 版去掉这些进阶功能，保留核心骨架

function SC:OnButtonDown(slot, screenPos, btnCenter)
    -- ① 校验槽位
    local sd = self._slots[slot]
    if not sd or not sd.isEnabled then return end
    if sd.cooldownEndTime > os.clock() then return end  -- CD 中

    -- 查配置
    local sk = SKCfg[sd.skillId]
    if not sk then return end

    -- ② Auto 型: 按下即释放，无指示器
    if sk.rangeType == Enums.SkillRangeType.Auto then
        self:_Execute(slot, {
            slotType  = slot,
            skillId   = sd.skillId,
            rangeType = 0,
        })
        return
    end

    -- ③ 当前正在释放技能 → 推入缓冲队列
    -- 来源: HOK OnButtonDown 中 ReadyUseSkillSlot() 会判断 isUsing
    if self._casting then
        self._cache:PushToCache({
            skillParam = {
                slotType  = slot,
                skillId   = sd.skillId,
                rangeType = sk.rangeType,
            },
            timestamp = os.clock(),
            isCommonAttack = false,
        })
        return
    end

    -- ④ 记录上下文
    self._activeSlot  = slot
    self._rangeType   = sk.rangeType
    self._pressStart  = os.clock()
    self._pressPos    = screenPos
    self._btnCenter   = btnCenter
    self._pressTime   = 0
    self._hasDragged  = false
    self._controlMove = false
    self._rotateFlag  = false
    self._moveFlag    = false
    self._targetPos   = Vector3.zero
    self._targetDir   = Vector3.zero
    self._targetActor = 0
    self._trackPts    = nil

    -- ⑤ 加载指示器配置并启用
    -- 来源: HOK EnableSkillCursor → 读取 IndicatorCfg → 创建三层 Prefab
    self._indCfg = IndCfg[sk.indicatorCfgId]
    if self._indCfg then
        self._indicator:Enable(slot, self._indCfg)
    end

    -- ⑥ 启动 Heartbeat（驱动 pressTime 累加 + 指示器 Tick）
    self:_StartHB()

    -- ⑦ 启用取消区域检测，记录按下位置（用于距离取消模式）
    -- 来源: HOK EnableCancelArea() 第7019-7050行
    -- 详见 10_CancelAreaDetector/CancelAreaDetector.md
    self._cancelDet:SetPressStart(screenPos)

    -- ⑧ 状态切换
    self._state = "Pressing"
end
```

## HOK 对照

| Roblox 版步骤 | HOK 原始调用 | 行号 |
|---|---|---|
| 校验 isEnabled + CD | `ReadyUseSkillSlot()` | 219-240 |
| Auto 即放 | `skillData.SkillRangeAppointType == 0` | 246-250 |
| 缓冲 | `EnableCacheSkillSlot()` → `SkillCache.PushCacheSkillList()` | 252-260 |
| 记录 pressStart | `m_pressSkillEventPos = eventData.pressPosition` | 280 |
| 启用指示器 | `EnableSkillCursor()` | 290 |
| Heartbeat | HOK 通过 Update() 驱动 | — |
| 取消区域启用 | `EnableCancelArea()` | 7019-7050 |
| 状态 Pressing | HOK 无显式状态机，通过 `bDraging/bPressed` 标记 | 295-300 |

## 关键设计决策

1. **Auto 型直接释放**: 不启用指示器，不进入 Pressing 状态。这对应 HOK 中"闪现"等即放技能。
2. **缓冲在 Down 阶段就判断**: 如果当前有技能释放中，直接入队而不是等到 Up 阶段。这保证了玩家"连招"时只需要依次按下，不需要等前一个技能结束。
3. **Heartbeat 只在按下时启动**: 避免空闲时浪费 CPU。每帧累加 `_pressTime`（毫秒），同时节流驱动指示器 `Tick`。

---

> **下一步**: `SkillController_Drag.md`
