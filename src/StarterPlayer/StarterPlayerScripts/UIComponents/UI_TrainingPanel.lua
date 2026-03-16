-- ==========================================
-- UI_TrainingPanel: 训练场控制面板
-- 职责: 训练场 UI 创建、交互、状态同步
-- REQ-009: 训练场模式（Training Ground）
-- 运行位置: 客户端 (StarterPlayerScripts)
-- ==========================================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

local TrainingEvent = ReplicatedStorage:WaitForChild("TrainingEvent", 10)
local TrainingSyncEvent = ReplicatedStorage:WaitForChild("TrainingSyncEvent", 10)
local MatchmakingEvent = ReplicatedStorage:FindFirstChild("MatchmakingEvent")

local UI_TrainingPanel = {}

-- ========== 颜色常量 (UX §6.3) ==========
local COLORS = {
	panelBg = Color3.fromRGB(15, 20, 35),
	titleBar = Color3.fromRGB(25, 35, 55),
	btnDefault = Color3.fromRGB(40, 60, 100),
	btnHover = Color3.fromRGB(60, 90, 140),
	toggleOn = Color3.fromRGB(76, 175, 80),
	toggleOff = Color3.fromRGB(80, 80, 80),
	toggleOnHover = Color3.fromRGB(56, 155, 60),
	toggleOffHover = Color3.fromRGB(110, 110, 110),
	textColor = Color3.fromRGB(230, 230, 230),
	disabledBg = Color3.fromRGB(50, 50, 50),
	warningRed = Color3.fromRGB(255, 80, 80),
	feedbackGreen = Color3.fromRGB(80, 255, 120),
}

-- ========== 状态 ==========
local panelExpanded = true
local cdEnabled = false
local dummyCount = 0
local currentLevel = 1
local panelVisible = true

-- ========== GUI 引用 ==========
local screenGui, panelFrame, collapsedIcon
local toggleOnBtn, toggleOffBtn
local dummyCountLabel, levelDisplay
local allButtons = {} -- 所有功能按钮引用

-- ========== UI 工具函数 ==========
local function createTextButton(name, text, parent, position, size)
	local btn = Instance.new("TextButton")
	btn.Name = name
	btn.Text = text
	btn.Position = position
	btn.Size = size
	btn.BackgroundColor3 = COLORS.btnDefault
	btn.TextColor3 = COLORS.textColor
	btn.Font = Enum.Font.GothamMedium
	btn.TextSize = 13
	btn.AutoButtonColor = false
	btn.BorderSizePixel = 0
	btn.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = btn

	-- Hover 效果
	btn.MouseEnter:Connect(function()
		if btn.Active then
			btn.BackgroundColor3 = COLORS.btnHover
		end
	end)
	btn.MouseLeave:Connect(function()
		if btn.Active then
			btn.BackgroundColor3 = COLORS.btnDefault
		end
	end)

	table.insert(allButtons, btn)
	return btn
end

local function fireAction(action, extraData)
	if not TrainingEvent then return end
	local data = { action = action }
	if extraData then
		for k, v in pairs(extraData) do
			data[k] = v
		end
	end
	TrainingEvent:FireServer(data)
end

local function setButtonsEnabled(enabled)
	for _, btn in ipairs(allButtons) do
		btn.Active = enabled
		btn.BackgroundColor3 = enabled and COLORS.btnDefault or COLORS.disabledBg
		btn.TextTransparency = enabled and 0 or 0.5
	end
	if toggleOnBtn then
		toggleOnBtn.Active = enabled
		toggleOffBtn.Active = enabled
	end
end

