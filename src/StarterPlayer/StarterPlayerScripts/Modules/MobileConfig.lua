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
MobileConfig.DEBUG_FORCE_MOBILE = true

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
MobileConfig.SKILL_BTN_NORMAL = 0.115        -- Q/W按钮直径(屏高比)
MobileConfig.SKILL_BTN_ULTIMATE = 0.13       -- R(大招)按钮直径(屏高比)
MobileConfig.SKILL_BTN_ATTACK = 0.19         -- 普攻按钮直径(屏高比) — 王者荣耀风格大圆
MobileConfig.CD_DISPLAY_DECIMAL = 1          -- CD显示小数位数

-- 按钮位置 (王者荣耀风格弧形布局)
-- AnchorPoint = (0.5, 0.5), 以中心为锚点
-- 只定义普攻的绝对位置, Q/W/R 按极坐标从普攻中心算出
-- 参考王者荣耀截图: R在普攻正上方偏左(11点), W在左上(10点), Q在正左偏上(9点)
MobileConfig.BTN_ATTACK_POS = { X = 0.89, Y = 0.80 }   -- 普攻按钮绝对位置(屏Scale)

-- 技能弧形参数 (以普攻中心为圆心的极坐标)
MobileConfig.SKILL_ARC_RADIUS = 0.27          -- 弧形半径(屏高比, 按钮中心到普攻中心的距离)
MobileConfig.SKILL_ARC_START_ANGLE = 190      -- 起始角度(度): Q的角度, 约9点钟偏下(左偏下方)
MobileConfig.SKILL_ARC_STEP = 35              -- 每个按钮间隔角度(度): Q→W→R 递增
-- 角度定义: 0°=正右, 90°=正下, 180°=正左, 270°=正上 (屏幕坐标Y朝下)
-- Q = 190° (9点钟偏下), W = 225° (约10点半, 左上45°), R = 260° (约11点, 正上偏左)
MobileConfig.SKILL_ARC_SLOTS = { "Q", "W", "R" }  -- 按角度从小到大排列
MobileConfig.SCREEN_ASPECT_RATIO = 16 / 9     -- 屏幕宽高比(X方向偏移需除以此值)

-- 按钮大小映射 (slotKey → 屏高比直径)
MobileConfig.BTN_SIZES = {
	Q      = MobileConfig.SKILL_BTN_NORMAL,
	W      = MobileConfig.SKILL_BTN_NORMAL,
	R      = MobileConfig.SKILL_BTN_ULTIMATE,
	Attack = MobileConfig.SKILL_BTN_ATTACK,
}

-- ═══════════════════════════════════════
-- 方向轮盘参数 (MOD-02)
-- ═══════════════════════════════════════
MobileConfig.AIM_LINE_WIDTH = 4              -- 方向指示线宽度(像素)
MobileConfig.AIM_LINE_COLOR = Color3.fromRGB(255, 255, 200)   -- 方向线颜色
MobileConfig.AIM_CANCEL_COLOR = Color3.fromRGB(255, 80, 80)   -- 取消区颜色

-- 瞄准范围圈 (王者荣耀风格: 按下技能后出现的圆形拖拽区域)
-- 拖出圈外 = 取消技能释放
MobileConfig.AIM_CIRCLE_RADIUS = 90          -- 范围圈半径(像素)
MobileConfig.AIM_CIRCLE_COLOR = Color3.fromRGB(80, 180, 255)  -- 范围圈边框颜色(浅蓝)
MobileConfig.AIM_CIRCLE_STROKE_WIDTH = 2.5   -- 范围圈边框线宽(像素)
MobileConfig.AIM_CIRCLE_STROKE_ALPHA = 0.35  -- 范围圈边框透明度(0=不透明,1=全透明)
MobileConfig.AIM_CIRCLE_FILL_ALPHA = 0.88    -- 范围圈填充透明度(接近全透明, 只是微微可见)

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

-- ═══════════════════════════════════════
-- 3D 技能指示器参数 (REQ-014)
-- ═══════════════════════════════════════
MobileConfig.INDICATOR_LINE_WIDTH = 1.5      -- LINE指示器宽度(studs)
MobileConfig.INDICATOR_LINE_ALPHA = 0.4      -- LINE指示器透明度(0=不透明,1=全透明)
MobileConfig.INDICATOR_LINE_ARROW_SIZE = 3   -- LINE箭头宽度(studs)
MobileConfig.INDICATOR_CIRCLE_ALPHA = 0.3    -- CIRCLE_SELF透明度
MobileConfig.INDICATOR_Y_OFFSET = 0.2        -- 指示器离地高度(studs, 防Z-fighting)
MobileConfig.INDICATOR_FLASH_DURATION = 0.15 -- 释放闪光动画时长(秒)
MobileConfig.INDICATOR_FADE_DURATION = 0.1   -- 取消消散动画时长(秒)
MobileConfig.INDICATOR_CANCEL_COLOR = Color3.fromRGB(255, 80, 80)  -- 取消态指示器颜色
MobileConfig.INDICATOR_CANCEL_ALPHA = 0.6    -- 取消态指示器透明度
MobileConfig.INDICATOR_ORIGIN_RADIUS = 2     -- 起始圆环半径(studs)

-- 英雄指示器颜色 (REQ-014)
MobileConfig.HERO_INDICATOR_COLORS = {
	Angela  = Color3.fromRGB(255, 100, 50),   -- 橙红 (火焰主题)
	HouYi   = Color3.fromRGB(255, 200, 50),   -- 金黄 (太阳主题)
	LianPo  = Color3.fromRGB(100, 200, 255),  -- 冰蓝 (岩石/霜寒主题)
	Lux     = Color3.fromRGB(200, 150, 255),  -- 淡紫 (光明主题)
}

return MobileConfig
