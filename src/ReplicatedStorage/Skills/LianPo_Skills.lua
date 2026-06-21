-- ==========================================
-- LianPo (廉颇) 技能配置
-- ID统一: 使用王者荣耀原始ID (技能/效果/被动)
-- 来源: 王者荣耀 21号表 技能ID 10500~10530
-- 新格式: 通用字段 + ArchetypeType + EffectRefs
-- 自动被 SkillRegistry 发现和注册
-- ==========================================
return {
	-- ============================================================
	-- 普攻 A1 (来源: 21号表 10500, CD=1000ms, 范围=2500)
	-- ============================================================
	[10500] = {
		Name = "LianPoA1",
		UIName = "普攻·第一击",
		Slot = "AA",
		CD = 1.0,           -- HoK: 1000ms
		Range = 2.5,         -- HoK: 最大攻击距离2500 ÷1000
		CastRule = "Auto",
		ArchetypeType = "Area", -- 近身范围(模板01)
		IsAutoAttack = true,
		ComboIndex = 1,
		-- 效果引用
		AreaRadius = 2.5,
		AreaEffects = { 105000 },  -- 物理伤害(100%AD+100%AA)
		SelfEffects = { 105001 },  -- +6怒气
	},

	-- ============================================================
	-- 普攻 A2 (来源: 21号表 10501, 同A1数值)
	-- ============================================================
	[10501] = {
		Name = "LianPoA2",
		UIName = "普攻·第二击",
		Slot = "AA",
		CD = 1.0,
		Range = 2.5,
		CastRule = "Auto",
		ArchetypeType = "Area",
		IsAutoAttack = true,
		ComboIndex = 2,
		AreaRadius = 2.5,
		AreaEffects = { 105000 },
		SelfEffects = { 105001 },  -- +6怒气
	},

	-- ============================================================
	-- 普攻 A3 (来源: 21号表 10502, 额外伤害+击飞+双倍回怒)
	-- ============================================================
	[10502] = {
		Name = "LianPoA3",
		UIName = "普攻·第三击",
		Slot = "AA",
		CD = 1.0,
		Range = 2.5,
		CastRule = "Auto",
		ArchetypeType = "Area",
		IsAutoAttack = true,
		ComboIndex = 3,
		AreaRadius = 2.5,
		-- A3效果: 基础物理伤害 + 额外伤害 + 击飞
		AreaEffects = { 105000, 105021 },  -- 基础+额外伤害
		AreaCC = { 105020 },               -- 击飞(来源: A3的stun动画)
		SelfEffects = { 105002 },          -- +12怒气(双倍)
	},

	-- ============================================================
	-- Q: 爆裂冲撞 (来源: 21号表 10510)
	-- Archetype: DashSkill (MoveActorDuration 方向位移)
	-- HoK: CD=10000ms(-400/lv), 范围=5000, 方向释放
	-- ============================================================
	[10510] = {
		Name = "LianPoQ",
		UIName = "爆裂冲撞",
		Icon = "rbxassetid://112235105032199",
		Slot = "Q",
		CD = 10,             -- HoK: 10000ms ÷1000
		CDPerLevel = -0.4,   -- HoK: -400ms ÷1000
		Range = 5,           -- HoK: 指示器范围5000 ÷1000
		EnergyCost = 0,      -- HoK: 无消耗(怒气通过被动获取)
		CastRule = "Direction",  -- HoK: 方向释放
		ArchetypeType = "Dash",
		-- Archetype 参数
		Speed = 40,
		Width = 4,           -- 碰撞宽度
		MaxRange = 5,        -- HoK: 距离5000 ÷1000
		LockMovement = true,
		-- 效果引用 (来源: 22号表)
		OnDashHitEffects = { 105100 },  -- 物理伤害 base=150+30/lv
		OnDashHitCC = { 105190 },       -- 击飞 0.5s
		SelfEffects = { 105101 },       -- +16怒气
		-- UI 描述
		DescAttrs = { Damage = 150, CC = "Knockup 0.5s", Type = "Physical" },
	},

	-- ============================================================
	-- W: 熔岩重击 (来源: 21号表 10520)
	-- Archetype: InstantSkill (自身AOE)
	-- HoK: CD=10000ms(-400/lv), 瞬发, 自身+目标效果
	-- 机制: 护盾→延迟AOE(3环递增伤害)→减速→刷新Q CD
	-- ============================================================
	[10520] = {
		Name = "LianPoW",
		UIName = "熔岩重击",
		Icon = "rbxassetid://72768482471616",
		Slot = "W",
		CD = 10,             -- HoK: 10000ms
		CDPerLevel = -0.4,   -- HoK: -400ms
		Range = 0,           -- 自身释放
		EnergyCost = 0,
		CastRule = "Instant",
		aimType = "self", -- 触屏: 点按即释放(自身护盾+AOE)
		ArchetypeType = "Instant",
		-- Archetype 参数
		SelfEffects = { 105250 },       -- 护盾 base=400+80/lv 5s
		-- 3环AOE: 外圈/中圈/内圈 递增伤害
		AreaRadius = 5,                 -- 外圈半径 (HoK碰撞框映射)
		AreaEffects = { 105200 },       -- 外圈伤害 base=330+66/lv 110%AD
		InnerRingEffects = { 105201 },  -- 中圈+内圈额外伤害
		AreaCC = { 105290 },            -- 减速 15%+3%/lv 1s
		-- 自定义参数
		ChargeDelay = 1,       -- 延迟1秒后AOE
		RefreshQOnHit = true,  -- 命中敌人刷新Q冷却
		SelfEffectsOnCast = { 105101 }, -- +16怒气
		-- UI 描述
		DescAttrs = { Shield = 400, Damage = "330/495/660", CC = "Slow 15%", Type = "Physical" },
	},

	-- ============================================================
	-- R: 天崩地裂 (来源: 21号表 10530)
	-- Archetype: AreaSkill (特殊: 3跺, 完全重写OnCast)
	-- HoK: CD=50000ms(-5000/lv), 位置释放, 范围5000
	-- 机制: 跳到目标→3次跺地(递增伤害+减速)→第3跺击飞
	--        施法期间: 自身加速50%+免控+减伤20% (2.8s)
	-- ============================================================
	[10530] = {
		Name = "LianPoR",
		UIName = "天崩地裂",
		Icon = "rbxassetid://127042110717394",
		Slot = "R",
		CD = 50,             -- HoK: 50000ms
		CDPerLevel = -5,     -- HoK: -5000ms
		Range = 5,           -- HoK: 指示器范围5000 ÷1000
		EnergyCost = 0,
		CastRule = "Position",
		aimType = "circle_drop", -- 触屏: 按住拖拽选位置释放(范围AOE)
		ArchetypeType = "Area",
		IsUltimate = true,
		-- Archetype 参数 (3段跺地, 重写OnCast)
		Radius = 5,          -- AOE半径 (HoK范围映射)
		Duration = 2.8,      -- 整体持续时间 (与免控/加速一致)
		-- 效果引用: 3段伤害递增 (来源: 22号表)
		Stomp1Effects = { 105300 },  -- 物理 +100 27%AD
		Stomp2Effects = { 105301 },  -- 物理 +150 40%AD
		Stomp3Effects = { 105302 },  -- 物理 +200 54%AD
		-- 3段减速递增
		Stomp1CC = { 105390 },       -- 减速30% 1s
		Stomp2CC = { 105391 },       -- 减速50% 1s
		Stomp3CC = { 105392 },       -- 击飞 1s
		-- 自身增益
		SelfBuffOnCast = {
			105303,  -- 加速50% 2.8s
			105310,  -- 免疫控制 2.8s
			105311,  -- 减伤20% 2.8s
		},
		RemoveBuffOnEnd = { 105303 }, -- 结束移除加速
		-- UI 描述
		DescAttrs = { Damage = "100→150→200+AD", CC = "Slow→Slow→Knockup", Type = "Physical" },
	},
}
