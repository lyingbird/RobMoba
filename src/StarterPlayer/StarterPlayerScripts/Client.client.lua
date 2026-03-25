-- ==========================================
-- 客户端主入口 (Client Entry Point) — 大厅模式
-- REQ-004: 进入即自由活动，左下角选英雄，右下角匹配
-- REQ-013: 移动端流程 — 大厅 → 模式选择 → 英雄选择 → 训练场/PVP
-- 流程(移动端): 角色加载 → LobbyPanel → 英雄选择 → ModeSelect → 战斗UI
-- 流程(PC端): 角色加载 → 英雄选择面板 → 装备技能 → 自由活动(不变)
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

local CameraManager = require(Modules:WaitForChild("CameraManager"))
local MovementManager = require(Modules:WaitForChild("MovementManager"))
local InputManager = require(Modules:WaitForChild("InputManager"))
local UIManager = require(script.Parent:WaitForChild("UIManager"))
local StatsBinding = require(Modules:WaitForChild("StatsBinding"))
local OverheadUI = require(Modules:WaitForChild("OverheadUI"))
local HeroAnimator = require(Modules:WaitForChild("HeroAnimator"))
local HeroSelectUI = require(UIComponents:WaitForChild("UI_HeroSelect"))
local UI_TrainingPanel = require(UIComponents:WaitForChild("UI_TrainingPanel"))
local HeroRegistry = require(ReplicatedStorage:WaitForChild("HeroRegistry"))
local SkillRegistry = require(ReplicatedStorage:WaitForChild("SkillRegistry"))

-- ========== RemoteEvents ==========
task.wait(0.5) -- 等待 RemoteEventInit 创建完成

local HeroSwapEvent = ReplicatedStorage:WaitForChild("HeroSwapEvent", 10)
local DuelEvent = ReplicatedStorage:WaitForChild("DuelEvent", 10)
local MatchmakingEvent = ReplicatedStorage:WaitForChild("MatchmakingEvent", 10)
local ModeSelectEvent = ReplicatedStorage:WaitForChild("ModeSelectEvent", 10)

-- ========== 状态变量 ==========
local selectedHeroID = nil
local systemsInitialized = false
local mobileInputManagerRef = nil -- REQ-011: 移动端InputManager引用(仅移动端有值)

-- REQ-013: 客户端阶段状态机 (仅移动端使用)
-- LOBBY → HERO_SELECT → TRAINING / COMBAT
local clientPhase = "LOBBY"

-- 切换英雄时需要的引用（在 initMobileCombatUI 中赋值）
local _skillSystemInitRef = nil  -- SkillSystemInit 模块
local _mobileFrameRef = nil      -- MobileFrame UI 容器

-- 移动端: 获取 LobbyPanel 引用
local UI_LobbyPanel = isMobile and UIManager.GetLobbyPanel() or nil

-- ========== 角色加载处理 ==========
local function onCharacterAdded(character)
	character:WaitForChild("HumanoidRootPart")
	character:WaitForChild("Humanoid")

	CameraManager.Init(character)
	MovementManager.Init(character)

	if selectedHeroID then
		HeroAnimator.Init(character, selectedHeroID)
	end
end

-- ========== 技能装备 ==========
local function equipHeroSkills(heroId)
	local heroData = HeroRegistry[heroId]
	if not heroData or not heroData.Skills or not next(heroData.Skills) then
		print("[Client] No skills to equip for hero:", heroId)
		return
	end

	local EquipSkillEvent = ReplicatedStorage:WaitForChild("EquipSkillEvent", 10)
	if not EquipSkillEvent then
		warn("[Client] EquipSkillEvent not found! Skills won't equip on server.")
	end
	-- 通知服务端装备技能(所有平台)
	for key, skillID in pairs(heroData.Skills) do
		if EquipSkillEvent then
			EquipSkillEvent:FireServer(key, skillID)
		end
		task.wait(0.05)
	end

	-- PC端: 更新 HUD 技能栏位卡片(移动端使用 UI_SkillButtons, 不需要 PC HUD)
	if not isMobile then
		local DragDrop = UIManager.GetDragDrop()
		local UI_HUD_mod = UIManager.GetHUD()
		local skillsContainer = UI_HUD_mod and UI_HUD_mod.SkillsContainer

		if skillsContainer then
			for key, skillID in pairs(heroData.Skills) do
				if SkillRegistry[skillID] then
					local slot = skillsContainer:FindFirstChild("ActionSlot_" .. key)
					if slot then
						DragDrop.CreateItemCard(slot, skillID, SkillRegistry[skillID].Icon, true)
					end
				end
			end
		end
	end
	print("[Client] 技能已自动装备:", heroId)
