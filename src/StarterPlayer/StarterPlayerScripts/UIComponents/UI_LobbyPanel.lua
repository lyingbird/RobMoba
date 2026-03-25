-- ==========================================
-- UI_LobbyPanel.lua
-- 职责: 大厅模式选择面板 — 训练场 / PVP 双入口
-- REQ-013: 移动端大厅流程
-- ==========================================
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Modules = script.Parent.Parent:WaitForChild("Modules")
local UITheme = require(Modules:WaitForChild("UITheme"))

local UI_LobbyPanel = {}

-- ========== 回调 ==========
local onTrainingCallback = nil
local onPVPCallback = nil

-- ========== UI 引用 ==========
local screenGui = nil
local mainFrame = nil

-- ========== 工具函数 ==========
local function createButton(parent, config)
	-- 卡片容器
	local card = Instance.new("Frame")
	card.Name = config.name
	card.Size = UDim2.new(0.42, 0, 0, 140)
	card.BackgroundColor3 = config.bgColor
	card.BorderSizePixel = 0
	card.Parent = parent
	UITheme.corner(card, 16)

	-- 渐变
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(config.gradientTop, config.gradientBottom)
	gradient.Rotation = 90
	gradient.Parent = card

	-- 描边
	UITheme.stroke(card, 1.5, config.borderColor, 0.2)

	-- 图标
	local iconLabel = Instance.new("TextLabel")
	iconLabel.Name = "Icon"
	iconLabel.Size = UDim2.new(1, 0, 0, 36)
	iconLabel.Position = UDim2.new(0, 0, 0, 18)
	iconLabel.BackgroundTransparency = 1
	iconLabel.Text = config.icon
	iconLabel.TextSize = 32
	iconLabel.Font = Enum.Font.GothamBold
	iconLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	iconLabel.Parent = card

	-- 标题
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 24)
	title.Position = UDim2.new(0, 0, 0, 60)
	title.BackgroundTransparency = 1
	title.Text = config.title
	title.TextSize = 20
	title.Font = Enum.Font.GothamBold
	title.TextColor3 = UITheme.TEXT_WHITE
	title.Parent = card

	-- 描述
	local desc = Instance.new("TextLabel")
	desc.Name = "Description"
	desc.Size = UDim2.new(0.85, 0, 0, 20)
	desc.Position = UDim2.new(0.075, 0, 0, 90)
	desc.BackgroundTransparency = 1
	desc.Text = config.description
	desc.TextSize = 14
	desc.Font = Enum.Font.Gotham
	desc.TextColor3 = UITheme.TEXT_LIGHT
	desc.TextWrapped = true
	desc.Parent = card

	-- 点击按钮(覆盖整个卡片)
	local btn = Instance.new("TextButton")
	btn.Name = "ClickArea"
	btn.Size = UDim2.new(1, 0, 1, 0)
	btn.BackgroundTransparency = 1
	btn.Text = ""
	btn.ZIndex = 10
	btn.Parent = card

	-- 悬停/按下反馈
	btn.MouseEnter:Connect(function()
		TweenService:Create(card, TweenInfo.new(0.15), {
			BackgroundTransparency = 0.1,
		}):Play()
	end)

	btn.MouseLeave:Connect(function()
		TweenService:Create(card, TweenInfo.new(0.15), {
			BackgroundTransparency = 0,
		}):Play()
	end)

	btn.MouseButton1Down:Connect(function()
		TweenService:Create(card, TweenInfo.new(0.08), {
			Size = UDim2.new(0.40, 0, 0, 134),
		}):Play()
	end)

	btn.MouseButton1Up:Connect(function()
		TweenService:Create(card, TweenInfo.new(0.12, Enum.EasingStyle.Back), {
			Size = UDim2.new(0.42, 0, 0, 140),
		}):Play()
	end)

	btn.MouseButton1Click:Connect(function()
		if config.callback then
			config.callback()
		end
	end)

	return card
end

