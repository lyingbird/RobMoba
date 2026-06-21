local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local SkillRegistry = require(ReplicatedStorage:WaitForChild("SkillRegistry"))
local HeroRegistry = require(ReplicatedStorage:WaitForChild("HeroRegistry"))
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

local CAST_ALLOWED_STATES = {
	DUELING = true,
	TRAINING = true,
}

local DIRECTION_AIM_TYPES = {
	line = true,
	rect = true,
	channel = true,
	directional = true,
}

local function isFiniteNumber(value)
	return typeof(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function isFiniteVector3(value)
	return typeof(value) == "Vector3"
		and isFiniteNumber(value.X)
		and isFiniteNumber(value.Y)
		and isFiniteNumber(value.Z)
end

local function getPlayerState(player)
	if shared.LobbyManager then
		return shared.LobbyManager.GetPlayerState(player)
	end
	return "LOBBY"
end

local function getPlayerHeroData(player)
	if not shared.LobbyManager then return nil, nil end
	local heroId = shared.LobbyManager.GetPlayerHero(player)
	if not heroId then return nil, nil end
	return heroId, HeroRegistry[heroId]
end

local function getHeroSkillId(player, key)
	local _, heroData = getPlayerHeroData(player)
	if not heroData or not heroData.Skills then return nil end
	return heroData.Skills[key]
end

local function getLiveCharacterParts(player)
	local character = player.Character
	if not character then return nil, nil, nil end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not rootPart or humanoid.Health <= 0 then
		return nil, nil, nil
	end

	return character, humanoid, rootPart
end

local function clampTargetToRange(rootPart, targetPos, maxRange)
	local startPos = rootPart.Position
	local flatOffset = Vector3.new(targetPos.X - startPos.X, 0, targetPos.Z - startPos.Z)
	if flatOffset.Magnitude < 0.001 then
		return startPos
	end

	local range = tonumber(maxRange)
	if not range then
		return startPos
	end
	range = math.max(0, range)
	if range <= 0 then
		return startPos
	end
	if flatOffset.Magnitude > range then
		flatOffset = flatOffset.Unit * range
	end

	return Vector3.new(startPos.X + flatOffset.X, startPos.Y, startPos.Z + flatOffset.Z)
end

local function getFacingTarget(rootPart, range)
	local facing = Vector3.new(rootPart.CFrame.LookVector.X, 0, rootPart.CFrame.LookVector.Z)
	if facing.Magnitude < 0.001 then
		facing = Vector3.new(0, 0, -1)
	end

	return rootPart.Position + facing.Unit * math.max(range or 0, 1)
end

local function getCastRule(skillData)
	return skillData and (skillData.CastRule or skillData.castRule)
end

local function getAimType(skillData)
	return skillData and (skillData.aimType or skillData.AimType)
end

local function isDirectionSkill(skillData)
	return getCastRule(skillData) == "Direction" or DIRECTION_AIM_TYPES[getAimType(skillData)] == true
end

local function resolveTargetPosition(rootPart, skillData, paramsOrDirection)
	local range = skillData and (skillData.Range or skillData.BaseRange or skillData.MaxRange) or 0
	local directionSkill = isDirectionSkill(skillData)

	if typeof(paramsOrDirection) == "table" then
		if isFiniteVector3(paramsOrDirection.direction) then
			local direction = Vector3.new(paramsOrDirection.direction.X, 0, paramsOrDirection.direction.Z)
			if direction.Magnitude >= 0.001 then
				return rootPart.Position + direction.Unit * math.max(range, 1)
			end
			return directionSkill and getFacingTarget(rootPart, range) or rootPart.Position
		end

		if isFiniteVector3(paramsOrDirection.position) then
			local targetPos = clampTargetToRange(rootPart, paramsOrDirection.position, range)
			if directionSkill then
				local flatOffset = Vector3.new(targetPos.X - rootPart.Position.X, 0, targetPos.Z - rootPart.Position.Z)
				if flatOffset.Magnitude < 0.001 then
					return getFacingTarget(rootPart, range)
				end
			end
			return targetPos
		end

		return directionSkill and getFacingTarget(rootPart, range) or rootPart.Position
	end

	if isFiniteVector3(paramsOrDirection) then
		local targetPos = clampTargetToRange(rootPart, paramsOrDirection, range)
		if directionSkill then
			local flatOffset = Vector3.new(targetPos.X - rootPart.Position.X, 0, targetPos.Z - rootPart.Position.Z)
			if flatOffset.Magnitude < 0.001 then
				return getFacingTarget(rootPart, range)
			end
		end
		return targetPos
	end

	return directionSkill and getFacingTarget(rootPart, range) or rootPart.Position
end

local function canPlayerCast(player, key, skillInstance)
	local state = getPlayerState(player)
	if not CAST_ALLOWED_STATES[state] then
		return false
	end

	if state == "DUELING" then
		if not shared.DuelManager or not shared.DuelManager.IsPlayerInActiveBattle(player) then
			return false
		end
	end

	local character, humanoid = getLiveCharacterParts(player)
	if not character or not humanoid then
		return false
	end

	if humanoid:GetAttribute("CanCastSkill") == false then
		return false
	end

	if getHeroSkillId(player, key) ~= skillInstance.ID then
		return false
	end

	return true
end

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
		if getHeroSkillId(player, key) then
			playerActiveSkills[userId][key] = nil
		end
		return
	end

	if typeof(skillID) ~= "number" then return end
	if not SkillRegistry[skillID] then return end
	if not InventoryManager.OwnsItem(userId, skillID) then return end

	local expectedSkillID = getHeroSkillId(player, key)
	if not expectedSkillID then
		task.wait(0.1)
		expectedSkillID = getHeroSkillId(player, key)
	end
	if expectedSkillID ~= skillID then return end

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

CastSkillEvent.OnServerEvent:Connect(function(player, key, paramsOrDirection)
	if typeof(key) ~= "string" then return end

	local userId = player.UserId
	local skillInstance = playerActiveSkills[userId] and playerActiveSkills[userId][key]

	if skillInstance then
		if canPlayerCast(player, key, skillInstance) and skillInstance:CanCast(player) then
			local _, _, rootPart = getLiveCharacterParts(player)
			if not rootPart then return end

			-- 能量检查: 从 SkillRegistry 读取 EnergyCost
			local skillData = SkillRegistry[skillInstance.ID]
			local targetPos = resolveTargetPosition(rootPart, skillData, paramsOrDirection)
			local energyCost = skillData and skillData.EnergyCost or 0
			-- REQ-009: 训练场无消耗模式
			local isNoCost = shared.TrainingManager and shared.TrainingManager.IsNoCost(player)
			local isRecast = skillInstance.WaitingForRecast == true
			if not isRecast and not isNoCost and energyCost > 0 and not EnergySystem:CanCast(player, energyCost) then
				return -- 能量不足，拒绝施法
			end

			if isRecast then
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

shared.PlayerSkillManager = {
	ResetCooldown = function(player, key, expectedSkillID)
		if typeof(key) ~= "string" then return false end

		local activeSkills = playerActiveSkills[player.UserId]
		local skillInstance = activeSkills and activeSkills[key]
		if not skillInstance then return false end
		if expectedSkillID and skillInstance.ID ~= expectedSkillID then return false end
		if skillInstance.ResetCooldown then
			skillInstance:ResetCooldown()
		else
			skillInstance.LastCastTime = 0
		end
		return true
	end,
}

Players.PlayerRemoving:Connect(function(player)
	playerActiveSkills[player.UserId] = nil
	playerItemRunes[player.UserId] = nil
end)
