local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local EquipSkillEvent = ReplicatedStorage:WaitForChild("EquipSkillEvent", 10)
local SyncRuneEvent = ReplicatedStorage:WaitForChild("SyncRuneEvent", 10)
local SkillConfig = require(ReplicatedStorage:WaitForChild("SkillConfig"))
local RuneConfig = require(ReplicatedStorage:WaitForChild("RuneConfig"))
local ItemConfig = require(ReplicatedStorage:WaitForChild("ItemConfig"))

local CooldownManager = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("CooldownManager"))
local Theme = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("UITheme"))

local UI_DragDrop = {}
local player = game.Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local mouse = player:GetMouse()

local localSocketedRunes = {}
local isDragging = false
local dragGhost = nil
local originSlot = nil
local dragItemCard = nil

local HUD, Backpack, Manager
local currentDetailSkillID = nil
local lastClickTime = 0

-- Tooltip system
local tooltipFrame = nil
local tooltipHoverThread = nil
local SyncEquipEvent = ReplicatedStorage:WaitForChild("SyncEquipEvent", 10)

local STAT_DISPLAY_NAMES = {
	MaxHP = "HP", MaxMP = "MP", ATK = "ATK", AP = "AP",
	DEF = "DEF", MR = "MR", MoveSpeed = "Speed", AtkSpeed = "AtkSpd",
	CritRate = "Crit%", CritDmg = "CritDmg", CDR = "CDR",
	HpRegen = "HP/s", MpRegen = "MP/s", Penetration = "Pen",
}

local function getItemTooltipInfo(itemID)
	if not itemID then return nil end

	-- Skill (1000-1999)
	if itemID >= 1000 and itemID < 2000 then
		local cfg = SkillConfig[itemID]
		if not cfg then return nil end
		local lines = {}
		table.insert(lines, {text = cfg.UIName or cfg.Name, color = Color3.fromRGB(255, 220, 80), size = 14, bold = true})
		if cfg.BaseDamage and cfg.BaseDamage > 0 then
			table.insert(lines, {text = "Damage: " .. cfg.BaseDamage, color = Color3.fromRGB(255, 160, 100)})
		end
		if cfg.ShieldAmount and cfg.ShieldAmount > 0 then
			table.insert(lines, {text = "Shield: " .. cfg.ShieldAmount, color = Color3.fromRGB(100, 200, 255)})
		end
		table.insert(lines, {text = "CD: " .. (cfg.BaseCD or 0) .. "s", color = Color3.fromRGB(150, 200, 255)})
		table.insert(lines, {text = "Range: " .. (cfg.BaseRange or 0), color = Color3.fromRGB(180, 180, 180)})
		if cfg.AreaRadius then
			table.insert(lines, {text = "Area: " .. cfg.AreaRadius, color = Color3.fromRGB(180, 180, 180)})
		end
		if cfg.IsUltimate then
			table.insert(lines, {text = "[Ultimate]", color = Color3.fromRGB(255, 100, 100)})
		end
		return lines
	end

	-- Rune (2000-2999)
	if itemID >= 2000 and itemID < 3000 then
		local cfg = RuneConfig[itemID]
		if not cfg then return nil end
		local lines = {}
		table.insert(lines, {text = cfg.Name, color = Color3.fromRGB(180, 140, 255), size = 14, bold = true})
		local typeNames = {CDR = "Cooldown Reduction", MultiShot = "Multi-cast", DamageBoost = "Damage Boost"}
		table.insert(lines, {text = "Type: " .. (typeNames[cfg.Type] or cfg.Type), color = Color3.fromRGB(200, 200, 200)})
		if cfg.Type == "CDR" then
			table.insert(lines, {text = "-" .. math.floor(cfg.Value * 100) .. "% Cooldown", color = Color3.fromRGB(135, 195, 255)})
		elseif cfg.Type == "MultiShot" then
			table.insert(lines, {text = "+" .. cfg.Value .. " Extra casts", color = Color3.fromRGB(255, 180, 100)})
		elseif cfg.Type == "DamageBoost" then
			table.insert(lines, {text = "x" .. cfg.Value .. " Damage", color = Color3.fromRGB(255, 120, 120)})
		end
		return lines
	end

	-- Equipment (3000-3999)
	if itemID >= 3000 and itemID < 4000 then
		local cfg = ItemConfig[itemID]
		if not cfg then return nil end
		local lines = {}
		table.insert(lines, {text = cfg.Name, color = Color3.fromRGB(100, 220, 255), size = 14, bold = true})
		if cfg.Description then
			table.insert(lines, {text = cfg.Description, color = Color3.fromRGB(180, 180, 180)})
		end
		if cfg.Stats then
			for stat, val in pairs(cfg.Stats) do
				local displayName = STAT_DISPLAY_NAMES[stat] or stat
				local valStr
				if stat == "CritRate" then
					valStr = "+" .. math.floor(val * 100) .. "%"
				elseif val == math.floor(val) then
					valStr = "+" .. val
				else
					valStr = "+" .. string.format("%.1f", val)
				end
				table.insert(lines, {text = displayName .. " " .. valStr, color = Color3.fromRGB(120, 230, 120)})
			end
		end
		return lines
	end

	return nil
