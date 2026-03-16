-- ==========================================
-- EnergyConfig: 能量类型配置
-- 由 EnergySystem (服务端) 和 UI_HUD (客户端) 读取
-- 运行位置: ReplicatedStorage (Server+Client 共享)
--
-- 4 种能量类型:
--   Mana    法力 — 自然恢复，消耗施法
--   Rage    怒气 — 战斗获取，脱战衰减
--   Energy  能量 — 快速恢复，CD才是约束
--   None    无消耗 — 不显示能量条
-- ==========================================
return {
	Mana = {
		DisplayName = "法力",
		BaseMax = 500,
		GrowthPerLevel = 40,
		RegenPerSecond = 5,
		RegenGrowth = 0.5,
		InitialValue = nil, -- nil = BaseMax (满蓝开局)
		BarColor = Color3.fromRGB(50, 100, 255),
		BarBgColor = Color3.fromRGB(15, 30, 80),
		ShowBar = true,
		ShowText = true,
	},
	Rage = {
		DisplayName = "怒气", -- HoK: 类型=怒气, 显示名称=战意
		BaseMax = 200,        -- HoK: 15号表ID=305 能量上限=200
		GrowthPerLevel = 0,
		RegenPerSecond = 0,   -- 怒气不自然恢复,通过被动和技能获取
		-- 怒气获取 (来源: 22号表 105001=+6, 105002=+12, 105101=+16)
		GainOnHit = 6,        -- 普攻A1/A2命中 +6 (HoK: 105001)
		GainOnA3Hit = 12,     -- 普攻A3命中 +12 (HoK: 105002)
		GainOnSkillHit = 16,  -- Q/W命中 +16 (HoK: 105101)
		GainOnDamaged = 0,    -- 受击不获取怒气
		-- 衰减 (脱战后衰减)
		DecayAfterCombat = { Delay = 5, Rate = 10 },
		InitialValue = 0,
		-- UI
		BarColor = Color3.fromRGB(255, 50, 50),
		BarBgColor = Color3.fromRGB(80, 15, 15),
		ShowBar = true,
		ShowText = true,
	},
	Energy = {
		DisplayName = "能量",
		BaseMax = 100,
		GrowthPerLevel = 0,
		RegenPerSecond = 10,
		RegenGrowth = 0,
		InitialValue = nil, -- nil = BaseMax (满能量开局)
		BarColor = Color3.fromRGB(255, 200, 50),
		BarBgColor = Color3.fromRGB(80, 60, 15),
		ShowBar = true,
		ShowText = true,
	},
	None = {
		DisplayName = "",
		BaseMax = 0,
		GrowthPerLevel = 0,
		RegenPerSecond = 0,
		InitialValue = 0,
		ShowBar = false,
		ShowText = false,
	},
}
