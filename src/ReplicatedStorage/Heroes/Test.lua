-- ==========================================
-- Test (测试英雄) 配置
-- Enabled = false，仅在调试模式下显示
-- 自动被 HeroRegistry 发现和注册
-- ==========================================
return {
	HeroID = "Test",
	DisplayName = "测试",
	Theme = Color3.fromRGB(180, 180, 180), -- 灰色

	-- 新增元数据
	Role = "Mage",
	Difficulty = 1,
	SortOrder = 999,
	Enabled = false,
	Tags = { "Debug" },
	FreeRotation = false,

	-- 技能映射（仅通用火球术）
	Skills = { Q = 1001 },
	AllowBackpack = true,

	-- 动画配置（最简）
	CastDurations = { Q = 0.5 },
	CastLift = { Q = 0 },
	MoveLock = { Q = "none" },
}
