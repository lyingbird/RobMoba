# 子任务卡片

## 基本信息
| 属性 | 值 |
|------|-----|
| 任务ID | TASK-05 |
| 父需求 | REQ-015 移动端UI布局重设计 |
| 子任务名称 | HUD布局重构+小地图位置调整 |
| 执行者 | 程序 Agent |
| 优先级 | 2 |

## 任务描述

### Part A: UI_MobileHUD.lua 布局重构
重构 `UI_MobileHUD.lua` 的布局以对标王者荣耀标准:

1. **顶部信息栏**:
   - 全宽，高度 5%，Y起始 = SafeArea顶部(36px)之后
   - 左区(30%): HP条+数值(上行) + MP条+数值(下行)
   - 左中(10%): 等级标签 "Lv.X"
   - 中区(20%): 对局计时(上行)
   - 右中(20%): 击杀比分 "X:Y"
   - 右区(20%): 预留

2. **HP/MP条视觉**:
   - HP条: 绿色(>50%)/黄色(25~50%)/红色(<25%) 颜色渐变
   - HP条宽度: 屏幕宽度25%（从MobileConfig.HP_BAR_WIDTH读取）
   - 数值格式: "当前/最大" 白色文字

3. **保留不变的功能**:
   - 击杀播报(ShowKillNotification)
   - 复活倒计时(ShowRespawnCountdown)
   - HP/MP属性监听逻辑

### Part B: UI_Minimap.lua 位置调整
- 位置改为 (MobileConfig.MINIMAP_POS_X, MobileConfig.MINIMAP_POS_Y) = (2%, 15%)
- 确保在HUD信息栏下方
- 其他功能不变

## 技术要求
- 文件: `UI_MobileHUD.lua` + `UI_Minimap.lua`
- ⚠️ 保留所有功能逻辑，仅调整布局参数
- HP/MP监听、击杀播报、复活倒计时逻辑不变

## 输入依赖
- TASK-01 MobileConfig (SAFE_AREA_TOP, HP_BAR_WIDTH, MINIMAP_POS_X/Y)

## 输出要求
- 修改文件: `UI_MobileHUD.lua` (~60行改动)
- 修改文件: `UI_Minimap.lua` (~10行改动)

## 与其他模块的关系
- 被依赖: TASK-02 (Client.client.lua 初始化时使用)
- 依赖: TASK-01 (MobileConfig 参数)
