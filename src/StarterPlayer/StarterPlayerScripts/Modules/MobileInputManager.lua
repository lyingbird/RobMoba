--[[
	MobileInputManager.lua
	移动端输入系统适配层 (MOD-04)
	REQ-011: 手机端MOBA UI与操控系统

	替代PC端 InputManager 的角色:
	- 接收 UI_VirtualJoystick 的方向输入 → 驱动 MovementManager 移动
	- 接收 UI_SkillButtons 的技能释放 → FireServer CastSkillEvent/SkillDirectionEvent
	- 接收 UI_SkillButtons 的普攻请求 → 自动索敌 → FireServer AttackTargetEvent

	状态机: IDLE → AIMING → CASTING → IDLE
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local MobileConfig = require(script.Parent.MobileConfig)
local MobileIndicatorManager = require(script.Parent.MobileIndicatorManager)
local MobileCancelZone = require(script.Parent.Parent.UIComponents.MobileCancelZone)
local SkillRegistry = require(ReplicatedStorage:WaitForChild("SkillRegistry"))

local MobileInputManager = {}

-- ═══════════════════════════════════════
-- 内部状态
-- ═══════════════════════════════════════
local character = nil
local humanoid = nil
local rootPart = nil
local modules = nil                   -- {MovementManager, CooldownManager, CameraManager, ...}
local joystick = nil                  -- UI_VirtualJoystick 引用
local skillButtons = nil              -- UI_SkillButtons 引用
local enabled = false
local currentState = "IDLE"           -- IDLE / AIMING / CASTING

-- RemoteEvent 引用(缓存)
local CastSkillEvent = nil
local SkillDirectionEvent = nil
local AttackTargetEvent = nil

-- ═══════════════════════════════════════
-- 辅助函数
-- ═══════════════════════════════════════

--- 2D屏幕方向 → 3D世界方向 (基于摄像机朝向)
--- REQ-022: 摇杆输入通过摄像机 CFrame 做坐标变换，使"摇杆上"始终对应屏幕视觉上方
local function screenToWorldDirection(screenDir: Vector2): Vector3
	if screenDir.Magnitude < 0.01 then
		return Vector3.zero
	end
	local camera = workspace.CurrentCamera
	if not camera then return Vector3.zero end
	-- 摄像机 LookVector 投影到 XZ 平面 → "屏幕上"对应的世界前方
	local camLook = camera.CFrame.LookVector
	local flatForward = Vector3.new(camLook.X, 0, camLook.Z)
	if flatForward.Magnitude < 0.001 then
		-- 摄像机正朝下(极端情况) fallback
		flatForward = Vector3.new(0, 0, -1)
	else
		flatForward = flatForward.Unit
	end
	-- 右方向 = forward 绕Y轴顺时针90度: (-fz, 0, fx)
	local flatRight = Vector3.new(-flatForward.Z, 0, flatForward.X)
	-- 组合: 摇杆X→世界右, 摇杆-Y→世界前(屏幕Y轴正方向朝下)
	local worldDir = flatRight * screenDir.X + flatForward * (-screenDir.Y)
	if worldDir.Magnitude < 0.001 then return Vector3.zero end
	return worldDir.Unit
end

--- 获取最近敌人(客户端侧简化版)
--- 遍历 workspace 中非己方角色, 取射程内最近的
local function getNearestEnemy(): Model?
	if not rootPart then return nil end

	local myPos = rootPart.Position
	local player = Players.LocalPlayer
	local myTeam = player.Team

	local nearestTarget = nil
	local nearestDist = MobileConfig.AUTO_ATTACK_RANGE

	-- 搜索其他玩家角色
	for _, otherPlayer in ipairs(Players:GetPlayers()) do
		if otherPlayer ~= player then
			-- 简化敌我判断: 不同队 或 无队伍(训练场)
			local isEnemy = (myTeam == nil) or (otherPlayer.Team ~= myTeam)
			if isEnemy then
				local otherChar = otherPlayer.Character
				if otherChar then
					local otherRoot = otherChar:FindFirstChild("HumanoidRootPart")
					local otherHumanoid = otherChar:FindFirstChildOfClass("Humanoid")
					if otherRoot and otherHumanoid and otherHumanoid.Health > 0 then
						local dist = (otherRoot.Position - myPos).Magnitude
						if dist < nearestDist then
							nearestDist = dist
							nearestTarget = otherChar
						end
					end
				end
			end
		end
	end

	-- 搜索训练假人 (IsTrainingDummy Attribute)
	for _, obj in ipairs(workspace:GetChildren()) do
		if obj:IsA("Model") and obj:GetAttribute("IsTrainingDummy") then
			local dummyRoot = obj:FindFirstChild("HumanoidRootPart")
			local dummyHumanoid = obj:FindFirstChildOfClass("Humanoid")
			if dummyRoot and dummyHumanoid and dummyHumanoid.Health > 0 then
				local dist = (dummyRoot.Position - myPos).Magnitude
				if dist < nearestDist then
					nearestDist = dist
					nearestTarget = obj
				end
			end
		end
	end

	return nearestTarget
end

local function directionToTargetPoint(direction: Vector3?): Vector3?
	if not rootPart or typeof(direction) ~= "Vector3" then
		return nil
	end

	local flatDirection = Vector3.new(direction.X, 0, direction.Z)
	if flatDirection.Magnitude < 0.001 then
		return nil
	end

	return rootPart.Position + flatDirection.Unit * 100
end

-- ═══════════════════════════════════════
-- 输入处理回调
-- ═══════════════════════════════════════

--- 摇杆方向变更回调
local function onJoystickDirection(direction: Vector2, magnitude: number)
	if not enabled then return end
	if not modules or not modules.MovementManager then return end

	if magnitude < 0.01 then
		-- 松开摇杆: 停止移动
		modules.MovementManager.SetMoveDirection(Vector3.zero)
	else
		-- 方向移动
		local worldDir = screenToWorldDirection(direction)
		-- 速度分级: 小力度=慢走, 大力度=全速
		local speed = magnitude < MobileConfig.JOYSTICK_WALK_THRESHOLD and 0.5 or 1.0
		modules.MovementManager.SetMoveDirection(worldDir * speed)
	end
end

--- 技能释放回调
--- REQ-026: 🔴修复Bug — 回调签名从(skillId, direction)改为(slotKey, params)
--- UI_SkillButtons 传 slotKey(string, "Q"/"W"/"R") 和 params(table)
--- 修复: 原来传 skillId(number) 被服务端 typeof(key)~="string" 静默丢弃
local function onSkillCast(slotKey: string, params: table?)
	if not enabled then return end
	if not CastSkillEvent then return end

	currentState = "CASTING"

	-- REQ-026: 发送方向(兼容SkillDirectionEvent)
	local direction = params and params.direction
	local directionTarget = directionToTargetPoint(direction)
	if directionTarget and SkillDirectionEvent then
		SkillDirectionEvent:FireServer(directionTarget)
	end

	-- REQ-026: 发送技能释放 — 新协议(slotKey: string, params: table)
	CastSkillEvent:FireServer(slotKey, params or {})
	if directionTarget and SkillDirectionEvent then
		task.delay(0.1, function()
			if SkillDirectionEvent then
				SkillDirectionEvent:FireServer(directionTarget)
			end
		end)
	end

	-- 立即回到 IDLE
	currentState = "IDLE"
end

--- 普攻回调
local function onAttackPressed()
	if not enabled then return end
	if not AttackTargetEvent then return end

	local target = getNearestEnemy()
	if target then
		AttackTargetEvent:FireServer(target)
	end
end

-- ═══════════════════════════════════════
-- 公共接口
-- ═══════════════════════════════════════

--- 初始化移动端输入管理器
--- @param char Model - 玩家角色
--- @param mods table - {MovementManager, CooldownManager, CameraManager, UI_VirtualJoystick, UI_SkillButtons}
function MobileInputManager.Init(char: Model, mods: table)
	character = char
	humanoid = char:FindFirstChildOfClass("Humanoid")
	rootPart = char:FindFirstChild("HumanoidRootPart")
	modules = mods

	-- 缓存 RemoteEvent 引用
	CastSkillEvent = ReplicatedStorage:WaitForChild("CastSkillEvent", 5)
	SkillDirectionEvent = ReplicatedStorage:WaitForChild("SkillDirectionEvent", 5)
	AttackTargetEvent = ReplicatedStorage:WaitForChild("AttackTargetEvent", 5)
	if not CastSkillEvent then
		warn("[MobileInputManager] CastSkillEvent missing; skills will not fire")
	end
	if not AttackTargetEvent then
		warn("[MobileInputManager] AttackTargetEvent missing; attacks will not fire")
	end

	-- 关联 UI 组件
	joystick = mods.joystick
	skillButtons = mods.skillButtons

	-- REQ-026: 初始化指示器和取消框
	MobileIndicatorManager.Init(char)
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	MobileCancelZone.Init(playerGui)

	-- REQ-026: 注入模块引用到 UI_SkillButtons
	if skillButtons then
		if skillButtons.SetIndicatorManager then
			skillButtons.SetIndicatorManager(MobileIndicatorManager)
		end
		if skillButtons.SetCancelZone then
			skillButtons.SetCancelZone(MobileCancelZone)
		end
		if skillButtons.SetSkillConfigs then
			skillButtons.SetSkillConfigs(SkillRegistry)
		end
	end

	-- 绑定回调
	if joystick then
		joystick.OnDirectionChanged(onJoystickDirection)
	end
	if skillButtons then
		skillButtons.OnSkillCast(onSkillCast)
		skillButtons.OnAttackPressed(onAttackPressed)
	end

	-- 监听角色变化(死亡后重新获取引用)
	if humanoid then
		humanoid.Died:Connect(function()
			MobileInputManager.SetEnabled(false)
		end)
	end

	currentState = "IDLE"

	-- REQ-021: Init完成后自动启用，使大厅/训练场模式下也能正常工作
	MobileInputManager.SetEnabled(true)
end

--- 启用/禁用全部输入
--- @param isEnabled boolean - true: 对决开始/复活, false: 对决结束/死亡/被控
function MobileInputManager.SetEnabled(isEnabled: boolean)
	enabled = isEnabled

	-- 同步UI组件启用状态
	if joystick then
		joystick.SetEnabled(isEnabled)
	end
	if skillButtons then
		skillButtons.SetEnabled(isEnabled)
	end

	-- 禁用时停止移动
	if not isEnabled and modules and modules.MovementManager then
		modules.MovementManager.SetMoveDirection(Vector3.zero)
	end

	if not isEnabled then
		currentState = "IDLE"
	end
end

--- 获取当前输入状态
function MobileInputManager.GetState(): string
	return currentState
end

--- 销毁清理
function MobileInputManager.Destroy()
	enabled = false
	character = nil
	humanoid = nil
	rootPart = nil
	modules = nil
	joystick = nil
	skillButtons = nil
	CastSkillEvent = nil
	SkillDirectionEvent = nil
	AttackTargetEvent = nil
	currentState = "IDLE"

	-- REQ-026: 清理指示器和取消框
	MobileIndicatorManager.Destroy()
	MobileCancelZone.Destroy()
end

return MobileInputManager
