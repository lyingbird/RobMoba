-- ==========================================
-- HeroConfig: 英雄级别配置表
-- 每个英雄包含：基本信息、技能映射、主题色、动画数据
-- Key = 英雄名字符串 (与 DEFAULT_HEROES / HERO_ORDER 对应)
-- ==========================================
return {
	["Lux"] = {
		HeroID = "Lux",
		DisplayName = "光辉女郎",
		Theme = Color3.fromRGB(255, 220, 100), -- 金色
		Skills = { Q = 1002, W = 1003, R = 1005 },
		-- 1001(Fireball) 是通用测试技能, 1004(LuxE) 是额外技能
		AllowBackpack = true,
		-- 动画配置（无特殊道具）
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
	},

	["Angela"] = {
		HeroID = "Angela",
		DisplayName = "安琪拉",
		Theme = Color3.fromRGB(200, 80, 255), -- 紫色
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
	},

	["HouYi"] = {
		HeroID = "HouYi",
		DisplayName = "后羿",
		Theme = Color3.fromRGB(255, 160, 50), -- 橙色
		Skills = { Q = 1009, W = 1010, R = 1011 },
		AllowBackpack = true,
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
	},

	["LianPo"] = {
		HeroID = "LianPo",
		DisplayName = "廉颇",
		Theme = Color3.fromRGB(100, 180, 255), -- 蓝色
		Skills = { Q = 1012, W = 1013, R = 1015 },
		-- 1014(LianPoR) 是普通R, 1015(LianPoCinematic) 是电影特写版R
		AllowBackpack = true,
		Poses = {
			Cast_Q = {
				RightShoulder = {-15, 0, -40},
				LeftShoulder = {-15, 0, 40},
				Waist = {5, 0, 0},
				Root = {-5, 0, 0},
			},
			Cast_W = {
				RightShoulder = {20, 0, -60},
				LeftShoulder = {20, 0, 60},
				Waist = {15, 0, 0},
			},
			Cast_R = {
				RightShoulder = {-30, 0, -50},
				LeftShoulder = {-30, 0, 50},
				Waist = {-20, 0, 0},
				Root = {-10, 0, 0},
				Neck = {-10, 0, 0},
			},
			Windup = {
				RightShoulder = {20, 0, 30},
				LeftShoulder = {20, 0, -30},
				Waist = {15, 0, 0},
				Root = {10, 0, 0},
			},
		},
		CastDurations = { Q = 0.5, W = 0.3, R = 1.0 },
		CastLift = { Q = 0, W = 0, R = 2 },
		MoveLock = { Q = "until_fire", W = "none", R = "full" },
	},

	-- 测试英雄（用通用火球术）
	["Test"] = {
		HeroID = "Test",
		DisplayName = "测试",
		Theme = Color3.fromRGB(180, 180, 180), -- 灰色
		Skills = { Q = 1001 },
		AllowBackpack = true,
		CastDurations = { Q = 0.5 },
		CastLift = { Q = 0 },
		MoveLock = { Q = "none" },
	},
}
