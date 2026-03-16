local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local SkillRegistry = require(ReplicatedStorage:WaitForChild("SkillRegistry"))
local RuneConfig = require(ReplicatedStorage:WaitForChild("RuneConfig"))
local InventoryManager = require(ServerScriptService.ServerModules:WaitForChild("InventoryManager"))
local EnergySystem = require(ServerScriptService.ServerModules:WaitForChild("EnergySystem"))

-- 启动时构建技能模块查找表（替代 FindFirstChild）
local SkillModuleMap = {}
for _, mod in ipairs(ServerScriptService.ServerModules.Skills:GetChildren()) do
	if mod:IsA("ModuleScript") then
		local id = tonumber(mod.Name:match("Skill_(%d+)"))
		if id then
			SkillModuleMap[id] = mod
		end
	end
end

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
	if not SkillRegistry[skillItemID] then return end
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
	if not SkillRegistry[skillID] then return end
	if not InventoryManager.OwnsItem(userId, skillID) then return end

	local skillModule = SkillModuleMap[skillID]
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
		if skillInstance:CanCast(player) then
			-- 能量检查: 从 SkillRegistry 读取 EnergyCost
			local skillData = SkillRegistry[skillInstance.ID]
			local energyCost = skillData and skillData.EnergyCost or 0
			-- REQ-009: 训练场无消耗模式
			local isNoCost = shared.TrainingManager and shared.TrainingManager.IsNoCost(player)
			if not isNoCost and energyCost > 0 and not EnergySystem:CanCast(player, energyCost) then
				return -- 能量不足，拒绝施法
			end

			if skillInstance.WaitingForRecast then
				-- Recast: detonate, then start real cooldown (不重复扣能量)
				skillInstance:OnCast(player, targetPos)
				skillInstance:StartCooldown(player)
				local finalCD = skillInstance:GetFinalCD()
				SyncRecastEvent:FireClient(player, skillInstance.ID, false)
				-- REQ-009: 无CD时发送CD=0
				if shared.TrainingManager and shared.TrainingManager.IsNoCooldown(player) then
					SyncCooldownEvent:FireClient(player, key, 0, skillInstance.ID)
				else
					SyncCooldownEvent:FireClient(player, key, finalCD, skillInstance.ID)
				end
			elseif skillInstance.IsRecastable then
				-- First cast of recastable skill: create zone, don't start cooldown
				skillInstance:OnCast(player, targetPos)
				-- 扣除能量 (首次释放时扣)
				if not isNoCost and energyCost > 0 then
					EnergySystem:ConsumeEnergy(player, energyCost)
				end
				skillInstance.WaitingForRecast = true
				SyncRecastEvent:FireClient(player, skillInstance.ID, true)
			else
				-- Normal skill: cast and start cooldown
				skillInstance:OnCast(player, targetPos)
				-- 扣除能量
				if not isNoCost and energyCost > 0 then
					EnergySystem:ConsumeEnergy(player, energyCost)
				end
				skillInstance:StartCooldown(player)
				local finalCD = skillInstance:GetFinalCD()
				-- REQ-009: 无CD时发送CD=0
				if shared.TrainingManager and shared.TrainingManager.IsNoCooldown(player) then
					SyncCooldownEvent:FireClient(player, key, 0, skillInstance.ID)
				else
					SyncCooldownEvent:FireClient(player, key, finalCD, skillInstance.ID)
				end
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	playerActiveSkills[player.UserId] = nil
	playerItemRunes[player.UserId] = nil
end)