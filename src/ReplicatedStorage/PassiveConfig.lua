-- ==========================================
-- PassiveConfig: 被动技能数据配置
-- 由 PassiveSystem 读取，事件驱动触发
-- 运行位置: ReplicatedStorage (Server+Client 共享)
--
-- ID 分配方案:
--   5001-5019  拉克丝(Lux) 被动 (预留)
--   5020-5039  安琪拉(Angela) 被动 (预留)
--   5040-5059  后羿(HouYi) 被动
--   10500+     廉颇(LianPo) 被动 — 王者原始ID (已统一)
--   5080-5099  预留（新英雄）
--
-- 触发事件类型:
--   OnHit       普攻/技能命中目标时
--   OnDamaged   受到伤害时
--   OnKill      击杀敌方英雄时
--   Periodic    每 N 秒自动触发
--   OnAbilityUse  释放技能时
--   OnHealthBelow 血量低于阈值时
--
-- 条件类型:
--   CooldownReady   内置CD已就绪
--   HealthBelow     自身血量低于百分比
--   HealthAbove     自身血量高于百分比
--   TargetIsHero    目标必须是英雄
--   HasBuff         自身拥有指定buff
--   NotHasBuff      自身没有指定buff
-- ==========================================
return {
	-- ============================================================
	-- 后羿 (HouYi) 被动 ID: 5003
	-- 多重射击 — 连续命中叠加攻速
	-- 参考: 王者荣耀后羿被动"惩戒射击"简化版
	-- ============================================================
	[5003] = {
		Name = "MultiShot",
		DisplayName = "多重射击",
		Description = "普攻命中叠加攻速，最多5层",
		TriggerEvent = "OnHit",
		Conditions = {},
		Effects = { 3080 },
		StackBehavior = {
			MaxStacks = 5,
			StackEffect = 3080,
			DecayDelay = 3,
			DecayRate = 1,
		},
		Cooldown = 0,
		Icon = "",
	},

	-- ============================================================
	-- 廉颇 (LianPo) 被动 — 王者原始ID
	-- 来源: 王者荣耀 26号表 被动技能ID
	-- ============================================================

	-- P0: 怒气→减伤转化 (来源: 26号表10500, 时间触发 param1=0 param2=1)
	-- 出生永久触发: 怒气越高减伤越高
	[10500] = {
		Name = "RageReduction",
		DisplayName = "战意·坚韧",
		Description = "怒气值转化为伤害减免，怒气越高减伤越大",
		TriggerEvent = "OnSpawn",
		Conditions = {},
		Effects = { 105400 },
		Cooldown = 0,
		Icon = "",
		DynamicScaling = {
			Source = "EnergyRatio",
			TargetEffect = 105400,
			TargetField = "Value",
			MaxValue = 0.20,
		},
	},

	-- P10: 战斗中获取怒气 (来源: 26号表10501, 时间触发+进入战斗条件)
	[10501] = {
		Name = "CombatRage",
		DisplayName = "战意·激怒",
		Description = "进入战斗状态后，持续获得怒气",
		TriggerEvent = "OnCombatEnter",
		Conditions = {},
		Effects = {},
		Cooldown = 0,
		Icon = "",
		OnTrigger = {
			Type = "EnergyGainOverTime",
			GainPerTick = 2,
			TickInterval = 0.5,
			StopOnCombatLeave = true,
		},
	},

	-- P11: 脱战回血 (来源: 26号表10502, 时间触发+脱离战斗条件)
	[10502] = {
		Name = "OutOfCombatHeal",
		DisplayName = "战意·修养",
		Description = "脱离战斗后，持续恢复生命值",
		TriggerEvent = "OnCombatLeave",
		Conditions = {},
		Effects = { 105500 },
		Cooldown = 0,
		Icon = "",
	},

	-- P100: 技能升级→普攻强化 (来源: 26号表10510, 时间触发+技能升级条件)
	[10510] = {
		Name = "SkillUpAttackBoost",
		DisplayName = "战意·觉醒",
		Description = "每次升级技能，永久强化普攻伤害",
		TriggerEvent = "OnSkillLevelUp",
		Conditions = {},
		Effects = {},
		Cooldown = 0,
		Icon = "",
		OnTrigger = {
			Type = "PermanentStatBuff",
			Stat = "AADamageBonus",
			ValuePerStack = 15,
		},
	},
}
