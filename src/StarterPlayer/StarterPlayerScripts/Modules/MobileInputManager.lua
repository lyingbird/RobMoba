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

--- 2D屏幕方向 → 3D世界方向
--- 摄像机位于角色后上方(+Z), 朝角色看: 屏幕上→世界-Z, 屏幕右→世界+X
--- 摇杆 offset.Y 在屏幕中: 上推<0, 下推>0 (屏幕Y轴正方向朝下)
--- 因此 worldZ = screenDir.Y (上推: Y<0 → Z<0 即-Z ✓)
local function screenToWorldDirection(screenDir: Vector2): Vector3
	if screenDir.Magnitude < 0.01 then
		return Vector3.zero
	end
	return Vector3.new(screenDir.X, 0, screenDir.Y).Unit
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
local function onSkillCast(skillId: number, direction: Vector3?)
	if not enabled then return end
	if not CastSkillEvent then return end

	currentState = "CASTING"

	-- 发送方向(如果有)
	if direction and SkillDirectionEvent then
		SkillDirectionEvent:FireServer(direction)
	end

	-- 发送技能释放
	CastSkillEvent:FireServer(skillId, direction or Vector3.zero)

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
	CastSkillEvent = ReplicatedStorage:FindFirstChild("CastSkillEvent")
	SkillDirectionEvent = ReplicatedStorage:FindFirstChild("SkillDirectionEvent")
	AttackTargetEvent = ReplicatedStorage:FindFirstChild("AttackTargetEvent")

	-- 关联 UI 组件
	joystick = mods.joystick
	skillButtons = mods.skillButtons

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
			-- 死亡时设置所有技能按钮为 Dead 状态(灰色+不可点击)
			if skillButtons and skillButtons.SetSkillState then
				for _, key in ipairs({"Q", "W", "R"}) do
					skillButtons.SetSkillState(key, "Dead")
				end
			end
		end)

		-- CC系统属性监听: 服务端 EffectExecutor 设置 CanCastSkill/CanAutoAttack Attribute
		-- 当被控(眩晕/沉默等)时禁用技能按钮, 解控后恢复
		humanoid:GetAttributeChangedSignal("CanCastSkill"):Connect(function()
			local canCast = humanoid:GetAttribute("CanCastSkill")
			if skillButtons and skillButtons.SetSkillState then
				if canCast == false then
					-- 被控: 所有技能按钮 → Disabled
					for _, key in ipairs({"Q", "W", "R"}) do
						skillButtons.SetSkillState(key, "Disabled")
					end
				else
					-- 解控: 所有技能按钮 → Idle (CD模块会再刷新为Cooldown如果还在CD中)
					for _, key in ipairs({"Q", "W", "R"}) do
						skillButtons.SetSkillState(key, "Idle")
					end
				end
			end
		end)

		humanoid:GetAttributeChangedSignal("CanAutoAttack"):Connect(function()
			local canAttack = humanoid:GetAttribute("CanAutoAttack")
			if skillButtons and skillButtons.SetSkillState then
				if canAttack == false then
					-- 缴械: 普攻按钮 → Disabled
					skillButtons.SetSkillState("Attack", "Disabled")
				else
					skillButtons.SetSkillState("Attack", "Idle")
				end
			end
		end)
	end

	currentState = "IDLE"
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
end

return MobileInputManager
