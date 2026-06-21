--[[
	MobileConfig.lua
	移动端所有可调参数的集中配置模块
	REQ-011: 手机端MOBA UI与操控系统

	所有移动端UI/输入模块从此处读取常量，方便统一调参
]]

local RunService = game:GetService("RunService")

local MobileConfig = {}

-- ═══════════════════════════════════════
-- 🔧 调试开关 (REQ-012)
-- ═══════════════════════════════════════
-- 设为 true 可在 PC 上强制使用移动端布局进行调试
-- 生产环境务必保持 false
MobileConfig.DEBUG_FORCE_MOBILE = false

-- REQ-014: Studio 环境检测
-- Device Emulator 设置 TouchEnabled=true 但实际输入仍是鼠标
-- 在 Studio 中运行移动端布局时，需要同时接受 Touch 和 Mouse 输入
MobileConfig.IS_STUDIO = RunService:IsStudio()

-- ═══════════════════════════════════════
-- 虚拟摇杆参数 (MOD-01)
-- ═══════════════════════════════════════
MobileConfig.JOYSTICK_MAX_RADIUS = 60        -- 摇杆外圈最大半径(像素)
MobileConfig.JOYSTICK_DEADZONE = 0.15        -- 死区百分比(中心15%不触发移动)
MobileConfig.JOYSTICK_FADE_TIME = 0.3        -- 松手后淡出时间(秒)
MobileConfig.JOYSTICK_WALK_THRESHOLD = 0.4   -- 慢走/全速分界比例
MobileConfig.JOYSTICK_OUTER_SIZE = 0.30      -- 外圈直径(屏高比) REQ-016: 0.25→0.30 参照王者
MobileConfig.JOYSTICK_INNER_SIZE = 0.12      -- 摇杆球直径(屏高比) REQ-016: 0.10→0.12
MobileConfig.JOYSTICK_OUTER_ALPHA = 0.6      -- 外圈透明度(1-Transparency)
MobileConfig.JOYSTICK_INNER_ALPHA = 0.8      -- 摇杆球透明度

-- ═══════════════════════════════════════
-- 技能按钮参数 (MOD-02)
-- ═══════════════════════════════════════
MobileConfig.SKILL_BTN_NORMAL = 0.12         -- Q/W/R按钮直径(屏高比) REQ-016: 0.11→0.12
MobileConfig.SKILL_BTN_ATTACK = 0.16         -- 普攻按钮直径(屏高比) REQ-016: 0.14→0.16
MobileConfig.SKILL_BTN_SUMM = 0.09           -- 召唤师技能按钮直径(屏高比) REQ-016: 0.08→0.09
MobileConfig.AIM_CANCEL_THRESHOLD = 0.3      -- 取消区域(按钮半径百分比)
MobileConfig.CD_DISPLAY_DECIMAL = 1          -- CD显示小数位数

-- REQ-016: 按钮位置 — 攻击按钮固定，Q/W/R/D/F 由弧形算法在 UI_SkillButtons 中动态计算
-- AnchorPoint = (0.5, 0.5), 以中心为锚点
MobileConfig.BTN_ATTACK_POS = { X = 0.85, Y = 0.82 }  -- 攻击按钮位置(右下角) fix: 0.88→0.85 防iPad超屏

-- 弧形布局参数 (以攻击按钮中心为圆心)
-- 角度约定: 0°=右, 90°=下, 180°=左, 270°=上 (顺时针)
-- 王者荣耀技能弧排列在攻击按钮的左上方 (约135°~225°范围)
MobileConfig.SKILL_ARC_RADIUS_RATIO = 1.5     -- 弧形半径 = ATK按钮直径 × 此比值 (1.25→1.5 解决重叠)
MobileConfig.SKILL_ARC_SUMM_RADIUS_RATIO = 1.6 -- 召唤师技能弧形半径比值 (1.4→1.6 解决R↔D重叠)

