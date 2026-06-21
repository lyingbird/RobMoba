-- ==========================================
-- 客户端主入口 (Client Entry Point) — 大厅模式
-- REQ-004: 进入即自由活动，左下角选英雄，右下角匹配
-- 流程: 角色加载 → 基础UI → 英雄选择面板 → 装备技能 → 自由活动
-- ==========================================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer

local Modules = script.Parent:WaitForChild("Modules")
local UIComponents = script.Parent:WaitForChild("UIComponents")

-- REQ-012: 调试开关优先于自动检测
local MobileConfig = require(Modules:WaitForChild("MobileConfig"))

-- 设备检测: DEBUG_FORCE_MOBILE 开关优先，否则 有触屏且无键盘 → 移动端
local isMobile = MobileConfig.DEBUG_FORCE_MOBILE or (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled)

if MobileConfig.DEBUG_FORCE_MOBILE and not (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled) then
	warn("[Client] ⚠️ DEBUG_FORCE_MOBILE 已启用 — PC上使用移动端布局（调试模式）")
end

-- REQ-020: 移动端强制横屏 (LandscapeSensor 支持左右横屏自动切换)
if isMobile then
	local playerGui = player:WaitForChild("PlayerGui")
	playerGui.ScreenOrientation = Enum.ScreenOrientation.LandscapeSensor
end

local CameraManager = require(Modules:WaitForChild("CameraManager"))
local MovementManager = require(Modules:WaitForChild("MovementManager"))
local InputManager = require(Modules:WaitForChild("InputManager"))
local UIManager = require(script.Parent:WaitForChild("UIManager"))
local StatsBinding = require(Modules:WaitForChild("StatsBinding"))
local OverheadUI = require(Modules:WaitForChild("OverheadUI"))
local HeroAnimator = require(Modules:WaitForChild("HeroAnimator"))
local HeroSelectUI = require(UIComponents:WaitForChild("UI_HeroSelect"))
local UI_TrainingPanel = require(UIComponents:WaitForChild("UI_TrainingPanel"))
local UI_LobbyMenu = require(UIComponents:WaitForChild("UI_LobbyMenu"))
local HeroRegistry = require(ReplicatedStorage:WaitForChild("HeroRegistry"))
local SkillRegistry = require(ReplicatedStorage:WaitForChild("SkillRegistry"))

-- REQ-015: 移动端UI组件(大厅阶段就需要)
local UI_VirtualJoystick = require(UIComponents:WaitForChild("UI_VirtualJoystick"))
local UI_SkillButtons = require(UIComponents:WaitForChild("UI_SkillButtons"))
local UI_MobileHUD = require(UIComponents:WaitForChild("UI_MobileHUD"))
local UI_Minimap = require(UIComponents:WaitForChild("UI_Minimap"))

-- ========== RemoteEvents ==========
-- 等待 RemoteEventInit 创建完成 (服务端脚本优先级高, 通常 <0.5s)
-- 注意: Rojo $path 同步可能删除运行时创建的 RemoteEvent, 超时设为 3s 避免长时间阻塞
task.wait(0.5)

local HeroSwapEvent = ReplicatedStorage:WaitForChild("HeroSwapEvent", 3)
local DuelEvent = ReplicatedStorage:WaitForChild("DuelEvent", 3)
local MatchmakingEvent = ReplicatedStorage:WaitForChild("MatchmakingEvent", 3)
local EquipSkillEvent = ReplicatedStorage:WaitForChild("EquipSkillEvent", 3)
local SyncCooldownEvent = ReplicatedStorage:WaitForChild("SyncCooldownEvent", 3)

if not HeroSwapEvent then warn("[Client] ⚠️ HeroSwapEvent 未找到(Rojo可能覆盖了RemoteEvents)") end
if not EquipSkillEvent then warn("[Client] ⚠️ EquipSkillEvent 未找到") end

