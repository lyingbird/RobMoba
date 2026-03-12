local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SkillConfig = require(ReplicatedStorage:WaitForChild("SkillConfig"))
local RuneConfig = require(ReplicatedStorage:WaitForChild("RuneConfig"))

local BaseSkill = {}
BaseSkill.__index = BaseSkill

function BaseSkill.new(skillID)
	local self = setmetatable({}, BaseSkill)
	self.ID = skillID
	self.Config = SkillConfig[skillID] or { Name = "Unknown", BaseCD = 5 }
	self.RuneSlots = { [1] = nil, [2] = nil, [3] = nil }
	self.LastCastTime = 0
	self.IsRecastable = false
	self.WaitingForRecast = false
	return self
end

function BaseSkill:EquipRune(slotIndex, runeID)
	if slotIndex < 1 or slotIndex > 3 then return end
	self.RuneSlots[slotIndex] = runeID
end

function BaseSkill:GetRuneStat(statType)
	local total = 0
	for i = 1, 3 do
		local runeID = self.RuneSlots[i]
		if runeID then
			local runeData = RuneConfig[runeID]
			if runeData and runeData.Type == statType then
				total = total + (runeData.Value or 0)
			end
		end
	end
	return total
end

function BaseSkill:GetFinalCD()
	local baseCD = self.Config.BaseCD or 5
	local cdrValue = self:GetRuneStat("CDR")
	return math.max(0.1, baseCD * (1 - cdrValue))
end

function BaseSkill:CanCast()
	return (os.clock() - self.LastCastTime) >= self:GetFinalCD()
end

function BaseSkill:StartCooldown()
	self.LastCastTime = os.clock()
end

function BaseSkill:OnCast(player, targetPos)
	warn(self.Config.Name .. " has no OnCast implementation!")
end

return BaseSkill