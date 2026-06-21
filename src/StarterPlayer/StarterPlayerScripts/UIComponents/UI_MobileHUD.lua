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
local EnergyConfig = require(ReplicatedStorage:WaitForChild("EnergyConfig"))

local UI_MobileHUD = {}


-- 内部引用缓存
local hudFrame = nil
local topBar = nil
local hpBar = nil
local hpFill = nil
local mpBar = nil
local mpFill = nil
local levelLabel = nil
local timerLabel = nil
local scoreLabel = nil
local killNotifyContainer = nil
local respawnOverlay = nil
local respawnCountLabel = nil

-- 状态
local connections = {}
local killQueue = {} -- 击杀播报队列
local lowHpTween = nil
local isVisible = false

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
	-- REQ-015: 王者荣耀标准顶部信息栏 (5区布局)
	-- 高度5%, 起始Y=SafeArea顶部之后
	topBar = Instance.new("Frame")
	topBar.Name = "TopBar"
	topBar.Size = UDim2.new(1, 0, 0.05, 0)
	topBar.Position = UDim2.new(0, 0, 0, MobileConfig.SAFE_AREA_TOP)
	topBar.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	topBar.BackgroundTransparency = 0.5
	topBar.BorderSizePixel = 0
	topBar.ZIndex = 5
	topBar.Parent = parent

	-- 左区(30%): 等级圆标 + HP条+数值(上行) + MP条+数值(下行)

	-- 等级标签(圆形)
	levelLabel = Instance.new("TextLabel")
	levelLabel.Name = "LevelLabel"
	levelLabel.Size = UDim2.new(0.03, 0, 0.7, 0)
	levelLabel.Position = UDim2.new(0.02, 0, 0.15, 0)
	levelLabel.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
	levelLabel.BackgroundTransparency = 0.3
	levelLabel.TextColor3 = Color3.new(1, 1, 1)
	levelLabel.Text = "1"
	levelLabel.TextScaled = true
	levelLabel.Font = Enum.Font.GothamBold
	levelLabel.ZIndex = 6
	levelLabel.BorderSizePixel = 0
	levelLabel.Parent = topBar

	local lvCorner = Instance.new("UICorner")
	lvCorner.CornerRadius = UDim.new(0.5, 0)
	lvCorner.Parent = levelLabel

	-- HP条
	local hpBg = Instance.new("Frame")
	hpBg.Name = "HPBackground"
	hpBg.Size = UDim2.new(MobileConfig.HP_BAR_WIDTH, 0, 0.35, 0)
	hpBg.Position = UDim2.new(0.06, 0, 0.1, 0)
	hpBg.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	hpBg.BorderSizePixel = 0
	hpBg.ZIndex = 6
	hpBg.Parent = topBar

	hpFill = Instance.new("Frame")
	hpFill.Name = "HPFill"
	hpFill.Size = UDim2.new(1, 0, 1, 0)
	hpFill.BackgroundColor3 = MobileConfig.HP_COLOR_HIGH
	hpFill.BorderSizePixel = 0
	hpFill.ZIndex = 7
	hpFill.Parent = hpBg

	local hpCorner = Instance.new("UICorner")
	hpCorner.CornerRadius = UDim.new(0, 3)
	hpCorner.Parent = hpFill

	local bgCorner = Instance.new("UICorner")
	bgCorner.CornerRadius = UDim.new(0, 3)
	bgCorner.Parent = hpBg

	hpBar = hpBg

	-- HP数值标签
	local hpText = Instance.new("TextLabel")
	hpText.Name = "HPText"
	hpText.Size = UDim2.new(1, 0, 1, 0)
	hpText.BackgroundTransparency = 1
	hpText.TextColor3 = Color3.new(1, 1, 1)
	hpText.Text = ""
	hpText.TextScaled = true
	hpText.Font = Enum.Font.GothamBold
	hpText.ZIndex = 8
	hpText.Parent = hpBg

	-- MP条
	local mpBg = Instance.new("Frame")
	mpBg.Name = "MPBackground"
	mpBg.Size = UDim2.new(MobileConfig.HP_BAR_WIDTH, 0, 0.28, 0)
	mpBg.Position = UDim2.new(0.06, 0, 0.55, 0)
	mpBg.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
	mpBg.BorderSizePixel = 0
	mpBg.ZIndex = 6
	mpBg.Parent = topBar

	mpFill = Instance.new("Frame")
	mpFill.Name = "MPFill"
	mpFill.Size = UDim2.new(1, 0, 1, 0)
	mpFill.BackgroundColor3 = MobileConfig.MP_COLOR
	mpFill.BorderSizePixel = 0
	mpFill.ZIndex = 7
	mpFill.Parent = mpBg

	local mpCorner = Instance.new("UICorner")
	mpCorner.CornerRadius = UDim.new(0, 3)
	mpCorner.Parent = mpFill

	local mpBgCorner = Instance.new("UICorner")
	mpBgCorner.CornerRadius = UDim.new(0, 3)
	mpBgCorner.Parent = mpBg

	mpBar = mpBg

	-- MP数值标签
	local mpText = Instance.new("TextLabel")
	mpText.Name = "MPText"
	mpText.Size = UDim2.new(1, 0, 1, 0)
	mpText.BackgroundTransparency = 1
	mpText.TextColor3 = Color3.new(1, 1, 1)
	mpText.Text = ""
	mpText.TextScaled = true
	mpText.Font = Enum.Font.GothamBold
	mpText.ZIndex = 8
	mpText.Parent = mpBg

	-- 中区(20%): 对局时间
	timerLabel = Instance.new("TextLabel")
	timerLabel.Name = "TimerLabel"
	timerLabel.Size = UDim2.new(0.1, 0, 0.5, 0)
	timerLabel.Position = UDim2.new(0.45, 0, 0.05, 0)
	timerLabel.BackgroundTransparency = 1
	timerLabel.TextColor3 = Color3.new(1, 1, 1)
	timerLabel.Text = "00:00"
	timerLabel.TextScaled = true
	timerLabel.Font = Enum.Font.GothamBold
	timerLabel.ZIndex = 6
	timerLabel.Parent = topBar

	-- 右中(20%): 击杀比分
	scoreLabel = Instance.new("TextLabel")
	scoreLabel.Name = "ScoreLabel"
	scoreLabel.Size = UDim2.new(0.1, 0, 0.4, 0)
	scoreLabel.Position = UDim2.new(0.45, 0, 0.55, 0)
	scoreLabel.BackgroundTransparency = 1
	scoreLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	scoreLabel.Text = "0 vs 0"
	scoreLabel.TextScaled = true
	scoreLabel.Font = Enum.Font.Gotham
	scoreLabel.ZIndex = 6
	scoreLabel.Parent = topBar
