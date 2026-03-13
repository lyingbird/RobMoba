--[[
	UI_HeroSelect - 英雄选择界面
	开局显示，选完英雄后回调通知主系统
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Theme = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("UITheme"))
local HeroConfig = require(ReplicatedStorage:WaitForChild("HeroConfig"))
local SkillConfig = require(ReplicatedStorage:WaitForChild("SkillConfig"))

local UI_HeroSelect = {}

local selectedHeroID = nil
local heroCards = {}
local confirmBtn = nil
local screenGui = nil

-- 英雄显示顺序
local HERO_ORDER = { "Angela", "Lux", "HouYi", "LianPo", "Test" }

local function createSkillIcon(parent, skillID, size)
	local data = SkillConfig[skillID]
	if not data then return end

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0, size, 0, size)
	frame.BackgroundColor3 = Theme.SLOT_BG
	frame.BorderSizePixel = 0
	frame.Parent = parent
	Theme.corner(frame, 6)

	if data.Icon and data.Icon ~= "" then
		local icon = Instance.new("ImageLabel")
		icon.Size = UDim2.new(1, -4, 1, -4)
		icon.Position = UDim2.new(0, 2, 0, 2)
		icon.BackgroundTransparency = 1
		icon.Image = data.Icon
		icon.ScaleType = Enum.ScaleType.Fit
		icon.Parent = frame
		Theme.corner(icon, 4)
	end

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, 0, 0, 14)
	nameLabel.Position = UDim2.new(0, 0, 1, 2)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = data.UIName or data.Name
	nameLabel.TextColor3 = Theme.TEXT_LIGHT
	nameLabel.TextSize = 10
	nameLabel.Font = Enum.Font.GothamMedium
	nameLabel.Parent = frame

	return frame
end

