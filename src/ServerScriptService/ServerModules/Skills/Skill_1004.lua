-- 拉克丝 E: 透光奇点 (Lucent Singularity)
-- 投掷一个光球到目标区域，持续减速区域内敌人，再次施放或到期后引爆造成伤害

local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")

local BaseSkill = require(ServerScriptService:WaitForChild("ServerModules"):WaitForChild("BaseSkill"))

local LuxE = setmetatable({}, BaseSkill)
LuxE.__index = LuxE

-- 存储每个玩家当前存在的E区域，用于二次引爆
local activeZones = {}

function LuxE.new(skillID)
	local self = setmetatable(BaseSkill.new(skillID), LuxE)
	self.IsRecastable = true
	return self
end

function LuxE:CanCast()
	if self.WaitingForRecast then
		return true
	end
	return (os.clock() - self.LastCastTime) >= self:GetFinalCD()
end

local function createZoneVFX(position, radius)
	-- 地面光圈
	local zone = Instance.new("Part")
	zone.Shape = Enum.PartType.Cylinder
	zone.Material = Enum.Material.Neon
	zone.Color = Color3.fromRGB(255, 245, 180)
	zone.Size = Vector3.new(0.5, radius * 2, radius * 2)
	zone.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	zone.Anchored = true
	zone.CanCollide = false
	zone.Transparency = 0.5
	zone.Parent = workspace

	-- 浮动光球（中心）
	local orb = Instance.new("Part")
	orb.Shape = Enum.PartType.Ball
	orb.Material = Enum.Material.Neon
	orb.Color = Color3.fromRGB(255, 250, 200)
	orb.Size = Vector3.new(3, 3, 3)
	orb.Position = position + Vector3.new(0, 3, 0)
	orb.Anchored = true
	orb.CanCollide = false
	orb.Transparency = 0.2
	orb.Parent = workspace

	-- 光球上下浮动
	local floatTween = TweenService:Create(orb, TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
		Position = position + Vector3.new(0, 4.5, 0)
	})
	floatTween:Play()

	-- 光球点光
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 245, 180)
	light.Brightness = 3
	light.Range = radius + 5
	light.Parent = orb

	-- 粒子下落效果
	local attach = Instance.new("Attachment")
	attach.Parent = orb

	local particles = Instance.new("ParticleEmitter")
	particles.Color = ColorSequence.new(Color3.fromRGB(255, 240, 170))
	particles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(1, 0),
	})
	particles.Lifetime = NumberRange.new(0.5, 1)
	particles.Rate = 25
	particles.Speed = NumberRange.new(1, 4)
	particles.SpreadAngle = Vector2.new(180, 180)
	particles.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	particles.LightEmission = 1
	particles.Parent = attach

	return zone, orb, particles, floatTween
end

local function createDetonationVFX(position, radius)
	-- 爆炸闪光
	local flash = Instance.new("Part")
	flash.Shape = Enum.PartType.Ball
	flash.Material = Enum.Material.Neon
	flash.Color = Color3.fromRGB(255, 255, 220)
	flash.Size = Vector3.new(2, 2, 2)
	flash.Position = position
	flash.Anchored = true
	flash.CanCollide = false
	flash.Transparency = 0
	flash.Parent = workspace

	local flashLight = Instance.new("PointLight")
	flashLight.Color = Color3.fromRGB(255, 250, 200)
	flashLight.Brightness = 6
	flashLight.Range = radius * 2
	flashLight.Parent = flash

	TweenService:Create(flash, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(radius * 2, radius * 2, radius * 2),
		Transparency = 1
	}):Play()

	TweenService:Create(flashLight, TweenInfo.new(0.4), { Brightness = 0 }):Play()

	Debris:AddItem(flash, 0.5)

	-- 冲击波环
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.fromRGB(255, 235, 150)
	ring.Size = Vector3.new(0.3, 2, 2)
	ring.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	ring.Anchored = true
	ring.CanCollide = false
	ring.Transparency = 0.3
	ring.Parent = workspace

	TweenService:Create(ring, TweenInfo.new(0.35), {
		Size = Vector3.new(0.3, radius * 3, radius * 3),
		Transparency = 1
	}):Play()

	Debris:AddItem(ring, 0.5)
end

local function detonateZone(zoneData)
	if zoneData.detonated then return end
	zoneData.detonated = true

	local position = zoneData.position
	local radius = zoneData.radius
	local damage = zoneData.damage

	createDetonationVFX(position, radius)

	-- 范围伤害
	for _, model in ipairs(workspace:GetChildren()) do
		local humanoid = model:FindFirstChild("Humanoid")
		local rootPart = model:FindFirstChild("HumanoidRootPart")
		if humanoid and rootPart and model ~= zoneData.casterCharacter then
			local dist = (rootPart.Position - position).Magnitude
			if dist <= radius then
				humanoid:TakeDamage(damage)
			end
		end
	end

	-- 也检查敌人文件夹
	local enemyFolder = workspace:FindFirstChild("敌人")
	if enemyFolder then
		for _, model in ipairs(enemyFolder:GetChildren()) do
			local humanoid = model:FindFirstChild("Humanoid")
			local rootPart = model:FindFirstChild("HumanoidRootPart")
			if humanoid and rootPart then
				local dist = (rootPart.Position - position).Magnitude
				if dist <= radius then
					humanoid:TakeDamage(damage)
				end
			end
		end
	end

	-- 清理VFX
	if zoneData.zonePart then zoneData.zonePart:Destroy() end
	if zoneData.orbPart then zoneData.orbPart:Destroy() end
	if zoneData.heartbeatConn then zoneData.heartbeatConn:Disconnect() end
end