-- ========== 状态变量 ==========
local selectedHeroID = nil
local systemsInitialized = false
local mobileInputManagerRef = nil -- REQ-011: 移动端InputManager引用(仅移动端有值)
local mobileFrameRef = nil        -- REQ-015: 移动端MobileFrame引用(大厅+战斗共享)
local lobbyTrainBtn = nil         -- REQ-015: 旧移动端训练场按钮引用（REQ-002 后默认隐藏）
local lobbyMatchBtn = nil         -- REQ-015: 移动端匹配按钮引用（仅 PVP 模式使用）
local lobbyMatchState = "idle"   -- REQ-002: 移动端匹配按钮状态
local UI_HUD = nil                -- PC端HUD引用(仅PC路径有值)
local currentMode = "lobby"      -- "lobby" | "pvp" | "training"
local heroServerReady = false     -- 服务端已确认英雄选择，才能匹配/进训练场


-- REQ-015: 创建移动端大厅功能按钮(训练场+匹配)
local function createMobileLobbyButtons(parent)
	local TrainingEvent = ReplicatedStorage:FindFirstChild("TrainingEvent")

	-- 训练场按钮
	-- REQ-023: 移至右上角（英雄切换面板下方）
	lobbyTrainBtn = Instance.new("TextButton")
	lobbyTrainBtn.Name = "LobbyTrainBtn"
	lobbyTrainBtn.AnchorPoint = Vector2.new(1, 0)
	lobbyTrainBtn.Position = UDim2.new(MobileConfig.LOBBY_TRAIN_BTN_POS.X, 0, MobileConfig.LOBBY_TRAIN_BTN_POS.Y, 0)
	lobbyTrainBtn.Size = UDim2.new(MobileConfig.LOBBY_BTN_SIZE.W, 0, MobileConfig.LOBBY_BTN_SIZE.H, 0)
	lobbyTrainBtn.BackgroundColor3 = Color3.fromRGB(60, 80, 60)
	lobbyTrainBtn.BackgroundTransparency = 0.2
	lobbyTrainBtn.Text = "训练场"
	lobbyTrainBtn.TextColor3 = Color3.new(1, 1, 1)
	lobbyTrainBtn.TextScaled = true
	lobbyTrainBtn.Font = Enum.Font.GothamBold
	lobbyTrainBtn.BorderSizePixel = 0
	lobbyTrainBtn.ZIndex = 12
	lobbyTrainBtn.Parent = parent

	local trainCorner = Instance.new("UICorner")
	trainCorner.CornerRadius = UDim.new(0.3, 0)
	trainCorner.Parent = lobbyTrainBtn
	lobbyTrainBtn.Visible = false -- REQ-002: 改由 UI_LobbyMenu 承担模式选择入口

	lobbyTrainBtn.MouseButton1Click:Connect(function()
		if TrainingEvent then
			TrainingEvent:FireServer({ action = "toggle" })
		end
	end)


	-- 匹配按钮
	lobbyMatchBtn = Instance.new("TextButton")
	lobbyMatchBtn.Name = "LobbyMatchBtn"
	lobbyMatchBtn.AnchorPoint = Vector2.new(1, 0)
	lobbyMatchBtn.Position = UDim2.new(MobileConfig.LOBBY_MATCH_BTN_POS.X, 0, MobileConfig.LOBBY_MATCH_BTN_POS.Y, 0)
	lobbyMatchBtn.Size = UDim2.new(MobileConfig.LOBBY_BTN_SIZE.W, 0, MobileConfig.LOBBY_BTN_SIZE.H, 0)
	lobbyMatchBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 120)
	lobbyMatchBtn.BackgroundTransparency = 0.2
	lobbyMatchBtn.Text = "开始匹配"
	lobbyMatchBtn.TextColor3 = Color3.new(1, 1, 1)
	lobbyMatchBtn.TextScaled = true
	lobbyMatchBtn.Font = Enum.Font.GothamBold
	lobbyMatchBtn.BorderSizePixel = 0
	lobbyMatchBtn.ZIndex = 12
	lobbyMatchBtn.Parent = parent

	local matchCorner = Instance.new("UICorner")
	matchCorner.CornerRadius = UDim.new(0.3, 0)
	matchCorner.Parent = lobbyMatchBtn
	lobbyMatchBtn.Visible = false -- REQ-002: 仅在 PVP 模式确认英雄后显示

	lobbyMatchBtn.MouseButton1Click:Connect(function()
		if not MatchmakingEvent then return end
		if lobbyMatchState == "idle" then
			MatchmakingEvent:FireServer({ action = "join" })
			lobbyMatchState = "matching"
			lobbyMatchBtn.Text = "取消匹配"
			lobbyMatchBtn.BackgroundColor3 = Color3.fromRGB(120, 40, 40)
		elseif lobbyMatchState == "matching" then
			MatchmakingEvent:FireServer({ action = "leave" })
			lobbyMatchState = "idle"
			lobbyMatchBtn.Text = "开始匹配"
			lobbyMatchBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 120)
		end
	end)
