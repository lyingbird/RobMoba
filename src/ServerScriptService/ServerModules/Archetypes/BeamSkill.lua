-- ==========================================
-- BeamSkill: 激光技能 Archetype 基类
-- 覆盖: ~10% 技能 (LuxR, AngelaR)
-- 两种模式: Instant(瞬发贯穿) / Channel(持续引导)
-- ==========================================
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseSkill = require(ServerScriptService:WaitForChild("ServerModules"):WaitForChild("BaseSkill"))
local CombatUtils = require(ServerScriptService:WaitForChild("ServerModules"):WaitForChild("CombatUtils"))
local SkillHelper = require(ServerScriptService:WaitForChild("ServerModules"):WaitForChild("SkillHelper"))

local BeamSkill = setmetatable({}, BaseSkill)
BeamSkill.__index = BeamSkill

function BeamSkill.new(skillID)
	return setmetatable(BaseSkill.new(skillID), BeamSkill)
end

--- 子类可重写: 返回激光配置
function BeamSkill:GetBeamConfig()
	return {
		Width = self.Config.Width or 6,
		Range = self.Config.Range or self.Config.BaseRange or 100,
		Duration = self.Config.Duration or 0,
		TickInterval = self.Config.TickInterval or 0.3,
		TickEffects = self.Config.TickEffects or {},
		OnHitEffects = self.Config.OnHitEffects or {},
		Mode = self.Config.Mode or "Instant",
		TrackMouse = self.Config.TrackMouse or false,
		TurnSpeed = self.Config.TurnSpeed or 1.5,
		CastTime = self.Config.CastTime or 0,
	}
end

--- 子类可选重写
function BeamSkill:OnBeamHit(player, target, hitPos) end
function BeamSkill:OnBeamTick(player, targets) end
function BeamSkill:OnBeamEnd(player) end

--- 直线范围检测: 获取光束路径上的所有敌人
function BeamSkill:_detectBeamTargets(player, character, beamStart, direction, range, halfWidth)
	local hitTargets = {}
	local enemies = CombatUtils.getEnemiesInRange(player, beamStart, range, character)
	for _, model in ipairs(enemies) do
		local targetRoot = model:FindFirstChild("HumanoidRootPart")
		if targetRoot then
			local toTarget = targetRoot.Position - beamStart
			local projected = toTarget:Dot(direction)
			if projected >= 0 and projected <= range then
				local closestPoint = beamStart + direction * projected
				local perpDist = (targetRoot.Position - closestPoint).Magnitude
				if perpDist <= halfWidth + 3 then
					table.insert(hitTargets, model)
				end
			end
		end
	end
	return hitTargets
end

--- 标准激光释放
function BeamSkill:OnCast(player, targetPos)
	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then return end
	local rootPart = character.HumanoidRootPart

	local config = self:GetBeamConfig()
	local halfWidth = config.Width / 2

	-- 蓄力等待
	if config.CastTime > 0 then
		task.wait(config.CastTime)
	end

	if not character or not character.Parent or not rootPart or not rootPart.Parent then return end

	if config.Mode == "Instant" then
		-- ===== 瞬发模式: 一次性命中 =====
		local startPos = rootPart.Position
		local direction = (Vector3.new(targetPos.X, startPos.Y, targetPos.Z) - startPos).Unit
		local beamStart = startPos + direction * 3

		-- 效果施加
		local effectIds = config.OnHitEffects
		local targets = self:_detectBeamTargets(player, character, beamStart, direction, config.Range, halfWidth)
		for _, model in ipairs(targets) do
			SkillHelper.ApplyEffects(self, character, model, effectIds)
			model:SetAttribute("LastDamagePlayer", player.Name)
			self:OnBeamHit(player, model, model:FindFirstChild("HumanoidRootPart") and model.HumanoidRootPart.Position or beamStart)
		end
		self:OnBeamEnd(player)

	elseif config.Mode == "Channel" then
		-- ===== 引导模式: 持续扫射 =====
		local humanoidSelf = character:FindFirstChildOfClass("Humanoid")
		local originalSpeed = humanoidSelf and humanoidSelf.WalkSpeed or 16
		if humanoidSelf then humanoidSelf.WalkSpeed = 0 end

		local currentAngle = math.atan2(targetPos.X - rootPart.Position.X, targetPos.Z - rootPart.Position.Z)
		local targetAngle = currentAngle

		-- 监听客户端鼠标方向
		local dirConn
		if config.TrackMouse then
			local dirEvent = ReplicatedStorage:FindFirstChild("SkillDirectionEvent")
			if dirEvent then
				dirConn = dirEvent.OnServerEvent:Connect(function(sender, newTargetPos)
					if sender ~= player then return end
					if typeof(newTargetPos) ~= "Vector3" then return end
					targetAngle = math.atan2(newTargetPos.X - rootPart.Position.X, newTargetPos.Z - rootPart.Position.Z)
				end)
			end
		end

		local startTime = os.clock()
		local lastTickTime = 0

		local heartbeatConn
		heartbeatConn = RunService.Heartbeat:Connect(function(dt)
			local elapsed = os.clock() - startTime

			if elapsed >= config.Duration or not character or not character.Parent or not rootPart or not rootPart.Parent then
				heartbeatConn:Disconnect()
				if dirConn then dirConn:Disconnect() end
				if humanoidSelf and humanoidSelf.Parent then
					humanoidSelf.WalkSpeed = originalSpeed
				end
				self:OnBeamEnd(player)
				return
			end

			-- 缓慢转向
			if config.TrackMouse then
				local angleDiff = targetAngle - currentAngle
				angleDiff = math.atan2(math.sin(angleDiff), math.cos(angleDiff))
				local maxTurn = config.TurnSpeed * dt
				if math.abs(angleDiff) > maxTurn then
					currentAngle = currentAngle + maxTurn * (angleDiff > 0 and 1 or -1)
				else
					currentAngle = targetAngle
				end
			end

			local direction = Vector3.new(math.sin(currentAngle), 0, math.cos(currentAngle))
			local beamStart = rootPart.Position + direction * 3

			-- 面向方向
			rootPart.CFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + direction)

			-- 定时 Tick 伤害
			if elapsed - lastTickTime >= config.TickInterval then
				lastTickTime = elapsed

				local effectIds = config.TickEffects
				local targets = self:_detectBeamTargets(player, character, beamStart, direction, config.Range, halfWidth)
				for _, model in ipairs(targets) do
					SkillHelper.ApplyEffects(self, character, model, effectIds)
					model:SetAttribute("LastDamagePlayer", player.Name)
				end
				self:OnBeamTick(player, targets)
			end
		end)
	end
end

return BeamSkill
