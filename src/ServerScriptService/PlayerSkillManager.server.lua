local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local SkillConfig = require(ReplicatedStorage:WaitForChild("SkillConfig"))
local RuneConfig = require(ReplicatedStorage:WaitForChild("RuneConfig"))
local InventoryManager = require(ServerScriptService.ServerModules:WaitForChild("InventoryManager"))

local function ensureRemoteEvent(name)
	local event = ReplicatedStorage:FindFirstChild(name)
	if not event then
		event = Instance.new("RemoteEvent")
		event.Name = name
		event.Parent = ReplicatedStorage
	end
	return event
end

local CastSkillEvent = ensureRemoteEvent("CastSkillEvent")
local EquipSkillEvent = ensureRemoteEvent("EquipSkillEvent")
local SyncCooldownEvent = ensureRemoteEvent("SyncCooldownEvent")
local SyncRuneEvent = ensureRemoteEvent("SyncRuneEvent")
local SyncRecastEvent = ensureRemoteEvent("SyncRecastEvent")

local playerActiveSkills = {}
local playerItemRunes = {}

Players.PlayerAdded:Connect(function(player)
	playerItemRunes[player.UserId] = {}
	playerActiveSkills[player.UserId] = {}
end)

SyncRuneEvent.OnServerEvent:Connect(function(player, skillItemID, slotIndex, runeID)
	if typeof(skillItemID) ~= "number" then return end
	if typeof(slotIndex) ~= "number" then return end
	if slotIndex ~= math.floor(slotIndex) or slotIndex < 1 or slotIndex > 3 then return end
	if typeof(runeID) ~= "number" then return end
	if not SkillConfig[skillItemID] then return end
	if not RuneConfig[runeID] then return end

	local userId = player.UserId
	if not InventoryManager.OwnsItem(userId, skillItemID) then return end
	if not InventoryManager.OwnsItem(userId, runeID) then return end

	if not playerItemRunes[userId] then playerItemRunes[userId] = {} end
	if not playerItemRunes[userId][skillItemID] then playerItemRunes[userId][skillItemID] = {} end

	playerItemRunes[userId][skillItemID][slotIndex] = runeID

	local activeSkills = playerActiveSkills[userId]
	if activeSkills then
		for _, skillInstance in pairs(activeSkills) do
			if skillInstance.ID == skillItemID then
				skillInstance:EquipRune(slotIndex, runeID)
			end
		end
	end
end)

EquipSkillEvent.OnServerEvent:Connect(function(player, key, skillID)
	if typeof(key) ~= "string" then return end

	local userId = player.UserId
	if not playerActiveSkills[userId] then playerActiveSkills[userId] = {} end

	if skillID == nil then
		playerActiveSkills[userId][key] = nil
		return
	end

	if typeof(skillID) ~= "number" then return end
	if not SkillConfig[skillID] then return end
	if not InventoryManager.OwnsItem(userId, skillID) then return end

	local skillModule = ServerScriptService.ServerModules.Skills:FindFirstChild("Skill_" .. skillID)
	if skillModule then
		local SpecificSkillClass = require(skillModule)
		local newSkillInstance = SpecificSkillClass.new(skillID)

		local savedRunes = playerItemRunes[userId] and playerItemRunes[userId][skillID]
		if savedRunes then
			for slotIdx, runeID in pairs(savedRunes) do
				if runeID ~= nil then
					newSkillInstance:EquipRune(slotIdx, runeID)
				end
			end
		end

		playerActiveSkills[userId][key] = newSkillInstance
	end
end)

CastSkillEvent.OnServerEvent:Connect(function(player, key, targetPos)
	if typeof(key) ~= "string" then return end
	if typeof(targetPos) ~= "Vector3" then return end

	local userId = player.UserId
	local skillInstance = playerActiveSkills[userId] and playerActiveSkills[userId][key]

	if skillInstance then
		if skillInstance:CanCast() then
			if skillInstance.WaitingForRecast then
				-- Recast: detonate, then start real cooldown
				skillInstance:OnCast(player, targetPos)
				skillInstance:StartCooldown()
				local finalCD = skillInstance:GetFinalCD()
				SyncRecastEvent:FireClient(player, skillInstance.ID, false)
				SyncCooldownEvent:FireClient(player, key, finalCD, skillInstance.ID)
			elseif skillInstance.IsRecastable then
				-- First cast of recastable skill: create zone, don't start cooldown
				skillInstance:OnCast(player, targetPos)
				skillInstance.WaitingForRecast = true
				SyncRecastEvent:FireClient(player, skillInstance.ID, true)
			else
				-- Normal skill: cast and start cooldown
				skillInstance:OnCast(player, targetPos)
				skillInstance:StartCooldown()
				local finalCD = skillInstance:GetFinalCD()
				SyncCooldownEvent:FireClient(player, key, finalCD, skillInstance.ID)
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	playerActiveSkills[player.UserId] = nil
	playerItemRunes[player.UserId] = nil
end)