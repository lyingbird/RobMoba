-- ==========================================
-- HouYi (后羿) 英雄配置
-- 自动被 HeroRegistry 发现和注册
-- ==========================================
return {
	HeroID = "HouYi",
	DisplayName = "后羿",
	Theme = Color3.fromRGB(255, 160, 50), -- 橙色

	-- 新增元数据
	Role = "Marksman",
	Difficulty = 1,
	SortOrder = 3,
	Enabled = true,
	Tags = { "DPS", "AOE" },
	FreeRotation = false,

	-- 被动 (REQ-007)
	Passives = { [1] = 5003 },  -- 多重射击
	EnergyType = "Mana",

	-- 技能映射
	Skills = { Q = 1009, W = 1010, R = 1011 },
	AllowBackpack = true,

	-- 动画配置
	Poses = {
		Cast_Q = {
			RightShoulder = {-40, 0, -60},
			LeftShoulder = {-10, 0, 30},
			Waist = {0, -10, 0},
		},
		Cast_W = {
			RightShoulder = {-60, 0, -90},
			LeftShoulder = {-20, 0, 50},
			Waist = {-10, 0, 0},
		},
		Cast_R = {
			RightShoulder = {-90, 0, -60},
			LeftShoulder = {-50, 0, 60},
			Waist = {-15, 0, 0},
			Neck = {-25, 0, 0},
		},
		Windup = {
			RightShoulder = {10, 0, 15},
			LeftShoulder = {5, 0, -10},
			Waist = {8, 0, 0},
			Root = {3, 0, 0},
		},
	},
	CastDurations = { Q = 0.4, W = 0.6, R = 1.0 },
	CastLift = { Q = 0, W = 0, R = 4 },
	MoveLock = { Q = "none", W = "none", R = "full" },
}
