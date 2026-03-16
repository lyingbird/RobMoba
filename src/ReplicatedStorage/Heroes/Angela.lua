-- ==========================================
-- Angela (安琪拉) 英雄配置
-- 自动被 HeroRegistry 发现和注册
-- ==========================================
return {
	HeroID = "Angela",
	DisplayName = "安琪拉",
	Theme = Color3.fromRGB(200, 80, 255), -- 紫色

	-- 新增元数据
	Role = "Mage",
	Difficulty = 2,
	SortOrder = 1,
	Enabled = true,
	Tags = { "Burst", "Control" },
	FreeRotation = false,

	-- 能量类型 (REQ-007)
	EnergyType = "Mana",

	-- 技能映射
	Skills = { Q = 1006, W = 1007, R = 1008 },
	AllowBackpack = true,

	-- Angela 有魔法书道具
	Accessory = {
		Type = "Book",
		Size = Vector3.new(1.2, 0.1, 0.8),
		Color = Color3.fromRGB(160, 60, 220),
		AttachJoint = "LeftHand",
		ScaleOnR = 2.5,
	},

	-- 动画配置
	Poses = {
		Cast_Q = {
			RightShoulder = {-30, 0, -80},
			LeftShoulder = {-10, 0, 40},
			Waist = {0, -20, 0},
		},
		Cast_W = {
			RightShoulder = {-20, 0, -70},
			LeftShoulder = {-20, 0, 70},
			Waist = {-5, 0, 0},
		},
		Cast_R = {
			RightShoulder = {-80, 0, -90},
			LeftShoulder = {-80, 0, 90},
			Waist = {-25, 0, 0},
			Neck = {-20, 0, 0},
		},
		Windup = {
			RightShoulder = {15, 0, 25},
			LeftShoulder = {15, 0, -25},
			Waist = {12, 0, 0},
			Root = {8, 0, 0},
		},
	},
	CastDurations = { Q = 0.5, W = 0.7, R = 1.5 },
	CastLift = { Q = 0, W = 1, R = 5 },
	MoveLock = { Q = "none", W = "until_fire", R = "full" },
}