end

local function resetMobileMatchButton()
	lobbyMatchState = "idle"
	if lobbyTrainBtn then
		lobbyTrainBtn.Visible = false
	end
	if lobbyMatchBtn then
		lobbyMatchBtn.Text = "开始匹配"
		lobbyMatchBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 120)
		lobbyMatchBtn.Visible = false
	end
end

local function showPvpEntry()
	if isMobile then
		if lobbyMatchBtn then
			lobbyMatchState = "idle"
			lobbyMatchBtn.Text = "开始匹配"
			lobbyMatchBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 120)
			lobbyMatchBtn.Visible = true
		end
		if lobbyTrainBtn then
			lobbyTrainBtn.Visible = false
		end
	else
		UIManager.SetMatchButtonState("idle")
		UIManager.SetMatchButtonVisible(true)
	end
end

local function updateMobileHeroSkills(heroId)
	if not isMobile then return end

	local heroData = HeroRegistry[heroId]
	local rawSkills = heroData and heroData.Skills or {}
	local skillSlots = {}
	for key, skillID in pairs(rawSkills) do
		local skillData = SkillRegistry[skillID]
		skillSlots[key] = {
			skillId = skillID,
			aimType = skillData and skillData.aimType or "directional",
		}
	end
	UI_SkillButtons.UpdateSkills(skillSlots)
end

local function restoreLobbyMode()
	currentMode = "lobby"
	selectedHeroID = nil
	heroServerReady = false
	_G._pendingTrainingMode = nil
	resetMobileMatchButton()
	if isMobile then
		UI_SkillButtons.UpdateSkills(nil)
		UI_SkillButtons.SetEnabled(true)
		UI_VirtualJoystick.SetLobbyMode(true)
		if mobileInputManagerRef then
			mobileInputManagerRef.SetEnabled(true)
		end
		if UI_MobileHUD and UI_MobileHUD.SetVisible then
			UI_MobileHUD.SetVisible(false)
		end
	else
		if UI_HUD and UI_HUD.HideAllFlowUI then
			UI_HUD.HideAllFlowUI()
		end
	end
	if UI_TrainingPanel and UI_TrainingPanel.SetVisible then
		UI_TrainingPanel.SetVisible(false)
	end
	if not isMobile then
		UIManager.SetMatchButtonState("idle")
		UIManager.SetMatchButtonVisible(false)
	end
	HeroSelectUI.ResetSelection()
	UI_LobbyMenu.Show()
end


-- ========== 角色加载处理 ==========
local function onCharacterAdded(character)
	character:WaitForChild("HumanoidRootPart")
	character:WaitForChild("Humanoid")

	CameraManager.Init(character)
	MovementManager.Init(character)

	if selectedHeroID then
		HeroAnimator.Init(character, selectedHeroID)
	end

	if isMobile and systemsInitialized and mobileInputManagerRef then
		mobileInputManagerRef.Destroy()
		UI_VirtualJoystick.SetLobbyMode(currentMode == "lobby")
		mobileInputManagerRef.Init(character, {
			joystick = UI_VirtualJoystick,
			skillButtons = UI_SkillButtons,
			MovementManager = MovementManager,
			CameraManager = CameraManager,
		})
	end
end

-- ========== 技能装备 ==========
local function equipHeroSkills(heroId)
	local heroData = HeroRegistry[heroId]
	if not heroData or not heroData.Skills or not next(heroData.Skills) then
		print("[Client] No skills to equip for hero:", heroId)
		return
	end

	-- 使用模块顶层已获取的 EquipSkillEvent (不再 WaitForChild 阻塞)
	if not EquipSkillEvent then
		warn("[Client] EquipSkillEvent not found! Skills won't equip on server.")
	end
	local DragDrop = UIManager.GetDragDrop()
	local UI_HUD_mod = UIManager.GetHUD()
	local skillsContainer = UI_HUD_mod and UI_HUD_mod.SkillsContainer

	for key, skillID in pairs(heroData.Skills) do
		if EquipSkillEvent then
			EquipSkillEvent:FireServer(key, skillID)
		end

		if skillsContainer and SkillRegistry[skillID] then
			local slot = skillsContainer:FindFirstChild("ActionSlot_" .. key)
			if slot then
				DragDrop.CreateItemCard(slot, skillID, SkillRegistry[skillID].Icon, true)
			end
		end
		task.wait(0.05)
	end
	print("[Client] 技能已自动装备:", heroId)
