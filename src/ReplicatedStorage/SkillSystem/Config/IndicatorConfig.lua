-- IndicatorConfig: 指示器配置表
-- 路径: ReplicatedStorage.SkillSystem.Config.IndicatorConfig
--
-- key = cfgId (number)，由 SkillConfigAdapter 的 indicatorCfgId 索引
--
-- 三层资源:
--   Guide  → 挂角色脚下，显示最大施法范围圆
--   Effect → 跟随目标位置移动（手指拖拽控制）
--   Fixed  → 挂角色脚下，始终显示

return {
	-------------------------------------------------------------------------
	-- Target 型：Guide(范围圆) + Effect(扇形)
	-------------------------------------------------------------------------
	[1001] = {
		cfgId = 1001,
		rangeType = 1,  -- Target

		guideEnabled = true,
		guideDistance = 8.0,
		guideResType = 4,       -- Ring

		effectEnabled = true,
		effectRadius = 3.0,
		effectAngle = 60,
		effectWidth = 0,
		effectLength = 0,
		effectResType = 1,       -- Sector
		effectResSize = 1000,
		effectResLength = 1000,

		fixedEnabled = false,
		fixedResType = 0,
	},

	-------------------------------------------------------------------------
	-- Pos 型：Guide(范围圆) + Effect(落点圆)
	-------------------------------------------------------------------------
	[1002] = {
		cfgId = 1002,
		rangeType = 2,  -- Pos

		guideEnabled = true,
		guideDistance = 12.0,
		guideResType = 4,       -- Ring

		effectEnabled = true,
		effectRadius = 4.0,
		effectAngle = 360,
		effectWidth = 0,
		effectLength = 0,
		effectResType = 2,       -- Circle
		effectResSize = 1000,
		effectResLength = 1000,

		fixedEnabled = false,
		fixedResType = 0,
	},

	-------------------------------------------------------------------------
	-- Directional 型：Effect(箭头) + Fixed(脚下圈)
	-------------------------------------------------------------------------
	[1003] = {
		cfgId = 1003,
		rangeType = 3,  -- Directional

		guideEnabled = false,
		guideDistance = 15.0,
		guideResType = 0,

		effectEnabled = true,
		effectRadius = 15.0,
		effectAngle = 0,
		effectWidth = 3.0,
		effectLength = 15.0,
		effectResType = 0,       -- Arrow
		effectResSize = 1000,
		effectResLength = 5000,

		fixedEnabled = true,
		fixedResType = 4,        -- Ring
	},

	-------------------------------------------------------------------------
	-- Pos 型 大范围：Guide(范围圆) + Effect(大落点圆)
	-------------------------------------------------------------------------
	[1004] = {
		cfgId = 1004,
		rangeType = 2,  -- Pos

		guideEnabled = true,
		guideDistance = 45.0,
		guideResType = 4,       -- Ring

		effectEnabled = true,
		effectRadius = 12.0,
		effectAngle = 360,
		effectWidth = 0,
		effectLength = 0,
		effectResType = 2,       -- Circle
		effectResSize = 1000,
		effectResLength = 1000,

		fixedEnabled = false,
		fixedResType = 0,
	},

	-------------------------------------------------------------------------
	-- Directional 型 宽矩形
	-------------------------------------------------------------------------
	[1005] = {
		cfgId = 1005,
		rangeType = 3,  -- Directional

		guideEnabled = false,
		guideDistance = 10.0,
		guideResType = 0,

		effectEnabled = true,
		effectRadius = 10.0,
		effectAngle = 0,
		effectWidth = 5.0,
		effectLength = 10.0,
		effectResType = 3,       -- Rectangle
		effectResSize = 1000,
		effectResLength = 3000,

		fixedEnabled = true,
		fixedResType = 4,
	},

	-------------------------------------------------------------------------
	-- Directional 型 引导(Beam): Effect(宽矩形) + Fixed(脚下圈)
	-- 用于安琪拉 R 之类的引导技能
	-------------------------------------------------------------------------
	[1006] = {
		cfgId = 1006,
		rangeType = 3,  -- Directional (引导时方向可变)

		guideEnabled = false,
		guideDistance = 60.0,
		guideResType = 0,

		effectEnabled = true,
		effectRadius = 60.0,
		effectAngle = 0,
		effectWidth = 8.0,
		effectLength = 60.0,
		effectResType = 3,       -- Rectangle (beam 用矩形表示)
		effectResSize = 1000,
		effectResLength = 5000,

		fixedEnabled = true,
		fixedResType = 4,
	},

	-------------------------------------------------------------------------
	-- Directional 型 散射：Effect(扇形) + Fixed(脚下圈)
	-- 用于安琪拉 Q 多弹散射
	-------------------------------------------------------------------------
	[1007] = {
		cfgId = 1007,
		rangeType = 3,  -- Directional

		guideEnabled = false,
		guideDistance = 45.0,
		guideResType = 0,

		effectEnabled = true,
		effectRadius = 45.0,
		effectAngle = 30,        -- 散射扇形角度
		effectWidth = 0,
		effectLength = 0,
		effectResType = 1,       -- Sector (扇形表示散射范围)
		effectResSize = 1000,
		effectResLength = 1000,

		fixedEnabled = true,
		fixedResType = 4,
	},

	-------------------------------------------------------------------------
	-- SelfRange 型：只有 Fixed(脚下范围圈)
	-- 用于自身释放技能(廉颇W等)，按下显示范围圈，松手释放
	-- guideDistance 由 SkillConfigAdapter 根据技能 AreaRadius/Radius 动态覆写
	-------------------------------------------------------------------------
	[1008] = {
		cfgId = 1008,
		rangeType = 5,  -- SelfRange

		guideEnabled = false,
		guideDistance = 5.0,     -- 默认值，会被 Adapter 覆写
		guideResType = 0,

		effectEnabled = false,
		effectRadius = 0,
		effectAngle = 0,
		effectWidth = 0,
		effectLength = 0,
		effectResType = 0,
		effectResSize = 0,
		effectResLength = 0,

		fixedEnabled = true,
		fixedResType = 4,        -- Ring (圆环)
	},
}
