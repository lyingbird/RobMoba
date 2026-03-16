-- ==========================================
-- Lux 技能配置 (含通用 Fireball)
-- 新格式: 通用字段 + ArchetypeType + EffectRefs
-- 自动被 SkillRegistry 发现和注册
-- ==========================================
return {
	[1001] = {
		Name = "Fireball",
		UIName = "火球术",
		Icon = "rbxassetid://105719906967326",
		Slot = "Q",
		CD = 10,
		Range = 40,
		EnergyCost = 0,
		CastRule = "Direction",
		ArchetypeType = "Projectile",
		-- Archetype 参数
		Speed = 60,
		Size = Vector3.new(1.5, 1.5, 1.5),
		Color = Color3.fromRGB(255, 120, 0),
		Material = Enum.Material.Neon,
		MaxLifetime = 3,
		MaxPierceCount = 1,
		-- 效果引用
		OnHitEffects = { 3900 },
		OnHitCC = {},
		-- UI 描述
		DescAttrs = { Damage = 2500, Type = "Magic" },
	},
	[1002] = {
		Name = "LuxQ",
		UIName = "光之束缚",
		Icon = "rbxassetid://128294170183609",
		Slot = "Q",
		CD = 11,
		Range = 50,
		EnergyCost = 50,
		CastRule = "Direction",
		ArchetypeType = "Projectile",
		-- Archetype 参数
		Speed = 55,
		Size = Vector3.new(2, 2, 2),
		Color = Color3.fromRGB(255, 240, 180),
		Material = Enum.Material.Neon,
		MaxLifetime = 3,
		MaxPierceCount = 2,
		-- 效果引用
		OnHitEffects = { 3001 },
		OnHitCC = { 3002 },
		-- UI 描述
		DescAttrs = { Damage = 250, CC = "Root 1s", Type = "Magic" },
	},
	[1003] = {
		Name = "LuxW",
		UIName = "曲光屏障",
		Icon = "rbxassetid://127821745515043",
		Slot = "W",
		CD = 14,
		Range = 45,
		EnergyCost = 60,
		CastRule = "Direction",
		ArchetypeType = "Projectile",
		-- Archetype 参数 (特殊: 对友方施加)
		Speed = 50,
		Size = Vector3.new(0.5, 0.5, 3),
		Color = Color3.fromRGB(180, 230, 255),
		Material = Enum.Material.Neon,
		MaxLifetime = 5,
		MaxPierceCount = 99,
		TargetAlly = true,
		ReturnToSource = true,
		-- 效果引用 (对友方施加护盾)
		SelfEffects = { 3003 },
		OnHitEffects = { 3003 },
		OnHitCC = {},
		-- UI 描述
		DescAttrs = { Shield = 150, Duration = "3s" },
	},
	[1004] = {
		Name = "LuxE",
		UIName = "透光奇点",
		Icon = "rbxassetid://136209389780773",
		Slot = "E",
		CD = 10,
		Range = 45,
		EnergyCost = 60,
		CastRule = "Position",
		aimType = "area", -- 触屏: 按住拖拽选位置释放(圆形范围)
		ArchetypeType = "Area",
		-- Archetype 参数
		Radius = 15,
		Duration = 5,
		TickInterval = 0.5,
		TravelSpeed = 40,
		CanRecast = true,
		-- 效果引用
		TickEffects = { 3004 },
		OnExpireEffects = { 3005 },
		-- UI 描述
		DescAttrs = { Damage = 240, CC = "Slow 25%", Duration = "5s", Type = "Magic" },
	},
	[1005] = {
		Name = "LuxR",
		UIName = "终极闪光",
		Icon = "rbxassetid://96074938800917",
		Slot = "R",
		CD = 60,
		Range = 200,
		EnergyCost = 100,
		CastRule = "Direction",
		ArchetypeType = "Beam",
		IsUltimate = true,
		-- Archetype 参数
		Width = 6,
		Duration = 0,
		Mode = "Instant",
		CastTime = 1,
		-- 效果引用
		OnHitEffects = { 3006 },
		-- UI 描述
		DescAttrs = { Damage = 500, Type = "Magic" },
	},
}