end

-- ========== 基础UI初始化 (REQ-015: PC/Mobile条件分支) ==========
if isMobile then
	-- ===== 移动端大厅路径 =====
	-- 创建 MobileUI ScreenGui + MobileFrame
	local playerGui = player:WaitForChild("PlayerGui")
	local mobileGui = Instance.new("ScreenGui")
	mobileGui.Name = "MobileUI"
	mobileGui.ResetOnSpawn = false
	mobileGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	mobileGui.DisplayOrder = 10 -- REQ-015 bugfix: 确保在Roblox默认TouchGui之上
	mobileGui.Parent = playerGui

	-- REQ-015 bugfix: 隐藏Roblox默认触控GUI(摇杆+跳跃按钮)
	-- TouchGui 由 PlayerModule 自动创建, 必须等待后移除/隐藏
	task.spawn(function()
		local touchGui = playerGui:WaitForChild("TouchGui", 5)
		if touchGui then
			touchGui.Enabled = false
			print("[Client] ✅ 已禁用 Roblox 默认 TouchGui")
		end
	end)

	local mobileFrame = Instance.new("Frame")
	mobileFrame.Name = "MobileFrame"
	mobileFrame.Size = UDim2.new(1, 0, 1, 0)
	mobileFrame.BackgroundTransparency = 1
	mobileFrame.Parent = mobileGui
	mobileFrameRef = mobileFrame

	-- 大厅摇杆(静态指示模式,不响应输入)
	UI_VirtualJoystick.Init(mobileFrame)
	UI_VirtualJoystick.SetLobbyMode(true)

	-- REQ-021: 英雄选择面板显示时禁用摇杆，隐藏时恢复
	-- 防止全屏 HeroSelect 面板下方的摇杆仍响应触摸（Bug A）
	HeroSelectUI.OnVisibilityChanged(function(isVisible)
		if isVisible then
			UI_VirtualJoystick.SetEnabled(false)
		else
			UI_VirtualJoystick.SetEnabled(true)
		end
	end)

	-- REQ-016 fix: 大厅阶段就绑定摇杆→移动回调(不等英雄选择)
	-- 让玩家在选英雄之前就能用摇杆自由移动
	UI_VirtualJoystick.OnDirectionChanged(function(direction, magnitude)
		if not player.Character then return end
		local humanoid = player.Character:FindFirstChild("Humanoid")
		if not humanoid then return end
		if magnitude < 0.01 then
			MovementManager.SetMoveDirection(Vector3.zero)
		else
			-- 屏幕Y轴正方向=向下，世界Z轴负方向=向前(朝摄像机前方)
			local worldDir = Vector3.new(direction.X, 0, -direction.Y)
			if worldDir.Magnitude < 0.001 then
				worldDir = Vector3.new(0, 0, -1)
			else
				worldDir = worldDir.Unit
			end
			local speed = magnitude < 0.4 and 0.5 or 1.0
			MovementManager.SetMoveDirection(worldDir * speed)
		end
	end)

	-- 大厅技能按钮(锁定态: 显示"?"图标)
	UI_SkillButtons.Init(mobileFrame, nil)

	-- 大厅功能按钮(训练场+匹配)
	createMobileLobbyButtons(mobileFrame)

	-- 大厅阶段就初始化小地图(REQ-015 bugfix: 不再等到英雄确认)
	UI_Minimap.Init(mobileFrame)

	-- REQ-002: 移动端不再初始化训练场面板(在进入训练场模式时初始化)
	-- UI_TrainingPanel.Init()  -- 已禁用，改为按需初始化

	-- OverheadUI 两端通用
	OverheadUI.Init()
