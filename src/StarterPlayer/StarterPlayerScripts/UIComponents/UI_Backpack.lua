local UI_Backpack = {}
local player = game.Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local Theme = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("UITheme"))

UI_Backpack.BackpackScreen = nil
UI_Backpack.InventoryContainer = nil
local bgBlur = nil

function UI_Backpack.Init()
	bgBlur = Instance.new("BlurEffect")
	bgBlur.Size = 0
	bgBlur.Name = "BackpackBlur"
	bgBlur.Parent = Lighting

	UI_Backpack.BackpackScreen = Instance.new("ScreenGui")
	UI_Backpack.BackpackScreen.Name = "BackpackScreen"
	UI_Backpack.BackpackScreen.ResetOnSpawn = false
	UI_Backpack.BackpackScreen.DisplayOrder = 30
	UI_Backpack.BackpackScreen.Enabled = false
	UI_Backpack.BackpackScreen.IgnoreGuiInset = true
	UI_Backpack.BackpackScreen.Parent = playerGui
	Theme.autoScale(UI_Backpack.BackpackScreen)

	-- Soft gradient overlay (top darker, bottom lighter for depth)
	local overlay = Instance.new("Frame")
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.BackgroundColor3 = Color3.fromRGB(12, 14, 22)
	overlay.BackgroundTransparency = 0.25
	overlay.BorderSizePixel = 0
	overlay.Parent = UI_Backpack.BackpackScreen

	local overlayGrad = Instance.new("UIGradient")
	overlayGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(8, 10, 18)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(18, 22, 35)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 12, 20)),
	})
	overlayGrad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(0.45, 0.35),
		NumberSequenceKeypoint.new(0.55, 0.35),
		NumberSequenceKeypoint.new(1, 0.2),
	})
	overlayGrad.Rotation = 90
	overlayGrad.Parent = overlay

	-- ==========================
	-- Main panel (dark style, matching HUD)
	-- ==========================
	local bpMain = Instance.new("Frame")
	bpMain.Size = UDim2.new(0, 640, 0, 440)
	bpMain.Position = UDim2.new(0.5, -320, 0.5, -220)
	bpMain.BackgroundColor3 = Color3.fromRGB(22, 26, 38)
	bpMain.BackgroundTransparency = 0.08
	bpMain.BorderSizePixel = 0
	bpMain.Parent = UI_Backpack.BackpackScreen
	Theme.corner(bpMain, 16)
	Theme.shadow(bpMain, 8, 36)
	Theme.gradient(bpMain, Color3.fromRGB(30, 35, 50), Color3.fromRGB(18, 22, 32))

	-- Subtle accent line at top
	local accentLine = Instance.new("Frame")
	accentLine.Size = UDim2.new(0.3, 0, 0, 2)
	accentLine.Position = UDim2.new(0.35, 0, 0, 0)
	accentLine.BackgroundColor3 = Theme.ACCENT
	accentLine.BackgroundTransparency = 0.5
	accentLine.BorderSizePixel = 0
	accentLine.ZIndex = 3
	accentLine.Parent = bpMain
	Theme.corner(accentLine, 1)

	-- Title
	local titleText = Instance.new("TextLabel")
	titleText.Size = UDim2.new(1, -30, 0, 44)
	titleText.Position = UDim2.new(0, 22, 0, 0)
	titleText.Text = "Backpack"
	titleText.TextColor3 = Theme.TEXT_WHITE
	titleText.Font = Enum.Font.GothamBold
	titleText.TextSize = 17
	titleText.TextXAlignment = Enum.TextXAlignment.Left
	titleText.BackgroundTransparency = 1
	titleText.Parent = bpMain

	local titleDivider = Instance.new("Frame")
	titleDivider.Size = UDim2.new(1, -36, 0, 1)
	titleDivider.Position = UDim2.new(0, 18, 0, 44)
	titleDivider.BackgroundColor3 = Color3.fromRGB(50, 56, 72)
	titleDivider.BackgroundTransparency = 0.3
	titleDivider.BorderSizePixel = 0
	titleDivider.Parent = bpMain

	-- ==========================
	-- Left: Character preview + Equipment
	-- ==========================
	local bpLeft = Instance.new("Frame")
	bpLeft.Size = UDim2.new(0.36, 0, 1, -56)
	bpLeft.Position = UDim2.new(0, 14, 0, 52)
	bpLeft.BackgroundTransparency = 1
	bpLeft.Parent = bpMain

	-- Character preview with subtle bg
	local charPreview = Instance.new("Frame")
	charPreview.Size = UDim2.new(1, -4, 0, 200)
	charPreview.Position = UDim2.new(0, 2, 0, 0)
	charPreview.BackgroundColor3 = Color3.fromRGB(28, 32, 46)
	charPreview.BackgroundTransparency = 0.2
	charPreview.BorderSizePixel = 0
	charPreview.Parent = bpLeft
	Theme.corner(charPreview, 12)
	Theme.stroke(charPreview, 1, Color3.fromRGB(50, 56, 72), 0.4)

	local previewGlow = Instance.new("Frame")
	previewGlow.Size = UDim2.new(1, 0, 0.25, 0)
	previewGlow.Position = UDim2.new(0, 0, 0.75, 0)
	previewGlow.BackgroundColor3 = Theme.ACCENT
	previewGlow.BackgroundTransparency = 0.88
	previewGlow.BorderSizePixel = 0
	previewGlow.Parent = charPreview
	Theme.corner(previewGlow, 12)

	local previewImage = Instance.new("ImageLabel")
	previewImage.Size = UDim2.new(0.85, 0, 0.85, 0)
	previewImage.Position = UDim2.new(0.075, 0, 0.05, 0)
	previewImage.BackgroundTransparency = 1
	previewImage.Image = "rbxthumb://type=Avatar&id=" .. player.UserId .. "&w=420&h=420"
	previewImage.ZIndex = 2
	previewImage.Parent = charPreview

	-- Equipment section
	local equipLabel = Instance.new("TextLabel")
	equipLabel.Size = UDim2.new(1, 0, 0, 18)
	equipLabel.Position = UDim2.new(0, 4, 0, 208)
	equipLabel.Text = "Equipment"
	equipLabel.TextColor3 = Theme.TEXT_LIGHT
	equipLabel.Font = Enum.Font.GothamMedium
	equipLabel.TextSize = 11
	equipLabel.TextXAlignment = Enum.TextXAlignment.Left
	equipLabel.BackgroundTransparency = 1
	equipLabel.Parent = bpLeft

	local equipGrid = Instance.new("Frame")
	equipGrid.Size = UDim2.new(1, -4, 0, 120)
	equipGrid.Position = UDim2.new(0, 2, 0, 230)
	equipGrid.BackgroundTransparency = 1
	equipGrid.Parent = bpLeft

	local equipLayout = Instance.new("UIGridLayout")
	equipLayout.CellSize = UDim2.new(0, 52, 0, 52)
	equipLayout.CellPadding = UDim2.new(0, 8, 0, 8)
	equipLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	equipLayout.FillDirectionMaxCells = 3
	equipLayout.Parent = equipGrid

	for i = 1, 6 do
		local slot = Theme.slot(equipGrid)
		slot.Name = "EquipSlot_Equip " .. i

		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, 0, 1, 0)
		label.BackgroundTransparency = 1
		label.TextColor3 = Color3.fromRGB(70, 78, 100)
		label.Text = "+"
		label.TextSize = 18
		label.Font = Enum.Font.GothamMedium
		label.ZIndex = 3
		label.Parent = slot
	end

	-- ==========================
	-- Right: Inventory grid
	-- ==========================
	local bpRight = Instance.new("Frame")
	bpRight.Size = UDim2.new(0.62, -22, 1, -56)
	bpRight.Position = UDim2.new(0.36, 14, 0, 52)
	bpRight.BackgroundColor3 = Color3.fromRGB(26, 30, 42)
	bpRight.BackgroundTransparency = 0.25
	bpRight.BorderSizePixel = 0
	bpRight.Parent = bpMain
	Theme.corner(bpRight, 12)
	Theme.stroke(bpRight, 1, Color3.fromRGB(45, 50, 65), 0.5)

	local invTitle = Instance.new("TextLabel")
	invTitle.Size = UDim2.new(1, 0, 0, 26)
	invTitle.Position = UDim2.new(0, 12, 0, 4)
	invTitle.Text = "Items"
	invTitle.TextColor3 = Theme.TEXT_LIGHT
	invTitle.Font = Enum.Font.GothamMedium
	invTitle.TextSize = 11
	invTitle.TextXAlignment = Enum.TextXAlignment.Left
	invTitle.BackgroundTransparency = 1
	invTitle.Parent = bpRight

	UI_Backpack.InventoryContainer = Instance.new("Frame")
	UI_Backpack.InventoryContainer.Size = UDim2.new(1, -14, 1, -36)
	UI_Backpack.InventoryContainer.Position = UDim2.new(0, 7, 0, 32)
	UI_Backpack.InventoryContainer.BackgroundTransparency = 1
	UI_Backpack.InventoryContainer.Parent = bpRight

	local inventoryPadding = Instance.new("UIPadding")
	inventoryPadding.PaddingTop = UDim.new(0, 4)
	inventoryPadding.PaddingLeft = UDim.new(0, 4)
	inventoryPadding.Parent = UI_Backpack.InventoryContainer

	local inventoryLayout = Instance.new("UIGridLayout")
	inventoryLayout.CellSize = UDim2.new(0, 52, 0, 52)
	inventoryLayout.CellPadding = UDim2.new(0, 8, 0, 8)
	inventoryLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	inventoryLayout.SortOrder = Enum.SortOrder.LayoutOrder
	inventoryLayout.Parent = UI_Backpack.InventoryContainer

	for i = 1, 24 do
		local slot = Theme.slot(UI_Backpack.InventoryContainer, UDim2.new(0, 52, 0, 52), 8)
		slot.Name = "InvSlot_" .. i
	end
end

function UI_Backpack.Toggle()
	if not UI_Backpack.BackpackScreen then return false end

	local newState = not UI_Backpack.BackpackScreen.Enabled
	UI_Backpack.BackpackScreen.Enabled = newState

	if newState then
		TweenService:Create(bgBlur, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = 32}):Play()
	else
		TweenService:Create(bgBlur, TweenInfo.new(0.25), {Size = 0}):Play()
	end

	return newState
end

return UI_Backpack