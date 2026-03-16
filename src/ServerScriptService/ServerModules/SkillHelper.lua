-- ==========================================
-- SkillHelper: 技能效果施加工具
-- 统一 EffectId → BuffSystem 管线
-- 所有技能通过此模块施加伤害/CC/Shield
-- ==========================================
local ServerScriptService = game:GetService("ServerScriptService")

local BuffSystem = require(ServerScriptService:WaitForChild("ServerModules"):WaitForChild("BuffSystem"))
local CombatUtils = require(ServerScriptService:WaitForChild("ServerModules"):WaitForChild("CombatUtils"))

local SkillHelper = {}

--- 统一效果施加（含符文 DamageBoost 加成）
-- @param skillInstance table 技能实例（用于读取 RuneSlots）
-- @param source Model 施加者角色
-- @param target Model 目标角色
-- @param effectIds {number} EffectConfig 中的 ID 列表
function SkillHelper.ApplyEffects(skillInstance, source, target, effectIds)
	if not effectIds or not target then return end
	local damageBoost = skillInstance:GetRuneStat("DamageBoost")
	for _, effectId in ipairs(effectIds) do
		BuffSystem:ApplyEffect(source, target, effectId)
	end
	-- DamageBoost 符文: 额外施加一次 Damage（通过直接扣血实现加成）
	-- 注: 当前 DamageBoost 由各 Archetype 在 GetXxxConfig 中的 powerScale 处理
	-- 此处预留接口，后续可改为统一加成逻辑
end

--- 区域批量施加效果
-- @param skillInstance table 技能实例
-- @param source Model 施加者角色
-- @param player Player 施法者 Player（用于 CombatUtils 敌我判定）
-- @param position Vector3 区域中心
-- @param radius number 区域半径
-- @param effectIds {number} EffectConfig 中的 ID 列表
-- @return {Model} 被命中的敌方列表
function SkillHelper.ApplyAreaEffects(skillInstance, source, player, position, radius, effectIds)
	if not effectIds or not position then return {} end
	local enemies = CombatUtils.getEnemiesInRange(player, position, radius, source)
	for _, enemy in ipairs(enemies) do
		SkillHelper.ApplyEffects(skillInstance, source, enemy, effectIds)
	end
	return enemies
end

return SkillHelper
