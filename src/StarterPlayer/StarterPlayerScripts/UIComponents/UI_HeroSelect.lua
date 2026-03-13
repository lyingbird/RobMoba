--[[
	UI_HeroSelect - 英雄选择界面（大厅模式）
	REQ-004: 进入后首次弹出全屏选人，选完后左下角显示小面板可随时重新打开
	锁定后通过 HeroSwapEvent 通知服务端
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

local selectedHeroID = nil    -- 当前预选（面板中点击的）
local confirmedHeroID = nil   -- 已确认的英雄（锁定后）
local heroCards = {}
local lockBtn = nil
local closeBtn = nil
local screenGui = nil         -- 全屏选人面板
local miniPanelGui = nil      -- 左下角小面板
local miniHeroLabel = nil
local miniAvatarLabel = nil
local isLocked = false
local isShowing = false       -- 全屏面板是否正在显示
local onHeroConfirmed = nil   -- 英雄确认后的回调函数

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
	initial.Text = string.sub(heroData.DisplayName, 1, 3)
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
		-- 已锁定则不允许更换（正在确认中）
		if isLocked then return end

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
		if lockBtn then
			lockBtn.BackgroundColor3 = heroData.Theme
			lockBtn.TextTransparency = 0
			lockBtn.Active = true
			-- 如果是切换英雄（已有confirmedHeroID），按钮文字改为"确认切换"
			if confirmedHeroID then
				if heroKey == confirmedHeroID then
					lockBtn.Text = "✅ 当前英雄"
					lockBtn.Active = false
					lockBtn.TextTransparency = 0.3
				else
					lockBtn.Text = "🔄 确认切换"
				end
			else
				lockBtn.Text = "🔒 锁定选择"
			end
		end
	end)

	-- hover效果
	clickBtn.MouseEnter:Connect(function()
		if selectedHeroID ~= heroKey and not isLocked then
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

-- ========== 更新左下角小面板 ==========
local function updateMiniPanel()
	if not miniPanelGui or not confirmedHeroID then return end
	local heroData = HeroConfig[confirmedHeroID]
	if not heroData then return end

	if miniAvatarLabel then
		miniAvatarLabel.Text = string.sub(heroData.DisplayName, 1, 3)
		miniAvatarLabel.Parent.BackgroundColor3 = heroData.Theme
	end
	if miniHeroLabel then
		miniHeroLabel.Text = heroData.DisplayName
	end
end

-- ========== 创建左下角小面板 ==========
local function createMiniPanel()
	if miniPanelGui then return end

	miniPanelGui = Instance.new("ScreenGui")
	miniPanelGui.Name = "HeroMiniPanel"
	miniPanelGui.DisplayOrder = 6
	miniPanelGui.ResetOnSpawn = false
	miniPanelGui.Parent = playerGui

	-- 小面板容器
	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Size = UDim2.new(0, 160, 0, 50)
	panel.Position = UDim2.new(0, 10, 1, -130)
	panel.BackgroundColor3 = Color3.fromRGB(20, 24, 36)
	panel.BackgroundTransparency = 0.15
	panel.BorderSizePixel = 0
	panel.Parent = miniPanelGui
	Theme.corner(panel, 10)
	Theme.shadow(panel, 3, 12)

	local panelStroke = Instance.new("UIStroke")
	panelStroke.Color = Color3.fromRGB(60, 70, 100)
	panelStroke.Thickness = 1
	panelStroke.Transparency = 0.5
	panelStroke.Parent = panel

	-- 圆形头像
	local avatarBg = Instance.new("Frame")
	avatarBg.Size = UDim2.new(0, 36, 0, 36)
	avatarBg.Position = UDim2.new(0, 8, 0.5, -18)
	avatarBg.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
	avatarBg.BorderSizePixel = 0
	avatarBg.Parent = panel
	Theme.corner(avatarBg, 18)

	miniAvatarLabel = Instance.new("TextLabel")
	miniAvatarLabel.Size = UDim2.new(1, 0, 1, 0)
	miniAvatarLabel.BackgroundTransparency = 1
	miniAvatarLabel.Text = "?"
	miniAvatarLabel.TextColor3 = Color3.new(1, 1, 1)
	miniAvatarLabel.TextSize = 14
	miniAvatarLabel.Font = Enum.Font.GothamBold
	miniAvatarLabel.Parent = avatarBg

	-- 英雄名字
	miniHeroLabel = Instance.new("TextLabel")
	miniHeroLabel.Size = UDim2.new(0, 60, 0, 20)
	miniHeroLabel.Position = UDim2.new(0, 50, 0, 6)
	miniHeroLabel.BackgroundTransparency = 1
	miniHeroLabel.Text = "未选择"
	miniHeroLabel.TextColor3 = Theme.TEXT_WHITE
	miniHeroLabel.TextSize = 13
	miniHeroLabel.TextXAlignment = Enum.TextXAlignment.Left
	miniHeroLabel.Font = Enum.Font.GothamBold
	miniHeroLabel.Parent = panel

	-- "切换▼"按钮
	local switchBtn = Instance.new("TextButton")
	switchBtn.Size = UDim2.new(0, 56, 0, 18)
	switchBtn.Position = UDim2.new(0, 50, 0, 27)
	switchBtn.BackgroundColor3 = Color3.fromRGB(40, 90, 180)
	switchBtn.BorderSizePixel = 0
	switchBtn.Text = "切换 ▼"
	switchBtn.TextColor3 = Color3.new(1, 1, 1)
	switchBtn.TextSize = 11
	switchBtn.Font = Enum.Font.GothamMedium
	switchBtn.Parent = panel
	Theme.corner(switchBtn, 6)

	switchBtn.MouseButton1Click:Connect(function()
		if not isShowing then
			UI_HeroSelect.Show(9999)
		end
	end)

	updateMiniPanel()
end

--- 显示英雄选择界面（大厅模式）
--- @param heroSelectTime number 倒计时秒数（9999=无限）
function UI_HeroSelect.Show(heroSelectTime)
	-- 如果已经在显示，不重复创建
	if isShowing and screenGui and screenGui.Parent then return end

	selectedHeroID = nil
	heroCards = {}
	isLocked = false
	isShowing = true

	local isFirstPick = (confirmedHeroID == nil) -- 首次选择 vs 切换英雄

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
	bg.Name = "Background"
	bg.Size = UDim2.new(1, 0, 1, 0)
	bg.BackgroundColor3 = Color3.fromRGB(8, 10, 18)
	bg.BackgroundTransparency = isFirstPick and 0.15 or 0.3
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
	title.Text = isFirstPick and "选择英雄" or "切换英雄"
	title.TextColor3 = Theme.TEXT_WHITE
	title.TextSize = 36
	title.Font = Enum.Font.GothamBold
	title.Parent = bg

	local subtitle = Instance.new("TextLabel")
	subtitle.Size = UDim2.new(1, 0, 0, 24)
	subtitle.Position = UDim2.new(0, 0, 0, 95)
	subtitle.BackgroundTransparency = 1
	subtitle.Text = isFirstPick and "SELECT YOUR HERO" or "SWITCH HERO"
	subtitle.TextColor3 = Theme.TEXT_MID
	subtitle.TextSize = 14
	subtitle.Font = Enum.Font.GothamMedium
	subtitle.Parent = bg

	-- 关闭按钮（切换模式下才有，首次必须选择）
	if not isFirstPick then
		closeBtn = Instance.new("TextButton")
		closeBtn.Name = "CloseBtn"
		closeBtn.Size = UDim2.new(0, 40, 0, 40)
		closeBtn.Position = UDim2.new(1, -60, 0, 30)
		closeBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
		closeBtn.BorderSizePixel = 0
		closeBtn.Text = "✕"
		closeBtn.TextColor3 = Color3.new(1, 1, 1)
		closeBtn.TextSize = 22
		closeBtn.Font = Enum.Font.GothamBold
		closeBtn.Parent = bg
		Theme.corner(closeBtn, 20)

		closeBtn.MouseButton1Click:Connect(function()
			UI_HeroSelect.Hide()
		end)
	end

	-- 倒计时显示（首次选择时右上角显示，切换模式不显示）
	if isFirstPick then
		local countdownText = Instance.new("TextLabel")
		countdownText.Name = "Countdown"
		countdownText.Size = UDim2.new(0, 80, 0, 50)
		countdownText.Position = UDim2.new(1, -100, 0, 30)
		countdownText.BackgroundTransparency = 1
		countdownText.Text = tostring(heroSelectTime or 30)
		countdownText.TextColor3 = Color3.fromRGB(255, 200, 80)
		countdownText.TextSize = 36
		countdownText.Font = Enum.Font.GothamBold
		countdownText.Parent = bg

		-- 倒计时动画
		local timeLeft = heroSelectTime or 30
		task.spawn(function()
			while timeLeft > 0 and screenGui and screenGui.Parent do
				countdownText.Text = tostring(math.ceil(timeLeft))
				if timeLeft <= 5 then
					countdownText.TextColor3 = Color3.fromRGB(255, 80, 80)
				end
				task.wait(1)
				timeLeft = timeLeft - 1
			end
			if countdownText then
				countdownText.Text = "0"
			end
		end)
	end

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

	-- 高亮当前已确认的英雄（切换模式下）
	if confirmedHeroID and heroCards[confirmedHeroID] then
		local currentCard = heroCards[confirmedHeroID].card
		local b = currentCard:FindFirstChild("Border")
		if b then
			b.Thickness = 3
			b.Transparency = 0
			b.Color = Color3.fromRGB(80, 220, 120) -- 绿色表示当前
		end
	end

	-- 确认/锁定按钮
	lockBtn = Instance.new("TextButton")
	lockBtn.Name = "LockBtn"
	lockBtn.Size = UDim2.new(0, 240, 0, 50)
	lockBtn.Position = UDim2.new(0.5, -120, 1, -110)
	lockBtn.BackgroundColor3 = Theme.SLOT_BORDER
	lockBtn.BorderSizePixel = 0
	lockBtn.Text = isFirstPick and "🔒 锁定选择" or "🔄 确认切换"
	lockBtn.TextColor3 = Theme.TEXT_WHITE
	lockBtn.TextSize = 20
	lockBtn.Font = Enum.Font.GothamBold
	lockBtn.TextTransparency = 0.5
	lockBtn.Active = false
	lockBtn.Parent = bg
	Theme.corner(lockBtn, 10)
	Theme.shadow(lockBtn, 4, 16)

	-- 确认按钮点击
	lockBtn.MouseButton1Click:Connect(function()
		if not selectedHeroID or isLocked then return end
		-- 如果选的是当前英雄，直接关闭
		if selectedHeroID == confirmedHeroID then
			UI_HeroSelect.Hide()
			return
		end

		isLocked = true
		confirmedHeroID = selectedHeroID

		-- UI反馈
		lockBtn.Text = "✅ 已确认"
		lockBtn.Active = false
		lockBtn.BackgroundColor3 = Color3.fromRGB(60, 120, 60)

		print("[UI_HeroSelect] Confirmed hero:", confirmedHeroID)

		-- 更新小面板
		updateMiniPanel()

		-- 触发回调
		if onHeroConfirmed then
			onHeroConfirmed(confirmedHeroID)
		end

		-- 延迟关闭面板
		task.delay(0.5, function()
			UI_HeroSelect.Hide()
		end)
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
end

--- 设置英雄确认后的回调
--- @param callback function(heroId: string)
function UI_HeroSelect.OnHeroConfirmed(callback)
	onHeroConfirmed = callback
end

--- 获取锁定的英雄ID（首次选择兼容）
function UI_HeroSelect.GetLockedHero()
	return confirmedHeroID
end

--- 获取当前已确认的英雄
function UI_HeroSelect.GetConfirmedHero()
	return confirmedHeroID
end

--- 面板是否正在显示
function UI_HeroSelect.IsShowing()
	return isShowing
end

--- 显示左下角小面板
function UI_HeroSelect.ShowMiniPanel()
	createMiniPanel()
	if miniPanelGui then
		miniPanelGui.Enabled = true
	end
end

--- 隐藏左下角小面板
function UI_HeroSelect.HideMiniPanel()
	if miniPanelGui then
		miniPanelGui.Enabled = false
	end
end

--- 关闭英雄选择界面（全屏面板）
function UI_HeroSelect.Hide()
	isShowing = false

	if screenGui then
		-- 退出动画
		local bg = screenGui:FindFirstChild("Background")
		if bg then
			TweenService:Create(bg, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				BackgroundTransparency = 1,
			}):Play()
		end
		for _, heroKey in ipairs(HERO_ORDER) do
			local data = heroCards[heroKey]
			if data and data.card then
				TweenService:Create(data.card, TweenInfo.new(0.3), {
					BackgroundTransparency = 1,
				}):Play()
			end
		end
		if lockBtn then
			TweenService:Create(lockBtn, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
		end
		task.delay(0.45, function()
			if screenGui then
				screenGui:Destroy()
				screenGui = nil
			end
		end)
	end
end

return UI_HeroSelect
