--[[
	UI_MobileHUD.lua
	移动端战斗HUD: 顶部信息栏 + 击杀播报 + 复活倒计时
	REQ-011: 手机端MOBA UI与操控系统 (MOD-03)

	不修改现有 UI_HUD.lua，独立新文件
	数据源: Character Attributes (HP/MP) + DuelEvent + SyncEnergyEvent
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer

local MobileConfig = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("MobileConfig"))

local UI_MobileHUD = {}

-- 内部引用缓存
local hudFrame = nil
local topBar = nil
local hpBar = nil
local hpFill = nil
local hpValueLabel = nil  -- HP数值标签 "当前/最大"
local mpBar = nil
local mpFill = nil
local mpValueLabel = nil  -- MP数值标签
local levelLabel = nil
local heroIcon = nil       -- 英雄头像框
local timerLabel = nil
local scoreLabel = nil
local timerBg = nil        -- 倒计时背景面板
local killNotifyContainer = nil
local respawnOverlay = nil
local respawnCountLabel = nil

-- 状态
local connections = {}
local killQueue = {} -- 击杀播报队列
local lowHpTween = nil
local isVisible = false
local currentHP, currentMaxHP = 100, 100
local currentMP, currentMaxMP = 100, 100

-- ═══════════════════════════════════════
-- 内部工具函数
-- ═══════════════════════════════════════
local function getHPColor(ratio)
	if ratio > 0.6 then
		return MobileConfig.HP_COLOR_HIGH
	elseif ratio > 0.3 then
		-- 绿→黄 插值
		local t = (ratio - 0.3) / 0.3
		return MobileConfig.HP_COLOR_MID:Lerp(MobileConfig.HP_COLOR_HIGH, t)
	else
		return MobileConfig.HP_COLOR_LOW
	end
end

local function formatTime(seconds)
	local m = math.floor(seconds / 60)
	local s = math.floor(seconds % 60)
	return string.format("%02d:%02d", m, s)
end

-- ═══════════════════════════════════════
-- UI 创建
-- ═══════════════════════════════════════
local function createTopBar(parent)
	-- ═══ 整体容器（无背景，只做定位） ═══
	topBar = Instance.new("Frame")
	topBar.Name = "TopBar"
	topBar.Size = UDim2.new(1, 0, 0, 0) -- 高度=0, 纯做锚点
	topBar.Position = UDim2.new(0, 0, 0, 0)
	topBar.BackgroundTransparency = 1
	topBar.BorderSizePixel = 0
	topBar.ZIndex = 5
	topBar.Parent = parent

	-- ═══════════════════════════════════════════════
	-- 左上角: 英雄头像框 + 等级徽章 + HP/MP条
	-- 王者荣耀风格: 圆形头像在左, 右侧两条窄长血蓝条
	-- ═══════════════════════════════════════════════
	local ICON_SIZE = 48           -- 头像框像素大小
	local BAR_LEFT = ICON_SIZE + 6 -- 血条左起点(头像右侧留间距)
	local BAR_W = 160              -- 血条宽度(像素)
	local HP_H = 14                -- HP条高度
	local MP_H = 10                -- MP条高度
	local MARGIN_TOP = 8           -- 顶部安全边距
	local MARGIN_LEFT = 8          -- 左侧安全边距

	-- 英雄头像容器
	local avatarFrame = Instance.new("Frame")
	avatarFrame.Name = "AvatarFrame"
	avatarFrame.Size = UDim2.new(0, ICON_SIZE, 0, ICON_SIZE)
	avatarFrame.Position = UDim2.new(0, MARGIN_LEFT, 0, MARGIN_TOP)
	avatarFrame.BackgroundColor3 = Color3.fromRGB(18, 22, 36)
	avatarFrame.BackgroundTransparency = 0.1
	avatarFrame.BorderSizePixel = 0
	avatarFrame.ZIndex = 8
	avatarFrame.Parent = topBar

	local avatarCorner = Instance.new("UICorner")
	avatarCorner.CornerRadius = UDim.new(0.5, 0)
	avatarCorner.Parent = avatarFrame

	-- 头像金色外框
	local avatarStroke = Instance.new("UIStroke")
	avatarStroke.Color = Color3.fromRGB(200, 180, 100)
	avatarStroke.Thickness = 2.5
	avatarStroke.Transparency = 0.15
	avatarStroke.Parent = avatarFrame

	-- 头像文字(英雄首字母占位 — 后续可换 ImageLabel)
	heroIcon = Instance.new("TextLabel")
	heroIcon.Name = "HeroIcon"
	heroIcon.Size = UDim2.new(1, 0, 1, 0)
	heroIcon.BackgroundTransparency = 1
	heroIcon.Text = "?"
	heroIcon.TextColor3 = Color3.fromRGB(200, 180, 100)
	heroIcon.Font = Enum.Font.GothamBold
	heroIcon.TextScaled = true
	heroIcon.ZIndex = 9
	heroIcon.Parent = avatarFrame

	-- 等级徽章(头像右下角小圆)
	local LV_SIZE = 20
	levelLabel = Instance.new("TextLabel")
	levelLabel.Name = "LevelBadge"
	levelLabel.Size = UDim2.new(0, LV_SIZE, 0, LV_SIZE)
	levelLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	levelLabel.Position = UDim2.new(1, 0, 1, 0) -- 头像右下角
	levelLabel.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
	levelLabel.BackgroundTransparency = 0.1
	levelLabel.TextColor3 = Color3.fromRGB(255, 220, 120)
	levelLabel.Text = "1"
	levelLabel.TextScaled = true
	levelLabel.Font = Enum.Font.GothamBold
	levelLabel.ZIndex = 10
	levelLabel.BorderSizePixel = 0
	levelLabel.Parent = avatarFrame

	local lvCorner = Instance.new("UICorner")
	lvCorner.CornerRadius = UDim.new(0.5, 0)
	lvCorner.Parent = levelLabel

	local lvStroke = Instance.new("UIStroke")
	lvStroke.Color = Color3.fromRGB(200, 180, 100)
	lvStroke.Thickness = 1.5
	lvStroke.Parent = levelLabel

	-- ═══ HP 条 ═══
	local hpBg = Instance.new("Frame")
	hpBg.Name = "HPBackground"
	hpBg.Size = UDim2.new(0, BAR_W, 0, HP_H)
	hpBg.Position = UDim2.new(0, MARGIN_LEFT + BAR_LEFT, 0, MARGIN_TOP + 6)
	hpBg.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
	hpBg.BackgroundTransparency = 0.15
	hpBg.BorderSizePixel = 0
	hpBg.ZIndex = 6
	hpBg.ClipsDescendants = true
	hpBg.Parent = topBar

	local bgCorner = Instance.new("UICorner")
	bgCorner.CornerRadius = UDim.new(0, 4)
	bgCorner.Parent = hpBg

	-- HP条外描边
	local hpBgStroke = Instance.new("UIStroke")
	hpBgStroke.Color = Color3.fromRGB(60, 60, 70)
	hpBgStroke.Thickness = 1
	hpBgStroke.Transparency = 0.4
	hpBgStroke.Parent = hpBg

	hpFill = Instance.new("Frame")
	hpFill.Name = "HPFill"
	hpFill.Size = UDim2.new(1, 0, 1, 0)
	hpFill.BackgroundColor3 = Color3.fromRGB(60, 200, 80) -- 鲜绿
	hpFill.BorderSizePixel = 0
	hpFill.ZIndex = 7
	hpFill.Parent = hpBg

	local hpCorner = Instance.new("UICorner")
	hpCorner.CornerRadius = UDim.new(0, 4)
	hpCorner.Parent = hpFill

	-- HP 高光条(顶部1/3区域, 微弱亮光模拟立体感)
	local hpHighlight = Instance.new("Frame")
	hpHighlight.Name = "HPHighlight"
	hpHighlight.Size = UDim2.new(1, 0, 0.35, 0)
	hpHighlight.Position = UDim2.new(0, 0, 0, 0)
	hpHighlight.BackgroundColor3 = Color3.new(1, 1, 1)
	hpHighlight.BackgroundTransparency = 0.8
	hpHighlight.BorderSizePixel = 0
	hpHighlight.ZIndex = 8
	hpHighlight.Parent = hpFill

	-- HP 数值文字
	hpValueLabel = Instance.new("TextLabel")
	hpValueLabel.Name = "HPValue"
	hpValueLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	hpValueLabel.Position = UDim2.fromScale(0.5, 0.5)
	hpValueLabel.Size = UDim2.new(1, -4, 1, 0)
	hpValueLabel.BackgroundTransparency = 1
	hpValueLabel.Text = "100/100"
	hpValueLabel.TextColor3 = Color3.new(1, 1, 1)
	hpValueLabel.TextScaled = true
	hpValueLabel.Font = Enum.Font.GothamBold
	hpValueLabel.TextStrokeTransparency = 0.5
	hpValueLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	hpValueLabel.ZIndex = 9
	hpValueLabel.Parent = hpBg

	hpBar = hpBg

	-- ═══ MP 条 ═══
	local mpBg = Instance.new("Frame")
	mpBg.Name = "MPBackground"
	mpBg.Size = UDim2.new(0, BAR_W, 0, MP_H)
	mpBg.Position = UDim2.new(0, MARGIN_LEFT + BAR_LEFT, 0, MARGIN_TOP + 6 + HP_H + 3)
	mpBg.BackgroundColor3 = Color3.fromRGB(15, 15, 30)
	mpBg.BackgroundTransparency = 0.15
	mpBg.BorderSizePixel = 0
	mpBg.ZIndex = 6
	mpBg.ClipsDescendants = true
	mpBg.Parent = topBar

	local mpBgCorner = Instance.new("UICorner")
	mpBgCorner.CornerRadius = UDim.new(0, 3)
	mpBgCorner.Parent = mpBg

	local mpBgStroke = Instance.new("UIStroke")
	mpBgStroke.Color = Color3.fromRGB(40, 50, 80)
	mpBgStroke.Thickness = 1
	mpBgStroke.Transparency = 0.4
	mpBgStroke.Parent = mpBg

	mpFill = Instance.new("Frame")
	mpFill.Name = "MPFill"
	mpFill.Size = UDim2.new(1, 0, 1, 0)
	mpFill.BackgroundColor3 = Color3.fromRGB(60, 120, 255) -- 亮蓝
	mpFill.BorderSizePixel = 0
	mpFill.ZIndex = 7
	mpFill.Parent = mpBg

	local mpCorner = Instance.new("UICorner")
	mpCorner.CornerRadius = UDim.new(0, 3)
	mpCorner.Parent = mpFill

	-- MP 高光
	local mpHighlight = Instance.new("Frame")
	mpHighlight.Name = "MPHighlight"
	mpHighlight.Size = UDim2.new(1, 0, 0.35, 0)
	mpHighlight.Position = UDim2.new(0, 0, 0, 0)
	mpHighlight.BackgroundColor3 = Color3.new(1, 1, 1)
	mpHighlight.BackgroundTransparency = 0.82
	mpHighlight.BorderSizePixel = 0
	mpHighlight.ZIndex = 8
	mpHighlight.Parent = mpFill

	-- MP 数值文字
	mpValueLabel = Instance.new("TextLabel")
	mpValueLabel.Name = "MPValue"
	mpValueLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	mpValueLabel.Position = UDim2.fromScale(0.5, 0.5)
	mpValueLabel.Size = UDim2.new(1, -4, 1, 0)
	mpValueLabel.BackgroundTransparency = 1
	mpValueLabel.Text = "100/100"
	mpValueLabel.TextColor3 = Color3.new(1, 1, 1)
	mpValueLabel.TextScaled = true
	mpValueLabel.Font = Enum.Font.GothamBold
	mpValueLabel.TextStrokeTransparency = 0.5
	mpValueLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	mpValueLabel.ZIndex = 9
	mpValueLabel.Parent = mpBg

	mpBar = mpBg

	-- ═══════════════════════════════════════════════
	-- 顶部中央: 对局时间 + 击杀比分 (精致悬浮面板)
	-- ═══════════════════════════════════════════════
	timerBg = Instance.new("Frame")
	timerBg.Name = "TimerBg"
	timerBg.AnchorPoint = Vector2.new(0.5, 0)
	timerBg.Position = UDim2.new(0.5, 0, 0, 4)
	timerBg.Size = UDim2.new(0, 120, 0, 40)
	timerBg.BackgroundColor3 = Color3.fromRGB(10, 12, 24)
	timerBg.BackgroundTransparency = 0.25
	timerBg.BorderSizePixel = 0
	timerBg.ZIndex = 6
	timerBg.Parent = topBar

	local timerBgCorner = Instance.new("UICorner")
	timerBgCorner.CornerRadius = UDim.new(0, 8)
	timerBgCorner.Parent = timerBg

	local timerBgStroke = Instance.new("UIStroke")
	timerBgStroke.Color = Color3.fromRGB(80, 80, 100)
	timerBgStroke.Thickness = 1
	timerBgStroke.Transparency = 0.5
	timerBgStroke.Parent = timerBg

	-- 对局时间
	timerLabel = Instance.new("TextLabel")
	timerLabel.Name = "TimerLabel"
	timerLabel.AnchorPoint = Vector2.new(0.5, 0)
	timerLabel.Size = UDim2.new(1, 0, 0, 22)
	timerLabel.Position = UDim2.new(0.5, 0, 0, 2)
	timerLabel.BackgroundTransparency = 1
	timerLabel.TextColor3 = Color3.fromRGB(240, 230, 200)
	timerLabel.Text = "00:00"
	timerLabel.TextScaled = true
	timerLabel.Font = Enum.Font.GothamBold
	timerLabel.TextStrokeTransparency = 0.6
	timerLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	timerLabel.ZIndex = 7
	timerLabel.Parent = timerBg

	-- 击杀比分
	scoreLabel = Instance.new("TextLabel")
	scoreLabel.Name = "ScoreLabel"
	scoreLabel.AnchorPoint = Vector2.new(0.5, 0)
	scoreLabel.Size = UDim2.new(1, 0, 0, 14)
	scoreLabel.Position = UDim2.new(0.5, 0, 0, 24)
	scoreLabel.BackgroundTransparency = 1
	scoreLabel.TextColor3 = Color3.fromRGB(180, 180, 190)
	scoreLabel.Text = "0 vs 0"
	scoreLabel.TextScaled = true
	scoreLabel.Font = Enum.Font.Gotham
	scoreLabel.TextStrokeTransparency = 0.7
	scoreLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	scoreLabel.ZIndex = 7
	scoreLabel.Parent = timerBg
end

local function createKillNotifyArea(parent)
	killNotifyContainer = Instance.new("Frame")
	killNotifyContainer.Name = "KillNotifyContainer"
	killNotifyContainer.AnchorPoint = Vector2.new(0.5, 0)
	killNotifyContainer.Size = UDim2.new(0, 300, 0, 60)
	killNotifyContainer.Position = UDim2.new(0.5, 0, 0, 50)
	killNotifyContainer.BackgroundTransparency = 1
	killNotifyContainer.ZIndex = 8
	killNotifyContainer.ClipsDescendants = true
	killNotifyContainer.Parent = parent

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.Parent = killNotifyContainer
end

local function createRespawnOverlay(parent)
	respawnOverlay = Instance.new("Frame")
	respawnOverlay.Name = "RespawnOverlay"
	respawnOverlay.Size = UDim2.new(1, 0, 1, 0)
	respawnOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	respawnOverlay.BackgroundTransparency = 0.45
	respawnOverlay.ZIndex = 20
	respawnOverlay.Visible = false
	respawnOverlay.Parent = parent

	-- 中心面板
	local panel = Instance.new("Frame")
	panel.Name = "RespawnPanel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.45)
	panel.Size = UDim2.new(0, 200, 0, 120)
	panel.BackgroundColor3 = Color3.fromRGB(15, 18, 30)
	panel.BackgroundTransparency = 0.2
	panel.BorderSizePixel = 0
	panel.ZIndex = 21
	panel.Parent = respawnOverlay

	local panelCorner = Instance.new("UICorner")
	panelCorner.CornerRadius = UDim.new(0, 12)
	panelCorner.Parent = panel

	local panelStroke = Instance.new("UIStroke")
	panelStroke.Color = Color3.fromRGB(100, 100, 140)
	panelStroke.Thickness = 1.5
	panelStroke.Transparency = 0.4
	panelStroke.Parent = panel

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "RespawnTitle"
	titleLabel.AnchorPoint = Vector2.new(0.5, 0)
	titleLabel.Size = UDim2.new(0.8, 0, 0, 24)
	titleLabel.Position = UDim2.new(0.5, 0, 0, 12)
	titleLabel.BackgroundTransparency = 1
	titleLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
	titleLabel.Text = "复活倒计时"
	titleLabel.TextScaled = true
	titleLabel.Font = Enum.Font.Gotham
	titleLabel.TextStrokeTransparency = 0.7
	titleLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	titleLabel.ZIndex = 22
	titleLabel.Parent = panel

	respawnCountLabel = Instance.new("TextLabel")
	respawnCountLabel.Name = "RespawnCount"
	respawnCountLabel.AnchorPoint = Vector2.new(0.5, 0)
	respawnCountLabel.Size = UDim2.new(0, 80, 0, 60)
	respawnCountLabel.Position = UDim2.new(0.5, 0, 0, 40)
	respawnCountLabel.BackgroundTransparency = 1
	respawnCountLabel.TextColor3 = Color3.fromRGB(255, 220, 120)
	respawnCountLabel.Text = "5"
	respawnCountLabel.TextScaled = true
	respawnCountLabel.Font = Enum.Font.GothamBold
	respawnCountLabel.TextStrokeTransparency = 0.4
	respawnCountLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	respawnCountLabel.ZIndex = 22
	respawnCountLabel.Parent = panel
end

-- ═══════════════════════════════════════
-- Attribute 绑定
-- ═══════════════════════════════════════
local function bindCharacterAttributes()
	-- 清理旧连接
	for _, conn in ipairs(connections) do
		conn:Disconnect()
	end
	connections = {}

	local character = player.Character
	if not character then return end

	-- HP 监听
	local hpConn = character:GetAttributeChangedSignal("HP"):Connect(function()
		local hp = character:GetAttribute("HP") or 0
		local maxHp = character:GetAttribute("MaxHP") or 100
		UI_MobileHUD.UpdateHP(hp, maxHp)
	end)
	table.insert(connections, hpConn)

	-- MP/Energy 监听
	local mpConn = character:GetAttributeChangedSignal("MP"):Connect(function()
		local mp = character:GetAttribute("MP") or 0
		local maxMp = character:GetAttribute("MaxMP") or 100
		UI_MobileHUD.UpdateMP(mp, maxMp)
	end)
	table.insert(connections, mpConn)

	-- Level 监听
	local lvConn = character:GetAttributeChangedSignal("Level"):Connect(function()
		local lv = character:GetAttribute("Level") or 1
		UI_MobileHUD.UpdateLevel(lv)
	end)
	table.insert(connections, lvConn)

	-- 初始赋值
	local hp = character:GetAttribute("HP") or 100
	local maxHp = character:GetAttribute("MaxHP") or 100
	local mp = character:GetAttribute("MP") or 100
	local maxMp = character:GetAttribute("MaxMP") or 100
	local lv = character:GetAttribute("Level") or 1
	UI_MobileHUD.UpdateHP(hp, maxHp)
	UI_MobileHUD.UpdateMP(mp, maxMp)
	UI_MobileHUD.UpdateLevel(lv)
end

-- ═══════════════════════════════════════
-- 公共 API
-- ═══════════════════════════════════════
function UI_MobileHUD.Init(parentFrame)
	hudFrame = Instance.new("Frame")
	hudFrame.Name = "MobileHUD"
	hudFrame.Size = UDim2.new(1, 0, 1, 0)
	hudFrame.BackgroundTransparency = 1
	hudFrame.ZIndex = 5
	hudFrame.Visible = false -- 默认大厅隐藏, 对决开始时显示
	hudFrame.Parent = parentFrame

	createTopBar(hudFrame)
	createKillNotifyArea(hudFrame)
	createRespawnOverlay(hudFrame)

	-- 绑定角色属性
	bindCharacterAttributes()

	-- 角色重生时重新绑定
	local charConn = player.CharacterAdded:Connect(function(character)
		character:WaitForChild("Humanoid")
		task.wait(0.2) -- 等待 Attributes 就绪
		bindCharacterAttributes()
		UI_MobileHUD.HideRespawnCountdown()
	end)
	table.insert(connections, charConn)

	-- 监听DuelEvent (对局时间、击杀通知)
	local duelEvent = ReplicatedStorage:FindFirstChild("DuelEvent")
	if duelEvent then
		local duelConn = duelEvent.OnClientEvent:Connect(function(data)
			if not data or not data.type then return end

			if data.type == "timer" and data.seconds then
				UI_MobileHUD.UpdateTimer(data.seconds)
			elseif data.type == "kill" and data.killer and data.victim then
				UI_MobileHUD.ShowKillNotification(data.killer, data.victim)
			elseif data.type == "score" and data.red and data.blue then
				UI_MobileHUD.UpdateScore(data.red, data.blue)
			elseif data.type == "start" then
				UI_MobileHUD.SetVisible(true)
			elseif data.type == "result" then
				task.delay(5, function()
					UI_MobileHUD.SetVisible(false)
				end)
			end
		end)
		table.insert(connections, duelConn)
	end
end

function UI_MobileHUD.UpdateHP(current, max)
	if not hpFill then return end
	currentHP = current
	currentMaxHP = max
	local ratio = (max > 0) and (current / max) or 0
	ratio = math.clamp(ratio, 0, 1)

	-- 数值标签
	if hpValueLabel then
		hpValueLabel.Text = string.format("%d/%d", math.floor(current), math.floor(max))
	end

	-- 平滑动画
	local tweenInfo = TweenInfo.new(MobileConfig.HP_CHANGE_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(hpFill, tweenInfo, {
		Size = UDim2.new(ratio, 0, 1, 0),
		BackgroundColor3 = getHPColor(ratio),
	}):Play()

	-- 低HP闪烁
	if ratio < 0.3 then
		if not lowHpTween then
			lowHpTween = TweenService:Create(hpFill, TweenInfo.new(
				MobileConfig.RESPAWN_PULSE_TIME / 2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true
			), { BackgroundTransparency = 0.4 })
			lowHpTween:Play()
		end
	else
		if lowHpTween then
			lowHpTween:Cancel()
			lowHpTween = nil
			hpFill.BackgroundTransparency = 0
		end
	end
end

function UI_MobileHUD.UpdateMP(current, max)
	if not mpFill then return end
	currentMP = current
	currentMaxMP = max
	local ratio = (max > 0) and (current / max) or 0
	ratio = math.clamp(ratio, 0, 1)

	-- 数值标签
	if mpValueLabel then
		mpValueLabel.Text = string.format("%d/%d", math.floor(current), math.floor(max))
	end

	local tweenInfo = TweenInfo.new(MobileConfig.HP_CHANGE_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(mpFill, tweenInfo, {
		Size = UDim2.new(ratio, 0, 1, 0),
	}):Play()
end

function UI_MobileHUD.UpdateLevel(level)
	if levelLabel then
		levelLabel.Text = tostring(level)
	end
end

function UI_MobileHUD.UpdateTimer(timeSeconds)
	if timerLabel then
		timerLabel.Text = formatTime(timeSeconds)
	end
end

function UI_MobileHUD.UpdateScore(redKills, blueKills)
	if scoreLabel then
		scoreLabel.Text = tostring(redKills) .. " vs " .. tostring(blueKills)
	end
end

--- 显示/隐藏对局信息（训练场不需要倒计时/比分/TopBar背景）
function UI_MobileHUD.SetTimerVisible(visible)
	if timerBg then timerBg.Visible = visible end
end

function UI_MobileHUD.ShowKillNotification(killerName, victimName)
	if not killNotifyContainer then return end

	-- 控制最大堆叠数
	local children = killNotifyContainer:GetChildren()
	local notifyCount = 0
	for _, child in ipairs(children) do
		if child:IsA("Frame") then
			notifyCount = notifyCount + 1
		end
	end
	-- 超过最大数时移除最旧的
	if notifyCount >= MobileConfig.KILL_NOTIFY_MAX_STACK then
		for _, child in ipairs(children) do
			if child:IsA("Frame") then
				child:Destroy()
				break
			end
		end
	end

	-- 创建通知条
	local notify = Instance.new("Frame")
	notify.Name = "KillNotify"
	notify.Size = UDim2.new(1, 0, 0, 26)
	notify.BackgroundColor3 = Color3.fromRGB(15, 18, 30)
	notify.BackgroundTransparency = 0.2
	notify.BorderSizePixel = 0
	notify.ZIndex = 9
	notify.Parent = killNotifyContainer

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = notify

	local notifyStroke = Instance.new("UIStroke")
	notifyStroke.Color = Color3.fromRGB(255, 80, 80)
	notifyStroke.Thickness = 1
	notifyStroke.Transparency = 0.5
	notifyStroke.Parent = notify

	local text = Instance.new("TextLabel")
	text.Name = "KillText"
	text.AnchorPoint = Vector2.new(0.5, 0.5)
	text.Position = UDim2.fromScale(0.5, 0.5)
	text.Size = UDim2.new(0.9, 0, 0.8, 0)
	text.BackgroundTransparency = 1
	text.TextColor3 = Color3.new(1, 1, 1)
	text.Text = killerName .. " 击杀了 " .. victimName
	text.TextScaled = true
	text.Font = Enum.Font.GothamBold
	text.TextStrokeTransparency = 0.5
	text.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	text.ZIndex = 10
	text.Parent = notify

	-- 滑入动画
	notify.Position = UDim2.new(0, 0, -0.5, 0)
	TweenService:Create(notify, TweenInfo.new(MobileConfig.KILL_SLIDE_IN_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0, 0, 0, 0),
	}):Play()

	-- 停留后淡出
	task.delay(MobileConfig.KILL_NOTIFY_DURATION, function()
		if notify and notify.Parent then
			local fadeOut = TweenService:Create(notify, TweenInfo.new(MobileConfig.KILL_FADE_OUT_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				BackgroundTransparency = 1,
			})
			TweenService:Create(text, TweenInfo.new(MobileConfig.KILL_FADE_OUT_TIME), {
				TextTransparency = 1,
				TextStrokeTransparency = 1,
			}):Play()
			local strokeRef = notify:FindFirstChildWhichIsA("UIStroke")
			if strokeRef then
				TweenService:Create(strokeRef, TweenInfo.new(MobileConfig.KILL_FADE_OUT_TIME), {
					Transparency = 1,
				}):Play()
			end
			fadeOut:Play()
			fadeOut.Completed:Connect(function()
				if notify and notify.Parent then
					notify:Destroy()
				end
			end)
		end
	end)
end

function UI_MobileHUD.ShowRespawnCountdown(seconds)
	if not respawnOverlay then return end
	respawnOverlay.Visible = true

	-- 倒计时循环
	task.spawn(function()
		for i = math.ceil(seconds), 1, -1 do
			if not respawnOverlay or not respawnOverlay.Visible then break end
			respawnCountLabel.Text = tostring(i)

			-- 数字缩放脉冲
			respawnCountLabel.Size = UDim2.new(0, 90, 0, 70)
			TweenService:Create(respawnCountLabel, TweenInfo.new(
				MobileConfig.RESPAWN_PULSE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out
			), {
				Size = UDim2.new(0, 80, 0, 60),
			}):Play()

			task.wait(1)
		end
	end)
end

function UI_MobileHUD.HideRespawnCountdown()
	if respawnOverlay then
		respawnOverlay.Visible = false
	end
end

function UI_MobileHUD.SetHeroIcon(heroName)
	if heroIcon and heroName then
		heroIcon.Text = string.sub(heroName, 1, 1):upper()
	end
end

function UI_MobileHUD.SetVisible(visible)
	isVisible = visible
	if hudFrame then
		hudFrame.Visible = visible
	end
end

function UI_MobileHUD.Destroy()
	for _, conn in ipairs(connections) do
		conn:Disconnect()
	end
	connections = {}

	if lowHpTween then
		lowHpTween:Cancel()
		lowHpTween = nil
	end

	if hudFrame then
		hudFrame:Destroy()
		hudFrame = nil
	end
end

return UI_MobileHUD
