local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LevelConfig = require(ReplicatedStorage:WaitForChild("LevelConfig"))

local ServerScriptService = game:GetService("ServerScriptService")
local ItemConfig = require(ReplicatedStorage:WaitForChild("ItemConfig"))
local InventoryManager = require(ServerScriptService.ServerModules:WaitForChild("InventoryManager"))

local StatsManager = {}

local DEFAULT_STATS = {
	MaxHP = 850,
	HP = 850,
	MaxMP = 500,
	MP = 350,
	ATK = 65,
	AP = 0,
	DEF = 28,
	MR = 30,
	MoveSpeed = 16,
	AtkSpeed = 1.0,
	CritRate = 0,
	CritDmg = 1.5,
	CDR = 0,
	HpRegen = 2,
	MpRegen = 1,
	Penetration = 0,
}

-- Store base stats per player (without level growth)
local playerBaseStats = {}
-- Store equipped items per player { [userId] = { [slotKey] = itemID } }
local playerEquipment = {}

-- Calculate total equipment stat bonuses for a player
local function getEquipmentStats(userId)
	local bonuses = {}
	local equips = playerEquipment[userId]
	if not equips then return bonuses end

	for _, itemID in pairs(equips) do
		local cfg = ItemConfig[itemID]
		if cfg and cfg.Stats then
			for stat, val in pairs(cfg.Stats) do
				bonuses[stat] = (bonuses[stat] or 0) + val
			end
		end
	end
	return bonuses
end

-- Recalculate all stats: base + level + equipment
local function recalculateStats(character)
	local userId = character:GetAttribute("OwnerUserId")
	if not userId then return end

	local base = playerBaseStats[userId] or DEFAULT_STATS
	local level = character:GetAttribute("Level") or 1
	local growth = LevelConfig.GetStatsForLevel(level)
	local equipBonus = getEquipmentStats(userId)

	local humanoid = character:FindFirstChild("Humanoid")
	local oldMaxHP = humanoid and humanoid.MaxHealth or (base.MaxHP or 850)

	-- Apply all stats that have growth or equipment bonuses
	local allStats = {}
	for stat, _ in pairs(DEFAULT_STATS) do
		allStats[stat] = true
	end
	for stat, _ in pairs(equipBonus) do
		allStats[stat] = true
	end

	for stat, _ in pairs(allStats) do
		local baseVal = base[stat] or 0
		local growthVal = growth[stat] or 0
		local equipVal = equipBonus[stat] or 0
		local newVal = baseVal + growthVal + equipVal

		if stat == "HP" then
			-- HP is managed by humanoid, skip direct set
		elseif stat == "MaxHP" then
			if humanoid then
				humanoid.MaxHealth = newVal
			end
			character:SetAttribute("MaxHP", newVal)
		elseif stat == "MoveSpeed" then
			character:SetAttribute(stat, newVal)
			if humanoid then
				humanoid.WalkSpeed = newVal
			end
		else
			character:SetAttribute(stat, newVal)
		end
	end

	-- Adjust current HP proportionally when MaxHP changes
	if humanoid then
		local newMaxHP = humanoid.MaxHealth
		if newMaxHP > oldMaxHP then
			humanoid.Health = humanoid.Health + (newMaxHP - oldMaxHP)
		elseif humanoid.Health > newMaxHP then
			humanoid.Health = newMaxHP
		end
		character:SetAttribute("HP", math.floor(humanoid.Health))
	end

	-- MaxMP adjustment
	local newMaxMP = (base.MaxMP or 500) + (growth.MaxMP or 0) + (equipBonus.MaxMP or 0)
	local oldMaxMP = character:GetAttribute("MaxMP") or newMaxMP
	character:SetAttribute("MaxMP", newMaxMP)
	if newMaxMP > oldMaxMP then
		character:SetAttribute("MP", math.min((character:GetAttribute("MP") or 0) + (newMaxMP - oldMaxMP), newMaxMP))
	end
end

