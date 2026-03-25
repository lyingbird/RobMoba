# 15 — 参考资料

> 常量速查表 + 平台适配表 + 建议目录结构 + 实现优先级

---

## 15.1 常量速查表

| 常量名 | 值 | HOK 来源 | 用途 | 定义位置 |
|---|---|---|---|---|
| `SKILL_CACHE_MAX_COUNT` | 1 | RES_GLOBAL_CONF_TYPE #1197 | 技能缓冲队列上限 | `GlobalConfig.lua` |
| `SKILL_CACHE_EXPIRED_TIME` | 2.0s | RES_GLOBAL_CONF_TYPE #1198 | 缓存过期时间 | `GlobalConfig.lua` |
| `CONTINUE_ATTACK_WINDOW_BEGIN_PCT` | 70% | RES_GAMECORE_CONF_TYPE #3 | 连续普攻窗口开始(CD的%) | `GlobalConfig.lua` |
| `CONTINUE_PURSUE_WINDOW_BEGIN_PCT` | 50% | RES_GAMECORE_CONF_TYPE #14 | 追击窗口开始(CD的%) | `GlobalConfig.lua` |
| `CANCEL_AREA_STAY_THRESHOLD` | 0.15s | CSkillButtonManager 硬编码 | 取消区域停留阈值 | `GlobalConfig.lua` |
| `CANCEL_DISTANCE_THRESHOLD` | 270px | c_skillICancleRadius | 距离取消阈值 | `GlobalConfig.lua` |
| `POS_PRESS_TIME_THRESHOLD` | 1.0s | IsAllowUseSkill 硬编码 1000ms | Pos防误触按压阈值 | `GlobalConfig.lua` |
| `DIR_QUICK_TAP_THRESHOLD` | 0.4s | OnSkillButtonUp 硬编码 400ms | Directional快速点击 | `GlobalConfig.lua` |
| `DRAG_THRESHOLD` | 10px | — | 拖动判定起始阈值 | `GlobalConfig.lua` |
| `INDICATOR_UPDATE_INTERVAL` | 2帧 | — | 指示器更新节流 | `GlobalConfig.lua` |
| `CONTROL_PROTECT_DURATION` | 0.5s | SkillInputCacheDuration | 受控保护窗口 | `GlobalConfig.lua` |
| maxDragRadius | 120px | 硬编码 | 按钮最大拖动半径 | `SkillController` |
| Target 模式切换分界 | normOff=0.5 | SelectSkillTarget | 简易/高级模式 | `SkillController` |
| Pos controlMove 阈值 | normOff=0.05 | _ST_Pos | 约6像素 | `SkillController` |
| 指示器 Lerp 系数 | dt*15 | LateUpdate | 平滑插值 | `SkillIndicator` |
| Y 轴偏移 | 0.1 stud | — | 避免 Z-fighting | `IndicatorRenderer` |
| 震动时长 | 0.1s | VibrationManager | 取消区域震动 | `CancelAreaDetector` |
| Track 最小间距 | 1.0 stud | 推断设计 | 轨迹点间距 | `SkillController` |

---

## 15.2 平台适配速查表

| HOK 概念 | Roblox 等价物 | 备注 |
|---|---|---|
| Unity EventTrigger (OnPointerDown/Drag/Up) | UserInputService + GuiButton.InputBegan | InputAdapter 统一封装 |
| Unity Prefab + Material | Part + MeshPart + Decal | IndicatorRenderer 创建 |
| Unity SetActive(true/false) | Transparency 0.5↔1 | 推荐 Transparency |
| Unity Layer 切换 (Actor↔Hide) | Transparency | Roblox 无 Layer 显隐系统 |
| Unity Transform.SetParent | Part.Parent = folder | — |
| Unity Camera.ScreenPointToRay | Camera:ScreenPointToRay() | API 名一致 |
| C# SkillSlotLinker | Luau SkillSlot table | ModuleScript 定义 |
| 帧同步 FrameCommand | RemoteEvent:FireServer() | 每种技能类型一个 Event |
| ResSkillIndicatorCfgInfo | ModuleScript config table | require 即用 |
| Time.deltaTime | RunService.Heartbeat dt | 回调参数直接给 |
| Time.realtimeSinceStartup | os.clock() | 不受 time scale 影响 |
| Vector2 屏幕坐标 | Vector2 (InputObject.Position) | 一致 |
| Vector3 世界坐标 | Vector3 (workspace) | 一致 |
| Quaternion.Slerp | CFrame:Lerp() | CFrame 内建 Slerp |
| VibrationManager | HapticService:SetMotor() | 仅手柄，移动端无原生 API |
| AGE 动画轨道事件 | AnimationTrack.KeyframeReached | 或自定义 task.delay |
| 对象池 (CGameObjectPool) | 自建 table 池 | 见 IndicatorRenderer 扩展建议 |
| TDR 配置表 | ModuleScript return table | 静态配置 |

---

## 15.3 建议目录结构

