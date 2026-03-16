-- ==========================================
-- DashSkill: 冲刺技能 Archetype 基类
-- 覆盖: ~15% 技能 (LianPoQ)
-- Template Method: OnCast → GetDashConfig → 通用冲刺逻辑
-- ==========================================
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local BaseSkill = require(ServerScriptService:WaitForChild("ServerModules"):WaitForChild("BaseSkill"))
local CombatUtils = require(ServerScriptService:WaitForChild("ServerModules"):WaitForChild("CombatUtils"))
local SkillHelper = require(ServerScriptService:WaitForChild("ServerModules"):WaitForChild("SkillHelper"))

local DashSkill = setmetatable({}, BaseSkill)
DashSkill.__index = DashSkill

function DashSkill.new(skillID)
	return setmetatable(BaseSkill.new(skillID), DashSkill)
end

--- 子类可重写: 返回冲刺配置
function DashSkill:GetDashConfig()
	return {
		Speed = self.Config.Speed or 40,
		Width = self.Config.Width or 6,
		MaxRange = self.Config.MaxRange or self.Config.Range or 30,
		OnDashHitEffects = self.Config.OnDashHitEffects or {},
		OnDashHitCC = self.Config.OnDashHitCC or {},
		LockMovement = (self.Config.LockMovement ~= false),
	}
end

--- 子类可选重写
function DashSkill:OnDashStart(player, startPos) end
function DashSkill:OnDashHit(player, target) end
function DashSkill:OnDashEnd(player, endPos) end

--- 标准冲刺释放
function DashSkill:OnCast(player, targetPos)
	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then return end
	local rootPart = character.HumanoidRootPart
	local humanoidSelf = character:FindFirstChildOfClass("Humanoid")
	if not humanoidSelf then return end

	local config = self:GetDashConfig()

	local startPos = rootPart.Position
	local direction = (Vector3.new(targetPos.X, startPos.Y, targetPos.Z) - startPos).Unit
	local endPos = startPos + direction * config.MaxRange

	-- 锁定移速
	local originalSpeed = humanoidSelf.WalkSpeed
	if config.LockMovement then
		humanoidSelf.WalkSpeed = 0
	end

	-- 回调: OnDashStart
	self:OnDashStart(player, startPos)

	-- 面向冲刺方向
	rootPart.CFrame = CFrame.lookAt(startPos, startPos + direction)

	-- Tween 驱动位移
	local dashTime = config.MaxRange / config.Speed
	local dashTween = TweenService:Create(rootPart,
		TweenInfo.new(dashTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ CFrame = CFrame.lookAt(endPos, endPos + direction) }
	)
	dashTween:Play()

	-- Heartbeat 路径碰撞检测
	local hitTargets = {}
	local halfWidth = config.Width / 2

	local checkConn
	checkConn = RunService.Heartbeat:Connect(function()
		if not rootPart or not rootPart.Parent then
			checkConn:Disconnect()
			return
		end

		local currentPos = rootPart.Position
		local enemies = CombatUtils.getEnemiesInRange(player, currentPos, halfWidth + 3, character)
		for _, model in ipairs(enemies) do
			if not hitTargets[model] then
				hitTargets[model] = true

				-- 效果施加
				local allEffects = {}
				for _, id in ipairs(config.OnDashHitEffects) do table.insert(allEffects, id) end
				for _, id in ipairs(config.OnDashHitCC) do table.insert(allEffects, id) end
				SkillHelper.ApplyEffects(self, character, model, allEffects)

				model:SetAttribute("LastDamagePlayer", player.Name)
				self:OnDashHit(player, model)
			end
		end
	end)

	-- 冲刺结束
	task.delay(dashTime, function()
		checkConn:Disconnect()
		if humanoidSelf and humanoidSelf.Parent then
			humanoidSelf.WalkSpeed = originalSpeed
		end
		self:OnDashEnd(player, rootPart and rootPart.Position or endPos)
	end)
end

return DashSkill