local function initCharacterStats(player, character)
	local userId = player.UserId

	-- Store base stats
	if not playerBaseStats[userId] then
		playerBaseStats[userId] = {}
		for k, v in pairs(DEFAULT_STATS) do
			playerBaseStats[userId][k] = v
		end
	end

	-- Set owner reference
	character:SetAttribute("OwnerUserId", userId)

	-- Init base stats
	for stat, value in pairs(DEFAULT_STATS) do
		character:SetAttribute(stat, value)
	end

	-- Level & XP (persist across respawns via player attributes)
	local totalXP = player:GetAttribute("TotalXP") or 0
	local level = LevelConfig.GetLevelFromXP(totalXP)

	character:SetAttribute("Level", level)
	character:SetAttribute("TotalXP", totalXP)
	player:SetAttribute("TotalXP", totalXP)
	player:SetAttribute("Level", level)

	-- Sync HP with Humanoid
	local humanoid = character:WaitForChild("Humanoid")
	humanoid.MaxHealth = DEFAULT_STATS.MaxHP
	humanoid.Health = DEFAULT_STATS.HP

	-- Hide default Roblox health bar / name
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff

	-- Apply level + equipment stats
	recalculateStats(character)
	-- Full heal on spawn
	humanoid.Health = humanoid.MaxHealth
	character:SetAttribute("HP", math.floor(humanoid.MaxHealth))
	character:SetAttribute("MP", character:GetAttribute("MaxMP"))

	humanoid.HealthChanged:Connect(function(newHealth)
		character:SetAttribute("HP", math.floor(newHealth))
	end)
end

function StatsManager.Init()
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Humanoid")
			initCharacterStats(player, character)
		end)

		if player.Character then
			initCharacterStats(player, player.Character)
		end
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			initCharacterStats(player, player.Character)
		end
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Humanoid")
			initCharacterStats(player, character)
		end)
	end

	Players.PlayerRemoving:Connect(function(player)
		playerBaseStats[player.UserId] = nil
		playerEquipment[player.UserId] = nil
	end)

	-- Listen for equipment changes
	local SyncEquipEvent = ReplicatedStorage:FindFirstChild("SyncEquipEvent")
	if not SyncEquipEvent then
		SyncEquipEvent = Instance.new("RemoteEvent")
		SyncEquipEvent.Name = "SyncEquipEvent"
		SyncEquipEvent.Parent = ReplicatedStorage
	end
	SyncEquipEvent.OnServerEvent:Connect(function(player, slotKey, itemID)
		if typeof(slotKey) ~= "string" then return end

		if itemID == nil then
			StatsManager.UnequipItem(player, slotKey)
			return
		end

		if typeof(itemID) ~= "number" then return end
		if not ItemConfig[itemID] then return end
		if not InventoryManager.OwnsItem(player.UserId, itemID) then return end

		-- Prevent equipping the same item in multiple slots
		local equips = playerEquipment[player.UserId]
		if equips then
			for otherSlot, otherItem in pairs(equips) do
				if otherItem == itemID and otherSlot ~= slotKey then
					return
				end
			end
		end

		StatsManager.EquipItem(player, slotKey, itemID)
	end)
end

function StatsManager.GiveXP(player, amount)
	local character = player.Character
	if not character then return end

	local oldLevel = character:GetAttribute("Level") or 1
	if oldLevel >= LevelConfig.MaxLevel then return end

	local totalXP = (player:GetAttribute("TotalXP") or 0) + amount
	player:SetAttribute("TotalXP", totalXP)
	character:SetAttribute("TotalXP", totalXP)

	local newLevel = LevelConfig.GetLevelFromXP(totalXP)

	if newLevel > oldLevel then
		character:SetAttribute("Level", newLevel)
		player:SetAttribute("Level", newLevel)
		recalculateStats(character)

		-- Level up VFX notification
		local SyncLevelEvent = ReplicatedStorage:FindFirstChild("SyncLevelEvent")
		if SyncLevelEvent then
			SyncLevelEvent:FireClient(player, newLevel, totalXP)
		end
	end
end

function StatsManager.EquipItem(player, slotKey, itemID)
	local userId = player.UserId
	if not playerEquipment[userId] then playerEquipment[userId] = {} end

	playerEquipment[userId][slotKey] = itemID

	local character = player.Character
	if character then
		recalculateStats(character)
	end
end

function StatsManager.UnequipItem(player, slotKey)
	local userId = player.UserId
	if playerEquipment[userId] then
		playerEquipment[userId][slotKey] = nil
	end

	local character = player.Character
	if character then
		recalculateStats(character)
	end
end

function StatsManager.GetStat(character, statName)
	return character:GetAttribute(statName)
end

function StatsManager.SetStat(character, statName, value)
	character:SetAttribute(statName, value)
	if statName == "MaxHP" then
		local humanoid = character:FindFirstChild("Humanoid")
		if humanoid then humanoid.MaxHealth = value end
	elseif statName == "HP" then
		local humanoid = character:FindFirstChild("Humanoid")
		if humanoid then humanoid.Health = value end
	end
end

return StatsManager