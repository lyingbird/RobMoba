-- 头顶血条 + 等级 + 经验条 (LOL风格)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LevelConfig = require(ReplicatedStorage:WaitForChild("LevelConfig"))

local OverheadUI = {}
local localPlayer = Players.LocalPlayer
local activeGuis = {}

local BAR_WIDTH = 7  -- studs
local BAR_HEIGHT = 0.6
local LEVEL_SIZE = 0.85

local function createOverheadGui(character, player)
	local rootPart = character:WaitForChild("HumanoidRootPart", 5)
	local humanoid = character:WaitForChild("Humanoid", 5)
	if not rootPart or not humanoid then return end

	-- Hide default Roblox display
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff

	-- Main BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = "OverheadBar"
	gui.Size = UDim2.new(BAR_WIDTH, 0, LEVEL_SIZE + BAR_HEIGHT + 0.3, 0)
	gui.StudsOffset = Vector3.new(0, 3.2, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 80
	gui.Parent = rootPart

	-- Container frame
	local container = Instance.new("Frame")
	container.Size = UDim2.new(1, 0, 1, 0)
	container.BackgroundTransparency = 1
	container.Parent = gui

	-- ===== Level circle (left side) =====
	local levelCircleSize = 28
	local levelFrame = Instance.new("Frame")
	levelFrame.Name = "LevelFrame"
	levelFrame.Size = UDim2.new(0, levelCircleSize, 0, levelCircleSize)
	levelFrame.Position = UDim2.new(0.5, -(BAR_WIDTH * 10) - levelCircleSize / 2 + 2, 0.5, -levelCircleSize / 2 + 2)
	-- Center relative to bar
	levelFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	levelFrame.Position = UDim2.new(0, -2, 0.5, 2)
	levelFrame.BackgroundColor3 = Color3.fromRGB(20, 24, 36)
	levelFrame.BorderSizePixel = 0
	levelFrame.ZIndex = 5
	levelFrame.Parent = container

	local levelCorner = Instance.new("UICorner")
	levelCorner.CornerRadius = UDim.new(1, 0)
	levelCorner.Parent = levelFrame

	local levelStroke = Instance.new("UIStroke")
	levelStroke.Color = Color3.fromRGB(180, 170, 120)
	levelStroke.Thickness = 2
	levelStroke.Transparency = 0.2
	levelStroke.Parent = levelFrame

	local levelText = Instance.new("TextLabel")
	levelText.Name = "LevelText"
	levelText.Size = UDim2.new(1, 0, 1, 0)
	levelText.BackgroundTransparency = 1
	levelText.Text = tostring(character:GetAttribute("Level") or 1)
	levelText.TextColor3 = Color3.fromRGB(220, 210, 160)
	levelText.Font = Enum.Font.GothamBold
	levelText.TextSize = 14
	levelText.ZIndex = 6
	levelText.Parent = levelFrame

	-- ===== Player name =====
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(1, -32, 0, 18)
	nameLabel.Position = UDim2.new(0, 28, 0, -3)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = player.DisplayName
	nameLabel.TextColor3 = (player == localPlayer) and Color3.fromRGB(100, 220, 130) or Color3.fromRGB(220, 220, 220)
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 13
	nameLabel.TextXAlignment = Enum.TextXAlignment.Center
	nameLabel.TextStrokeTransparency = 0.5
	nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	nameLabel.Parent = container

	-- ===== HP bar =====
	local hpBarY = 18
	local hpBarHeight = 12

	local hpBg = Instance.new("Frame")
	hpBg.Name = "HpBg"
	hpBg.Size = UDim2.new(1, -32, 0, hpBarHeight)
	hpBg.Position = UDim2.new(0, 28, 0, hpBarY)
	hpBg.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
	hpBg.BorderSizePixel = 0
	hpBg.Parent = container

	local hpCorner = Instance.new("UICorner")
	hpCorner.CornerRadius = UDim.new(0, 3)
	hpCorner.Parent = hpBg

	local hpStroke = Instance.new("UIStroke")
	hpStroke.Color = Color3.fromRGB(10, 10, 10)
	hpStroke.Thickness = 1
	hpStroke.Transparency = 0.3
	hpStroke.Parent = hpBg

	-- HP fill (green for allies/self, red for enemies in future)
	local isLocal = (player == localPlayer)
	local hpColor = isLocal and Color3.fromRGB(50, 190, 80) or Color3.fromRGB(50, 190, 80)

	local hpFill = Instance.new("Frame")
	hpFill.Name = "HpFill"
	hpFill.Size = UDim2.new(1, 0, 1, 0)
	hpFill.BackgroundColor3 = hpColor
	hpFill.BorderSizePixel = 0
	hpFill.Parent = hpBg

	local hpFillCorner = Instance.new("UICorner")
	hpFillCorner.CornerRadius = UDim.new(0, 3)
	hpFillCorner.Parent = hpFill

	-- HP gradient for depth
	local hpGrad = Instance.new("UIGradient")
	hpGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(220, 220, 220)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 180, 180)),
	})
	hpGrad.Rotation = 90
	hpGrad.Parent = hpFill

	-- Shield bar (white, overlaid on top of HP from right side)
	local shieldFill = Instance.new("Frame")
	shieldFill.Name = "ShieldFill"
	shieldFill.Size = UDim2.new(0, 0, 1, 0)
	shieldFill.AnchorPoint = Vector2.new(1, 0)
	shieldFill.Position = UDim2.new(1, 0, 0, 0)
	shieldFill.BackgroundColor3 = Color3.fromRGB(240, 240, 255)
	shieldFill.BackgroundTransparency = 0.15
	shieldFill.BorderSizePixel = 0
	shieldFill.ZIndex = 2
	shieldFill.Parent = hpBg

	local shieldCorner = Instance.new("UICorner")
	shieldCorner.CornerRadius = UDim.new(0, 3)
	shieldCorner.Parent = shieldFill

	-- HP text
	local hpText = Instance.new("TextLabel")
	hpText.Name = "HpText"
	hpText.Size = UDim2.new(1, 0, 1, 0)
	hpText.BackgroundTransparency = 1
	hpText.TextColor3 = Color3.fromRGB(255, 255, 255)
	hpText.Font = Enum.Font.GothamBold
	hpText.TextSize = 10
	hpText.ZIndex = 3
	hpText.TextStrokeTransparency = 0.4
	hpText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	hpText.Parent = hpBg

	-- ===== XP bar (thin bar under HP) =====
	local xpBarHeight = 4

	local xpBg = Instance.new("Frame")
	xpBg.Name = "XpBg"
	xpBg.Size = UDim2.new(1, -32, 0, xpBarHeight)
	xpBg.Position = UDim2.new(0, 28, 0, hpBarY + hpBarHeight + 2)
	xpBg.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
	xpBg.BorderSizePixel = 0
	xpBg.Parent = container

	local xpCorner = Instance.new("UICorner")
	xpCorner.CornerRadius = UDim.new(0, 2)
	xpCorner.Parent = xpBg

	local xpFill = Instance.new("Frame")
	xpFill.Name = "XpFill"
	xpFill.Size = UDim2.new(0, 0, 1, 0)
	xpFill.BackgroundColor3 = Color3.fromRGB(80, 140, 230)
	xpFill.BorderSizePixel = 0
	xpFill.Parent = xpBg

	local xpFillCorner = Instance.new("UICorner")
	xpFillCorner.CornerRadius = UDim.new(0, 2)
	xpFillCorner.Parent = xpFill

	-- Store references
	local data = {
		gui = gui,
		hpFill = hpFill,
		hpText = hpText,
		shieldFill = shieldFill,
		xpFill = xpFill,
		levelText = levelText,
		levelFrame = levelFrame,
		humanoid = humanoid,
		character = character,
		player = player,
	}

	activeGuis[character] = data

	-- Initial update
	OverheadUI.UpdateBar(data)

	-- Listen for attribute changes
	local connections = {}

	table.insert(connections, humanoid.HealthChanged:Connect(function()
		OverheadUI.UpdateBar(data)
	end))

	table.insert(connections, character:GetAttributeChangedSignal("Level"):Connect(function()
		local newLevel = character:GetAttribute("Level") or 1
		levelText.Text = tostring(newLevel)

		-- Level up flash effect
		local flash = Instance.new("Frame")
		flash.Size = UDim2.new(1, 4, 1, 4)
		flash.Position = UDim2.new(0, -2, 0, -2)
		flash.BackgroundColor3 = Color3.fromRGB(255, 230, 100)
		flash.BackgroundTransparency = 0
		flash.ZIndex = 10
		flash.Parent = levelFrame

		local flashCorner = Instance.new("UICorner")
		flashCorner.CornerRadius = UDim.new(1, 0)
		flashCorner.Parent = flash

		TweenService:Create(flash, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 14, 1, 14),
			Position = UDim2.new(0, -7, 0, -7),
		}):Play()

		task.delay(0.7, function()
			if flash and flash.Parent then flash:Destroy() end
		end)
	end))

	table.insert(connections, character:GetAttributeChangedSignal("TotalXP"):Connect(function()
		OverheadUI.UpdateBar(data)
	end))

	table.insert(connections, character:GetAttributeChangedSignal("MaxHP"):Connect(function()
		OverheadUI.UpdateBar(data)
	end))

	table.insert(connections, character:GetAttributeChangedSignal("Shield"):Connect(function()
		OverheadUI.UpdateBar(data)
	end))

	-- Cleanup on character removal
	humanoid.Died:Connect(function()
		task.delay(2, function()
			for _, conn in ipairs(connections) do
				conn:Disconnect()
			end
			activeGuis[character] = nil
			if gui and gui.Parent then gui:Destroy() end
		end)
	end)
