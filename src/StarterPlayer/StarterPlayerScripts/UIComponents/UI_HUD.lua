local UI_HUD = {}
local player = game.Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("UITheme"))
local CooldownManager = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("CooldownManager"))

UI_HUD.SkillsContainer = nil
UI_HUD.SkillIcons = {}
UI_HUD.DetailWindow = nil
UI_HUD.DetailIcon = nil
UI_HUD.DetailName = nil
UI_HUD.DetailDesc = nil
UI_HUD.DetailSockets = {}

-- Exposed for StatsBinding
UI_HUD.HpFill = nil
UI_HUD.HpText = nil
UI_HUD.MpFill = nil
UI_HUD.MpText = nil
UI_HUD.StatLabels = {}
UI_HUD.LevelText = nil
UI_HUD.XpFill = nil
UI_HUD.XpText = nil

-- PvP UI references
local killScoreFrame = nil
local myKillText = nil
local enemyKillText = nil
local deathOverlay = nil
local deathTimerText = nil
local resultScreen = nil
local resultText = nil

local warningScreen = nil

function UI_HUD.GetSkillIDInSlot(key)
	if not UI_HUD.SkillsContainer then return nil end
	local slot = UI_HUD.SkillsContainer:FindFirstChild("ActionSlot_" .. key)
	local card = slot and slot:FindFirstChild("ItemCard")
	return card and card:GetAttribute("ItemID")
end

local function StartGlobalCDMonitor()
	RunService.RenderStepped:Connect(function()
		if not UI_HUD.SkillsContainer then return end
		for _, key in ipairs({"Q", "W", "E", "R", "D", "F"}) do
			local iconData = UI_HUD.SkillIcons[key]
			if not iconData then continue end

			local currentSkillID = UI_HUD.GetSkillIDInSlot(key)
			if not currentSkillID then
				iconData.CDText.Visible = false
				iconData.Overlay.Visible = false
				continue
			end

			local remaining, totalDuration = CooldownManager.GetRemaining(currentSkillID)
			if remaining > 0 then
				local cooldownRatio = 1
				if totalDuration and totalDuration > 0 then
					cooldownRatio = math.clamp(remaining / totalDuration, 0, 1)
				end

				iconData.CDText.Text = string.format("%.1f", remaining)
				iconData.CDText.Visible = true
				iconData.Overlay.Visible = true
				iconData.Overlay.Size = UDim2.new(1, 0, cooldownRatio, 0)
			else
				iconData.CDText.Visible = false
				iconData.Overlay.Visible = false
			end
		end
	end)
end