end

local function hideTooltip()
	if tooltipFrame then tooltipFrame:Destroy() tooltipFrame = nil end
	if tooltipHoverThread then pcall(task.cancel, tooltipHoverThread) tooltipHoverThread = nil end
end

local function getTooltipScreen()
	local ts = playerGui:FindFirstChild("TooltipScreen")
	if not ts then
		ts = Instance.new("ScreenGui")
		ts.Name = "TooltipScreen"
		ts.DisplayOrder = 200
		ts.ResetOnSpawn = false
		ts.Parent = playerGui
		Theme.autoScale(ts)
	end
	return ts
end

local function showTooltip(screenX, screenY, itemID)
	hideTooltip()

	local lines = getItemTooltipInfo(itemID)
	if not lines or #lines == 0 then return end

	local ts = getTooltipScreen()
	local uiScale = ts:FindFirstChildOfClass("UIScale")
	local scale = uiScale and uiScale.Scale or 1

	tooltipFrame = Instance.new("Frame")
	tooltipFrame.Name = "Tooltip"
	tooltipFrame.BackgroundColor3 = Color3.fromRGB(18, 22, 34)
	tooltipFrame.BackgroundTransparency = 0.06
	tooltipFrame.BorderSizePixel = 0
	tooltipFrame.AutomaticSize = Enum.AutomaticSize.Y
	tooltipFrame.Size = UDim2.new(0, 180, 0, 0)
	tooltipFrame.Position = UDim2.new(0, screenX / scale + 12, 0, screenY / scale - 10)
	tooltipFrame.Parent = ts
	Theme.corner(tooltipFrame, 8)
	Theme.stroke(tooltipFrame, 1, Color3.fromRGB(60, 68, 90), 0.3)

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 8)
	pad.PaddingBottom = UDim.new(0, 8)
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	pad.Parent = tooltipFrame

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 3)
	layout.Parent = tooltipFrame

	for i, line in ipairs(lines) do
		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, 0, 0, (line.size or 11) + 4)
		label.BackgroundTransparency = 1
		label.Text = line.text
		label.TextColor3 = line.color or Color3.fromRGB(200, 200, 200)
		label.Font = line.bold and Enum.Font.GothamBold or Enum.Font.Gotham
		label.TextSize = line.size or 11
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextWrapped = true
		label.AutomaticSize = Enum.AutomaticSize.Y
		label.LayoutOrder = i
		label.Parent = tooltipFrame
	end
end

local function CleanupDrag()
	if dragItemCard then dragItemCard.ImageTransparency = 0 end
	if dragGhost then dragGhost:Destroy() dragGhost = nil end
	isDragging = false
	originSlot = nil
end

local function IsSkillOnCooldown(slotName)
	if not slotName then return false end
	local key = slotName:gsub("ActionSlot_", "")
	local skillID = HUD and HUD.GetSkillIDInSlot and HUD.GetSkillIDInSlot(key)
	if skillID then
		return CooldownManager.IsOnCooldown(skillID)
	end
	return false
end