end

function OverheadUI.UpdateBar(data)
	if not data or not data.humanoid or not data.humanoid.Parent then return end

	local hp = data.humanoid.Health
	local maxHp = data.humanoid.MaxHealth
	local ratio = math.clamp(hp / maxHp, 0, 1)

	-- Shield display
	local shield = data.character:GetAttribute("Shield") or 0
	local totalPool = maxHp + shield -- effective max with shield
	local hpRatio = math.clamp(hp / totalPool, 0, 1)
	local shieldRatio = math.clamp(shield / totalPool, 0, 1)

	-- HP fill shows hp portion of total pool
	TweenService:Create(data.hpFill, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.new(hpRatio, 0, 1, 0)
	}):Play()

	-- Shield fill shows white shield portion (anchored right of hp fill)
	if shield > 0 then
		data.shieldFill.Visible = true
		-- Position shield right after hp
		data.shieldFill.AnchorPoint = Vector2.new(0, 0)
		data.shieldFill.Position = UDim2.new(hpRatio, 0, 0, 0)
		TweenService:Create(data.shieldFill, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.new(shieldRatio, 0, 1, 0)
		}):Play()
	else
		data.shieldFill.Visible = false
		data.shieldFill.Size = UDim2.new(0, 0, 1, 0)
	end

	if shield > 0 then
		data.hpText.Text = math.floor(hp) .. "+" .. math.floor(shield) .. " / " .. math.floor(maxHp)
	else
		data.hpText.Text = math.floor(hp) .. " / " .. math.floor(maxHp)
	end

	-- Change color based on HP percentage
	if ratio > 0.5 then
		data.hpFill.BackgroundColor3 = Color3.fromRGB(50, 190, 80)
	elseif ratio > 0.25 then
		data.hpFill.BackgroundColor3 = Color3.fromRGB(220, 180, 40)
	else
		data.hpFill.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
	end

	-- XP bar
	local level = data.character:GetAttribute("Level") or 1
	local totalXP = data.character:GetAttribute("TotalXP") or 0
	local xpProgress = LevelConfig.GetLevelProgress(level, totalXP)

	TweenService:Create(data.xpFill, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.new(xpProgress, 0, 1, 0)
	}):Play()

	data.levelText.Text = tostring(level)