function UI_HUD.Init()
	local hudScreen = Instance.new("ScreenGui")
	hudScreen.Name = "MOBA_HUD"
	hudScreen.ResetOnSpawn = false
	hudScreen.DisplayOrder = 10
	hudScreen.Parent = playerGui
	Theme.autoScale(hudScreen)

	local popupScreen = Instance.new("ScreenGui")
	popupScreen.Name = "PopupScreen"
	popupScreen.DisplayOrder = 50
	popupScreen.Parent = playerGui
	Theme.autoScale(popupScreen)

	warningScreen = Instance.new("ScreenGui")
	warningScreen.Name = "WarningScreen"
	warningScreen.DisplayOrder = 100
	warningScreen.Parent = playerGui
	Theme.autoScale(warningScreen)

	-- ==========================
	-- Left panel: Avatar + Bars
	-- ==========================
	-- Layout: all panels bottom-aligned at Y = 1, -12
	-- Left: 210x68, Center: 350x68, Right: 180x168
	-- Gap between panels: 8px
	-- Total width: 210+8+350+8+180 = 756, offset = -378

	local leftPanel = Instance.new("Frame")
	leftPanel.Name = "LeftPanel"
	leftPanel.Size = UDim2.new(0, 210, 0, 68)
	leftPanel.Position = UDim2.new(0.5, -378, 1, -80)
	leftPanel.BackgroundColor3 = Theme.HUD_BG
	leftPanel.BackgroundTransparency = Theme.HUD_TRANSPARENCY
	leftPanel.BorderSizePixel = 0
	leftPanel.Parent = hudScreen
	Theme.corner(leftPanel, 12)
	Theme.shadow(leftPanel, 4, 16)
	Theme.gradient(leftPanel, Color3.fromRGB(28, 33, 48), Theme.HUD_BG)

	-- Round avatar
	local avatarSize = 50
	local avatarFrame = Theme.circleFrame(leftPanel, avatarSize, UDim2.new(0, 9, 0.5, -avatarSize / 2))
	avatarFrame.BackgroundColor3 = Theme.HUD_INNER
	Theme.stroke(avatarFrame, 2, Theme.ACCENT_DIM, 0.25)

	local avatarImage = Instance.new("ImageLabel")
	avatarImage.Size = UDim2.new(1, -4, 1, -4)
	avatarImage.Position = UDim2.new(0, 2, 0, 2)
	avatarImage.Image = "rbxthumb://type=AvatarHeadShot&id=" .. player.UserId .. "&w=150&h=150"
	avatarImage.BackgroundTransparency = 1
	avatarImage.Parent = avatarFrame
	Theme.corner(avatarImage, avatarSize / 2)

	-- Level badge
	local levelBadge = Theme.circleFrame(avatarFrame, 18, UDim2.new(1, -14, 1, -14))
	levelBadge.BackgroundColor3 = Theme.ACCENT
	levelBadge.ZIndex = 5

	local levelText = Instance.new("TextLabel")
	levelText.Size = UDim2.new(1, 0, 1, 0)
	levelText.Text = "1"
	levelText.TextColor3 = Theme.TEXT_WHITE
	levelText.Font = Enum.Font.GothamBold
	levelText.TextSize = 10
	levelText.BackgroundTransparency = 1
	levelText.ZIndex = 6
	levelText.Parent = levelBadge
	UI_HUD.LevelText = levelText

	-- HP bar
	local barX = avatarSize + 18
	local barW = 210 - barX - 10

	local hpBarBg = Instance.new("Frame")
	hpBarBg.Size = UDim2.new(0, barW, 0, 18)
	hpBarBg.Position = UDim2.new(0, barX, 0, 14)
	hpBarBg.BackgroundColor3 = Theme.HP_BG
	hpBarBg.BorderSizePixel = 0
	hpBarBg.Parent = leftPanel
	Theme.corner(hpBarBg, 5)

	UI_HUD.HpFill = Instance.new("Frame")
	UI_HUD.HpFill.Name = "HpFill"
	UI_HUD.HpFill.Size = UDim2.new(1, 0, 1, 0)
	UI_HUD.HpFill.BackgroundColor3 = Theme.HP_GREEN
	UI_HUD.HpFill.BorderSizePixel = 0
	UI_HUD.HpFill.Parent = hpBarBg
	Theme.corner(UI_HUD.HpFill, 5)

	UI_HUD.HpText = Instance.new("TextLabel")
	UI_HUD.HpText.Size = UDim2.new(1, 0, 1, 0)
	UI_HUD.HpText.Text = "--- / ---"
	UI_HUD.HpText.TextColor3 = Theme.TEXT_WHITE
	UI_HUD.HpText.Font = Enum.Font.GothamBold
	UI_HUD.HpText.TextSize = 9
	UI_HUD.HpText.BackgroundTransparency = 1
	UI_HUD.HpText.ZIndex = 3
	UI_HUD.HpText.Parent = hpBarBg

	-- MP bar
	local mpBarBg = Instance.new("Frame")
	mpBarBg.Size = UDim2.new(0, barW, 0, 12)
	mpBarBg.Position = UDim2.new(0, barX, 0, 36)
	mpBarBg.BackgroundColor3 = Theme.MP_BG
	mpBarBg.BorderSizePixel = 0
	mpBarBg.Parent = leftPanel
	Theme.corner(mpBarBg, 4)

	UI_HUD.MpFill = Instance.new("Frame")
	UI_HUD.MpFill.Name = "MpFill"
	UI_HUD.MpFill.Size = UDim2.new(0.7, 0, 1, 0)
	UI_HUD.MpFill.BackgroundColor3 = Theme.MP_BLUE
	UI_HUD.MpFill.BorderSizePixel = 0
	UI_HUD.MpFill.Parent = mpBarBg
	Theme.corner(UI_HUD.MpFill, 4)

	UI_HUD.MpText = Instance.new("TextLabel")
	UI_HUD.MpText.Size = UDim2.new(1, 0, 1, 0)
	UI_HUD.MpText.Text = "--- / ---"
	UI_HUD.MpText.TextColor3 = Theme.TEXT_WHITE
	UI_HUD.MpText.Font = Enum.Font.GothamBold
	UI_HUD.MpText.TextSize = 8
	UI_HUD.MpText.BackgroundTransparency = 1
	UI_HUD.MpText.ZIndex = 3
	UI_HUD.MpText.Parent = mpBarBg

	-- XP bar (thin, under MP bar)
	local xpBarBg = Instance.new("Frame")
	xpBarBg.Size = UDim2.new(0, barW, 0, 6)
	xpBarBg.Position = UDim2.new(0, barX, 0, 52)
	xpBarBg.BackgroundColor3 = Color3.fromRGB(15, 18, 30)
	xpBarBg.BorderSizePixel = 0
	xpBarBg.Parent = leftPanel
	Theme.corner(xpBarBg, 3)

	UI_HUD.XpFill = Instance.new("Frame")
	UI_HUD.XpFill.Name = "XpFill"
	UI_HUD.XpFill.Size = UDim2.new(0, 0, 1, 0)
	UI_HUD.XpFill.BackgroundColor3 = Color3.fromRGB(80, 140, 230)
	UI_HUD.XpFill.BorderSizePixel = 0
	UI_HUD.XpFill.Parent = xpBarBg
	Theme.corner(UI_HUD.XpFill, 3)

	UI_HUD.XpText = Instance.new("TextLabel")
	UI_HUD.XpText.Size = UDim2.new(1, 0, 1, 0)
	UI_HUD.XpText.Text = ""
	UI_HUD.XpText.TextColor3 = Theme.TEXT_WHITE
	UI_HUD.XpText.Font = Enum.Font.GothamBold
	UI_HUD.XpText.TextSize = 6
	UI_HUD.XpText.BackgroundTransparency = 1
	UI_HUD.XpText.ZIndex = 3
	UI_HUD.XpText.Parent = xpBarBg

	-- ==========================
	-- Center panel: Skill slots
	-- ==========================
	local centerPanel = Instance.new("Frame")
	centerPanel.Name = "CenterPanel"
	centerPanel.Size = UDim2.new(0, 350, 0, 68)
	centerPanel.Position = UDim2.new(0.5, -160, 1, -80)
	centerPanel.BackgroundColor3 = Theme.HUD_BG
	centerPanel.BackgroundTransparency = Theme.HUD_TRANSPARENCY
	centerPanel.BorderSizePixel = 0
	centerPanel.Parent = hudScreen
	Theme.corner(centerPanel, 12)
	Theme.shadow(centerPanel, 4, 16)
	Theme.gradient(centerPanel, Color3.fromRGB(28, 33, 48), Theme.HUD_BG)

	UI_HUD.SkillsContainer = Instance.new("Frame")
	UI_HUD.SkillsContainer.Name = "SkillsContainer"
	UI_HUD.SkillsContainer.Size = UDim2.new(1, 0, 1, 0)
	UI_HUD.SkillsContainer.BackgroundTransparency = 1
	UI_HUD.SkillsContainer.Parent = centerPanel

	local skillLayout = Instance.new("UIListLayout")
	skillLayout.FillDirection = Enum.FillDirection.Horizontal
	skillLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	skillLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	skillLayout.Padding = UDim.new(0, 6)
	skillLayout.SortOrder = Enum.SortOrder.LayoutOrder
	skillLayout.Parent = UI_HUD.SkillsContainer

	local SKILL_SIZE = 50
	local ULT_SIZE = 56
	local SLOT_RADIUS = 10
	local ULT_RADIUS = 12

	for i, key in ipairs({"Q", "W", "E", "R", "D", "F"}) do
		local isUlt = (key == "R")
		local slotSize = isUlt and ULT_SIZE or SKILL_SIZE
		local radius = isUlt and ULT_RADIUS or SLOT_RADIUS

		local slotFrame = Instance.new("Frame")
		slotFrame.Name = "ActionSlot_" .. key
		slotFrame.Size = UDim2.new(0, slotSize, 0, slotSize)
		slotFrame.BackgroundColor3 = Color3.fromRGB(30, 35, 50)
		slotFrame.BorderSizePixel = 0
		slotFrame.LayoutOrder = i
		slotFrame.Parent = UI_HUD.SkillsContainer
		Theme.corner(slotFrame, radius)

		if isUlt then
			Theme.stroke(slotFrame, 2, Theme.ACCENT, 0.15)
		else
			Theme.stroke(slotFrame, 1.2, Color3.fromRGB(55, 62, 80), 0.2)
		end

		-- Inner highlight (top edge)
		local slotHighlight = Instance.new("Frame")
		slotHighlight.Size = UDim2.new(1, -4, 0.35, 0)
		slotHighlight.Position = UDim2.new(0, 2, 0, 1)
		slotHighlight.BackgroundColor3 = Color3.fromRGB(55, 62, 82)
		slotHighlight.BackgroundTransparency = 0.5
		slotHighlight.BorderSizePixel = 0
		slotHighlight.ZIndex = 2
		slotHighlight.Parent = slotFrame
		Theme.corner(slotHighlight, math.max(radius - 2, 4))

		local slotHighlightGrad = Instance.new("UIGradient")
		slotHighlightGrad.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.3),
			NumberSequenceKeypoint.new(1, 1),
		})
		slotHighlightGrad.Rotation = 90
		slotHighlightGrad.Parent = slotHighlight

		-- Key label (bottom-right badge)
		local keyBadge = Instance.new("Frame")
		keyBadge.Size = UDim2.new(0, 16, 0, 14)
		keyBadge.Position = UDim2.new(1, -18, 1, -16)
		keyBadge.BackgroundColor3 = isUlt and Theme.ACCENT or Color3.fromRGB(45, 50, 68)
		keyBadge.BackgroundTransparency = isUlt and 0.3 or 0.4
		keyBadge.BorderSizePixel = 0
		keyBadge.ZIndex = 22
		keyBadge.Parent = slotFrame
		Theme.corner(keyBadge, 4)

		local keyLabel = Instance.new("TextLabel")
		keyLabel.Size = UDim2.new(1, 0, 1, 0)
		keyLabel.Text = key
		keyLabel.TextColor3 = Theme.TEXT_WHITE
		keyLabel.Font = Enum.Font.GothamBold
		keyLabel.TextSize = 9
		keyLabel.BackgroundTransparency = 1
		keyLabel.ZIndex = 23
		keyLabel.Parent = keyBadge

		-- CD overlay
		local cdOverlay = Instance.new("Frame")
		cdOverlay.Name = "CDOverlay"
		cdOverlay.Size = UDim2.new(1, 0, 1, 0)
		cdOverlay.AnchorPoint = Vector2.new(0, 1)
		cdOverlay.Position = UDim2.new(0, 0, 1, 0)
		cdOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		cdOverlay.BackgroundTransparency = 0.4
		cdOverlay.ZIndex = 20
		cdOverlay.Visible = false
		cdOverlay.BorderSizePixel = 0
		cdOverlay.Parent = slotFrame
		Theme.corner(cdOverlay, radius)

		-- CD text
		local cdText = Instance.new("TextLabel")
		cdText.Size = UDim2.new(1, 0, 1, 0)
		cdText.TextColor3 = Theme.TEXT_WHITE
		cdText.Font = Enum.Font.GothamBold
		cdText.TextSize = 16
		cdText.ZIndex = 21
		cdText.BackgroundTransparency = 1
		cdText.Visible = false
		cdText.Parent = slotFrame

		UI_HUD.SkillIcons[key] = { Overlay = cdOverlay, CDText = cdText }
	end

	-- ==========================
	-- Right panel: All stats (2 columns)
	-- ==========================
	local rightPanel = Instance.new("Frame")
	rightPanel.Name = "RightPanel"
	rightPanel.Size = UDim2.new(0, 180, 0, 156)
	rightPanel.Position = UDim2.new(0.5, 198, 1, -168)
	rightPanel.BackgroundColor3 = Theme.HUD_BG
	rightPanel.BackgroundTransparency = Theme.HUD_TRANSPARENCY
	rightPanel.BorderSizePixel = 0
	rightPanel.Parent = hudScreen
	Theme.corner(rightPanel, 10)
	Theme.shadow(rightPanel, 4, 16)
	Theme.gradient(rightPanel, Color3.fromRGB(28, 33, 48), Theme.HUD_BG)

	-- Stats content container with padding
	local statsContent = Instance.new("Frame")
	statsContent.Size = UDim2.new(1, -20, 1, -16)
	statsContent.Position = UDim2.new(0, 10, 0, 8)
	statsContent.BackgroundTransparency = 1
	statsContent.Parent = rightPanel

	-- Use two explicit columns for perfect alignment
	local colWidth = 76
	local rowHeight = 20
	local colGap = 8
	local rowGap = 4

	local statDefs = {
		{key = "ATK",         icon = "ATK",  color = Color3.fromRGB(255, 140, 90)},
		{key = "AP",          icon = "AP",   color = Color3.fromRGB(110, 175, 255)},
		{key = "DEF",         icon = "DEF",  color = Color3.fromRGB(240, 205, 80)},
		{key = "MR",          icon = "MR",   color = Color3.fromRGB(185, 130, 240)},
		{key = "MoveSpeed",   icon = "SPD",  color = Color3.fromRGB(120, 215, 185)},
		{key = "AtkSpeed",    icon = "AS",   color = Color3.fromRGB(255, 215, 90)},
		{key = "CritRate",    icon = "CRT",  color = Color3.fromRGB(255, 165, 135)},
		{key = "CritDmg",     icon = "CDM",  color = Color3.fromRGB(255, 145, 165)},
		{key = "CDR",         icon = "CDR",  color = Color3.fromRGB(135, 195, 255)},
		{key = "HpRegen",     icon = "HPR",  color = Color3.fromRGB(135, 220, 135)},
		{key = "MpRegen",     icon = "MPR",  color = Color3.fromRGB(125, 175, 240)},
		{key = "Penetration", icon = "PEN",  color = Color3.fromRGB(235, 155, 105)},
	}

	UI_HUD.StatLabels = {}

	local nameWidth = 28
	local valueWidth = colWidth - nameWidth

	for idx, def in ipairs(statDefs) do
		local col = (idx - 1) % 2        -- 0 or 1
		local row = math.floor((idx - 1) / 2) -- 0..5

		local x = col * (colWidth + colGap)
		local y = row * (rowHeight + rowGap)

		local cell = Instance.new("Frame")
		cell.Size = UDim2.new(0, colWidth, 0, rowHeight)
		cell.Position = UDim2.new(0, x, 0, y)
		cell.BackgroundTransparency = 1
		cell.Parent = statsContent

		-- Stat name (fixed width, right-aligned so values line up)
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(0, nameWidth, 1, 0)
		nameLabel.Position = UDim2.new(0, 0, 0, 0)
		nameLabel.Text = def.icon
		nameLabel.TextColor3 = def.color
		nameLabel.TextTransparency = 0.4
		nameLabel.Font = Enum.Font.GothamMedium
		nameLabel.TextSize = 9
		nameLabel.TextXAlignment = Enum.TextXAlignment.Right
		nameLabel.BackgroundTransparency = 1
		nameLabel.Parent = cell

		-- Stat value (left-aligned, starts at same X for all rows)
		local valueLabel = Instance.new("TextLabel")
		valueLabel.Size = UDim2.new(0, valueWidth, 1, 0)
		valueLabel.Position = UDim2.new(0, nameWidth + 4, 0, 0)
		valueLabel.Text = "0"
		valueLabel.TextColor3 = def.color
		valueLabel.Font = Enum.Font.GothamBold
		valueLabel.TextSize = 11
		valueLabel.TextXAlignment = Enum.TextXAlignment.Left
		valueLabel.BackgroundTransparency = 1
		valueLabel.Parent = cell

		UI_HUD.StatLabels[def.key] = { text = valueLabel, icon = "" }
	end

	-- ==========================
	-- Detail popup (dark style)
	-- ==========================
	UI_HUD.DetailWindow = Instance.new("Frame")
	UI_HUD.DetailWindow.Size = UDim2.new(0, 310, 0, 230)
	UI_HUD.DetailWindow.Position = UDim2.new(0.5, -155, 0.38, -115)
	UI_HUD.DetailWindow.BackgroundColor3 = Color3.fromRGB(22, 26, 38)
	UI_HUD.DetailWindow.BackgroundTransparency = 0.06
	UI_HUD.DetailWindow.BorderSizePixel = 0
	UI_HUD.DetailWindow.Visible = false
	UI_HUD.DetailWindow.Parent = popupScreen
	Theme.corner(UI_HUD.DetailWindow, 14)
	Theme.shadow(UI_HUD.DetailWindow, 6, 30)
	Theme.stroke(UI_HUD.DetailWindow, 1, Color3.fromRGB(50, 56, 72), 0.35)
	Theme.gradient(UI_HUD.DetailWindow, Color3.fromRGB(30, 35, 50), Color3.fromRGB(18, 22, 32))

	-- Title bar (draggable)
	local titleBar = Instance.new("Frame")
	titleBar.Size = UDim2.new(1, 0, 0, 34)
	titleBar.BackgroundColor3 = Color3.fromRGB(28, 33, 48)
	titleBar.BackgroundTransparency = 0.3
	titleBar.BorderSizePixel = 0
	titleBar.Parent = UI_HUD.DetailWindow
	Theme.corner(titleBar, 14)

	local dragging = false
	local dragStart, startPos

	titleBar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			dragStart = input.Position
			startPos = UI_HUD.DetailWindow.Position
		end
	end)

	titleBar.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			local delta = input.Position - dragStart
			UI_HUD.DetailWindow.Position = UDim2.new(
				startPos.X.Scale, startPos.X.Offset + delta.X,
				startPos.Y.Scale, startPos.Y.Offset + delta.Y
			)
		end
	end)

	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 34, 0, 34)
	closeBtn.Position = UDim2.new(1, -34, 0, 0)
	closeBtn.Text = "X"
	closeBtn.TextColor3 = Theme.TEXT_LIGHT
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.TextSize = 20
	closeBtn.BackgroundTransparency = 1
	closeBtn.Parent = titleBar
	closeBtn.MouseButton1Click:Connect(function() UI_HUD.DetailWindow.Visible = false end)

	-- Skill icon (rounded square)
	local iconSize = 58
	local iconBg = Instance.new("Frame")
	iconBg.Size = UDim2.new(0, iconSize, 0, iconSize)
	iconBg.Position = UDim2.new(0, 18, 0, 46)
	iconBg.BackgroundColor3 = Color3.fromRGB(32, 37, 52)
	iconBg.BorderSizePixel = 0
	iconBg.Parent = UI_HUD.DetailWindow
	Theme.corner(iconBg, 12)
	Theme.stroke(iconBg, 1.5, Theme.ACCENT, 0.3)

	UI_HUD.DetailIcon = Instance.new("ImageLabel")
	UI_HUD.DetailIcon.Size = UDim2.new(1, -6, 1, -6)
	UI_HUD.DetailIcon.Position = UDim2.new(0, 3, 0, 3)
	UI_HUD.DetailIcon.BackgroundTransparency = 1
	UI_HUD.DetailIcon.Parent = iconBg
	Theme.corner(UI_HUD.DetailIcon, 10)

	UI_HUD.DetailName = Instance.new("TextLabel")
	UI_HUD.DetailName.Size = UDim2.new(1, -96, 0, 22)
	UI_HUD.DetailName.Position = UDim2.new(0, 88, 0, 48)
	UI_HUD.DetailName.TextColor3 = Theme.TEXT_WHITE
	UI_HUD.DetailName.Font = Enum.Font.GothamBold
	UI_HUD.DetailName.TextSize = 16
	UI_HUD.DetailName.TextXAlignment = Enum.TextXAlignment.Left
	UI_HUD.DetailName.BackgroundTransparency = 1
	UI_HUD.DetailName.Parent = UI_HUD.DetailWindow

	UI_HUD.DetailDesc = Instance.new("TextLabel")
	UI_HUD.DetailDesc.Size = UDim2.new(1, -96, 0, 40)
	UI_HUD.DetailDesc.Position = UDim2.new(0, 88, 0, 72)
	UI_HUD.DetailDesc.TextColor3 = Theme.TEXT_LIGHT
	UI_HUD.DetailDesc.Font = Enum.Font.Gotham
	UI_HUD.DetailDesc.TextSize = 11
	UI_HUD.DetailDesc.TextWrapped = true
	UI_HUD.DetailDesc.TextXAlignment = Enum.TextXAlignment.Left
	UI_HUD.DetailDesc.TextYAlignment = Enum.TextYAlignment.Top
	UI_HUD.DetailDesc.BackgroundTransparency = 1
	UI_HUD.DetailDesc.Parent = UI_HUD.DetailWindow

	-- Divider
	local detailDivider = Instance.new("Frame")
	detailDivider.Size = UDim2.new(1, -36, 0, 1)
	detailDivider.Position = UDim2.new(0, 18, 0, 130)
	detailDivider.BackgroundColor3 = Color3.fromRGB(50, 56, 72)
	detailDivider.BackgroundTransparency = 0.3
	detailDivider.BorderSizePixel = 0
	detailDivider.Parent = UI_HUD.DetailWindow

	local socketLabel = Instance.new("TextLabel")
	socketLabel.Size = UDim2.new(1, -36, 0, 16)
	socketLabel.Position = UDim2.new(0, 18, 0, 138)
	socketLabel.Text = "Rune Sockets"
	socketLabel.TextColor3 = Theme.TEXT_LIGHT
	socketLabel.Font = Enum.Font.GothamMedium
	socketLabel.TextSize = 10
	socketLabel.TextXAlignment = Enum.TextXAlignment.Left
	socketLabel.BackgroundTransparency = 1
	socketLabel.Parent = UI_HUD.DetailWindow

	-- Circular rune sockets
	local socketContainer = Instance.new("Frame")
	socketContainer.Size = UDim2.new(1, -30, 0, 52)
	socketContainer.Position = UDim2.new(0, 15, 0, 160)
	socketContainer.BackgroundTransparency = 1
	socketContainer.Parent = UI_HUD.DetailWindow

	local socketLayout = Instance.new("UIListLayout")
	socketLayout.FillDirection = Enum.FillDirection.Horizontal
	socketLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	socketLayout.Padding = UDim.new(0, 18)
	socketLayout.Parent = socketContainer

	for i = 1, 3 do
		local socketSize = 42
		local hole = Theme.circleFrame(socketContainer, socketSize)
		hole.Name = "SocketSlot_" .. i
		hole.BackgroundColor3 = Color3.fromRGB(32, 37, 52)
		Theme.stroke(hole, 1, Color3.fromRGB(55, 62, 80), 0.25)
		UI_HUD.DetailSockets[i] = hole
	end

	StartGlobalCDMonitor()

	-- ==========================
	-- PvP: Kill Score Display (top center)
	-- ==========================
	local pvpScreen = Instance.new("ScreenGui")
	pvpScreen.Name = "PvP_HUD"
	pvpScreen.ResetOnSpawn = false
	pvpScreen.DisplayOrder = 15
	pvpScreen.Parent = playerGui
	Theme.autoScale(pvpScreen)

	killScoreFrame = Instance.new("Frame")
	killScoreFrame.Name = "KillScore"
	killScoreFrame.Size = UDim2.new(0, 220, 0, 48)
	killScoreFrame.Position = UDim2.new(0.5, -110, 0, 12)
	killScoreFrame.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
	killScoreFrame.BackgroundTransparency = 0.25
	killScoreFrame.BorderSizePixel = 0
	killScoreFrame.Parent = pvpScreen
	Theme.corner(killScoreFrame, 10)
	Theme.shadow(killScoreFrame, 3, 12)

	-- My team kills (left, blue side)
	local myTeamLabel = Instance.new("TextLabel")
	myTeamLabel.Size = UDim2.new(0.35, 0, 1, 0)
	myTeamLabel.Position = UDim2.new(0, 0, 0, 0)
	myTeamLabel.BackgroundTransparency = 1
	myTeamLabel.Font = Enum.Font.GothamBold
	myTeamLabel.TextSize = 26
	myTeamLabel.TextColor3 = Color3.fromRGB(80, 180, 255)
	myTeamLabel.Text = "0"
	myTeamLabel.Parent = killScoreFrame
	myKillText = myTeamLabel

	-- VS separator (center)
	local vsLabel = Instance.new("TextLabel")
	vsLabel.Size = UDim2.new(0.3, 0, 1, 0)
	vsLabel.Position = UDim2.new(0.35, 0, 0, 0)
	vsLabel.BackgroundTransparency = 1
	vsLabel.Font = Enum.Font.GothamBold
	vsLabel.TextSize = 16
	vsLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
	vsLabel.Text = "VS"
	vsLabel.Parent = killScoreFrame

	-- Enemy team kills (right, red side)
	local enemyTeamLabel = Instance.new("TextLabel")
	enemyTeamLabel.Size = UDim2.new(0.35, 0, 1, 0)
	enemyTeamLabel.Position = UDim2.new(0.65, 0, 0, 0)
	enemyTeamLabel.BackgroundTransparency = 1
	enemyTeamLabel.Font = Enum.Font.GothamBold
	enemyTeamLabel.TextSize = 26
	enemyTeamLabel.TextColor3 = Color3.fromRGB(235, 75, 75)
	enemyTeamLabel.Text = "0"
	enemyTeamLabel.Parent = killScoreFrame
	enemyKillText = enemyTeamLabel

	-- ==========================
	-- PvP: Death Overlay
	-- ==========================
	deathOverlay = Instance.new("Frame")
	deathOverlay.Name = "DeathOverlay"
	deathOverlay.Size = UDim2.new(1, 0, 1, 0)
	deathOverlay.BackgroundColor3 = Color3.fromRGB(15, 0, 0)
	deathOverlay.BackgroundTransparency = 0.35
	deathOverlay.BorderSizePixel = 0
	deathOverlay.ZIndex = 50
	deathOverlay.Visible = false
	deathOverlay.Parent = pvpScreen

	local deathLabel = Instance.new("TextLabel")
	deathLabel.Size = UDim2.new(0.6, 0, 0, 40)
	deathLabel.Position = UDim2.new(0.2, 0, 0.38, 0)
	deathLabel.BackgroundTransparency = 1
	deathLabel.Font = Enum.Font.GothamBold
	deathLabel.TextSize = 32
	deathLabel.TextColor3 = Color3.fromRGB(220, 60, 60)
	deathLabel.Text = "YOU HAVE BEEN SLAIN"
	deathLabel.TextStrokeTransparency = 0.3
	deathLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	deathLabel.ZIndex = 51
	deathLabel.Parent = deathOverlay

	deathTimerText = Instance.new("TextLabel")
	deathTimerText.Size = UDim2.new(0.4, 0, 0, 50)
	deathTimerText.Position = UDim2.new(0.3, 0, 0.48, 0)
	deathTimerText.BackgroundTransparency = 1
	deathTimerText.Font = Enum.Font.GothamBold
	deathTimerText.TextSize = 48
	deathTimerText.TextColor3 = Color3.fromRGB(255, 255, 255)
	deathTimerText.Text = "5"
	deathTimerText.TextStrokeTransparency = 0.2
	deathTimerText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	deathTimerText.ZIndex = 51
	deathTimerText.Parent = deathOverlay

	-- ==========================
	-- PvP: Result Screen
	-- ==========================
	resultScreen = Instance.new("Frame")
	resultScreen.Name = "ResultScreen"
	resultScreen.Size = UDim2.new(1, 0, 1, 0)
	resultScreen.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	resultScreen.BackgroundTransparency = 0.3
	resultScreen.BorderSizePixel = 0
	resultScreen.ZIndex = 60
	resultScreen.Visible = false
	resultScreen.Parent = pvpScreen

	local resultBanner = Instance.new("Frame")
	resultBanner.Size = UDim2.new(0.6, 0, 0, 140)
	resultBanner.Position = UDim2.new(0.2, 0, 0.3, 0)
	resultBanner.BackgroundColor3 = Color3.fromRGB(22, 26, 38)
	resultBanner.BackgroundTransparency = 0.1
	resultBanner.BorderSizePixel = 0
	resultBanner.ZIndex = 61
	resultBanner.Parent = resultScreen
	Theme.corner(resultBanner, 16)
	Theme.shadow(resultBanner, 6, 30)

	resultText = Instance.new("TextLabel")
	resultText.Size = UDim2.new(1, 0, 0, 60)
	resultText.Position = UDim2.new(0, 0, 0, 20)
	resultText.BackgroundTransparency = 1
	resultText.Font = Enum.Font.GothamBold
	resultText.TextSize = 42
	resultText.TextColor3 = Color3.fromRGB(255, 230, 80)
	resultText.Text = "VICTORY!"
	resultText.TextStrokeTransparency = 0.2
	resultText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	resultText.ZIndex = 62
	resultText.Parent = resultBanner

	local resultSubText = Instance.new("TextLabel")
	resultSubText.Name = "SubText"
	resultSubText.Size = UDim2.new(1, 0, 0, 30)
	resultSubText.Position = UDim2.new(0, 0, 0, 85)
	resultSubText.BackgroundTransparency = 1
	resultSubText.Font = Enum.Font.GothamMedium
	resultSubText.TextSize = 16
	resultSubText.TextColor3 = Color3.fromRGB(180, 180, 180)
	resultSubText.Text = ""
	resultSubText.ZIndex = 62
	resultSubText.Parent = resultBanner

	-- ==========================
	-- PvP: RemoteEvent Listeners
	-- ==========================
	task.spawn(function()
		local matchStateEvent = ReplicatedStorage:WaitForChild("MatchStateEvent", 30)
		if not matchStateEvent then return end

		matchStateEvent.OnClientEvent:Connect(function(eventType, data)
			if eventType == "kill_update" then
				-- data = { kills = { [teamName] = count, ... } }
				local myTeam = player.Team
				if not myTeam then return end
				local myTeamName = myTeam.Name
				local myKills = 0
				local enemyKills = 0
				for teamName, count in pairs(data.kills) do
					if teamName == myTeamName then
						myKills = count
					else
						enemyKills = count
					end
				end
				if myKillText then myKillText.Text = tostring(myKills) end
				if enemyKillText then enemyKillText.Text = tostring(enemyKills) end

			elseif eventType == "match_end" then
				-- data = { winnerTeam = "Red"/"Blue", kills = {...} }
				if resultScreen then
					resultScreen.Visible = true
					local myTeam = player.Team
					local won = myTeam and (myTeam.Name == data.winnerTeam)
					if won then
						resultText.Text = "VICTORY!"
						resultText.TextColor3 = Color3.fromRGB(80, 220, 120)
					else
						resultText.Text = "DEFEAT"
						resultText.TextColor3 = Color3.fromRGB(235, 75, 75)
					end
					-- Update sub text with final score
					local myKills = 0
					local enemyKills = 0
					if myTeam and data.kills then
						for teamName, count in pairs(data.kills) do
							if teamName == myTeam.Name then
								myKills = count
							else
								enemyKills = count
							end
						end
					end
					local subText = resultScreen:FindFirstChild("ResultScreen") and resultScreen:FindFirstChild("SubText")
					local banner = resultBanner
					if banner then
						local sub = banner:FindFirstChild("SubText")
						if sub then
							sub.Text = "Final Score: " .. myKills .. " - " .. enemyKills
						end
					end
				end
			end
		end)
	end)

	task.spawn(function()
		local deathTimerEvent = ReplicatedStorage:WaitForChild("DeathTimerEvent", 30)
		if not deathTimerEvent then return end

		deathTimerEvent.OnClientEvent:Connect(function(eventType, data)
			if eventType == "death_start" then
				-- data = { respawnTime = 5 }
				if deathOverlay then
					deathOverlay.Visible = true
					local remaining = data.respawnTime or 5
					task.spawn(function()
						while remaining > 0 and deathOverlay.Visible do
							if deathTimerText then
								deathTimerText.Text = tostring(math.ceil(remaining))
							end
							task.wait(1)
							remaining = remaining - 1
						end
						if deathOverlay then deathOverlay.Visible = false end
					end)
				end

			elseif eventType == "death_end" then
				if deathOverlay then deathOverlay.Visible = false end
			end
		end)
	end)
end

function UI_HUD.CloseAllPopups()
	if UI_HUD.DetailWindow then UI_HUD.DetailWindow.Visible = false end
end

function UI_HUD.ShowWarning(text)
	if not warningScreen then return end
	local msg = Instance.new("TextLabel")
	msg.Text = text
	msg.TextColor3 = Color3.fromRGB(240, 90, 80)
	msg.Font = Enum.Font.GothamBold
	msg.TextSize = 20
	msg.BackgroundTransparency = 1
	msg.Position = UDim2.new(0.5, -120, 0.4, 0)
	msg.Size = UDim2.new(0, 240, 0, 36)
	msg.Parent = warningScreen

	TweenService:Create(msg, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, -120, 0.35, 0),
		TextTransparency = 1
	}):Play()
	task.delay(0.8, function() msg:Destroy() end)
end

function UI_HUD.HasSkillInSlot(key)
	return UI_HUD.GetSkillIDInSlot(key) ~= nil
end

return UI_HUD
