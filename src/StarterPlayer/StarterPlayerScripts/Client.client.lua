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

-- ========== 状态变量 ==========
local selectedHeroID = nil
local systemsInitialized = false
local mobileInputManagerRef = nil -- REQ-011: 移动端InputManager引用(仅移动端有值)

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

-- ========== 基础UI初始化 ==========
UIManager.Init()
OverheadUI.Init()
UI_TrainingPanel.Init() -- REQ-009: 训练场面板
local UI_HUD = UIManager.GetHUD()
StatsBinding.Init(UI_HUD)

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

	-- 初始化输入系统（仅首次）
	if not systemsInitialized then
		if isMobile then
			-- ========== 移动端路径 (REQ-011) ==========
			local MobileInputManager = require(Modules:WaitForChild("MobileInputManager"))
			local UI_VirtualJoystick = require(UIComponents:WaitForChild("UI_VirtualJoystick"))
			local UI_SkillButtons = require(UIComponents:WaitForChild("UI_SkillButtons"))

			-- 摄像机切换到移动端Lerp平滑模式
			CameraManager.SetMobileMode(true)

			-- 获取MobileHUD容器(使用PlayerGui下的ScreenGui)
			local playerGui = player:WaitForChild("PlayerGui")
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

			-- 初始化虚拟摇杆
			UI_VirtualJoystick.Init(mobileFrame)

			-- 获取英雄技能栏配置给技能按钮
			local mobileHeroData = HeroRegistry[heroId]
			local skillSlots = mobileHeroData and mobileHeroData.Skills or {}
			UI_SkillButtons.Init(mobileFrame, skillSlots)

			-- 初始化输入管理器(聚合摇杆+技能输入)
			if player.Character then
				MobileInputManager.Init(player.Character, {
					joystick = UI_VirtualJoystick,
					skillButtons = UI_SkillButtons,
					MovementManager = MovementManager,
					CameraManager = CameraManager,
				})
			end

			mobileInputManagerRef = MobileInputManager -- 保存引用供DuelEvent使用

			print("[Client] 移动端输入系统初始化完成")
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

	if not isSwitch then
		print("[Client] 大厅系统全部初始化完成!")
	end
end

-- 注册回调
HeroSelectUI.OnHeroConfirmed(onHeroConfirmed)

-- 首次弹出英雄选择全屏面板
HeroSelectUI.Show(9999)

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