end

local function createKillNotifyArea(parent)
	killNotifyContainer = Instance.new("Frame")
	killNotifyContainer.Name = "KillNotifyContainer"
	killNotifyContainer.Size = UDim2.new(0.4, 0, 0.12, 0)
	killNotifyContainer.Position = UDim2.new(0.3, 0, 0.1, 0)
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
	respawnOverlay.BackgroundTransparency = 0.5
	respawnOverlay.ZIndex = 20
	respawnOverlay.Visible = false
	respawnOverlay.Parent = parent

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "RespawnTitle"
	titleLabel.Size = UDim2.new(0.4, 0, 0.06, 0)
	titleLabel.Position = UDim2.new(0.3, 0, 0.35, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	titleLabel.Text = "复活倒计时"
	titleLabel.TextScaled = true
	titleLabel.Font = Enum.Font.Gotham
	titleLabel.ZIndex = 21
	titleLabel.Parent = respawnOverlay

	respawnCountLabel = Instance.new("TextLabel")
	respawnCountLabel.Name = "RespawnCount"
	respawnCountLabel.Size = UDim2.new(0.2, 0, 0.15, 0)
	respawnCountLabel.Position = UDim2.new(0.4, 0, 0.42, 0)
	respawnCountLabel.BackgroundTransparency = 1
	respawnCountLabel.TextColor3 = Color3.new(1, 1, 1)
	respawnCountLabel.Text = "5"
	respawnCountLabel.TextScaled = true
	respawnCountLabel.Font = Enum.Font.GothamBold
	respawnCountLabel.ZIndex = 21
	respawnCountLabel.Parent = respawnOverlay
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
	local ratio = (max > 0) and (current / max) or 0
	ratio = math.clamp(ratio, 0, 1)

	-- 平滑动画
	local tweenInfo = TweenInfo.new(MobileConfig.HP_CHANGE_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(hpFill, tweenInfo, {
		Size = UDim2.new(ratio, 0, 1, 0),
		BackgroundColor3 = getHPColor(ratio),
	}):Play()

	-- REQ-015: 更新HP数值文字
	local hpText = hpBar and hpBar:FindFirstChild("HPText")
	if hpText then
		hpText.Text = math.floor(current) .. "/" .. math.floor(max)
	end

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
	local ratio = (max > 0) and (current / max) or 0
	ratio = math.clamp(ratio, 0, 1)

	local tweenInfo = TweenInfo.new(MobileConfig.HP_CHANGE_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(mpFill, tweenInfo, {
		Size = UDim2.new(ratio, 0, 1, 0),
	}):Play()

	-- REQ-015: 更新MP数值文字
	local mpText = mpBar and mpBar:FindFirstChild("MPText")
	if mpText then
		mpText.Text = math.floor(current) .. "/" .. math.floor(max)
	end
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
	notify.Size = UDim2.new(1, 0, 0.45, 0)
	notify.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	notify.BackgroundTransparency = 0.3
	notify.BorderSizePixel = 0
	notify.ZIndex = 9
	notify.Parent = killNotifyContainer

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = notify

	local text = Instance.new("TextLabel")
	text.Name = "KillText"
	text.Size = UDim2.new(0.9, 0, 0.8, 0)
	text.Position = UDim2.new(0.05, 0, 0.1, 0)
	text.BackgroundTransparency = 1
	text.TextColor3 = Color3.new(1, 1, 1)
	text.Text = killerName .. " 击杀了 " .. victimName
	text.TextScaled = true
	text.Font = Enum.Font.GothamBold
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
			}):Play()
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
			respawnCountLabel.Size = UDim2.new(0.25, 0, 0.18, 0)
			TweenService:Create(respawnCountLabel, TweenInfo.new(
				MobileConfig.RESPAWN_PULSE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out
			), {
				Size = UDim2.new(0.2, 0, 0.15, 0),
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