local function createHeroCard(heroKey, heroData, parent)
	local card = Instance.new("Frame")
	card.Name = "Card_" .. heroKey
	card.Size = UDim2.new(0, 180, 0, 280)
	card.BackgroundColor3 = Theme.HUD_BG
	card.BackgroundTransparency = 0.1
	card.BorderSizePixel = 0
	card.Parent = parent
	Theme.corner(card, 12)
	Theme.shadow(card, 6, 24)

	-- 边框（英雄主题色）
	local border = Instance.new("UIStroke")
	border.Name = "Border"
	border.Color = heroData.Theme
	border.Thickness = 2
	border.Transparency = 0.5
	border.Parent = card

	-- 顶部主题色条
	local topBar = Instance.new("Frame")
	topBar.Size = UDim2.new(1, 0, 0, 6)
	topBar.Position = UDim2.new(0, 0, 0, 0)
	topBar.BackgroundColor3 = heroData.Theme
	topBar.BorderSizePixel = 0
	topBar.Parent = card
	local topCorner = Instance.new("UICorner")
	topCorner.CornerRadius = UDim.new(0, 12)
	topCorner.Parent = topBar

	-- 英雄头像区域（主题色圆形）
	local avatarFrame = Instance.new("Frame")
	avatarFrame.Size = UDim2.new(0, 80, 0, 80)
	avatarFrame.Position = UDim2.new(0.5, -40, 0, 24)
	avatarFrame.BackgroundColor3 = heroData.Theme
	avatarFrame.BackgroundTransparency = 0.3
	avatarFrame.BorderSizePixel = 0
	avatarFrame.Parent = card
	Theme.corner(avatarFrame, 40)

	-- 英雄首字母
	local initial = Instance.new("TextLabel")
	initial.Size = UDim2.new(1, 0, 1, 0)
	initial.BackgroundTransparency = 1
	initial.Text = string.sub(heroData.DisplayName, 1, 3) -- 取前三个字
	initial.TextColor3 = Color3.new(1, 1, 1)
	initial.TextSize = 24
	initial.Font = Enum.Font.GothamBold
	initial.Parent = avatarFrame

	-- 英雄名称
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, 0, 0, 28)
	nameLabel.Position = UDim2.new(0, 0, 0, 110)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = heroData.DisplayName
	nameLabel.TextColor3 = Theme.TEXT_WHITE
	nameLabel.TextSize = 20
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Parent = card

	-- 英雄ID副标题
	local subLabel = Instance.new("TextLabel")
	subLabel.Size = UDim2.new(1, 0, 0, 18)
	subLabel.Position = UDim2.new(0, 0, 0, 136)
	subLabel.BackgroundTransparency = 1
	subLabel.Text = heroData.HeroID
	subLabel.TextColor3 = Theme.TEXT_MID
	subLabel.TextSize = 12
	subLabel.Font = Enum.Font.GothamMedium
	subLabel.Parent = card

	-- 技能图标行
	local skillRow = Instance.new("Frame")
	skillRow.Size = UDim2.new(1, -20, 0, 60)
	skillRow.Position = UDim2.new(0, 10, 0, 164)
	skillRow.BackgroundTransparency = 1
	skillRow.Parent = card

	local skillLayout = Instance.new("UIListLayout")
	skillLayout.FillDirection = Enum.FillDirection.Horizontal
	skillLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	skillLayout.Padding = UDim.new(0, 10)
	skillLayout.Parent = skillRow

	for _, key in ipairs({"Q", "W", "R"}) do
		local skillID = heroData.Skills[key]
		if skillID then
			createSkillIcon(skillRow, skillID, 42)
		end
	end

	-- 点击区域
	local clickBtn = Instance.new("TextButton")
	clickBtn.Size = UDim2.new(1, 0, 1, 0)
	clickBtn.BackgroundTransparency = 1
	clickBtn.Text = ""
	clickBtn.ZIndex = 10
	clickBtn.Parent = card

	clickBtn.MouseButton1Click:Connect(function()
		-- 取消之前的选中
		for key, data in pairs(heroCards) do
			local b = data.card:FindFirstChild("Border")
			if b then
				b.Thickness = 2
				b.Transparency = 0.5
			end
			data.card.BackgroundTransparency = 0.1
		end

		-- 选中当前
		selectedHeroID = heroKey
		border.Thickness = 3
		border.Transparency = 0
		card.BackgroundTransparency = 0.02

		-- 激活确认按钮
		if confirmBtn then
			confirmBtn.BackgroundColor3 = heroData.Theme
			confirmBtn.TextTransparency = 0
			confirmBtn.Active = true
		end
	end)

	-- hover效果
	clickBtn.MouseEnter:Connect(function()
		if selectedHeroID ~= heroKey then
			TweenService:Create(card, TweenInfo.new(0.15), {
				BackgroundTransparency = 0.05
			}):Play()
		end
	end)
	clickBtn.MouseLeave:Connect(function()
		if selectedHeroID ~= heroKey then
			TweenService:Create(card, TweenInfo.new(0.15), {
				BackgroundTransparency = 0.1
			}):Play()
		end
	end)

	return card
end

