--[[
	UI_HeroSelect - 英雄选择界面（大厅模式）
	REQ-004: 进入后首次弹出全屏选人，选完后左下角显示小面板可随时重新打开
	锁定后通过 HeroSwapEvent 通知服务端
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Theme = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("UITheme"))
local HeroRegistry = require(ReplicatedStorage:WaitForChild("HeroRegistry"))
local SkillRegistry = require(ReplicatedStorage:WaitForChild("SkillRegistry"))

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

-- REQ-007: Tab 筛选相关
local currentTab = "All"
local tabButtons = {}
local cardContainer = nil     -- 卡片容器引用 (ScrollingFrame 内部)
local scrollFrame = nil       -- ScrollingFrame 引用

-- 职业映射
local ROLE_MAP = {
	Mage = "法师",
	Marksman = "射手",
	Tank = "坦克",
	Assassin = "刺客",
	Support = "辅助",
	Fighter = "战士",
}

-- Tab 定义
local TABS = {
	{ key = "All", label = "全部", role = nil },
	{ key = "Mage", label = "法师", role = "Mage" },
	{ key = "Marksman", label = "射手", role = "Marksman" },
	{ key = "Tank", label = "坦克", role = "Tank" },
	{ key = "Assassin", label = "刺客", role = "Assassin" },
	{ key = "Support", label = "辅助", role = "Support" },
	{ key = "Fighter", label = "战士", role = "Fighter" },
}

-- 英雄显示顺序：从 HeroRegistry 自动派生（过滤 Enabled，按 SortOrder 排序）
local HERO_ORDER = {}
do
	for heroName, heroData in pairs(HeroRegistry) do
		if heroData.Enabled ~= false then
			table.insert(HERO_ORDER, heroName)
		end
	end
	table.sort(HERO_ORDER, function(a, b)
		local sa = HeroRegistry[a].SortOrder or 999
		local sb = HeroRegistry[b].SortOrder or 999
		return sa < sb
	end)
end

local function createSkillIcon(parent, skillID, size)
	local data = SkillRegistry[skillID]
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
	card.Size = UDim2.new(0, 160, 0, 240)
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
	topBar.Size = UDim2.new(1, 0, 0, 5)
	topBar.Position = UDim2.new(0, 0, 0, 0)
	topBar.BackgroundColor3 = heroData.Theme
	topBar.BorderSizePixel = 0
	topBar.Parent = card
	local topCorner = Instance.new("UICorner")
	topCorner.CornerRadius = UDim.new(0, 12)
	topCorner.Parent = topBar

	-- 英雄头像区域（主题色圆形）
	local avatarFrame = Instance.new("Frame")
	avatarFrame.Size = UDim2.new(0, 64, 0, 64)
	avatarFrame.Position = UDim2.new(0.5, -32, 0, 16)
	avatarFrame.BackgroundColor3 = heroData.Theme
	avatarFrame.BackgroundTransparency = 0.3
	avatarFrame.BorderSizePixel = 0
	avatarFrame.Parent = card
	Theme.corner(avatarFrame, 32)

	-- 英雄首字母
	local initial = Instance.new("TextLabel")
	initial.Size = UDim2.new(1, 0, 1, 0)
	initial.BackgroundTransparency = 1
	initial.Text = string.sub(heroData.DisplayName, 1, 3)
	initial.TextColor3 = Color3.new(1, 1, 1)
	initial.TextSize = 20
	initial.Font = Enum.Font.GothamBold
	initial.Parent = avatarFrame

	-- 英雄名称
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, 0, 0, 22)
	nameLabel.Position = UDim2.new(0, 0, 0, 86)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = heroData.DisplayName
	nameLabel.TextColor3 = Theme.TEXT_WHITE
	nameLabel.TextSize = 16
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Parent = card

	-- REQ-007: 职业中文名
	local roleName = ROLE_MAP[heroData.Role] or heroData.Role or "未知"
	local roleLabel = Instance.new("TextLabel")
	roleLabel.Size = UDim2.new(1, 0, 0, 16)
	roleLabel.Position = UDim2.new(0, 0, 0, 108)
	roleLabel.BackgroundTransparency = 1
	roleLabel.Text = roleName
	roleLabel.TextColor3 = Theme.TEXT_MID
	roleLabel.TextSize = 10
	roleLabel.Font = Enum.Font.GothamMedium
	roleLabel.Parent = card

	-- REQ-007: 难度星级
	local difficulty = heroData.Difficulty or 1
	local starStr = string.rep("★", difficulty) .. string.rep("☆", 3 - difficulty)
	local starLabel = Instance.new("TextLabel")
	starLabel.Size = UDim2.new(1, 0, 0, 16)
	starLabel.Position = UDim2.new(0, 0, 0, 122)
	starLabel.BackgroundTransparency = 1
	starLabel.Text = starStr
	starLabel.TextColor3 = Color3.fromRGB(255, 200, 50)
	starLabel.TextSize = 12
	starLabel.Font = Enum.Font.GothamMedium
	starLabel.Parent = card

	-- 技能图标行
	local skillRow = Instance.new("Frame")
	skillRow.Size = UDim2.new(1, -16, 0, 50)
	skillRow.Position = UDim2.new(0, 8, 0, 142)
	skillRow.BackgroundTransparency = 1
	skillRow.Parent = card

	local skillLayout = Instance.new("UIListLayout")
	skillLayout.FillDirection = Enum.FillDirection.Horizontal
	skillLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	skillLayout.Padding = UDim.new(0, 8)
	skillLayout.Parent = skillRow

	for _, key in ipairs({"Q", "W", "R"}) do
		local skillID = heroData.Skills[key]
		if skillID then
			createSkillIcon(skillRow, skillID, 36)
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
	local heroData = HeroRegistry[confirmedHeroID]
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

	-- 小面板容器(右上角, 避免与左下角摇杆重叠)
	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Size = UDim2.new(0, 160, 0, 50)
	panel.Position = UDim2.new(1, -170, 0, 60)
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

	-- ========== 拖拽功能 (鼠标 + 触摸) ==========
	local dragging = false
	local dragStart = nil  -- Vector3: input.Position at drag start
	local panelStartPos = nil  -- UDim2: panel.Position at drag start
	local dragMoved = false  -- 区分拖拽和点击

	panel.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragMoved = false
			dragStart = input.Position
			panelStartPos = panel.Position
		end
	end)

	panel.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if not dragging then return end
		if input.UserInputType ~= Enum.UserInputType.MouseMovement
			and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		if not dragStart or not panelStartPos then return end

		local delta = input.Position - dragStart
		-- 超过 4px 才算拖拽（区分点击和拖拽）
		if math.abs(delta.X) > 4 or math.abs(delta.Y) > 4 then
			dragMoved = true
		end
		if dragMoved then
			panel.Position = UDim2.new(
				panelStartPos.X.Scale, panelStartPos.X.Offset + delta.X,
				panelStartPos.Y.Scale, panelStartPos.Y.Offset + delta.Y
			)
		end
	end)

	-- 全局 InputEnded 兜底：防止 panel 外松手导致拖拽卡住
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
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

	-- REQ-007: 职业 Tab 筛选栏
	local tabBar = Instance.new("Frame")
	tabBar.Name = "TabBar"
	tabBar.Size = UDim2.new(1, -100, 0, 36)
	tabBar.Position = UDim2.new(0, 50, 0, 128)
	tabBar.BackgroundTransparency = 1
	tabBar.Parent = bg

	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	tabLayout.Padding = UDim.new(0, 8)
	tabLayout.Parent = tabBar

	-- 统计每个职业的英雄数量
	local roleCounts = {}
	local totalCount = 0
	for _, heroKey in ipairs(HERO_ORDER) do
		local hd = HeroRegistry[heroKey]
		if hd then
			totalCount = totalCount + 1
			local role = hd.Role or "Unknown"
			roleCounts[role] = (roleCounts[role] or 0) + 1
		end
	end

	currentTab = "All"
	tabButtons = {}

	-- Tab 筛选函数
	local function applyFilter(tabKey)
		currentTab = tabKey
		local visibleCount = 0
		for heroKey, data in pairs(heroCards) do
			local hd = HeroRegistry[heroKey]
			if not hd then continue end
			local matchesTab = (tabKey == "All") or (hd.Role == tabKey)
			data.card.Visible = matchesTab
			if matchesTab then
				visibleCount = visibleCount + 1
			end
		end

		-- 更新 CanvasSize
		if scrollFrame then
			local cols = 5
			local rows = math.ceil(math.max(visibleCount, 1) / cols)
			scrollFrame.CanvasSize = UDim2.new(0, 0, 0, rows * (240 + 16) + 16)
			scrollFrame.CanvasPosition = Vector2.new(0, 0) -- 重置滚动位置
		end

		-- 更新 Tab 高亮
		for _, tb in pairs(tabButtons) do
			if tb.key == tabKey then
				tb.btn.BackgroundColor3 = Color3.fromRGB(60, 90, 180)
				tb.btn.BackgroundTransparency = 0
			else
				tb.btn.BackgroundColor3 = Color3.fromRGB(40, 45, 65)
				tb.btn.BackgroundTransparency = 0.3
			end
		end
	end

	for _, tabDef in ipairs(TABS) do
		local count = tabDef.role and (roleCounts[tabDef.role] or 0) or totalCount
		local hasHeroes = count > 0

		local tabBtn = Instance.new("TextButton")
		tabBtn.Size = UDim2.new(0, 90, 0, 30)
		tabBtn.BackgroundColor3 = Color3.fromRGB(40, 45, 65)
		tabBtn.BackgroundTransparency = 0.3
		tabBtn.BorderSizePixel = 0
		tabBtn.Text = tabDef.label .. "(" .. count .. ")"
		tabBtn.TextColor3 = hasHeroes and Theme.TEXT_WHITE or Color3.fromRGB(80, 80, 90)
		tabBtn.TextSize = 12
		tabBtn.Font = Enum.Font.GothamMedium
		tabBtn.Active = hasHeroes
		tabBtn.Parent = tabBar
		Theme.corner(tabBtn, 8)

		if hasHeroes then
			tabBtn.MouseButton1Click:Connect(function()
				applyFilter(tabDef.key)
			end)
		end

		table.insert(tabButtons, { key = tabDef.key, btn = tabBtn })
	end

	-- REQ-007: ScrollingFrame + UIGridLayout 卡片容器
	scrollFrame = Instance.new("ScrollingFrame")
	scrollFrame.Name = "HeroScrollFrame"
	scrollFrame.Size = UDim2.new(1, -60, 0.55, 0)
	scrollFrame.Position = UDim2.new(0, 30, 0, 172)
	scrollFrame.BackgroundTransparency = 1
	scrollFrame.BorderSizePixel = 0
	scrollFrame.ScrollBarThickness = 4
	scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 110, 140)
	scrollFrame.ScrollBarImageTransparency = 0.3
	scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0) -- 动态计算
	scrollFrame.Parent = bg

	cardContainer = Instance.new("Frame")
	cardContainer.Name = "CardContainer"
	cardContainer.Size = UDim2.new(1, 0, 1, 0)
	cardContainer.BackgroundTransparency = 1
	cardContainer.Parent = scrollFrame

	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.new(0, 160, 0, 240)
	gridLayout.CellPadding = UDim2.new(0, 16, 0, 16)
	gridLayout.FillDirectionMaxCells = 5
	gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = cardContainer

	-- 创建英雄卡片
	for idx, heroKey in ipairs(HERO_ORDER) do
		local heroData = HeroRegistry[heroKey]
		if heroData then
			local card = createHeroCard(heroKey, heroData, cardContainer)
			card.LayoutOrder = idx
			heroCards[heroKey] = { card = card }
		end
	end

	-- 初始化 Tab 为"全部"
	applyFilter("All")

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

	-- 入场动画 (简化版适配 Grid)
	for _, heroKey in ipairs(HERO_ORDER) do
		local data = heroCards[heroKey]
		if data then
			data.card.BackgroundTransparency = 1
		end
	end
	for i, heroKey in ipairs(HERO_ORDER) do
		local data = heroCards[heroKey]
		if data then
			task.delay(i * 0.05, function()
				if data.card and data.card.Parent then
					TweenService:Create(data.card, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
						BackgroundTransparency = 0.1,
					}):Play()
				end
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