-- Q/W/R 技能弧形角度 (以攻击按钮为圆心, 度)
-- 屏幕坐标: 0°=右, 90°=下, 180°=左, 270°=上
MobileConfig.SKILL_ARC_ANGLES = {
	R = 245,  -- 左上方 (240→245)
	W = 205,  -- 左侧偏上 (210→205)
	Q = 165,  -- 左侧偏下 (180→165) 整体扩展弧度避免重叠
}

-- D/F 召唤师技能角度 (在攻击按钮的上方)
MobileConfig.SUMM_ARC_ANGLES = {
	D = 275,  -- 上方偏右 (270→275)
	F = 300,  -- 右上方 (不变)
}

-- 按钮大小映射 (slotKey → 屏高比直径)
MobileConfig.BTN_SIZES = {
	Q      = MobileConfig.SKILL_BTN_NORMAL,
	W      = MobileConfig.SKILL_BTN_NORMAL,
	R      = MobileConfig.SKILL_BTN_NORMAL,
	D      = MobileConfig.SKILL_BTN_SUMM,
	F      = MobileConfig.SKILL_BTN_SUMM,
	Attack = MobileConfig.SKILL_BTN_ATTACK,
}

-- ═══════════════════════════════════════
-- 方向轮盘参数 (MOD-02)
-- ═══════════════════════════════════════
MobileConfig.AIM_LINE_WIDTH = 4              -- 方向指示线宽度(像素)
MobileConfig.AIM_LINE_COLOR = Color3.fromRGB(255, 255, 200)   -- 方向线颜色
MobileConfig.AIM_CANCEL_COLOR = Color3.fromRGB(255, 80, 80)   -- 取消区颜色

-- ═══════════════════════════════════════
-- 摄像机参数 (MOD-05)
-- ═══════════════════════════════════════
MobileConfig.CAMERA_SMOOTH_FACTOR = 0.15     -- Lerp插值系数(每帧)
MobileConfig.CAMERA_MOBILE_DEPTH = 25        -- 移动端水平偏移(studs)
MobileConfig.CAMERA_MOBILE_HEIGHT = 30       -- 移动端摄像机高度(studs)

-- ═══════════════════════════════════════
-- 小地图参数 (MOD-06)
-- ═══════════════════════════════════════
MobileConfig.MINIMAP_SIZE = 0.22             -- 小地图大小(屏高比, 正方形) REQ-016: 0.18→0.22
MobileConfig.MINIMAP_UPDATE_INTERVAL = 0.5   -- 位置标记刷新频率(秒)
MobileConfig.MINIMAP_MY_COLOR = Color3.fromRGB(50, 130, 255)   -- 己方标记颜色
MobileConfig.MINIMAP_ENEMY_COLOR = Color3.fromRGB(255, 60, 60) -- 敌方标记颜色
MobileConfig.MINIMAP_DOT_SIZE = 0.08         -- 标记圆点大小(地图比例)

-- ═══════════════════════════════════════
-- 战斗HUD参数 (MOD-03)
-- ═══════════════════════════════════════
MobileConfig.KILL_NOTIFY_DURATION = 2.0      -- 击杀通知停留时间(秒)
MobileConfig.KILL_NOTIFY_MAX_STACK = 2       -- 最多同时显示通知数
MobileConfig.HP_BAR_WIDTH = 0.15             -- HP条宽度(屏宽比)
MobileConfig.HP_BAR_HEIGHT = 0.02            -- HP条高度(屏高比)
MobileConfig.MP_BAR_HEIGHT = 0.015           -- MP条高度(屏高比)

-- HP条颜色渐变
MobileConfig.HP_COLOR_HIGH = Color3.fromRGB(0, 200, 0)        -- 100%~60%
MobileConfig.HP_COLOR_MID = Color3.fromRGB(255, 200, 0)       -- 60%~30%
MobileConfig.HP_COLOR_LOW = Color3.fromRGB(255, 50, 50)       -- <30%
MobileConfig.MP_COLOR = Color3.fromRGB(80, 130, 255)          -- MP条颜色