local function OpenDetailWindow(itemID, iconURL)
	if not HUD or not HUD.DetailWindow or not HUD.DetailName then
		warn("[UI_DragDrop] HUD components not initialized")
		return
	end

	currentDetailSkillID = itemID
	if not localSocketedRunes[itemID] then localSocketedRunes[itemID] = {} end

	local configData = SkillConfig[itemID]
	if configData then
		HUD.DetailName.Text = configData.UIName or configData.Name or "Unknown"
		HUD.DetailDesc.Text = "Base Damage: " .. (configData.BaseDamage or 0) .. "\nCooldown: " .. (configData.BaseCD or 0) .. "s"
		if HUD.DetailIcon then HUD.DetailIcon.Image = iconURL end
	end

	if HUD.DetailSockets then
		for i = 1, 3 do
			local socketFrame = HUD.DetailSockets[i]
			if socketFrame then
				for _, child in ipairs(socketFrame:GetChildren()) do
					if child.Name == "ItemCard" then child:Destroy() end
				end
				local runeData = localSocketedRunes[itemID][i]
				if runeData then
					UI_DragDrop.CreateItemCard(socketFrame, runeData.id, runeData.icon, true)
				end
			end
		end
	end

	HUD.DetailWindow.Visible = true
end

local function SyncSlotToServer(slot, card)
	if not slot then return end
	if slot.Name:match("ActionSlot_") then
		local key = slot.Name:gsub("ActionSlot_", "")
		local itemID = card and card:GetAttribute("ItemID") or nil
		EquipSkillEvent:FireServer(key, itemID)
	elseif slot.Name:match("EquipSlot_") then
		local key = slot.Name
		local itemID = card and card:GetAttribute("ItemID") or nil
		if SyncEquipEvent then
			SyncEquipEvent:FireServer(key, itemID)
		end
	end
end

function UI_DragDrop.CreateItemCard(parentSlot, itemID, iconURL, isSilent)
	if not parentSlot then return end

	for _, child in ipairs(parentSlot:GetChildren()) do
		if child.Name == "ItemCard" then child:Destroy() end
	end

	local card = Instance.new("ImageLabel")
	card.Name = "ItemCard"
	card.Size = UDim2.new(1, -6, 1, -6)
	card.Position = UDim2.new(0, 3, 0, 3)
	card.BackgroundTransparency = 1
	card.Image = iconURL
	card.ZIndex = 5
	card:SetAttribute("ItemID", itemID)
	card.Active = true  -- Required for MouseEnter/MouseLeave events
	card.Parent = parentSlot
	Theme.corner(card, 8)

	-- Hover tooltip (0.8s delay)
	card.MouseEnter:Connect(function()
		hideTooltip()
		tooltipHoverThread = task.delay(0.8, function()
			showTooltip(mouse.X, mouse.Y, itemID)
			tooltipHoverThread = nil
		end)
	end)

	card.MouseLeave:Connect(function()
		hideTooltip()
	end)

	card.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			hideTooltip()
			if Backpack and not Backpack.BackpackScreen.Enabled then return end

			if parentSlot.Name:match("ActionSlot_") then
				if IsSkillOnCooldown(parentSlot.Name) then
					if Manager then Manager.ShowWarning("Skill on cooldown!") end
					return
				end
			end

			-- Double-click opens detail window
			local now = os.clock()
			if now - lastClickTime < 0.3 then
				if itemID >= 1000 and itemID < 2000 then
					CleanupDrag()
					OpenDetailWindow(itemID, iconURL)
					return
				end
			end
			lastClickTime = now

			-- Start drag
			isDragging = true
			originSlot = card.Parent
			dragItemCard = card
			card.ImageTransparency = 0.6

			local ds = playerGui:FindFirstChild("DragScreen")
			if ds then
				dragGhost = Instance.new("ImageLabel")
				dragGhost.Size = UDim2.new(0, 50, 0, 50)
				dragGhost.AnchorPoint = Vector2.new(0.5, 0.5)
				dragGhost.BackgroundTransparency = 1
				dragGhost.Image = iconURL
				dragGhost.ZIndex = 100
				dragGhost.Parent = ds
				local uiScale = ds:FindFirstChildOfClass("UIScale")
				local scale = uiScale and uiScale.Scale or 1
				dragGhost.Position = UDim2.new(0, mouse.X / scale, 0, mouse.Y / scale)
				Theme.corner(dragGhost, 10)
			end
		end
	end)
end