end

-- ========== 基础UI初始化 ==========
-- 移动端大厅阶段：不创建 HUD/MatchButton/TrainingPanel，只显示 LobbyPanel
-- PC端：保持原有逻辑，全部初始化
local UI_HUD = nil
if isMobile then
	UIManager.InitLobbyOnly()
	OverheadUI.Init()
	-- HUD / TrainingPanel / StatsBinding / MatchButton 延迟到 initMobileCombatUI() 中
else
	UIManager.Init()
	OverheadUI.Init()
	UI_TrainingPanel.Init() -- REQ-009: 训练场面板
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

-- ========== 移动端战斗UI初始化(延迟到进入训练场/战斗后) ==========
local function initMobileCombatUI(heroId)
	if systemsInitialized then return end

	-- REQ-014: 移动端使用 MobileHUD 替代 PC HUD
	local playerGui = player:WaitForChild("PlayerGui")

	-- 创建 MobileHUD 容器 ScreenGui
	local mobileHUDGui = Instance.new("ScreenGui")
	mobileHUDGui.Name = "MobileHUDGui"
	mobileHUDGui.ResetOnSpawn = false
	mobileHUDGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	mobileHUDGui.Parent = playerGui

	local mobileHUDFrame = Instance.new("Frame")
	mobileHUDFrame.Name = "MobileHUDFrame"
	mobileHUDFrame.Size = UDim2.new(1, 0, 1, 0)
	mobileHUDFrame.BackgroundTransparency = 1
	mobileHUDFrame.Parent = mobileHUDGui

	-- 初始化移动端HUD（跳过PC端UI_HUD/背包/拖拽）
	UIManager.InitMobileOnly(mobileHUDFrame)
	local mobileHUD = UIManager.GetMobileHUD()
	if mobileHUD then
		StatsBinding.InitMobile(mobileHUD)
	else
		warn("[Client] MobileHUD 初始化失败, StatsBinding 跳过")
	end

	local MobileInputManager = require(Modules:WaitForChild("MobileInputManager"))
	local UI_VirtualJoystick = require(UIComponents:WaitForChild("UI_VirtualJoystick"))

	-- 新技能系统初始化模块
	local SkillSystemInit = require(Modules:WaitForChild("SkillSystem"):WaitForChild("SkillSystemInit"))
	_skillSystemInitRef = SkillSystemInit  -- 保存引用供切换英雄使用

	-- 摄像机切换到移动端Lerp平滑模式
	CameraManager.SetMobileMode(true)

	-- 创建移动端操控容器 ScreenGui
	local mobileGui = Instance.new("ScreenGui")
	mobileGui.Name = "MobileUI"
	mobileGui.ResetOnSpawn = false
	mobileGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	mobileGui.Parent = playerGui

	local mobileFrame = Instance.new("Frame")
	mobileFrame.Name = "MobileFrame"
	mobileFrame.Size = UDim2.new(1, 0, 1, 0)
	mobileFrame.BackgroundTransparency = 1
	mobileFrame.Parent = mobileGui
	_mobileFrameRef = mobileFrame  -- 保存引用供切换英雄使用

	-- 初始化虚拟摇杆
	UI_VirtualJoystick.Init(mobileFrame)

	-- 新技能系统: 初始化技能按钮/指示器/状态机/缓冲队列
	local skillOk, skillErr = pcall(function()
		SkillSystemInit.Init(mobileFrame, heroId)
	end)
	if not skillOk then
		warn("[Client] SkillSystemInit 初始化失败:", skillErr)
	else
		print("[Client] 新技能系统初始化成功")
	end

	-- 初始化输入管理器(仅负责摇杆→移动, 技能由新 SkillSystem 接管)
	local function initMobileInputForCharacter(char)
		char:WaitForChild("HumanoidRootPart")
		char:WaitForChild("Humanoid")
		MobileInputManager.Init(char, {
			joystick = UI_VirtualJoystick,
			skillButtons = nil,  -- 技能由新 SkillSystem 处理，不再传旧 UI_SkillButtons
			MovementManager = MovementManager,
			CameraManager = CameraManager,
		})
		-- Init 完成后，如果是训练模式立即启用输入
		if clientPhase == "TRAINING" then
			MobileInputManager.SetEnabled(true)
		end
	end

	local currentChar = player.Character
	if currentChar then
		task.spawn(function()
			initMobileInputForCharacter(currentChar)
		end)
	end
	-- 角色重生后重新绑定输入
	player.CharacterAdded:Connect(function(newChar)
		task.spawn(function()
			initMobileInputForCharacter(newChar)
		end)
	end)

	mobileInputManagerRef = MobileInputManager -- 保存引用供DuelEvent使用
	systemsInitialized = true

	-- 训练模式: MobileHUD 立即可见, 但隐藏倒计时/比分(训练场不需要)
	if clientPhase == "TRAINING" then
		if mobileHUD then
			mobileHUD.SetVisible(true)
			mobileHUD.SetTimerVisible(false)
		end
	end

	print("[Client] 移动端战斗UI初始化完成 (REQ-014: MobileHUD + 3D指示器)")