--- 显示英雄选择界面，返回选中的heroID (yield函数)
function UI_HeroSelect.Show()
	selectedHeroID = nil
	heroCards = {}

	-- 创建 ScreenGui
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "HeroSelectScreen"
	screenGui.DisplayOrder = 100
	screenGui.IgnoreGuiInset = true
	screenGui.ResetOnSpawn = false
	screenGui.Parent = playerGui
	Theme.autoScale(screenGui)

	-- 背景遮罩
	local bg = Instance.new("Frame")
	bg.Size = UDim2.new(1, 0, 1, 0)
	bg.BackgroundColor3 = Color3.fromRGB(8, 10, 18)
	bg.BackgroundTransparency = 0.15
	bg.BorderSizePixel = 0
	bg.Parent = screenGui

	-- 背景渐变
	local bgGrad = Instance.new("UIGradient")
	bgGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(15, 18, 30)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(25, 30, 45)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 12, 22)),
	})
	bgGrad.Rotation = 90
	bgGrad.Parent = bg

	-- 标题
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 60)
	title.Position = UDim2.new(0, 0, 0, 40)
	title.BackgroundTransparency = 1
	title.Text = "选择英雄"
	title.TextColor3 = Theme.TEXT_WHITE
	title.TextSize = 36
	title.Font = Enum.Font.GothamBold
	title.Parent = bg

	local subtitle = Instance.new("TextLabel")
	subtitle.Size = UDim2.new(1, 0, 0, 24)
	subtitle.Position = UDim2.new(0, 0, 0, 95)
	subtitle.BackgroundTransparency = 1
	subtitle.Text = "SELECT YOUR HERO"
	subtitle.TextColor3 = Theme.TEXT_MID
	subtitle.TextSize = 14
	subtitle.Font = Enum.Font.GothamMedium
	subtitle.Parent = bg

	-- 英雄卡片容器
	local cardContainer = Instance.new("Frame")
	cardContainer.Size = UDim2.new(1, 0, 0, 300)
	cardContainer.Position = UDim2.new(0, 0, 0.5, -170)
	cardContainer.BackgroundTransparency = 1
	cardContainer.Parent = bg

	local cardLayout = Instance.new("UIListLayout")
	cardLayout.FillDirection = Enum.FillDirection.Horizontal
	cardLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	cardLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	cardLayout.Padding = UDim.new(0, 24)
	cardLayout.Parent = cardContainer

	-- 创建英雄卡片
	for _, heroKey in ipairs(HERO_ORDER) do
		local heroData = HeroConfig[heroKey]
		if heroData then
			local card = createHeroCard(heroKey, heroData, cardContainer)
			heroCards[heroKey] = { card = card }
		end
	end

	-- 确认按钮
	confirmBtn = Instance.new("TextButton")
	confirmBtn.Size = UDim2.new(0, 240, 0, 50)
	confirmBtn.Position = UDim2.new(0.5, -120, 1, -100)
	confirmBtn.BackgroundColor3 = Theme.SLOT_BORDER
	confirmBtn.BorderSizePixel = 0
	confirmBtn.Text = "确认选择"
	confirmBtn.TextColor3 = Theme.TEXT_WHITE
	confirmBtn.TextSize = 20
	confirmBtn.Font = Enum.Font.GothamBold
	confirmBtn.TextTransparency = 0.5
	confirmBtn.Active = false
	confirmBtn.Parent = bg
	Theme.corner(confirmBtn, 10)
	Theme.shadow(confirmBtn, 4, 16)

	-- 等待确认
	local result = nil
	confirmBtn.MouseButton1Click:Connect(function()
		if selectedHeroID then
			result = selectedHeroID
		end
	end)

	-- 入场动画
	for _, heroKey in ipairs(HERO_ORDER) do
		local data = heroCards[heroKey]
		if data then
			data.card.Position = data.card.Position + UDim2.new(0, 0, 0, 40)
			data.card.BackgroundTransparency = 1
		end
	end
	for i, heroKey in ipairs(HERO_ORDER) do
		local data = heroCards[heroKey]
		if data then
			task.delay(i * 0.08, function()
				TweenService:Create(data.card, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
					BackgroundTransparency = 0.1,
				}):Play()
			end)
		end
	end

	-- yield等待结果
	while not result do
		task.wait(0.1)
	end

	-- 退出动画
	TweenService:Create(bg, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		BackgroundTransparency = 1,
	}):Play()
	for _, heroKey in ipairs(HERO_ORDER) do
		local data = heroCards[heroKey]
		if data then
			TweenService:Create(data.card, TweenInfo.new(0.3), {
				BackgroundTransparency = 1,
			}):Play()
		end
	end
	TweenService:Create(confirmBtn, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
	task.wait(0.45)
	screenGui:Destroy()
	screenGui = nil

	return result
end

function UI_HeroSelect.Hide()
	if screenGui then
		screenGui:Destroy()
		screenGui = nil
	end
end

return UI_HeroSelect