end

function OverheadUI.Init()
	-- Setup for existing players
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			createOverheadGui(player.Character, player)
		end
		player.CharacterAdded:Connect(function(character)
			task.defer(function()
				createOverheadGui(character, player)
			end)
		end)
	end

	-- Setup for new players
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			task.defer(function()
				createOverheadGui(character, player)
			end)
		end)
		if player.Character then
			createOverheadGui(player.Character, player)
		end
	end)

	-- Listen for level up events (for local VFX like floating text)
	local SyncLevelEvent = ReplicatedStorage:WaitForChild("SyncLevelEvent", 5)
	if SyncLevelEvent then
		SyncLevelEvent.OnClientEvent:Connect(function(newLevel, totalXP)
			local character = localPlayer.Character
			if not character or not character:FindFirstChild("HumanoidRootPart") then return end

			-- Floating "LEVEL UP!" text
			local rootPart = character.HumanoidRootPart
			local lvlGui = Instance.new("BillboardGui")
			lvlGui.Size = UDim2.new(6, 0, 2, 0)
			lvlGui.StudsOffset = Vector3.new(0, 6, 0)
			lvlGui.AlwaysOnTop = true
			lvlGui.Parent = rootPart

			local lvlLabel = Instance.new("TextLabel")
			lvlLabel.Size = UDim2.new(1, 0, 1, 0)
			lvlLabel.BackgroundTransparency = 1
			lvlLabel.Text = "LEVEL UP! Lv." .. newLevel
			lvlLabel.TextColor3 = Color3.fromRGB(255, 230, 80)
			lvlLabel.Font = Enum.Font.GothamBold
			lvlLabel.TextSize = 26
			lvlLabel.TextStrokeTransparency = 0.2
			lvlLabel.TextStrokeColor3 = Color3.fromRGB(80, 60, 0)
			lvlLabel.Parent = lvlGui

			TweenService:Create(lvlGui, TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				StudsOffset = Vector3.new(0, 9, 0)
			}):Play()

			TweenService:Create(lvlLabel, TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				TextTransparency = 1,
				TextStrokeTransparency = 1
			}):Play()

			task.delay(1.6, function()
				if lvlGui and lvlGui.Parent then lvlGui:Destroy() end
			end)
		end)
	end
end

return OverheadUI