-- ═══════════════════════════════════════
-- 普攻索敌参数 (MOD-04)
-- ═══════════════════════════════════════
MobileConfig.AUTO_ATTACK_RANGE = 20          -- 自动索敌范围(studs)

-- ═══════════════════════════════════════
-- 按钮状态视觉参数
-- ═══════════════════════════════════════
MobileConfig.BTN_PRESS_SCALE = 0.9           -- 按下时缩小比例
MobileConfig.BTN_PRESS_DURATION = 0.08       -- 按下动画时长(秒)
MobileConfig.BTN_RELEASE_DURATION = 0.15     -- 释放动画时长(秒)
MobileConfig.BTN_CD_MASK_ALPHA = 0.7         -- CD遮罩透明度
MobileConfig.BTN_DISABLED_ALPHA = 0.4        -- 不可用状态透明度
MobileConfig.BTN_FLASH_DURATION = 0.15       -- 闪烁反馈时长(秒)
MobileConfig.BTN_FLASH_COLOR_CD = Color3.fromRGB(255, 80, 80) -- CD中按下闪红

-- ═══════════════════════════════════════
-- 动画缓动参数
-- ═══════════════════════════════════════
MobileConfig.JOYSTICK_APPEAR_TIME = 0.1      -- 摇杆出现时间(秒)
MobileConfig.KILL_SLIDE_IN_TIME = 0.3        -- 击杀播报滑入时间(秒)
MobileConfig.KILL_FADE_OUT_TIME = 0.5        -- 击杀播报淡出时间(秒)
MobileConfig.HP_CHANGE_DURATION = 0.15       -- HP条变化动画时长(秒)
MobileConfig.RESPAWN_PULSE_TIME = 1.0        -- 复活倒计时脉冲时间(秒)

-- ═══════════════════════════════════════
-- 🆕 REQ-015: 移动端UI布局优化参数
-- ═══════════════════════════════════════

-- 摇杆位置参数 (REQ-016: 始终可见,固定位置)
MobileConfig.JOYSTICK_DEFAULT_X = 0.18       -- 摇杆默认位置X(Scale) REQ-016: 0.15→0.18
MobileConfig.JOYSTICK_DEFAULT_Y = 0.72       -- 摇杆默认位置Y(Scale) REQ-016: 0.75→0.72
MobileConfig.JOYSTICK_LOBBY_OUTER_ALPHA = 0.5 -- 大厅模式外圈透明度 REQ-016: 0.2→0.5
MobileConfig.JOYSTICK_LOBBY_INNER_ALPHA = 0.6 -- 大厅模式摇杆球透明度 REQ-016: 0.3→0.6
MobileConfig.JOYSTICK_DISABLED_ALPHA = 0.3    -- REQ-021: 禁用态透明度(~70%透明)

-- (弧形布局参数已移至 BTN_ATTACK_POS / SKILL_ARC_ANGLES / SUMM_ARC_ANGLES)

-- SafeArea安全区(像素)
MobileConfig.SAFE_AREA_TOP = 36              -- 顶部(Roblox系统按钮)
MobileConfig.SAFE_AREA_BOTTOM = 34           -- 底部(iPhone指示条)
MobileConfig.SAFE_AREA_SIDES = 44            -- 左右(刘海/挖孔)

-- 大厅功能按钮参数
-- REQ-023: 训练场按钮移至右上角（英雄切换小面板下方），避免与摇杆区域重叠
-- 布局: MiniPanel底边≈215px, 留12px间距 → Y≈0.21 (≈227px@1080p)
MobileConfig.LOBBY_TRAIN_BTN_POS = { X = 0.95, Y = 0.21 }   -- 训练场按钮位置(右上角)
MobileConfig.LOBBY_MATCH_BTN_POS = { X = 0.95, Y = 0.08 }  -- 匹配按钮位置
MobileConfig.LOBBY_BTN_SIZE = { W = 0.12, H = 0.06 }        -- 大厅按钮尺寸