```
game/
├── ReplicatedStorage/
│   └── SkillSystem/
│       ├── Config/
│       │   ├── SkillConfig.lua           -- 技能基础配置 (§3.1)
│       │   ├── IndicatorConfig.lua       -- 指示器配置 (§3.2)
│       │   └── GlobalConfig.lua          -- 全局常量 (§3.3)
│       ├── Enums/
│       │   └── SkillEnums.lua            -- 枚举定义 (§2.1)
│       └── Types/
│           └── SkillTypes.lua            -- 类型标注 (§2.2)
│
├── StarterPlayerScripts/
│   └── SkillSystem/
│       ├── InputAdapter.lua              -- 输入适配 (§4)
│       ├── SkillButtonManager.lua        -- 按钮管理 (§5)
│       ├── SkillController.lua           -- 核心状态机 (§6+§7+§14)
│       ├── CommonAttackController.lua    -- 普攻控制 (§12)
│       ├── SkillCacheManager.lua         -- 缓冲区管理 (§11)
│       ├── SkillIndicator.lua            -- 指示器主控 (§8)
│       ├── IndicatorRenderer.lua         -- 指示器渲染 (§9)
│       └── CancelAreaDetector.lua        -- 取消区域检测 (§10)
│
├── ServerScriptService/
│   └── SkillSystem/
│       ├── SkillServerInit.server.lua    -- 服务端入口 (§13)
│       ├── SkillValidator.lua            -- 服务端校验 (§13)
│       └── SkillExecutor.lua             -- 技能执行 (§13)
│
└── StarterGui/
    └── SkillUI/
        ├── SkillButtonBar/               -- 技能按钮栏
        │   ├── Skill1Button (ImageButton)
        │   ├── Skill2Button (ImageButton)
        │   ├── Skill3Button (ImageButton)
        │   ├── Skill4Button (ImageButton)
        │   └── AttackButton (ImageButton)
        └── CancelArea/
            └── CancelFrame (Frame)       -- 取消区域
                └── CancelTips (ImageLabel) -- "松手取消" 提示
```

---

## 15.4 实现优先级

### P0 — 核心骨架（必须先实现）

| 序号 | 模块 | 文件 | 预估工时 |
|---|---|---|---|
| 1 | 枚举 + 类型 | `SkillEnums.lua` + `SkillTypes.lua` | 0.5h |
| 2 | 配置表 | `SkillConfig.lua` + `IndicatorConfig.lua` + `GlobalConfig.lua` | 1h |
| 3 | 输入适配 | `InputAdapter.lua` | 1h |
| 4 | 按钮管理 | `SkillButtonManager.lua` | 1.5h |
| 5 | 控制器 | `SkillController.lua`（含 SelectSkillTarget + 防误触） | 3h |
| 6 | 服务端 | `SkillValidator.lua` + `SkillExecutor.lua` | 2h |

### P1 — 操作手感（实现后体验质的飞跃）

| 序号 | 模块 | 文件 | 预估工时 |
|---|---|---|---|
| 7 | 指示器 | `SkillIndicator.lua` + `IndicatorRenderer.lua` | 3h |
| 8 | 取消区域 | `CancelAreaDetector.lua` | 1.5h |
| 9 | 缓冲区 | `SkillCacheManager.lua` | 2h |

### P2 — 锦上添花

| 序号 | 模块 | 文件 | 预估工时 |
|---|---|---|---|
| 10 | 普攻控制 | `CommonAttackController.lua` | 1h |
| 11 | 连续普攻窗口 | `SkillCacheManager` 扩展 | 1h |
| 12 | 受控保护 | `SkillCacheManager` 扩展 | 1h |
| 13 | Track 型 | `SkillController` 扩展 | 1.5h |
| 14 | 扇形指示器 | `IndicatorRenderer` MeshPart 方案 | 2h |
| 15 | 对象池 | `IndicatorRenderer` 扩展 | 1h |

### 依赖关系图

```
SkillEnums ─────┐
SkillTypes ─────┤
GlobalConfig ───┤
SkillConfig ────┼──→ SkillController ──→ SkillButtonManager
IndicatorConfig ┘        │                      │
                         ├──→ SkillIndicator    │
                         │       └──→ IndicatorRenderer
                         ├──→ CancelAreaDetector
                         └──→ SkillCacheManager
                                     │
InputAdapter ──────────→ SkillButtonManager
                                     │
                              SkillServerInit
                                ├──→ SkillValidator
                                └──→ SkillExecutor
```

**建议实现顺序**: 按序号 1→15 从上到下。每完成一个 P 级别后做一次集成测试。

---

## 15.5 测试检查清单

### 基础功能

- [ ] Auto 型技能：按下即释放，无指示器
- [ ] Target 型技能：拖动选择目标，简易/高级模式切换
- [ ] Pos 型技能：拖动选择位置，指示器跟随
- [ ] Directional 型技能：拖动选择方向，指示器旋转

### 操作手感

- [ ] Pos 型误触：短按不拖动不释放
- [ ] Pos 型长按：超过1秒不拖动也释放
- [ ] Directional 快速点击：0.4秒内点击使用角色朝向
- [ ] 取消区域：拖到底部>0.15秒取消
- [ ] 取消区域：快速划过不取消
- [ ] 指示器平滑：拖动时无跳跃
- [ ] 缓冲区：技能释放中按下一个技能自动衔接
- [ ] CD 正确：释放后 CD 开始，CD 中不可再放

### 边界情况

- [ ] 双指同时按两个技能：只响应第一个
- [ ] 技能释放中死亡：缓冲清空
- [ ] 快速连按同一技能：CD 内忽略
- [ ] 网络延迟：客户端先播动画，服务端校验失败后回滚

---

*文档集完成。实现者按模块逐个实现，每个模块的接口和内部逻辑均已给出伪代码级别的定义。*
