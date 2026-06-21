-- ==========================================
-- HouYi (后羿) 技能配置
-- 新格式: 通用字段 + ArchetypeType + EffectRefs
-- 自动被 SkillRegistry 发现和注册
-- ==========================================
return {
	[1009] = {
		Name = "HouYiQ",
		UIName = "多重箭矢",
		Icon = "rbxassetid://79835807608371",
		Slot = "Q",
		CD = 10,
		Range = 20,
		EnergyCost = 50,
		CastRule = "Instant",
		aimType = "self", -- 触屏: 点按即释放(自我增益)
		ArchetypeType = "Instant",
		-- Archetype 参数
		SelfEffects = { 3040 },
		-- 自定义参数 (环绕浮剑)
		SwordCount = 5,
		Duration = 6,
		DetectRadius = 20,
		SwordEffects = { 3045 },
		-- UI 描述
		DescAttrs = { Effect = "+2 AttackCount", Duration = "6s" },
	},
	[1010] = {
		Name = "HouYiW",
		UIName = "日之塔",
		Icon = "rbxassetid://114645837123980",
		Slot = "W",
		CD = 12,
		Range = 45,
		EnergyCost = 70,
		CastRule = "Position",
		aimType = "area", -- 触屏: 按住拖拽选位置释放(范围AOE)
		ArchetypeType = "Area",
		-- Archetype 参数
		Radius = 12,
		Duration = 2,
		TickInterval = 0.5,
		-- 效果引用
		TickEffects = { 3041 },
		-- UI 描述
		DescAttrs = { Damage = "30/tick × 4", Duration = "2s", Type = "Magic" },
	},
	[1011] = {
		Name = "HouYiR",
		UIName = "烈日裁决",
		Icon = "rbxassetid://105119622343321",
		Slot = "R",
		CD = 40,
		Range = 100,
		EnergyCost = 100,
		CastRule = "Direction",
		aimType = "line", -- 触屏: 按住拖拽方向释放
		ArchetypeType = "Projectile",
		IsUltimate = true,
		-- Archetype 参数 (复合: 命中后落点爆炸)
		Speed = 65,
		Size = Vector3.new(0.6, 0.6, 4),
		Color = Color3.fromRGB(255, 120, 0),
		Material = Enum.Material.Neon,
		MaxLifetime = 5,
		MaxPierceCount = 1,
		-- 效果引用 (弹道直接命中)
		OnHitEffects = { 3042 },
		OnHitCC = { 3043 },
		-- 复合: 爆炸区域参数
		ExplosionRadius = 12,
		ExplosionEffects = { 3044 },
		ExplosionCC = { 3043 },
		-- UI 描述
		DescAttrs = { Damage = "500+250AOE", CC = "Stun 1.5s", Type = "Magic" },
	},
}