function UI_DragDrop.Init(hudModule, backpackModule, uiManager)
	HUD, Backpack, Manager = hudModule, backpackModule, uiManager

	local dragScreen = playerGui:FindFirstChild("DragScreen")
	if not dragScreen then
		dragScreen = Instance.new("ScreenGui")
		dragScreen.Name = "DragScreen"
		dragScreen.DisplayOrder = 100
		dragScreen.Parent = playerGui
		Theme.autoScale(dragScreen)
	end

	local function getDragScale()
		local uiScale = dragScreen:FindFirstChildOfClass("UIScale")
		return uiScale and uiScale.Scale or 1
	end

	UserInputService.InputChanged:Connect(function(input)
		if isDragging and dragGhost and input.UserInputType == Enum.UserInputType.MouseMovement then
			local scale = getDragScale()
			dragGhost.Position = UDim2.new(0, mouse.X / scale, 0, mouse.Y / scale)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 and isDragging then
			local elementsUnderMouse = playerGui:GetGuiObjectsAtPosition(mouse.X, mouse.Y)
			local targetSlot = nil
			for _, element in ipairs(elementsUnderMouse) do
				if element.Name:match("Slot") then targetSlot = element break end
			end

			if targetSlot and targetSlot ~= originSlot then
				local itemID = dragItemCard:GetAttribute("ItemID")
				local slotName = targetSlot.Name
				local canDrop = false

				if slotName:match("InvSlot") then
					canDrop = true
					-- Unequip rune if dragging from socket
					if originSlot.Name:match("SocketSlot") and currentDetailSkillID then
						local idx = tonumber(originSlot.Name:match("%d+"))
						localSocketedRunes[currentDetailSkillID][idx] = nil
						SyncRuneEvent:FireServer(currentDetailSkillID, idx, nil)
					end
				elseif slotName:match("SocketSlot_") then
					-- Rune slots: only accept runes (2000-2999)
					if itemID >= 2000 and itemID < 3000 then
						if currentDetailSkillID then
							local idx = tonumber(slotName:match("%d+"))
							localSocketedRunes[currentDetailSkillID] = localSocketedRunes[currentDetailSkillID] or {}
							localSocketedRunes[currentDetailSkillID][idx] = {id = itemID, icon = dragItemCard.Image}
							SyncRuneEvent:FireServer(currentDetailSkillID, idx, itemID)
							canDrop = true
						end
					else
						if Manager then Manager.ShowWarning("Runes only!") end
					end
				elseif slotName:match("ActionSlot_") then
					-- Skill slots: only accept skills (1000-1999)
					if itemID >= 1000 and itemID < 2000 then
						if IsSkillOnCooldown(slotName) then
							if Manager then Manager.ShowWarning("Slot on cooldown!") end
						else
							canDrop = true
						end
					else
						if Manager then Manager.ShowWarning("Skills only!") end
					end
				elseif slotName:match("EquipSlot_") then
					-- Equipment slots: only accept equipment (3000-3999)
					if itemID >= 3000 and itemID < 4000 then
						canDrop = true
					else
						if Manager then Manager.ShowWarning("Equipment only!") end
					end
				end

				if canDrop then
					local existingCard = targetSlot:FindFirstChild("ItemCard")
					if existingCard then existingCard.Parent = originSlot end
					dragItemCard.Parent = targetSlot
					SyncSlotToServer(originSlot, existingCard)
					SyncSlotToServer(targetSlot, dragItemCard)
				end
			end

			CleanupDrag()
		end
	end)

	-- Test items (1xxx=skill, 2xxx=rune, 3xxx=equipment)
	local inv1 = Backpack.InventoryContainer:WaitForChild("InvSlot_1")
	local inv2 = Backpack.InventoryContainer:WaitForChild("InvSlot_2")
	local inv3 = Backpack.InventoryContainer:WaitForChild("InvSlot_3")
	local inv4 = Backpack.InventoryContainer:WaitForChild("InvSlot_4")
	local inv5 = Backpack.InventoryContainer:WaitForChild("InvSlot_5")
	local inv6 = Backpack.InventoryContainer:WaitForChild("InvSlot_6")
	local inv7 = Backpack.InventoryContainer:WaitForChild("InvSlot_7")
	local inv8 = Backpack.InventoryContainer:WaitForChild("InvSlot_8")
	local inv9 = Backpack.InventoryContainer:WaitForChild("InvSlot_9")
	local inv10 = Backpack.InventoryContainer:WaitForChild("InvSlot_10")
	local inv11 = Backpack.InventoryContainer:WaitForChild("InvSlot_11")
	local inv12 = Backpack.InventoryContainer:WaitForChild("InvSlot_12")
	local inv13 = Backpack.InventoryContainer:WaitForChild("InvSlot_13")
	local inv14 = Backpack.InventoryContainer:WaitForChild("InvSlot_14")
	local inv15 = Backpack.InventoryContainer:WaitForChild("InvSlot_15")
	local inv16 = Backpack.InventoryContainer:WaitForChild("InvSlot_16")
	local inv17 = Backpack.InventoryContainer:WaitForChild("InvSlot_17")
	local inv18 = Backpack.InventoryContainer:WaitForChild("InvSlot_18")
	local inv19 = Backpack.InventoryContainer:WaitForChild("InvSlot_19")
	local inv20 = Backpack.InventoryContainer:WaitForChild("InvSlot_20")
	local inv21 = Backpack.InventoryContainer:WaitForChild("InvSlot_21")

	UI_DragDrop.CreateItemCard(inv1, 1001, SkillConfig[1001].Icon, true)
	UI_DragDrop.CreateItemCard(inv2, 1002, SkillConfig[1002].Icon, true)
	UI_DragDrop.CreateItemCard(inv3, 1003, SkillConfig[1003].Icon, true)
	UI_DragDrop.CreateItemCard(inv4, 1004, SkillConfig[1004].Icon, true)
	UI_DragDrop.CreateItemCard(inv5, 1005, SkillConfig[1005].Icon, true)
	-- 安琪拉技能
	UI_DragDrop.CreateItemCard(inv6, 1006, SkillConfig[1006].Icon, true)
	UI_DragDrop.CreateItemCard(inv7, 1007, SkillConfig[1007].Icon, true)
	UI_DragDrop.CreateItemCard(inv8, 1008, SkillConfig[1008].Icon, true)
	-- 后羿技能
	UI_DragDrop.CreateItemCard(inv9, 1009, SkillConfig[1009].Icon, true)
	UI_DragDrop.CreateItemCard(inv10, 1010, SkillConfig[1010].Icon, true)
	UI_DragDrop.CreateItemCard(inv11, 1011, SkillConfig[1011].Icon, true)
	-- 廉颇技能
	UI_DragDrop.CreateItemCard(inv12, 1012, SkillConfig[1012].Icon, true)
	UI_DragDrop.CreateItemCard(inv13, 1013, SkillConfig[1013].Icon, true)
	UI_DragDrop.CreateItemCard(inv14, 1014, SkillConfig[1014].Icon, true)
	-- 廉颇终极特写
	local inv22 = Backpack.InventoryContainer:WaitForChild("InvSlot_22")
	UI_DragDrop.CreateItemCard(inv22, 1015, SkillConfig[1015].Icon, true)
	-- 符文
	UI_DragDrop.CreateItemCard(inv15, 2001, "rbxthumb://type=Asset&id=1081577782&w=150&h=150", true)
	UI_DragDrop.CreateItemCard(inv16, 2002, "rbxthumb://type=Asset&id=1081577782&w=150&h=150", true)
	UI_DragDrop.CreateItemCard(inv17, 2003, "rbxthumb://type=Asset&id=1081577782&w=150&h=150", true)
	-- 装备
	local defaultEquipIcon = "rbxthumb://type=Asset&id=258074092&w=150&h=150"
	UI_DragDrop.CreateItemCard(inv18, 3001, ItemConfig[3001] and ItemConfig[3001].Icon or defaultEquipIcon, true)
	UI_DragDrop.CreateItemCard(inv19, 3002, ItemConfig[3002] and ItemConfig[3002].Icon or defaultEquipIcon, true)
	UI_DragDrop.CreateItemCard(inv20, 3003, ItemConfig[3003] and ItemConfig[3003].Icon or defaultEquipIcon, true)
	UI_DragDrop.CreateItemCard(inv21, 3004, ItemConfig[3004] and ItemConfig[3004].Icon or defaultEquipIcon, true)
end

return UI_DragDrop