else
	-- ===== PC端路径（完全不变）=====
	UIManager.Init()
	OverheadUI.Init()
	-- REQ-002: PC端不再初始化训练场面板(在进入训练场模式时初始化)
	-- UI_TrainingPanel.Init()  -- 已禁用，改为按需初始化
	UI_HUD = UIManager.GetHUD()
	StatsBinding.Init(UI_HUD)
end

-- 绑定角色加载
if player.Character then
	task.spawn(function()
		onCharacterAdded(player.Character)
	end)
end
player.CharacterAdded:Connect(onCharacterAdded)

-- ========== 英雄选择流程 (大厅模式) ==========
-- 英雄确认回调：首次和切换都走这里
local function onHeroConfirmed(heroId)
	local isSwitch = (selectedHeroID ~= nil and selectedHeroID ~= heroId)
	selectedHeroID = heroId
	heroServerReady = false
	print("[Client] 确认英雄:", heroId, isSwitch and "(切换)" or "(首次)")

	-- 通知服务端
	if HeroSwapEvent then
		HeroSwapEvent:FireServer({ heroId = heroId })
	end

	-- 背包控制(仅PC端, 移动端不使用PC版背包)
	if not isMobile then
		local heroData = HeroRegistry[heroId]
		if heroData and not heroData.AllowBackpack then
			UIManager.SetBackpackLocked(true)
		else
			UIManager.SetBackpackLocked(false)
		end
	end

	-- 初始化输入系统（仅首次）
	if isMobile then
		updateMobileHeroSkills(heroId)
	end

	if not systemsInitialized then
		if isMobile then
			-- ========== 移动端路径 (REQ-015 改造) ==========
			local MobileInputManager = require(Modules:WaitForChild("MobileInputManager"))

			-- 摄像机切换到移动端Lerp平滑模式
			CameraManager.SetMobileMode(true)

			-- REQ-015: MobileUI 已在大厅阶段创建, 此处激活组件
			-- 激活摇杆(从大厅静态→战斗操控)
			UI_VirtualJoystick.SetLobbyMode(false)

			-- 初始化输入管理器(聚合摇杆+技能输入)
			if player.Character then
				MobileInputManager.Init(player.Character, {
					joystick = UI_VirtualJoystick,
					skillButtons = UI_SkillButtons,
					MovementManager = MovementManager,
					CameraManager = CameraManager,
				})
			end

			-- 初始化战斗HUD(挂载到MobileFrame; 小地图已在大厅阶段初始化)
			if mobileFrameRef then
				UI_MobileHUD.Init(mobileFrameRef)
			end

			-- REQ-015 bugfix: 英雄确认后再次确保 TouchGui 禁用
			-- (MovementManager.Init 会 Disable controls, 但不会隐藏 TouchGui)
			local playerGui = player:WaitForChild("PlayerGui")
			local touchGui = playerGui:FindFirstChild("TouchGui")
			if touchGui then
				touchGui.Enabled = false
			end

			-- REQ-002: 模式按钮由 showPvpEntry/restoreLobbyMode 统一控制
			resetMobileMatchButton()

			mobileInputManagerRef = MobileInputManager -- 保存引用供DuelEvent使用


			print("[Client] 移动端输入系统初始化完成 (REQ-015)")
		else
			-- ========== PC端路径 (原有逻辑) ==========
			InputManager.Init()
		end
		systemsInitialized = true
	end

	-- 动画
	if player.Character and heroId then
		HeroAnimator.Init(player.Character, heroId)
	end

	-- 显示左下角小面板（选完后常驻）
	HeroSelectUI.ShowMiniPanel()

	if currentMode == "pvp" and heroServerReady then
		showPvpEntry()
	else
		resetMobileMatchButton()
		if not isMobile then
			UIManager.SetMatchButtonState("idle")
			UIManager.SetMatchButtonVisible(false)
		end
	end

	if not isSwitch then
		print("[Client] 大厅系统全部初始化完成!")
	end

end

-- 注册回调
HeroSelectUI.OnHeroConfirmed(onHeroConfirmed)

