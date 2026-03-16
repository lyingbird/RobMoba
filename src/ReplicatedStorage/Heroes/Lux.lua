-- ==========================================
-- Lux (光辉女郎) 英雄配置
-- 自动被 HeroRegistry 发现和注册
-- ==========================================
return {
	HeroID = "Lux",
	DisplayName = "光辉女郎",
	Theme = Color3.fromRGB(255, 220, 100), -- 金色

	-- 新增元数据
	Role = "Mage",
	Difficulty = 3,
	SortOrder = 2,
	Enabled = true,
	Tags = { "Poke", "Control", "Shield" },
	FreeRotation = false,

	-- 能量类型 (REQ-007)
	EnergyType = "Mana",

	-- 技能映射
	Skills = { Q = 1002, W = 1003, R = 1005 },
	-- 1001(Fireball) 是通用测试技能, 1004(LuxE) 是额外技能
	AllowBackpack = true,

	-- 动画配置
	Poses = {
		Cast_Q = {
			RightShoulder = {-20, 0, -90},
			LeftShoulder = {0, 0, 30},
			Waist = {0, -15, 0},
		},
		Cast_W = {
			RightShoulder = {-30, 0, -80},
			LeftShoulder = {-30, 0, 80},
			Waist = {-10, 0, 0},
		},
		Cast_R = {
			RightShoulder = {-70, 0, -90},
			LeftShoulder = {-70, 0, 90},
			Waist = {-20, 0, 0},
			Neck = {-15, 0, 0},
		},
		Windup = {
			RightShoulder = {10, 0, 20},
			LeftShoulder = {10, 0, -20},
			Waist = {10, 0, 0},
			Root = {5, 0, 0},
		},
	},
	CastDurations = { Q = 0.6, W = 0.5, R = 1.2 },
	CastLift = { Q = 0, W = 0, R = 3 },
	MoveLock = { Q = "none", W = "none", R = "full" },
}
