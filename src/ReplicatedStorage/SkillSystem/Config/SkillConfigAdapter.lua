-- SkillConfigAdapter: 适配层
-- 路径: ReplicatedStorage.SkillSystem.Config.SkillConfigAdapter
--
-- 读取现有 SkillRegistry（Skills/*.lua 汇聚后的表），
-- 将 CastRule/aimType/Slot 等旧格式字段转换为新系统统一的 SkillConfigEntry 格式。
-- 运行时只需 require 此模块即可获取适配后的完整技能配置。

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- 加载枚举
local SkillEnums = require(
	ReplicatedStorage:WaitForChild("SkillSystem")
		:WaitForChild("Enums")
		:WaitForChild("SkillEnums")
)

-- 加载现有技能注册表
local SkillRegistry = require(
	ReplicatedStorage:WaitForChild("SkillRegistry")
)

local CastRuleToRangeType = SkillEnums.CastRuleToRangeType
local AimTypeToRangeType = SkillEnums.AimTypeToRangeType
local SlotNameToType = SkillEnums.SlotNameToType

--------------------------------------------------------------------------------
-- 根据技能属性自动分配指示器配置 ID
--------------------------------------------------------------------------------
local function resolveIndicatorCfgId(rangeType: number, rawConfig: any): number
	-- Auto 型无指示器
	if rangeType == SkillEnums.SkillRangeType.Auto then
		return 0
	end

	-- 如果原始配置有显式指定
	if rawConfig.indicatorCfgId then
		return rawConfig.indicatorCfgId
	end

	-- SelfRange 型: 自身范围圈
	if rangeType == SkillEnums.SkillRangeType.SelfRange then
		return 1008
	end

	-- Target 型
	if rangeType == SkillEnums.SkillRangeType.Target then
		return 1001
	end

	-- Pos 型
	if rangeType == SkillEnums.SkillRangeType.Pos then
		-- 大范围 AOE（Radius > 8）用大圈指示器
		if rawConfig.Radius and rawConfig.Radius > 8 then
			return 1004
		end
		return 1002
	end

	-- Directional 型
	if rangeType == SkillEnums.SkillRangeType.Directional then
		-- Beam 引导类
		if rawConfig.ArchetypeType == "Beam" then
			return 1006
		end
		-- 多弹散射
		if rawConfig.BulletCount and rawConfig.BulletCount > 1 then
			return 1007
		end
		-- 宽矩形（Width > 4）
		if rawConfig.Width and rawConfig.Width > 4 then
			return 1005
		end
		-- 默认箭头
		return 1003
	end

	return 0
end

--------------------------------------------------------------------------------
-- 解析 rangeType
--------------------------------------------------------------------------------
local function resolveRangeType(rawConfig: any): number
	-- 优先用 aimType（更精确的移动端描述）
	if rawConfig.aimType then
		local mapped = AimTypeToRangeType[rawConfig.aimType]
		if mapped then
			return mapped
		end
	end

	-- 再用 CastRule
	if rawConfig.CastRule then
		local mapped = CastRuleToRangeType[rawConfig.CastRule]
		if mapped then
			return mapped
		end
	end

	-- 默认 Auto
	warn("[SkillConfigAdapter] 无法解析 rangeType, skillId=" .. tostring(rawConfig.Name or "?"))
	return SkillEnums.SkillRangeType.Auto
end

--------------------------------------------------------------------------------
-- 解析 slotType
--------------------------------------------------------------------------------
local function resolveSlotType(rawConfig: any): number
	if rawConfig.Slot then
		return SlotNameToType[rawConfig.Slot] or 1
	end
	return 1
end

--------------------------------------------------------------------------------
-- 构建适配后的配置表
--------------------------------------------------------------------------------
local AdaptedConfig = {}

for skillId, rawConfig in pairs(SkillRegistry) do
	local rangeType = resolveRangeType(rawConfig)
	local slotType = resolveSlotType(rawConfig)
	local indicatorCfgId = resolveIndicatorCfgId(rangeType, rawConfig)

	AdaptedConfig[skillId] = {
		skillId = skillId,
		skillName = rawConfig.Name or ("Skill_" .. tostring(skillId)),
		uiName = rawConfig.UIName or rawConfig.Name or "",
		icon = rawConfig.Icon or "",
		slotType = slotType,
		rangeType = rangeType,
		cooldown = rawConfig.CD or 10,
		manaCost = rawConfig.EnergyCost or 0,
		castRange = rawConfig.Range or 10,
		indicatorCfgId = indicatorCfgId,
		-- SelfRange 型: 保留技能 AOE 半径，用于动态覆写指示器范围圈大小
		selfRangeRadius = (rangeType == SkillEnums.SkillRangeType.SelfRange)
			and (rawConfig.AreaRadius or rawConfig.Radius or 5) or nil,
		-- 保留原始引用
		archetypeType = rawConfig.ArchetypeType,
		isUltimate = rawConfig.IsUltimate or false,
	}
end

return AdaptedConfig