-- ========== MCP 测试 GM 命令 (REQ-019) ==========
-- execute_luau 中调用:
--   local GM = require(game.Players:GetPlayers()[1].PlayerScripts.Modules.GM_Commands)
--   GM.ForceHeroConfirm("LianPo")
local GM_Commands = require(Modules:WaitForChild("GM_Commands"))
GM_Commands._register("ForceHeroConfirm", function(heroId, mode)
	heroId = heroId or "LianPo"
	mode = mode or "training"
	currentMode = (mode == "training") and "training" or "pvp"
	HeroSelectUI.Hide()
	task.delay(0.5, function()
		local screen = player.PlayerGui:FindFirstChild("HeroSelectScreen")
		if screen then screen:Destroy() end
	end)
	-- REQ-002: GM 命令支持模式参数
	if mode == "training" then
		_G._pendingTrainingMode = true
	else
		_G._pendingTrainingMode = nil
	end
	UI_LobbyMenu.Hide()
	onHeroConfirmed(heroId)
	return "[GM] Hero confirmed: " .. heroId .. " mode=" .. mode
end)

GM_Commands._register("ToggleMatchmaking", function(action)
	if not MatchmakingEvent then
		return "[GM] MatchmakingEvent missing"
	end

	currentMode = "pvp"
	action = action or ((lobbyMatchState == "matching") and "leave" or "join")

	if action == "join" then
		showPvpEntry()
		MatchmakingEvent:FireServer({ action = "join" })
		lobbyMatchState = "matching"
		if lobbyMatchBtn then
			lobbyMatchBtn.Text = "取消匹配"
			lobbyMatchBtn.BackgroundColor3 = Color3.fromRGB(120, 40, 40)
			lobbyMatchBtn.Visible = true
		end
		if not isMobile then
			UIManager.SetMatchButtonState("matching")
			UIManager.SetMatchButtonVisible(true)
		end
	elseif action == "leave" then
		MatchmakingEvent:FireServer({ action = "leave" })
		lobbyMatchState = "idle"
		if lobbyMatchBtn then
			lobbyMatchBtn.Text = "开始匹配"
			lobbyMatchBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 120)
			lobbyMatchBtn.Visible = true
		end
		if not isMobile then
			UIManager.SetMatchButtonState("idle")
			UIManager.SetMatchButtonVisible(true)
		end
	else
		return "[GM] Unknown matchmaking action: " .. tostring(action)
	end

	return "[GM] Matchmaking action: " .. action
end)


-- ========== REQ-002: 大厅主菜单初始化 ==========

-- 玩家以 avatar 形象进入，通过主菜单选择模式
UI_LobbyMenu.Init(isMobile)

-- REQ-002: 等待 TrainingModeEvent (服务端已在 RemoteEventInit 中创建)
local TrainingModeEvent = ReplicatedStorage:WaitForChild("TrainingModeEvent", 5)

-- REQ-002: 模式选择回调
UI_LobbyMenu.OnModeSelected(function(mode)
	print("[Client] 模式选择:", mode)

	resetMobileMatchButton()
	if not isMobile then
		UIManager.SetMatchButtonState("idle")
		UIManager.SetMatchButtonVisible(false)
	end

	if mode == "pvp" then
		currentMode = "pvp"
		_G._pendingTrainingMode = nil
		-- PVP 模式: 隐藏主菜单 → 弹出英雄选择
		UI_LobbyMenu.Hide()
		HeroSelectUI.Show(9999)

	elseif mode == "training" then
		currentMode = "training"
		-- 训练场模式: 隐藏主菜单 → 弹出英雄选择(训练场专用)
		UI_LobbyMenu.Hide()
		-- 先弹英雄选择，选完后进入训练场
		HeroSelectUI.Show(9999)
		-- 注册一次性训练场模式标记
		-- onHeroConfirmed 中会检查此标记
		_G._pendingTrainingMode = true
	end
end)


-- REQ-002: 训练场模式事件监听(初始化 TrainingPanel + 显示/隐藏)
if TrainingModeEvent then
	TrainingModeEvent.OnClientEvent:Connect(function(data)
		if not data then return end

		if data.status == "entered" then
			currentMode = "training"
			resetMobileMatchButton()
			if not isMobile then
				UIManager.SetMatchButtonState("idle")
				UIManager.SetMatchButtonVisible(false)
			end
			-- 进入训练场模式 → 初始化并显示训练场面板
			print("[Client] 进入训练场模式")
			UI_TrainingPanel.Init(true)
		elseif data.status == "left" then
			-- 退出训练场模式 → 回到大厅模式选择
			print("[Client] 退出训练场模式")
			restoreLobbyMode()
		elseif data.status == "error" then
			warn("[Client] 训练场模式错误:", data.message)
			-- 错误时重新显示主菜单
			restoreLobbyMode()
		end

	end)
