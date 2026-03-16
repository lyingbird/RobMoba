--[[
	MobileConfig.lua
	移动端所有可调参数的集中配置模块
	REQ-011: 手机端MOBA UI与操控系统

	所有移动端UI/输入模块从此处读取常量，方便统一调参
]]

local MobileConfig = {}

-- ═══════════════════════════════════════
-- 🔧 调试开关 (REQ-012)
-- ═══════════════════════════════════════
-- 设为 true 可在 PC 上强制使用移动端布局进行调试
-- 生产环境务必保持 false
MobileConfig.DEBUG_FORCE_MOBILE = false

-- ═══════════════════════════════════════
-- 虚拟摇杆参数 (MOD-01)
-- ═══════════════════════════════════════
MobileConfig.JOYSTICK_MAX_RADIUS = 60        -- 摇杆外圈最大半径(像素)
MobileConfig.JOYSTICK_DEADZONE = 0.15        -- 死区百分比(中心15%不触发移动)
MobileConfig.JOYSTICK_FADE_TIME = 0.3        -- 松手后淡出时间(秒)
MobileConfig.JOYSTICK_WALK_THRESHOLD = 0.4   -- 慢走/全速分界比例
MobileConfig.JOYSTICK_OUTER_SIZE = 0.25      -- 外圈直径(屏高比)
MobileConfig.JOYSTICK_INNER_SIZE = 0.10      -- 摇杆球直径(屏高比)
MobileConfig.JOYSTICK_OUTER_ALPHA = 0.6      -- 外圈透明度(1-Transparency)
MobileConfig.JOYSTICK_INNER_ALPHA = 0.8      -- 摇杆球透明度

-- ═══════════════════════════════════════
-- 技能按钮参数 (MOD-02)
-- ═══════════════════════════════════════
MobileConfig.SKILL_BTN_NORMAL = 0.11         -- Q/W/R按钮直径(屏高比)
MobileConfig.SKILL_BTN_ATTACK = 0.14         -- 普攻按钮直径(屏高比)
MobileConfig.SKILL_BTN_SUMM = 0.08           -- 召唤师技能按钮直径(屏高比)
MobileConfig.AIM_CANCEL_THRESHOLD = 0.3      -- 取消区域(按钮半径百分比)
MobileConfig.CD_DISPLAY_DECIMAL = 1          -- CD显示小数位数

-- 按钮位置 (UDim2 Scale值, 来自UX设计)
-- AnchorPoint = (1, 1), 以右下角为锚点
MobileConfig.BTN_POSITIONS = {
	Attack = { X = 0.94, Y = 0.92 },
	R      = { X = 0.88, Y = 0.78 },
	W      = { X = 0.82, Y = 0.67 },
	Q      = { X = 0.75, Y = 0.78 },
	D      = { X = 0.70, Y = 0.85 },
	F      = { X = 0.70, Y = 0.93 },
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
MobileConfig.MINIMAP_SIZE = 0.18             -- 小地图大小(屏高比, 正方形)
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

return MobileConfig
