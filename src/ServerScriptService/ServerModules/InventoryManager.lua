local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SkillConfig = require(ReplicatedStorage:WaitForChild("SkillConfig"))
local RuneConfig = require(ReplicatedStorage:WaitForChild("RuneConfig"))
local ItemConfig = require(ReplicatedStorage:WaitForChild("ItemConfig"))

local InventoryManager = {}

local playerInventories = {} -- [userId] = { [itemID] = true }

local function buildDefaultInventory()
	local inv = {}
	for id in pairs(SkillConfig) do
		inv[id] = true
	end
	for id in pairs(RuneConfig) do
		inv[id] = true
	end
	for id in pairs(ItemConfig) do
		inv[id] = true
	end
	return inv
end

function InventoryManager.Init()
	Players.PlayerAdded:Connect(function(player)
		playerInventories[player.UserId] = buildDefaultInventory()
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		if not playerInventories[player.UserId] then
			playerInventories[player.UserId] = buildDefaultInventory()
		end
	end

	Players.PlayerRemoving:Connect(function(player)
		playerInventories[player.UserId] = nil
	end)
end

function InventoryManager.OwnsItem(userId: number, itemID: number): boolean
	local inv = playerInventories[userId]
	return inv ~= nil and inv[itemID] == true
end

function InventoryManager.GiveItem(userId: number, itemID: number)
	if not playerInventories[userId] then
		playerInventories[userId] = {}
	end
	playerInventories[userId][itemID] = true
end

function InventoryManager.RemoveItem(userId: number, itemID: number)
	if playerInventories[userId] then
		playerInventories[userId][itemID] = nil
	end
end

return InventoryManager