end

-- ========== 移动端技能冷却显示 ==========
if isMobile and SyncCooldownEvent then
	SyncCooldownEvent.OnClientEvent:Connect(function(slotKey, duration)
		if slotKey == "ALL" then
			for _, key in ipairs({ "Q", "W", "R", "D", "F" }) do
				UI_SkillButtons.UpdateCooldown(key, 0, 0)
			end
			return
		end

		if typeof(slotKey) == "string" then
			local cd = typeof(duration) == "number" and duration or 0
			UI_SkillButtons.UpdateCooldown(slotKey, cd, cd)
		end
	end)
end

-- ========== 监听英雄切换确认（服务端响应） ==========
if HeroSwapEvent then
	HeroSwapEvent.OnClientEvent:Connect(function(data)
		if not data then return end
		if data.success then
			heroServerReady = true
			task.spawn(equipHeroSkills, data.heroId)
			updateMobileHeroSkills(data.heroId)

			-- 服务端确认成功（如果是通过物理区域等其他方式触发的切换）
			if data.heroId ~= selectedHeroID then
				selectedHeroID = data.heroId
				if player.Character then
					HeroAnimator.Init(player.Character, data.heroId)
				end
			end

			if currentMode == "pvp" then
				showPvpEntry()
			end

			-- REQ-002: 如果是训练场模式选择后确认英雄，自动进入训练场
			if _G._pendingTrainingMode then
				_G._pendingTrainingMode = nil
				local TrainingModeEvent_ref = ReplicatedStorage:FindFirstChild("TrainingModeEvent")
				if TrainingModeEvent_ref then
					print("[Client] 英雄服务端确认完成，自动进入训练场模式")
					TrainingModeEvent_ref:FireServer({ action = "enter" })
				end
			end

			print("[Client] 服务端确认英雄:", data.heroId)
		else
			heroServerReady = false
			warn("[Client] 英雄切换失败:", data.message)
			restoreLobbyMode()
		end
	end)
end

-- ========== 监听对决事件 ==========
if DuelEvent then
	DuelEvent.OnClientEvent:Connect(function(data)
		if not data or not data.type then return end

		if data.type == "matched" then
			print("[Client] 匹配成功! 对手:", data.opponent and data.opponent.name)

		elseif data.type == "countdown" then
			if UI_HUD and UI_HUD.ShowBattleCountdown then
				UI_HUD.ShowBattleCountdown(data.seconds)
			end

		elseif data.type == "start" then
			print("[Client] 对决开始! 阵营:", data.team)
			if UI_HUD and UI_HUD.HideBattleCountdown then
				UI_HUD.HideBattleCountdown()
			end
			if systemsInitialized then
				if mobileInputManagerRef then
					mobileInputManagerRef.SetEnabled(true)
				else
					InputManager.SetEnabled(true)
				end
			end

		elseif data.type == "result" then
			print("[Client] 对决结束! 胜者:", data.winner)
			if UI_HUD and UI_HUD.ShowResult then
				UI_HUD.ShowResult(data)
			end
			if systemsInitialized then
				if mobileInputManagerRef then
					mobileInputManagerRef.SetEnabled(false)
				else
					InputManager.SetEnabled(false)
				end
			end
		elseif data.type == "return_lobby" then
			print("[Client] 已返回大厅")
			restoreLobbyMode()
		end
	end)
end

-- ========== 监听匹配状态 ==========
if MatchmakingEvent then
	MatchmakingEvent.OnClientEvent:Connect(function(data)
		if not data then return end
		if data.status == "queued" then
			print("[Client] 排队中... 队列人数:", data.queueSize)
		elseif data.status == "cancelled" then
			print("[Client] 匹配已取消")
			if data.message then
				warn("[Client]", data.message)
			end
			restoreLobbyMode()
		elseif data.status == "matched" then
			print("[Client] 匹配成功!")
			lobbyMatchState = "idle"
			if lobbyMatchBtn then
				lobbyMatchBtn.Text = "开始匹配"
				lobbyMatchBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 120)
				lobbyMatchBtn.Visible = false
			end
		end
	end)
end


print("[Client] 大厅模式客户端已初始化")