function LuxE:OnCast(player, targetPos)
	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then return end
	local userId = player.UserId

	-- 如果已有活跃区域，直接引爆
	if activeZones[userId] and not activeZones[userId].detonated then
		detonateZone(activeZones[userId])
		activeZones[userId] = nil
		self.WaitingForRecast = false
		return
	end

	local damageBoost = self:GetRuneStat("DamageBoost")
	local powerScale = (damageBoost > 0) and damageBoost or 1
	local finalDamage = (self.Config.BaseDamage or 240) * powerScale
	-- MultiShot: 增加区域半径
	local extraShots = self:GetRuneStat("MultiShot")
	local radius = (self.Config.AreaRadius or 15) + extraShots * 3
	local duration = self.Config.Duration or 5

	local rootPart = character.HumanoidRootPart
	local startPos = rootPart.Position + Vector3.new(0, 2, 0)
	local landPos = Vector3.new(targetPos.X, targetPos.Y, targetPos.Z)
	local travelSpeed = self.Config.Speed or 40

	-- 飞行弹体动画
	local travelOrb = Instance.new("Part")
	travelOrb.Shape = Enum.PartType.Ball
	travelOrb.Material = Enum.Material.Neon
	travelOrb.Color = Color3.fromRGB(255, 245, 180)
	travelOrb.Size = Vector3.new(2.5, 2.5, 2.5)
	travelOrb.Position = startPos
	travelOrb.Anchored = true
	travelOrb.CanCollide = false
	travelOrb.Transparency = 0.1
	travelOrb.Parent = workspace

	-- 飞行拖尾
	local travelAttach = Instance.new("Attachment")
	travelAttach.Parent = travelOrb

	local trail = Instance.new("Trail")
	local trailAttach2 = Instance.new("Attachment")
	trailAttach2.Position = Vector3.new(0, 0, 0.5)
	trailAttach2.Parent = travelOrb
	trail.Attachment0 = travelAttach
	trail.Attachment1 = trailAttach2
	trail.Color = ColorSequence.new(Color3.fromRGB(255, 240, 170), Color3.fromRGB(255, 200, 100))
	trail.Lifetime = 0.3
	trail.MinLength = 0.1
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 2),
		NumberSequenceKeypoint.new(1, 0),
	})
	trail.LightEmission = 1
	trail.Parent = travelOrb

	local travelDist = (landPos - startPos).Magnitude
	local travelTime = math.clamp(travelDist / travelSpeed, 0.15, 1.2)

	-- 抛物线飞行
	local arcHeight = math.min(travelDist * 0.15, 8)
	local startTime = os.clock()
	local travelConn
	travelConn = RunService.Heartbeat:Connect(function()
		local elapsed = os.clock() - startTime
		local t = math.clamp(elapsed / travelTime, 0, 1)

		local flatPos = startPos:Lerp(landPos, t)
		local yOffset = arcHeight * 4 * t * (1 - t) -- parabola
		travelOrb.Position = Vector3.new(flatPos.X, flatPos.Y + yOffset, flatPos.Z)

		if t >= 1 then
			travelConn:Disconnect()
			travelOrb:Destroy()
		end
	end)

	-- 等待弹体到达后再创建区域
	task.wait(travelTime)

	local zonePart, orbPart, particles, floatTween = createZoneVFX(landPos, radius)

	local zoneData = {
		position = landPos,
		radius = radius,
		damage = finalDamage,
		casterCharacter = character,
		zonePart = zonePart,
		orbPart = orbPart,
		detonated = false,
		heartbeatConn = nil,
	}

	-- 区域内减速效果
	local slowedTargets = {}
	zoneData.heartbeatConn = RunService.Heartbeat:Connect(function()
		if zoneData.detonated then return end

		local enemyFolder = workspace:FindFirstChild("敌人")
		local modelsToCheck = {}

		if enemyFolder then
			for _, m in ipairs(enemyFolder:GetChildren()) do
				table.insert(modelsToCheck, m)
			end
		end

		-- 检测区域内敌人并减速
		for _, model in ipairs(modelsToCheck) do
			local humanoid = model:FindFirstChild("Humanoid")
			local rootPart = model:FindFirstChild("HumanoidRootPart")
			if humanoid and rootPart then
				local dist = (rootPart.Position - landPos).Magnitude
				if dist <= radius then
					if not slowedTargets[model] then
						slowedTargets[model] = humanoid.WalkSpeed
						humanoid.WalkSpeed = humanoid.WalkSpeed * 0.5
					end
				else
					if slowedTargets[model] then
						humanoid.WalkSpeed = slowedTargets[model]
						slowedTargets[model] = nil
					end
				end
			end
		end
	end)

	activeZones[userId] = zoneData

	-- 超时自动引爆
	task.delay(duration, function()
		if activeZones[userId] == zoneData and not zoneData.detonated then
			detonateZone(zoneData)
			activeZones[userId] = nil
			self.WaitingForRecast = false
			-- Start cooldown on zone expiry
			self:StartCooldown()
			local ReplicatedStorage = game:GetService("ReplicatedStorage")
			local SyncCooldownEvent = ReplicatedStorage:FindFirstChild("SyncCooldownEvent")
			local SyncRecastEvent = ReplicatedStorage:FindFirstChild("SyncRecastEvent")
			if SyncRecastEvent then
				SyncRecastEvent:FireClient(player, self.ID, false)
			end
			if SyncCooldownEvent then
				-- Find the key for this skill
				local finalCD = self:GetFinalCD()
				SyncCooldownEvent:FireClient(player, nil, finalCD, self.ID)
			end
		end

		-- 恢复所有减速
		for model, originalSpeed in pairs(slowedTargets) do
			local humanoid = model:FindFirstChild("Humanoid")
			if humanoid then
				humanoid.WalkSpeed = originalSpeed
			end
		end
	end)
end

return LuxE
