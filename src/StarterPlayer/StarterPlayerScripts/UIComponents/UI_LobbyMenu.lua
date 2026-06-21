--[[
	UI_LobbyMenu - 大厅主菜单组件
	REQ-002(重启): 游戏主流程重设计
	
	玩家进入游戏后以 avatar 形象在大厅漫游，
	屏幕显示两个主入口按钮："前往PVP" 和 "进入训练场"
	
	API:
	  .Init(parent)           -- 初始化，parent 为 ScreenGui/Frame
	  .Show()                 -- 显示主菜单
	  .Hide()                 -- 隐藏主菜单
	  .OnModeSelected(cb)     -- 注册模式选择回调 cb(mode: "pvp"|"training")
]]

local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local UI_LobbyMenu = {}

local screenGui = nil
local menuFrame = nil
local onModeSelected = nil  -- callback(mode)
local isVisible = false

--- 初始化大厅主菜单
--- @param isMobile boolean 是否移动端
function UI_LobbyMenu.Init(isMobile)
	if screenGui then return end

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "LobbyMenuScreen"
	screenGui.DisplayOrder = 8
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = false
	screenGui.Parent = playerGui

	-- 菜单容器 — 屏幕下方居中
	menuFrame = Instance.new("Frame")
	menuFrame.Name = "MenuFrame"
	menuFrame.AnchorPoint = Vector2.new(0.5, 1)

	if isMobile then
		-- 移动端：全屏居中大按钮
		menuFrame.Position = UDim2.new(0.5, 0, 0.88, 0)
		menuFrame.Size = UDim2.new(0.7, 0, 0.15, 0)
	else
		-- PC端：底部居中
		menuFrame.Position = UDim2.new(0.5, 0, 0.92, 0)
		menuFrame.Size = UDim2.new(0, 480, 0, 70)
	end

	menuFrame.BackgroundColor3 = Color3.fromRGB(10, 14, 24)
	menuFrame.BackgroundTransparency = 0.3
	menuFrame.BorderSizePixel = 0
	menuFrame.Parent = screenGui

	local menuCorner = Instance.new("UICorner")
	menuCorner.CornerRadius = UDim.new(0.15, 0)
	menuCorner.Parent = menuFrame

	local menuStroke = Instance.new("UIStroke")
	menuStroke.Color = Color3.fromRGB(60, 80, 140)
	menuStroke.Thickness = 1.5
	menuStroke.Transparency = 0.4
	menuStroke.Parent = menuFrame

	-- 水平布局
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0.04, 0)
	layout.Parent = menuFrame

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0.03, 0)
	padding.PaddingRight = UDim.new(0.03, 0)
	padding.PaddingTop = UDim.new(0.1, 0)
	padding.PaddingBottom = UDim.new(0.1, 0)
	padding.Parent = menuFrame

	-- PVP 按钮
	local pvpBtn = Instance.new("TextButton")
	pvpBtn.Name = "PvpBtn"
	pvpBtn.Size = UDim2.new(0.45, 0, 1, 0)
	pvpBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
	pvpBtn.BorderSizePixel = 0
	pvpBtn.Text = "⚔️ 前往PVP"
	pvpBtn.TextColor3 = Color3.new(1, 1, 1)
	pvpBtn.TextScaled = true
	pvpBtn.Font = Enum.Font.GothamBold
	pvpBtn.AutoButtonColor = false
	pvpBtn.Parent = menuFrame

	local pvpCorner = Instance.new("UICorner")
	pvpCorner.CornerRadius = UDim.new(0.2, 0)
	pvpCorner.Parent = pvpBtn

	local pvpStroke = Instance.new("UIStroke")
	pvpStroke.Color = Color3.fromRGB(255, 100, 100)
	pvpStroke.Thickness = 1.5
	pvpStroke.Transparency = 0.3
	pvpStroke.Parent = pvpBtn

	-- 文字约束
	local pvpTextConstraint = Instance.new("UITextSizeConstraint")
	pvpTextConstraint.MinTextSize = 12
	pvpTextConstraint.MaxTextSize = 28
	pvpTextConstraint.Parent = pvpBtn

	-- 训练场按钮
	local trainBtn = Instance.new("TextButton")
	trainBtn.Name = "TrainBtn"
	trainBtn.Size = UDim2.new(0.45, 0, 1, 0)
	trainBtn.BackgroundColor3 = Color3.fromRGB(40, 120, 60)
	trainBtn.BorderSizePixel = 0
	trainBtn.Text = "🏋️ 进入训练场"
	trainBtn.TextColor3 = Color3.new(1, 1, 1)
	trainBtn.TextScaled = true
	trainBtn.Font = Enum.Font.GothamBold
	trainBtn.AutoButtonColor = false
	trainBtn.Parent = menuFrame

	local trainCorner = Instance.new("UICorner")
	trainCorner.CornerRadius = UDim.new(0.2, 0)
	trainCorner.Parent = trainBtn

	local trainStroke = Instance.new("UIStroke")
	trainStroke.Color = Color3.fromRGB(80, 200, 100)
	trainStroke.Thickness = 1.5
	trainStroke.Transparency = 0.3
	trainStroke.Parent = trainBtn

	local trainTextConstraint = Instance.new("UITextSizeConstraint")
	trainTextConstraint.MinTextSize = 12
	trainTextConstraint.MaxTextSize = 28
	trainTextConstraint.Parent = trainBtn

	-- Hover 效果
	local function setupHover(btn, normalColor, hoverColor)
		btn.MouseEnter:Connect(function()
			TweenService:Create(btn, TweenInfo.new(0.15), {
				BackgroundColor3 = hoverColor
			}):Play()
		end)
		btn.MouseLeave:Connect(function()
			TweenService:Create(btn, TweenInfo.new(0.15), {
				BackgroundColor3 = normalColor
			}):Play()
		end)
	end

	setupHover(pvpBtn, Color3.fromRGB(180, 50, 50), Color3.fromRGB(220, 70, 70))
	setupHover(trainBtn, Color3.fromRGB(40, 120, 60), Color3.fromRGB(60, 160, 80))

	-- 点击事件
	pvpBtn.MouseButton1Click:Connect(function()
		if onModeSelected then
			onModeSelected("pvp")
		end
	end)

	trainBtn.MouseButton1Click:Connect(function()
		if onModeSelected then
			onModeSelected("training")
		end
	end)

	isVisible = true
	print("[UI_LobbyMenu] Initialized")
end

--- 显示主菜单
function UI_LobbyMenu.Show()
	if not screenGui then return end
	screenGui.Enabled = true
	isVisible = true

	-- 淡入动画
	if menuFrame then
		menuFrame.BackgroundTransparency = 1
		TweenService:Create(menuFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = 0.3
		}):Play()
	end
end

--- 隐藏主菜单
function UI_LobbyMenu.Hide()
	if not screenGui then return end
	screenGui.Enabled = false
	isVisible = false
end

--- 注册模式选择回调
--- @param callback function(mode: "pvp" | "training")
function UI_LobbyMenu.OnModeSelected(callback)
	onModeSelected = callback
end

--- 是否正在显示
function UI_LobbyMenu.IsVisible()
	return isVisible
end

return UI_LobbyMenu
