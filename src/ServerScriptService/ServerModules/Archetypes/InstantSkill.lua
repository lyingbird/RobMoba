-- ==========================================
-- InstantSkill: 瞬发技能 Archetype 基类
-- 覆盖: ~10% 技能 (HouYiQ, LianPoW, LianPoCinematic)
-- Template Method: OnCast → GetInstantConfig → 通用瞬发逻辑
-- ==========================================
local ServerScriptService = game:GetService("ServerScriptService")

local BaseSkill = require(ServerScriptService:WaitForChild("ServerModules"):WaitForChild("BaseSkill"))
local SkillHelper = require(ServerScriptService:WaitForChild("ServerModules"):WaitForChild("SkillHelper"))

local InstantSkill = setmetatable({}, BaseSkill)
InstantSkill.__index = InstantSkill

function InstantSkill.new(skillID)
	return setmetatable(BaseSkill.new(skillID), InstantSkill)
end

--- 子类可重写: 返回瞬发配置
function InstantSkill:GetInstantConfig()
	return {
		SelfEffects = self.Config.SelfEffects or {},
		TargetEffects = self.Config.TargetEffects or {},
		AreaRadius = self.Config.AreaRadius or 0,
		AreaEffects = self.Config.AreaEffects or {},
		AreaCC = self.Config.AreaCC or {},
	}
end

--- 子类可选重写: 瞬发回调（自定义逻辑入口）
function InstantSkill:OnInstantCast(player, targetPos) end

--- 标准瞬发释放
function InstantSkill:OnCast(player, targetPos)
	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then return end

	local config = self:GetInstantConfig()

	-- 对自身施加效果
	if #config.SelfEffects > 0 then
		SkillHelper.ApplyEffects(self, character, character, config.SelfEffects)
	end

	-- 区域效果
	if config.AreaRadius > 0 then
		local position = character.HumanoidRootPart.Position
		-- 合并 AreaEffects + AreaCC
		local allEffects = {}
		for _, id in ipairs(config.AreaEffects) do table.insert(allEffects, id) end
		for _, id in ipairs(config.AreaCC) do table.insert(allEffects, id) end
		if #allEffects > 0 then
			SkillHelper.ApplyAreaEffects(self, character, player, position, config.AreaRadius, allEffects)
		end
	end

	-- 子类回调
	self:OnInstantCast(player, targetPos)
end

return InstantSkill