-- ========== Init ==========
function UI_LobbyPanel.Init()
	if screenGui then return end

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "LobbyPanelGui"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.DisplayOrder = 5
	screenGui.Parent = playerGui

	-- 全屏半透明背景遮罩
	local overlay = Instance.new("Frame")
	overlay.Name = "Overlay"
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	overlay.BackgroundTransparency = 0.4
	overlay.BorderSizePixel = 0
	overlay.ZIndex = 1
	overlay.Parent = screenGui

	-- 主内容容器
	mainFrame = Instance.new("Frame")
	mainFrame.Name = "MainContent"
	mainFrame.Size = UDim2.new(1, 0, 1, 0)
	mainFrame.BackgroundTransparency = 1
	mainFrame.ZIndex = 2
	mainFrame.Parent = screenGui

	-- 标题区域
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "GameTitle"
	titleLabel.Size = UDim2.new(1, 0, 0, 40)
	titleLabel.Position = UDim2.new(0, 0, 0.22, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "⚔️ 王者竞技场"
	titleLabel.TextSize = 32
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	titleLabel.TextStrokeTransparency = 0.5
	titleLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	titleLabel.ZIndex = 3
	titleLabel.Parent = mainFrame

	-- 副标题
	local subtitleLabel = Instance.new("TextLabel")
	subtitleLabel.Name = "Subtitle"
	subtitleLabel.Size = UDim2.new(1, 0, 0, 24)
	subtitleLabel.Position = UDim2.new(0, 0, 0.22, 46)
	subtitleLabel.BackgroundTransparency = 1
	subtitleLabel.Text = "选择游戏模式"
	subtitleLabel.TextSize = 16
	subtitleLabel.Font = Enum.Font.Gotham
	subtitleLabel.TextColor3 = UITheme.TEXT_LIGHT
	subtitleLabel.ZIndex = 3
	subtitleLabel.Parent = mainFrame

	-- 按钮容器(水平排列)
	local buttonContainer = Instance.new("Frame")
	buttonContainer.Name = "ButtonContainer"
	buttonContainer.Size = UDim2.new(0.9, 0, 0, 140)
	buttonContainer.Position = UDim2.new(0.05, 0, 0.42, 0)
	buttonContainer.BackgroundTransparency = 1
	buttonContainer.ZIndex = 3
	buttonContainer.Parent = mainFrame

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 16)
	layout.Parent = buttonContainer

	-- 训练场卡片(蓝色)
	createButton(buttonContainer, {
		name = "TrainingCard",
		icon = "🛡️⚔️",
		title = "单人训练",
		description = "选择英雄，自由练习技能",
		bgColor = Color3.fromRGB(30, 58, 95),
		gradientTop = Color3.fromRGB(30, 58, 95),
		gradientBottom = Color3.fromRGB(42, 95, 143),
		borderColor = Color3.fromRGB(70, 175, 230),
		callback = function()
			if onTrainingCallback then
				onTrainingCallback()
			end
		end,
	})

	-- PVP 卡片(红色)
	createButton(buttonContainer, {
		name = "PVPCard",
		icon = "⚔️⚔️",
		title = "PVP 匹配",
		description = "与其他玩家实时对战",
		bgColor = Color3.fromRGB(95, 30, 30),
		gradientTop = Color3.fromRGB(95, 30, 30),
		gradientBottom = Color3.fromRGB(143, 42, 42),
		borderColor = Color3.fromRGB(255, 80, 80),
		callback = function()
			if onPVPCallback then
				onPVPCallback()
			end
		end,
	})

	-- 底部提示
	local tipLabel = Instance.new("TextLabel")
	tipLabel.Name = "Tip"
	tipLabel.Size = UDim2.new(1, 0, 0, 20)
	tipLabel.Position = UDim2.new(0, 0, 0.75, 0)
	tipLabel.BackgroundTransparency = 1
	tipLabel.Text = "💡 选择模式后将进入英雄选择"
	tipLabel.TextSize = 13
	tipLabel.Font = Enum.Font.Gotham
	tipLabel.TextColor3 = UITheme.TEXT_MID
	tipLabel.ZIndex = 3
	tipLabel.Parent = mainFrame

	print("[UI_LobbyPanel] Initialized")
end

-- ========== Show / Hide ==========
function UI_LobbyPanel.Show()
	if not screenGui then
		UI_LobbyPanel.Init()
	end
	screenGui.Enabled = true

	-- 渐入动画
	if mainFrame then
		mainFrame.Position = UDim2.new(0, 0, 0.05, 0)
		TweenService:Create(mainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = UDim2.new(0, 0, 0, 0),
		}):Play()
	end
end

function UI_LobbyPanel.Hide()
	if not screenGui then return end

	-- 渐出动画
	if mainFrame then
		local tween = TweenService:Create(mainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(0, 0, 0.05, 0),
		})
		tween:Play()
		tween.Completed:Connect(function()
			if screenGui then
				screenGui.Enabled = false
			end
		end)
	else
		screenGui.Enabled = false
	end
end

-- ========== 回调注册 ==========
function UI_LobbyPanel.OnTrainingClicked(callback)
	onTrainingCallback = callback
end

function UI_LobbyPanel.OnPVPClicked(callback)
	onPVPCallback = callback
end

-- ========== Destroy ==========
function UI_LobbyPanel.Destroy()
	if screenGui then
		screenGui:Destroy()
		screenGui = nil
		mainFrame = nil
	end
end

return UI_LobbyPanel
