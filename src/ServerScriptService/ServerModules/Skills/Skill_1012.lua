-- 廉颇 Q: 爆裂冲撞
-- 向前冲锋位移，路径上敌人造成伤害+击飞

local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")

local BaseSkill = require(ServerScriptService:WaitForChild("ServerModules"):WaitForChild("BaseSkill"))

local LianPoQ = setmetatable({}, BaseSkill)
LianPoQ.__index = LianPoQ

function LianPoQ.new(skillID)
	return setmetatable(BaseSkill.new(skillID), LianPoQ)
end

local function knockup(humanoid, targetRoot, duration)
	local originalAnchored = targetRoot.Anchored
	targetRoot.Anchored = true

	local startPos = targetRoot.Position
	local upPos = startPos + Vector3.new(0, 8, 0)

	-- 上升
	local upTween = TweenService:Create(targetRoot, TweenInfo.new(duration * 0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		CFrame = CFrame.new(upPos) * (targetRoot.CFrame - targetRoot.CFrame.Position)
	})
	upTween:Play()

	-- 下落
	task.delay(duration * 0.5, function()
		if targetRoot and targetRoot.Parent then
			local downTween = TweenService:Create(targetRoot, TweenInfo.new(duration * 0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				CFrame = CFrame.new(startPos) * (targetRoot.CFrame - targetRoot.CFrame.Position)
			})
			downTween:Play()
		end
	end)

	task.delay(duration, function()
		if targetRoot and targetRoot.Parent then
			targetRoot.Anchored = originalAnchored
		end
	end)
end

local function createDashVFX(startPos, endPos, width)
	local mid = (startPos + endPos) / 2
	local length = (endPos - startPos).Magnitude
	local direction = (endPos - startPos).Unit

	local trail = Instance.new("Part")
	trail.Size = Vector3.new(width, 0.3, length)
	trail.Material = Enum.Material.Neon
	trail.Color = Color3.fromRGB(200, 160, 80)
	trail.CFrame = CFrame.lookAt(mid, endPos)
	trail.CFrame = CFrame.new(mid.X, startPos.Y - 2, mid.Z) * (trail.CFrame - trail.CFrame.Position)
	trail.Anchored = true
	trail.CanCollide = false
	trail.Transparency = 0.3
	trail.Parent = workspace

	TweenService:Create(trail, TweenInfo.new(0.5), { Transparency = 1 }):Play()
	Debris:AddItem(trail, 0.6)

	-- 地面裂缝粒子
	local dustPart = Instance.new("Part")
	dustPart.Size = Vector3.new(1, 1, 1)
	dustPart.Position = endPos
	dustPart.Anchored = true
	dustPart.CanCollide = false
	dustPart.Transparency = 1
	dustPart.Parent = workspace

	local attach = Instance.new("Attachment")
	attach.Parent = dustPart

	local particles = Instance.new("ParticleEmitter")
	particles.Color = ColorSequence.new(Color3.fromRGB(180, 150, 100), Color3.fromRGB(120, 100, 60))
	particles.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 0)})
	particles.Lifetime = NumberRange.new(0.3, 0.6)
	particles.Rate = 0
	particles.Speed = NumberRange.new(5, 15)
	particles.SpreadAngle = Vector2.new(360, 30)
	particles.LightEmission = 0.3
	particles.Parent = attach
	particles:Emit(20)

	Debris:AddItem(dustPart, 1)
end

function LianPoQ:OnCast(player, targetPos)
	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then return end
	local rootPart = character.HumanoidRootPart
	local humanoidSelf = character:FindFirstChild("Humanoid")
	if not humanoidSelf then return end

	local damageBoost = self:GetRuneStat("DamageBoost")
	local powerScale = (damageBoost > 0) and damageBoost or 1
	local finalDamage = (self.Config.BaseDamage or 350) * powerScale
	local dashRange = self.Config.BaseRange or 30
	local dashWidth = self.Config.DashWidth or 6
	local knockupDuration = self.Config.KnockupDuration or 0.8

	local startPos = rootPart.Position
	local direction = (Vector3.new(targetPos.X, startPos.Y, targetPos.Z) - startPos).Unit
	local endPos = startPos + direction * dashRange

	-- 冲锋动画（位移）
	local dashTime = dashRange / (self.Config.Speed or 40)
	local originalSpeed = humanoidSelf.WalkSpeed
	humanoidSelf.WalkSpeed = 0

	rootPart.CFrame = CFrame.lookAt(startPos, startPos + direction)

	local dashTween = TweenService:Create(rootPart, TweenInfo.new(dashTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		CFrame = CFrame.lookAt(endPos, endPos + direction)
	})
	dashTween:Play()

	createDashVFX(startPos, endPos, dashWidth)

	-- 冲锋路径检测
	local hitTargets = {}
	local halfWidth = dashWidth / 2

	local checkConn
	checkConn = RunService.Heartbeat:Connect(function()
		if not rootPart or not rootPart.Parent then
			checkConn:Disconnect()
			return
		end

		local currentPos = rootPart.Position

		local function checkModels(parent)
			for _, model in ipairs(parent:GetChildren()) do
				if hitTargets[model] then continue end
				local humanoid = model:FindFirstChild("Humanoid")
				local targetRoot = model:FindFirstChild("HumanoidRootPart")
				if humanoid and targetRoot and model ~= character then
					local dist = (targetRoot.Position - currentPos).Magnitude
					if dist <= halfWidth + 3 then
						hitTargets[model] = true
						humanoid:TakeDamage(finalDamage)
						knockup(humanoid, targetRoot, knockupDuration)
					end
				end
			end
		end

		checkModels(workspace)
		local enemyFolder = workspace:FindFirstChild("敌人")
		if enemyFolder then checkModels(enemyFolder) end
	end)

	task.delay(dashTime, function()
		checkConn:Disconnect()
		if humanoidSelf and humanoidSelf.Parent then
			humanoidSelf.WalkSpeed = originalSpeed
		end
	end)
end

return LianPoQ