-- REQ-025: 英雄切换小面板位置参数 — 移至右上角(用户截图指示)
-- 布局: 右上角区域，匹配按钮(Y=0.08)下方
MobileConfig.MINI_PANEL_POS = { X = 0.83, Y = 0.08 }        -- 小面板位置(右上角)
MobileConfig.MINI_PANEL_WIDTH = 0.15                          -- 小面板宽度(屏宽比)
MobileConfig.MINI_PANEL_HEIGHT = 0.06                         -- 小面板高度(屏高比)

-- 小地图REQ-016位置参数
MobileConfig.MINIMAP_POS_X = 0.02            -- 小地图X位置(Scale)
MobileConfig.MINIMAP_POS_Y = 0.12            -- 小地图Y位置(Scale) REQ-016: 0.15→0.12

-- ═══════════════════════════════════════
-- 🆕 REQ-026: 移动端技能释放系统参数
-- ═══════════════════════════════════════

-- 取消框参数 (MobileCancelZone)
MobileConfig.CANCEL_ZONE_POS = { X = 0.85, Y = 0.15 }     -- 取消框位置(右上角, Scale)
MobileConfig.CANCEL_ZONE_SIZE = 0.07                        -- 取消框直径(屏高比)
MobileConfig.CANCEL_ZONE_MIN_SIZE = 44                      -- 取消框最小像素(可触达性)
MobileConfig.CANCEL_HIT_RADIUS_MULT = 1.2                   -- 取消区域判定容错系数
MobileConfig.CANCEL_ZONE_TWEEN_IN = 0.15                    -- 取消框淡入时间(秒)
MobileConfig.CANCEL_ZONE_TWEEN_OUT = 0.1                    -- 取消框淡出时间(秒)
MobileConfig.CANCEL_ZONE_NORMAL_COLOR = Color3.fromRGB(180, 180, 180)   -- 取消框默认颜色
MobileConfig.CANCEL_ZONE_ACTIVE_COLOR = Color3.fromRGB(255, 60, 60)     -- 取消框激活(变红)颜色
MobileConfig.CANCEL_ZONE_NORMAL_ALPHA = 0.5                  -- 取消框默认透明度
MobileConfig.CANCEL_ZONE_ACTIVE_ALPHA = 0.8                  -- 取消框激活透明度

-- 快速点按(智能释放)参数
MobileConfig.QUICK_TAP_MAX_DURATION = 0.2                    -- 快速点按最大时长(秒)
MobileConfig.QUICK_TAP_MAX_DISTANCE = 10                     -- 快速点按最大移动距离(像素)
MobileConfig.SMART_CAST_RANGE_MULT = 1.5                     -- 智能释放索敌范围倍率

-- 指示器参数 (MobileIndicatorManager)
MobileConfig.INDICATOR_NORMAL_COLOR = Color3.fromRGB(100, 200, 255)     -- 指示器正常颜色
MobileConfig.INDICATOR_CANCEL_COLOR = Color3.fromRGB(255, 60, 60)       -- 指示器取消(变红)颜色
MobileConfig.INDICATOR_FILL_ALPHA = 0.3                       -- 指示器填充透明度
MobileConfig.INDICATOR_BORDER_ALPHA = 0.1                     -- 指示器边框透明度
MobileConfig.INDICATOR_LINE_DEFAULT_WIDTH = 3                 -- line指示器默认宽度(studs)
MobileConfig.INDICATOR_RANGE_RING_ALPHA = 0.6                 -- 射程环透明度
MobileConfig.INDICATOR_RANGE_RING_COLOR = Color3.fromRGB(255, 255, 255) -- 射程环颜色

-- 指示器ScreenGui层级
MobileConfig.INDICATOR_GUI_DISPLAY_ORDER = 5                  -- 指示器ScreenGui DisplayOrder
MobileConfig.CANCEL_ZONE_GUI_DISPLAY_ORDER = 15               -- 取消框ScreenGui DisplayOrder

return MobileConfig
