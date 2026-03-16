-- ==========================================
-- EffectConfig: 效果数据定义
-- 6 种标准效果类型: Damage, CC, Shield, DoT, HoT, StatMod
-- 由 BuffSystem 读取和执行 | 被动效果由 PassiveSystem 引用
--
-- ID 分配方案:
--   3001-3019  拉克丝(Lux) — 临时ID, 后续统一为王者原始ID
--   3020-3039  安琪拉(Angela) — 临时ID
--   3040-3059  后羿(HouYi) — 临时ID
--   3080       后羿被动攻速 — 临时ID
--   105xxx     廉颇(LianPo) — 王者原始ID (已统一)
--   3900-3949  通用效果
--   3950-3999  调试/测试
--
-- 叠加规则:
--   Replace     新效果替换旧效果（刷新持续时间和参数）
--   Stack       效果叠加层数，直到 MaxStacks
--   Refresh     保持当前参数，只刷新持续时间
--   Independent 完全独立的多个实例
-- ==========================================
return {
	-- ============================================================
	-- 拉克丝 (Lux) 效果 ID: 3001-3019
	-- ============================================================

	-- LuxQ: 光之束缚 — 伤害
	[3001] = {
		Type = "Damage",
		DamageType = "Magic",
		Amount = 250,
	},

	-- LuxQ: 光之束缚 — 定身
	[3002] = {
		Type = "CC",
		CCType = "Root",
		Duration = 1.0,
		Stacking = "Replace",
	},

	-- LuxW: 曲光屏障 — 护盾
	[3003] = {
		Type = "Shield",
		Amount = 150,
		Duration = 3.0,
		Stacking = "Replace",
	},

	-- LuxE: 透光奇点 — 减速
	[3004] = {
		Type = "CC",
		CCType = "Slow",
		Percent = 0.25,
		Duration = 2.0,
		Stacking = "Replace",
	},

	-- LuxE: 透光奇点 — 区域伤害 (按 Tick)
	[3005] = {
		Type = "Damage",
		DamageType = "Magic",
		Amount = 240,
	},

	-- LuxR: 终极闪光 — 伤害
	[3006] = {
		Type = "Damage",
		DamageType = "Magic",
		Amount = 500,
	},

	-- ============================================================
	-- 安琪拉 (Angela) 效果 ID: 3020-3039
	-- ============================================================

	-- AngelaQ: 火球术 — 伤害 (每颗弹丸)
	[3020] = {
		Type = "Damage",
		DamageType = "Magic",
		Amount = 300,
	},

	-- AngelaW: 混沌火种 — 弹道伤害
	[3021] = {
		Type = "Damage",
		DamageType = "Magic",
		Amount = 400,
	},

	-- AngelaW: 混沌火种 — 眩晕
	[3022] = {
		Type = "CC",
		CCType = "Stun",
		Duration = 1.0,
		Stacking = "Replace",
		MutexGroup = "HardCC",
	},

	-- AngelaW: 混沌火种 — 漩涡持续伤害
	[3023] = {
		Type = "DoT",
		DamageType = "Magic",
		TickDamage = 80,
		TickInterval = 0.5,
		Duration = 3.0,
		Stacking = "Replace",
	},

	-- AngelaR: 炽热光辉 — 每 Tick 伤害
	[3024] = {
		Type = "Damage",
		DamageType = "Magic",
		Amount = 200,
	},

	-- ============================================================
	-- 后羿 (HouYi) 效果 ID: 3040-3059
	-- ============================================================

	-- HouYiQ: 多重箭矢 — 增加攻击次数
	[3040] = {
		Type = "StatMod",
		Stat = "AttackCount",
		ModType = "Flat",
		Value = 2,
		Duration = 6.0,
		Stacking = "Replace",
	},

	-- HouYiQ: 多重箭矢 — 浮剑命中伤害
	[3045] = {
		Type = "Damage",
		DamageType = "Magic",
		Amount = 150,
	},

	-- HouYiW: 日之塔 — 持续伤害
	[3041] = {
		Type = "DoT",
		DamageType = "Magic",
		TickDamage = 30,
		TickInterval = 0.5,
		Duration = 2.0,
		Stacking = "Replace",
	},

	-- HouYiR: 烈日裁决 — 弹道伤害
	[3042] = {
		Type = "Damage",
		DamageType = "Magic",
		Amount = 500,
	},

	-- HouYiR: 烈日裁决 — 眩晕
	[3043] = {
		Type = "CC",
		CCType = "Stun",
		Duration = 1.5,
		Stacking = "Replace",
		MutexGroup = "HardCC",
	},

	-- HouYiR: 烈日裁决 — 爆炸伤害
	[3044] = {
		Type = "Damage",
		DamageType = "Magic",
		Amount = 250,
	},

	-- ============================================================
	-- 廉颇 (LianPo) 效果 — 王者原始ID (105xxx)
	-- 来源: 王者荣耀 22号表 效果组合ID
	-- ============================================================

	-- 普攻: 基础物理伤害 (来源: 105000, 100%AD+100%AA)
	[105000] = {
		Type = "Damage",
		DamageType = "Physical",
		Amount = 198,  -- HoK: baseAD=198, 100%AD加成
		ScalingAD = 1.0,
		ScalingAA = 1.0,
	},

	-- 普攻A3: 额外物理伤害 (来源: 105021, base=250+50/lv, 100%AD)
	[105021] = {
		Type = "Damage",
		DamageType = "Physical",
		Amount = 250,
		AmountPerLevel = 50,
		ScalingAD = 1.0,
	},

	-- 普攻A3: 击飞 (来源: A3击飞效果, 约0.5s)
	[105020] = {
		Type = "CC",
		CCType = "Knockup",
		Duration = 0.5,
		Stacking = "Replace",
		MutexGroup = "HardCC",
	},

	-- Q: 爆裂冲撞 — 物理伤害 (来源: 105100, base=150+30/lv, +3%额外HP)
	[105100] = {
		Type = "Damage",
		DamageType = "Physical",
		Amount = 150,
		AmountPerLevel = 30,
		ScalingBonusHP = 0.03,
	},

	-- Q: 爆裂冲撞 — 击飞 (来源: 105190, 控制效果击飞 500ms)
	[105190] = {
		Type = "CC",
		CCType = "Knockup",
		Duration = 0.5,    -- HoK: 500ms
		Stacking = "Replace",
		MutexGroup = "HardCC",
	},

	-- W: 熔岩重击 — 护盾 (来源: 105250, base=400+80/lv, 5s, 额外HP加成)
	[105250] = {
		Type = "Shield",
		Amount = 400,
		AmountPerLevel = 80,
		Duration = 5.0,     -- HoK: 5000ms
		Stacking = "Replace",
		ScalingBonusHP = 0.03,
	},

	-- W: 熔岩重击 — 外圈AOE伤害 (来源: 105200, base=330+66/lv, 110%AD)
	[105200] = {
		Type = "Damage",
		DamageType = "Physical",
		Amount = 330,
		AmountPerLevel = 66,
		ScalingAD = 1.1,
	},

	-- W: 熔岩重击 — 中圈/内圈额外伤害 (来源: 105201+105202, +165×2 55%AD×2)
	[105201] = {
		Type = "Damage",
		DamageType = "Physical",
		Amount = 330,      -- 165+165 中圈+内圈合计
		AmountPerLevel = 66,
		ScalingAD = 1.1,   -- 55%+55%
	},

	-- W: 熔岩重击 — 减速 (来源: 105290, 15%+3%/lv, 1s)
	[105290] = {
		Type = "CC",
		CCType = "Slow",
		Percent = 0.15,     -- HoK: 1500万分比
		PercentPerLevel = 0.03,
		Duration = 1.0,     -- HoK: 1000ms
		Stacking = "Replace",
	},

	-- R: 天崩地裂 — 第1跺伤害 (来源: 105300, +100, 27%AD)
	[105300] = {
		Type = "Damage",
		DamageType = "Physical",
		Amount = 100,
		AmountPerLevel = 50,
		ScalingAD = 0.27,
	},

	-- R: 天崩地裂 — 第2跺伤害 (来源: 105301, +150, 40%AD)
	[105301] = {
		Type = "Damage",
		DamageType = "Physical",
		Amount = 150,
		AmountPerLevel = 75,
		ScalingAD = 0.40,
	},

	-- R: 天崩地裂 — 第3跺伤害 (来源: 105302, +200, 54%AD)
	[105302] = {
		Type = "Damage",
		DamageType = "Physical",
		Amount = 200,
		AmountPerLevel = 100,
		ScalingAD = 0.54,
	},

	-- R: 天崩地裂 — 第1跺减速 (来源: 105390, 30%, 1s)
	[105390] = {
		Type = "CC",
		CCType = "Slow",
		Percent = 0.30,
		Duration = 1.0,
		Stacking = "Refresh",
	},

	-- R: 天崩地裂 — 第2跺减速 (来源: 105391, 50%, 1s)
	[105391] = {
		Type = "CC",
		CCType = "Slow",
		Percent = 0.50,
		Duration = 1.0,
		Stacking = "Refresh",
	},

	-- R: 天崩地裂 — 第3跺击飞 (来源: 105392, 击飞 1s)
	[105392] = {
		Type = "CC",
		CCType = "Knockup",
		Duration = 1.0,
		Stacking = "Replace",
		MutexGroup = "HardCC",
	},

	-- R: 天崩地裂 — 自身加速50% (来源: 105303, 2.8s)
	[105303] = {
		Type = "StatMod",
		Stat = "MoveSpeed",
		ModType = "Percent",
		Value = 0.50,
		Duration = 2.8,
		Stacking = "Replace",
	},

	-- R: 天崩地裂 — 免疫控制 (来源: 105310, 2.8s)
	[105310] = {
		Type = "StatMod",
		Stat = "CCImmune",
		ModType = "Flat",
		Value = 1,
		Duration = 2.8,
		Stacking = "Replace",
	},

	-- R: 天崩地裂 — 减伤20% (来源: 105311, 2.8s)
	[105311] = {
		Type = "StatMod",
		Stat = "DamageReduction",
		ModType = "Flat",
		Value = 0.20,
		Duration = 2.8,
		Stacking = "Replace",
	},

	-- 普攻: +6怒气 (来源: 105001)
	[105001] = {
		Type = "StatMod",
		Stat = "Energy",
		ModType = "Flat",
		Value = 6,
		Duration = 0,
		Stacking = "Replace",
		IsInstant = true,
	},

	-- 普攻A3: +12怒气 (来源: 105002)
	[105002] = {
		Type = "StatMod",
		Stat = "Energy",
		ModType = "Flat",
		Value = 12,
		Duration = 0,
		Stacking = "Replace",
		IsInstant = true,
	},

	-- Q/W: +16怒气 (来源: 105101)
	[105101] = {
		Type = "StatMod",
		Stat = "Energy",
		ModType = "Flat",
		Value = 16,
		Duration = 0,
		Stacking = "Replace",
		IsInstant = true,
	},

	-- 被动P0: 怒气→减伤 (来源: 26号表10500, 永久buff)
	[105400] = {
		Type = "StatMod",
		Stat = "DamageReduction",
		ModType = "Flat",
		Value = 0,            -- 动态: 由PassiveSystem根据怒气比例计算
		Duration = 999,
		Stacking = "Replace",
	},

	-- 被动P11: 脱战回血 (来源: 26号表10502)
	[105500] = {
		Type = "HoT",
		DamageType = "Physical",
		TickHeal = 50,
		TickInterval = 2.0,
		Duration = 999,
		Stacking = "Replace",
	},

	-- ============================================================
	-- 通用效果 ID: 3900-3949
	-- ============================================================

	-- 通用火球术 (Fireball/1001) — 伤害
	[3900] = {
		Type = "Damage",
		DamageType = "Magic",
		Amount = 2500,
	},

	-- ============================================================
	-- 调试/测试效果 ID: 3950-3999
	-- ============================================================

	-- 测试减速
	[3950] = {
		Type = "CC",
		CCType = "Slow",
		Percent = 0.5,
		Duration = 3.0,
		Stacking = "Replace",
	},

	-- 测试 DoT
	[3951] = {
		Type = "DoT",
		DamageType = "Magic",
		TickDamage = 10,
		TickInterval = 1.0,
		Duration = 5.0,
		Stacking = "Stack",
		MaxStacks = 3,
	},
}
