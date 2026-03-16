-- ==========================================
-- LianPo (廉颇) 英雄配置
-- 来源: 王者荣耀 11号表 武将ID=105
-- 自动被 HeroRegistry 发现和注册
-- ==========================================
return {
	HeroID = "LianPo",
	DisplayName = "廉颇",
	Theme = Color3.fromRGB(100, 180, 255), -- 蓝色

	-- 元数据 (来源: 11号表 主要职业=坦克, 细分职业=先锋坦克)
	Role = "Tank",
	SubRole = "Vanguard", -- 先锋坦克
	Difficulty = 2,
	SortOrder = 4,
	Enabled = true,
	Tags = { "Engage", "Shield", "CC", "Vanguard" },
	FreeRotation = false,

	-- 被动 (来源: 11号表 被动技能1~4 → 26号表)
	Passives = {
		[1] = 10500, -- P0: 怒气→减伤转化 (OnSpawn永久)
		[2] = 10501, -- P10: 战斗中获取怒气 (OnCombatEnter)
		[3] = 10502, -- P11: 脱战回血 (OnCombatLeave)
		[4] = 10510, -- P100: 技能升级→普攻强化 (OnSkillLevelUp)
	},
	EnergyType = "Rage",

	-- 普攻 (来源: 21号表 10500→10501→10502 三段循环)
	AutoAttack = {
		Combo = { 10500, 10501, 10502 }, -- A1→A2→A3→循环
		BaseCD = 1.0,  -- 来源: 冷却时间=1000ms
		Range = 2.5,   -- 来源: 最大攻击距离=2500 ÷1000
		-- A3 有额外伤害+击飞+双倍回怒
	},

	-- 技能映射 (来源: 11号表 技能2ID=10510, 技能3ID=10520, 技能4ID=10530)
	Skills = { Q = 10510, W = 10520, R = 10530 },
	AllowBackpack = true,

	-- 基础属性 (来源: 11号表, 用于Roblox侧游戏性参考)
	-- 注: 王者原始值较大,Roblox侧需按游戏性缩放
	HokStats = {
		baseHP = 3675,       -- 基础生命
		baseAD = 198,        -- 基础攻击力
		baseArmor = 150,     -- 基础护甲
		hpGrowth = 0.3084,   -- 3084000÷10000000 每级成长系数
		adGrowth = 0.0083,   -- 83000÷10000000
		armorGrowth = 0.0205, -- 205000÷10000000
	},

	-- 动画配置
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
}
