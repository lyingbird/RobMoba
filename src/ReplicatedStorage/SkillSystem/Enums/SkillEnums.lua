-- SkillEnums: 技能系统枚举定义
-- 路径: ReplicatedStorage.SkillSystem.Enums.SkillEnums
local SkillEnums = {}

--------------------------------------------------------------------------------
-- 1. 技能范围指定类型
--------------------------------------------------------------------------------
SkillEnums.SkillRangeType = {
	Auto        = 0,  -- 按下即释放，无指示器（如闪现）
	Target      = 1,  -- 指定目标，拖动锁定敌方单位（如点控技能）
	Pos         = 2,  -- 指定位置，拖动选择地面落点（如 AOE 技能）
	Directional = 3,  -- 指定方向，拖动选择释放朝向（如线性技能）
	Track       = 4,  -- 指定轨迹，拖动绘制路径（预留）
	SelfRange   = 5,  -- 自身范围，按下显示脚下范围圈，松手释放（如廉颇W）
}

--------------------------------------------------------------------------------
-- 2. 技能槽位
--------------------------------------------------------------------------------
SkillEnums.SlotType = {
	SLOT_SKILL_0 = 0,  -- 普攻
	SLOT_SKILL_1 = 1,  -- 技能1 (Q)
	SLOT_SKILL_2 = 2,  -- 技能2 (W)
	SLOT_SKILL_3 = 3,  -- 技能3 大招 (R)
	SLOT_SKILL_4 = 4,  -- 召唤师技能1
	SLOT_SKILL_5 = 5,  -- 召唤师技能2
}

-- 从英雄配置的 Slot 字符串映射到 SlotType
SkillEnums.SlotNameToType = {
	["Q"] = 1,
	["W"] = 2,
	["E"] = 2, -- 有些英雄用 E 代表二技能
	["R"] = 3,
	["D"] = 4,
	["F"] = 5,
}

--------------------------------------------------------------------------------
-- 3. 指示器层
--------------------------------------------------------------------------------
SkillEnums.IndicatorLayer = {
	Guide  = 1,  -- 挂角色脚下，显示最大施法范围圆
	Effect = 2,  -- 挂场景根节点，跟随目标位置移动
	Fixed  = 3,  -- 挂角色脚下，始终显示（如大招固定圈）
}

--------------------------------------------------------------------------------
-- 4. 指示器资源类型
--------------------------------------------------------------------------------
SkillEnums.IndicatorResType = {
	Arrow      = 0,  -- 箭头（Directional 默认）
	Sector     = 1,  -- 扇形（Target 近距离）
	Circle     = 2,  -- 圆形（Pos 默认）
	Rectangle  = 3,  -- 矩形（Directional 宽度型）
	Ring       = 4,  -- 圆环（Guide 默认）
	HalfCircle = 5,  -- 半圆
	Line       = 6,  -- 线型（Track 默认）
}

--------------------------------------------------------------------------------
-- 5. 控制器状态机
--------------------------------------------------------------------------------
SkillEnums.ControllerState = {
	Idle      = "Idle",
	Pressing  = "Pressing",
	Dragging  = "Dragging",
	Released  = "Released",
	Cancelled = "Cancelled",
	Buffered  = "Buffered",
}

--------------------------------------------------------------------------------
-- 6. 取消模式
--------------------------------------------------------------------------------
SkillEnums.CancelMode = {
	AreaCancel     = 1,  -- UI矩形区域：手指进入底部 CancelFrame
	DistanceCancel = 2,  -- 拖动距离：从按下点到当前位置超过阈值
}

--------------------------------------------------------------------------------
-- 7. CastRule 到 SkillRangeType 的映射（适配现有配置）
--------------------------------------------------------------------------------
SkillEnums.CastRuleToRangeType = {
	["Instant"]   = 0,  -- Auto
	["Auto"]      = 0,  -- Auto (普攻等自动施放技能)
	["Target"]    = 1,  -- Target
	["Position"]  = 2,  -- Pos
	["Direction"] = 3,  -- Directional
}

-- aimType 到 SkillRangeType 的映射（适配现有配置）
SkillEnums.AimTypeToRangeType = {
	["self"]        = 5,  -- SelfRange: 显示自身范围圈，松手释放
	["target"]      = 1,  -- Target
	["area"]        = 2,  -- Pos
	["directional"] = 3,  -- Directional
	["channel"]     = 3,  -- Channel 类似 Directional（引导技能）
}

return SkillEnums