-- ========== 创建 GUI ==========
local function createPanel()
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "TrainingPanel"
	screenGui.DisplayOrder = 5
	screenGui.ResetOnSpawn = false
	screenGui.Parent = player.PlayerGui

	-- 展开面板
	panelFrame = Instance.new("Frame")
	panelFrame.Name = "Panel"
	panelFrame.Position = UDim2.new(0, 12, 0, 12)
	panelFrame.Size = UDim2.new(0, 200, 0, 270)
	panelFrame.BackgroundColor3 = COLORS.panelBg
	panelFrame.BackgroundTransparency = 0.25
	panelFrame.BorderSizePixel = 0
	panelFrame.Parent = screenGui

	local panelCorner = Instance.new("UICorner")
	panelCorner.CornerRadius = UDim.new(0, 8)
	panelCorner.Parent = panelFrame

	-- 标题栏
	local titleBar = Instance.new("Frame")
	titleBar.Name = "TitleBar"
	titleBar.Size = UDim2.new(1, 0, 0, 36)
	titleBar.BackgroundColor3 = COLORS.titleBar
	titleBar.BorderSizePixel = 0
	titleBar.Parent = panelFrame

	local titleCorner = Instance.new("UICorner")
	titleCorner.CornerRadius = UDim.new(0, 8)
	titleCorner.Parent = titleBar

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -40, 1, 0)
	titleLabel.Position = UDim2.new(0, 10, 0, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "🏋️ 训练场"
	titleLabel.TextColor3 = COLORS.textColor
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 14
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = titleBar

	local collapseBtn = Instance.new("TextButton")
	collapseBtn.Name = "CollapseBtn"
	collapseBtn.Size = UDim2.new(0, 30, 0, 30)
	collapseBtn.Position = UDim2.new(1, -34, 0, 3)
	collapseBtn.BackgroundTransparency = 1
	collapseBtn.Text = "−"
	collapseBtn.TextColor3 = COLORS.textColor
	collapseBtn.Font = Enum.Font.GothamBold
	collapseBtn.TextSize = 18
	collapseBtn.Parent = titleBar

	-- 提示文本（未选英雄时显示）
	local warningLabel = Instance.new("TextLabel")
	warningLabel.Name = "Warning"
	warningLabel.Size = UDim2.new(1, -16, 0, 20)
	warningLabel.Position = UDim2.new(0, 8, 0, 38)
	warningLabel.BackgroundTransparency = 1
	warningLabel.Text = ""
	warningLabel.TextColor3 = COLORS.warningRed
	warningLabel.Font = Enum.Font.GothamMedium
	warningLabel.TextSize = 11
	warningLabel.TextXAlignment = Enum.TextXAlignment.Left
	warningLabel.Parent = panelFrame

	local yOffset = 42

	-- Row 1: 技能冷却 Toggle
	local cdLabel = Instance.new("TextLabel")
	cdLabel.Size = UDim2.new(0, 70, 0, 30)
	cdLabel.Position = UDim2.new(0, 8, 0, yOffset)
	cdLabel.BackgroundTransparency = 1
	cdLabel.Text = "技能冷却"
	cdLabel.TextColor3 = COLORS.textColor
	cdLabel.Font = Enum.Font.GothamMedium
	cdLabel.TextSize = 12
	cdLabel.TextXAlignment = Enum.TextXAlignment.Left
	cdLabel.Parent = panelFrame

	toggleOnBtn = Instance.new("TextButton")
	toggleOnBtn.Name = "OnBtn"
	toggleOnBtn.Size = UDim2.new(0, 50, 0, 26)
	toggleOnBtn.Position = UDim2.new(0, 90, 0, yOffset + 2)
	toggleOnBtn.BackgroundColor3 = COLORS.toggleOff
	toggleOnBtn.Text = "ON"
	toggleOnBtn.TextColor3 = COLORS.textColor
	toggleOnBtn.Font = Enum.Font.GothamBold
	toggleOnBtn.TextSize = 12
	toggleOnBtn.AutoButtonColor = false
	toggleOnBtn.BorderSizePixel = 0
	toggleOnBtn.Parent = panelFrame
	local onCorner = Instance.new("UICorner")
	onCorner.CornerRadius = UDim.new(0, 4)
	onCorner.Parent = toggleOnBtn

	toggleOffBtn = Instance.new("TextButton")
	toggleOffBtn.Name = "OffBtn"
	toggleOffBtn.Size = UDim2.new(0, 50, 0, 26)
	toggleOffBtn.Position = UDim2.new(0, 144, 0, yOffset + 2)
	toggleOffBtn.BackgroundColor3 = COLORS.toggleOn
	toggleOffBtn.Text = "OFF"
	toggleOffBtn.TextColor3 = COLORS.textColor
	toggleOffBtn.Font = Enum.Font.GothamBold
	toggleOffBtn.TextSize = 12
	toggleOffBtn.AutoButtonColor = false
	toggleOffBtn.BorderSizePixel = 0
	toggleOffBtn.Parent = panelFrame
	local offCorner = Instance.new("UICorner")
	offCorner.CornerRadius = UDim.new(0, 4)
	offCorner.Parent = toggleOffBtn

	yOffset = yOffset + 36

	-- Row 2: 回满 HP/MP
	local refreshBtn = createTextButton(
		"RefreshBtn", "❤️ 回满 HP / MP",
		panelFrame,
		UDim2.new(0, 8, 0, yOffset),
		UDim2.new(1, -16, 0, 32)
	)
	yOffset = yOffset + 38

	-- Row 3: 假人
	local spawnBtn = createTextButton(
		"SpawnBtn", "🎯 生成假人",
		panelFrame,
		UDim2.new(0, 8, 0, yOffset),
		UDim2.new(0, 88, 0, 32)
	)
	local clearBtn = createTextButton(
		"ClearBtn", "🗑 清除全部",
		panelFrame,
		UDim2.new(0, 100, 0, yOffset),
		UDim2.new(0, 92, 0, 32)
	)
	yOffset = yOffset + 34

	dummyCountLabel = Instance.new("TextLabel")
	dummyCountLabel.Size = UDim2.new(1, -16, 0, 16)
	dummyCountLabel.Position = UDim2.new(0, 8, 0, yOffset)
	dummyCountLabel.BackgroundTransparency = 1
	dummyCountLabel.Text = "假人数量: 0 / 3"
	dummyCountLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
	dummyCountLabel.Font = Enum.Font.Gotham
	dummyCountLabel.TextSize = 11
	dummyCountLabel.TextXAlignment = Enum.TextXAlignment.Center
	dummyCountLabel.Parent = panelFrame
	yOffset = yOffset + 22

	-- Row 4: 等级调整
	local levelLabel = Instance.new("TextLabel")
	levelLabel.Size = UDim2.new(0, 36, 0, 30)
	levelLabel.Position = UDim2.new(0, 8, 0, yOffset)
	levelLabel.BackgroundTransparency = 1
	levelLabel.Text = "等级"
	levelLabel.TextColor3 = COLORS.textColor
	levelLabel.Font = Enum.Font.GothamMedium
	levelLabel.TextSize = 12
	levelLabel.TextXAlignment = Enum.TextXAlignment.Left
	levelLabel.Parent = panelFrame

	local levelDownBtn = createTextButton(
		"LevelDown", "−",
		panelFrame,
		UDim2.new(0, 52, 0, yOffset),
		UDim2.new(0, 36, 0, 30)
	)
	levelDownBtn.TextSize = 18

	levelDisplay = Instance.new("TextLabel")
	levelDisplay.Size = UDim2.new(0, 50, 0, 30)
	levelDisplay.Position = UDim2.new(0, 92, 0, yOffset)
	levelDisplay.BackgroundTransparency = 1
	levelDisplay.Text = "Lv. 1"
	levelDisplay.TextColor3 = COLORS.textColor
	levelDisplay.Font = Enum.Font.GothamBold
	levelDisplay.TextSize = 14
	levelDisplay.Parent = panelFrame

	local levelUpBtn = createTextButton(
		"LevelUp", "+",
		panelFrame,
		UDim2.new(0, 146, 0, yOffset),
		UDim2.new(0, 36, 0, 30)
	)
	levelUpBtn.TextSize = 18
	yOffset = yOffset + 36

	-- Row 5: 回到出生点
	local resetPosBtn = createTextButton(
		"ResetPosBtn", "🏠 回到出生点",
		panelFrame,
		UDim2.new(0, 8, 0, yOffset),
		UDim2.new(1, -16, 0, 32)
	)

	-- 折叠图标
	collapsedIcon = Instance.new("TextButton")
	collapsedIcon.Name = "CollapsedIcon"
	collapsedIcon.Position = UDim2.new(0, 12, 0, 12)
	collapsedIcon.Size = UDim2.new(0, 44, 0, 44)
	collapsedIcon.BackgroundColor3 = COLORS.panelBg
	collapsedIcon.BackgroundTransparency = 0.25
	collapsedIcon.Text = "🏋️"
	collapsedIcon.TextSize = 22
	collapsedIcon.AutoButtonColor = false
	collapsedIcon.BorderSizePixel = 0
	collapsedIcon.Visible = false
	collapsedIcon.Parent = screenGui

	local iconCorner = Instance.new("UICorner")
	iconCorner.CornerRadius = UDim.new(0, 8)
	iconCorner.Parent = collapsedIcon

	-- ========== 交互事件 ==========

	-- Toggle CD
	local function updateToggleVisual()
		if cdEnabled then
			toggleOnBtn.BackgroundColor3 = COLORS.toggleOn
			toggleOffBtn.BackgroundColor3 = COLORS.toggleOff
		else
			toggleOnBtn.BackgroundColor3 = COLORS.toggleOff
			toggleOffBtn.BackgroundColor3 = COLORS.toggleOn
		end
	end

	toggleOnBtn.MouseButton1Click:Connect(function()
		if not cdEnabled then
			cdEnabled = true
			updateToggleVisual()
			fireAction("toggleCD", { enabled = true })
		end
	end)

	toggleOffBtn.MouseButton1Click:Connect(function()
		if cdEnabled then
			cdEnabled = false
			updateToggleVisual()
			fireAction("toggleCD", { enabled = false })
		end
	end)

	-- 回满
	refreshBtn.MouseButton1Click:Connect(function()
		fireAction("refreshHP")
		-- 视觉反馈: 按钮闪绿色
		refreshBtn.BackgroundColor3 = COLORS.feedbackGreen
		task.delay(0.3, function()
			if refreshBtn.Active then
				refreshBtn.BackgroundColor3 = COLORS.btnDefault
			end
		end)
	end)

	-- 假人
	spawnBtn.MouseButton1Click:Connect(function()
		fireAction("spawnDummy")
	end)

	clearBtn.MouseButton1Click:Connect(function()
		fireAction("clearDummies")
	end)

	-- 等级
	levelDownBtn.MouseButton1Click:Connect(function()
		if currentLevel > 1 then
			currentLevel = currentLevel - 1
			levelDisplay.Text = "Lv. " .. currentLevel
			fireAction("setLevel", { level = currentLevel })
		end
	end)

	levelUpBtn.MouseButton1Click:Connect(function()
		if currentLevel < 18 then
			currentLevel = currentLevel + 1
			levelDisplay.Text = "Lv. " .. currentLevel
			fireAction("setLevel", { level = currentLevel })
		end
	end)

	-- 重置位置
	resetPosBtn.MouseButton1Click:Connect(function()
		fireAction("resetPos")
		-- 视觉反馈
		resetPosBtn.BackgroundColor3 = COLORS.feedbackGreen
		task.delay(0.3, function()
			if resetPosBtn.Active then
				resetPosBtn.BackgroundColor3 = COLORS.btnDefault
			end
		end)
	end)

	-- 折叠/展开
	collapseBtn.MouseButton1Click:Connect(function()
		panelExpanded = false
		panelFrame.Visible = false
		collapsedIcon.Visible = true
	end)

	collapsedIcon.MouseButton1Click:Connect(function()
		panelExpanded = true
		panelFrame.Visible = true
		collapsedIcon.Visible = false
	end)

	updateToggleVisual()
end

-- ========== 服务端状态同步 ==========
local function onSyncState(data)
	if not data or typeof(data) ~= "table" then return end

	if data.noCooldown ~= nil then
		cdEnabled = data.noCooldown
		if toggleOnBtn then
			if cdEnabled then
				toggleOnBtn.BackgroundColor3 = COLORS.toggleOn
				toggleOffBtn.BackgroundColor3 = COLORS.toggleOff
			else
				toggleOnBtn.BackgroundColor3 = COLORS.toggleOff
				toggleOffBtn.BackgroundColor3 = COLORS.toggleOn
			end
		end
	end

	if data.dummyCount ~= nil then
		dummyCount = data.dummyCount
		if dummyCountLabel then
			dummyCountLabel.Text = "假人数量: " .. dummyCount .. " / 3"
		end
	end

	if data.level ~= nil then
		currentLevel = data.level
		if levelDisplay then
			levelDisplay.Text = "Lv. " .. currentLevel
		end
	end

	if data.panelVisible ~= nil then
		panelVisible = data.panelVisible
		if screenGui then
			screenGui.Enabled = panelVisible
		end
		-- 隐藏时重置折叠状态
		if not panelVisible then
			panelExpanded = true
			if panelFrame then panelFrame.Visible = true end
			if collapsedIcon then collapsedIcon.Visible = false end
		end
	end
end

-- ========== 英雄选择状态监听 ==========
local function checkHeroSelected()
	-- 检查玩家是否已选择英雄（通过 Character Attributes 或 HeroSwapEvent）
	local character = player.Character
	if character then
		local heroId = character:GetAttribute("HeroId")
		if heroId then
			setButtonsEnabled(true)
			return
		end
	end
	-- 也检查 LobbyManager 的英雄数据（通过 Attribute 桥）
	local heroAttr = player:GetAttribute("SelectedHero")
	if heroAttr then
		setButtonsEnabled(true)
	else
		setButtonsEnabled(false)
	end
end

-- ========== 初始化 ==========
function UI_TrainingPanel.Init()
	createPanel()

	-- 监听服务端同步
	if TrainingSyncEvent then
		TrainingSyncEvent.OnClientEvent:Connect(onSyncState)
	end

	-- 监听匹配状态变化（隐藏/显示面板）
	if MatchmakingEvent then
		MatchmakingEvent.OnClientEvent:Connect(function(data)
			if not data then return end
			if data.status == "queued" or data.status == "matched" then
				-- 进入匹配/对决 → 隐藏面板
				if screenGui then screenGui.Enabled = false end
			elseif data.status == "cancelled" then
				-- 取消匹配 → 显示面板
				if screenGui then screenGui.Enabled = true end
			end
		end)
	end

	-- 初始英雄检查
	task.delay(1, checkHeroSelected)

	-- 监听 HeroSwapEvent 用于更新按钮状态
	local HeroSwapEvent = ReplicatedStorage:FindFirstChild("HeroSwapEvent")
	if HeroSwapEvent then
		HeroSwapEvent.OnClientEvent:Connect(function(data)
			if data and data.success then
				setButtonsEnabled(true)
			end
		end)
	end
end

return UI_TrainingPanel