end

-- ========== 英雄选择流程 (大厅模式) ==========
-- 英雄确认回调：首次和切换都走这里
local function onHeroConfirmed(heroId)
	local isSwitch = (selectedHeroID ~= nil and selectedHeroID ~= heroId)
	selectedHeroID = heroId
	print("[Client] 确认英雄:", heroId, isSwitch and "(切换)" or "(首次)")

	-- 通知服务端
	if HeroSwapEvent then
		HeroSwapEvent:FireServer({ heroId = heroId })
	end

	-- 装备技能
	equipHeroSkills(heroId)

	-- 背包控制
	local heroData = HeroRegistry[heroId]
	if heroData and not heroData.AllowBackpack then
		UIManager.SetBackpackLocked(true)
	else
		UIManager.SetBackpackLocked(false)
	end

	if isMobile then
		-- ========== 移动端路径 (REQ-013) ==========
		if systemsInitialized and clientPhase == "TRAINING" and _skillSystemInitRef and _mobileFrameRef then
			-- 已在训练场中切换英雄: 直接调用 SwitchHero，不走服务端 ModeSelect 流程
			local ok, err = pcall(function()
				_skillSystemInitRef.SwitchHero(_mobileFrameRef, heroId)
			end)
			if not ok then
				warn("[Client] SwitchHero 失败:", err)
			else
				print("[Client] 移动端: 训练场内切换英雄完成:", heroId)
			end
		else
			-- 首次进入: 向服务端请求进入训练场
			-- 战斗UI 在收到 ModeSelectEvent 确认后才初始化（不在这里）
			clientPhase = "HERO_SELECT"

			if ModeSelectEvent then
				ModeSelectEvent:FireServer({ mode = "Training" })
			end

			print("[Client] 移动端: 英雄已确认，等待服务端模式确认...")
		end
	else
		-- ========== PC端路径 (原有逻辑，不变) ==========
		if not systemsInitialized then
			InputManager.Init()
			systemsInitialized = true
		end
	end

	-- 动画
	if player.Character and heroId then
		HeroAnimator.Init(player.Character, heroId)
	end

	-- 显示左下角小面板（选完后常驻）— PC端立即显示，移动端等进入训练场后显示
	if not isMobile then
		HeroSelectUI.ShowMiniPanel()
	end

	if not isSwitch and not isMobile then
		print("[Client] 大厅系统全部初始化完成!")
	end
end

-- 注册回调
HeroSelectUI.OnHeroConfirmed(onHeroConfirmed)

-- ========== 启动流程分叉: 移动端 vs PC端 ==========
if isMobile then
	-- REQ-013: 移动端 → 先显示 LobbyPanel（大厅模式选择）
	if UI_LobbyPanel then
		UI_LobbyPanel.Init()

		-- "训练场"按钮 → 弹出英雄选择
		UI_LobbyPanel.OnTrainingClicked(function()
			UI_LobbyPanel.Hide()
			HeroSelectUI.Show(9999)
		end)

		-- "PVP匹配"按钮 → 暂时弹出英雄选择（选完后走匹配流程）
		UI_LobbyPanel.OnPVPClicked(function()
			-- TODO: PVP 流程后续完善
			UI_LobbyPanel.Hide()
			HeroSelectUI.Show(9999)
		end)

		UI_LobbyPanel.Show()
		print("[Client] 移动端: 显示大厅模式选择面板")
	end
