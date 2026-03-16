-- ==========================================
-- Angela (安琪拉) 技能配置
-- 新格式: 通用字段 + ArchetypeType + EffectRefs
-- 自动被 SkillRegistry 发现和注册
-- ==========================================
return {
	[1006] = {
		Name = "AngelaQ",
		UIName = "火球术",
		Icon = "rbxassetid://79478084537574",
		Slot = "Q",
		CD = 6,
		Range = 45,
		EnergyCost = 50,
		CastRule = "Direction",
		ArchetypeType = "Projectile",
		-- Archetype 参数 (特殊: 多弹散射, 重写OnCast)
		Speed = 55,
		Size = Vector3.new(1.8, 1.8, 1.8),
		Color = Color3.fromRGB(255, 100, 0),
		Material = Enum.Material.Neon,
		MaxLifetime = 3,
		MaxPierceCount = 1,
		BulletCount = 5,
		SpreadWidth = 8,
		-- 效果引用
		OnHitEffects = { 3020 },
		OnHitCC = {},
		-- UI 描述
		DescAttrs = { Damage = "300×5", Type = "Magic" },
	},
	[1007] = {
		Name = "AngelaW",
		UIName = "混沌火种",
		Icon = "rbxassetid://74736538945177",
		Slot = "W",
		CD = 8,
		Range = 40,
		EnergyCost = 70,
		CastRule = "Direction",
		ArchetypeType = "Projectile",
		-- Archetype 参数 (复合: 命中后创建漩涡区域)
		Speed = 50,
		Size = Vector3.new(2, 2, 2),
		Color = Color3.fromRGB(255, 100, 0),
		Material = Enum.Material.Neon,
		MaxLifetime = 3,
		MaxPierceCount = 1,
		-- 效果引用
		OnHitEffects = { 3021 },
		OnHitCC = { 3022 },
		-- 复合: 漩涡区域参数
		VortexRadius = 8,
		VortexDuration = 3,
		VortexEffects = { 3023 },
		-- UI 描述
		DescAttrs = { Damage = 400, CC = "Stun 1s", Vortex = "80/tick × 3s", Type = "Magic" },
	},
	[1008] = {
		Name = "AngelaR",
		UIName = "炽热光辉",
		Icon = "rbxassetid://85476569427906",
		Slot = "R",
		CD = 50,
		Range = 60,
		EnergyCost = 100,
		CastRule = "Direction",
		ArchetypeType = "Beam",
		IsUltimate = true,
		-- Archetype 参数
		Width = 8,
		Duration = 3,
		TickInterval = 0.3,
		Mode = "Channel",
		TrackMouse = true,
		TurnSpeed = 1.5,
		-- 效果引用
		TickEffects = { 3024 },
		-- UI 描述
		DescAttrs = { Damage = "200/tick × 10", Duration = "3s", Type = "Magic" },
	},
}