else
	-- PC端: 保持原有逻辑，首次直接弹出英雄选择全屏面板
	HeroSelectUI.Show(9999)
end

-- ========== 监听英雄切换确认（服务端响应） ==========
if HeroSwapEvent then
	HeroSwapEvent.OnClientEvent:Connect(function(data)
		if not data then return end
		if data.success then
			-- 服务端确认成功（如果是通过物理区域等其他方式触发的切换）
			if data.heroId ~= selectedHeroID then
				selectedHeroID = data.heroId
				equipHeroSkills(data.heroId)
				if player.Character then
					HeroAnimator.Init(player.Character, data.heroId)
				end
			end
			print("[Client] 服务端确认英雄:", data.heroId)
		else
			warn("[Client] 英雄切换失败:", data.message)
		end
	end)
end

-- ========== 监听模式选择响应 (REQ-013: 移动端流程) ==========
if ModeSelectEvent then
	ModeSelectEvent.OnClientEvent:Connect(function(data)
		if not data then return end

		if data.success and data.mode == "Training" then
			-- 服务端确认进入训练场
			clientPhase = "TRAINING"
			print("[Client] 移动端: 进入训练场模式")

			-- 隐藏 LobbyPanel（如果还在显示的话）
			if UI_LobbyPanel then
				UI_LobbyPanel.Hide()
			end

			-- 等待角色传送完成并确保状态就绪
			task.wait(0.3)

			-- 初始化移动端战斗UI（技能按钮/摇杆/MobileHUD）
			if isMobile and selectedHeroID then
				if systemsInitialized and _skillSystemInitRef and _mobileFrameRef then
					-- 切换英雄: 战斗UI已存在，只需重新配置技能槽位和按钮
					local ok, err = pcall(function()
						_skillSystemInitRef.SwitchHero(_mobileFrameRef, selectedHeroID)
					end)
					if not ok then
						warn("[Client] SwitchHero 失败:", err)
					else
						print("[Client] 切换英雄技能系统更新成功:", selectedHeroID)
					end
				else
					-- 首次进入: 完整初始化战斗UI
					local ok, err = pcall(function()
						initMobileCombatUI(selectedHeroID)
					end)
					if not ok then
						warn("[Client] initMobileCombatUI 失败:", err)
					end
				end
				-- 重新装备技能到 HUD 槽位（之前英雄确认时 HUD 还未初始化）
				equipHeroSkills(selectedHeroID)
			end

			-- 隐藏匹配按钮（训练场不需要）
			UIManager.SetMatchButtonVisible(false)

			-- 隐藏大厅3D标牌（PvP匹配 BillboardGui）
			for _, obj in ipairs(workspace:GetDescendants()) do
				if obj:IsA("BillboardGui") and obj.Name == "ZoneLabel" then
					obj.Enabled = false
				end
			end

			-- 显示英雄小面板 + 训练面板
			HeroSelectUI.ShowMiniPanel()
			UI_TrainingPanel.Init()

			print("[Client] 移动端: 训练场初始化完成!")

		elseif data.success and data.mode == "Lobby" then
			-- 返回大厅
			clientPhase = "LOBBY"
			-- 隐藏战斗相关 UI
			if UI_HUD and UI_HUD.HideAllFlowUI then
				UI_HUD.HideAllFlowUI()
			end
			UIManager.SetMatchButtonVisible(false)
			-- 恢复大厅3D标牌
			for _, obj in ipairs(workspace:GetDescendants()) do
				if obj:IsA("BillboardGui") and obj.Name == "ZoneLabel" then
					obj.Enabled = true
				end
			end
			-- 重新显示 LobbyPanel
			if UI_LobbyPanel then
				UI_LobbyPanel.Show()
			end
			print("[Client] 移动端: 返回大厅")

		elseif not data.success then
			-- 模式选择失败
			warn("[Client] 模式选择失败:", data.message)
			-- 回到大厅面板
			if isMobile and UI_LobbyPanel then
				UI_LobbyPanel.Show()
			end
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
		elseif data.status == "matched" then
			print("[Client] 匹配成功!")
		end
	end)
end

print("[Client] 大厅模式客户端已初始化")
