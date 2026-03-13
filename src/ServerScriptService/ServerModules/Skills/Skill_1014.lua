-- 廉颇 R: 地裂天崩
-- 跳向目标区域连续锤击地面3次，伤害递增，第三次击飞

local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local BaseSkill = require(ServerScriptService:WaitForChild("ServerModules"):WaitForChild("BaseSkill"))
local CombatUtils = require(ServerScriptService:WaitForChild("ServerModules"):WaitForChild("CombatUtils"))

local LianPoR = setmetatable({}, BaseSkill)
LianPoR.__index = LianPoR

function LianPoR.new(skillID)
	return setmetatable(BaseSkill.new(skillID), LianPoR)
end

local function knockup(targetRoot, duration)
	local originalAnchored = targetRoot.Anchored
	targetRoot.Anchored = true
	local startPos = targetRoot.Position
	local upPos = startPos + Vector3.new(0, 10, 0)

	TweenService:Create(targetRoot, TweenInfo.new(duration * 0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		CFrame = CFrame.new(upPos) * (targetRoot.CFrame - targetRoot.CFrame.Position)
	}):Play()

	task.delay(duration * 0.5, function()
		if targetRoot and targetRoot.Parent then
			TweenService:Create(targetRoot, TweenInfo.new(duration * 0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				CFrame = CFrame.new(startPos) * (targetRoot.CFrame - targetRoot.CFrame.Position)
			}):Play()
		end
	end)

	task.delay(duration, function()
		if targetRoot and targetRoot.Parent then
			targetRoot.Anchored = originalAnchored
		end
	end)
end

local function applySlow(humanoid, slowPercent, slowDuration)
	local origSpeed = humanoid.WalkSpeed
	humanoid.WalkSpeed = origSpeed * (1 - slowPercent)
	task.delay(slowDuration, function()
		if humanoid and humanoid.Parent then
			humanoid.WalkSpeed = origSpeed
		end
	end)
end

local function createSlamVFX(position, radius, intensity)
	-- 地面碎裂特效
	local crack = Instance.new("Part")
	crack.Shape = Enum.PartType.Cylinder
	crack.Material = Enum.Material.Neon
	crack.Color = Color3.fromRGB(255, 140 - intensity * 30, 0)
	crack.Size = Vector3.new(0.3, 2, 2)
	crack.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	crack.Anchored = true
	crack.CanCollide = false
	crack.Transparency = 0.1
	crack.Parent = workspace

	TweenService:Create(crack, TweenInfo.new(0.3), {
		Size = Vector3.new(0.3, radius * 2 + intensity * 4, radius * 2 + intensity * 4),
		Transparency = 0.4
	}):Play()

	task.delay(0.6, function()
		TweenService:Create(crack, TweenInfo.new(0.4), { Transparency = 1 }):Play()
	end)
	Debris:AddItem(crack, 1.2)

	-- 岩石粒子
	local dustPart = Instance.new("Part")
	dustPart.Size = Vector3.new(1, 1, 1)
	dustPart.Position = position + Vector3.new(0, 1, 0)
	dustPart.Anchored = true
	dustPart.CanCollide = false
	dustPart.Transparency = 1
	dustPart.Parent = workspace

	local attach = Instance.new("Attachment")
	attach.Parent = dustPart

	local particles = Instance.new("ParticleEmitter")
	particles.Color = ColorSequence.new(Color3.fromRGB(180, 140, 80), Color3.fromRGB(120, 90, 50))
	particles.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 1 + intensity), NumberSequenceKeypoint.new(1, 0)})
	particles.Lifetime = NumberRange.new(0.3, 0.7)
	particles.Rate = 0
	particles.Speed = NumberRange.new(8 + intensity * 5, 20 + intensity * 8)
	particles.SpreadAngle = Vector2.new(360, 40)
	particles.LightEmission = 0.2
	particles.Parent = attach
	particles:Emit(20 + intensity * 15)

	Debris:AddItem(dustPart, 1.2)

	-- 冲击波光环
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.fromRGB(200, 150, 60)
	ring.Size = Vector3.new(0.2, 3, 3)
	ring.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	ring.Anchored = true
	ring.CanCollide = false
	ring.Transparency = 0.3
	ring.Parent = workspace

	TweenService:Create(ring, TweenInfo.new(0.35), {
		Size = Vector3.new(0.2, radius * 2.5 + intensity * 3, radius * 2.5 + intensity * 3),
		Transparency = 1
	}):Play()
	Debris:AddItem(ring, 0.5)
end

function LianPoR:OnCast(player, targetPos)
	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then return end
	local rootPart = character.HumanoidRootPart
	local humanoidSelf = character:FindFirstChild("Humanoid")
	if not humanoidSelf then return end

	local damageBoost = self:GetRuneStat("DamageBoost")
	local powerScale = (damageBoost > 0) and damageBoost or 1
	local baseDamage = (self.Config.BaseDamage or 200) * powerScale
	local maxRange = self.Config.BaseRange or 30
	local radius = self.Config.AreaRadius or 12

	local startPos = rootPart.Position
	local direction = (Vector3.new(targetPos.X, startPos.Y, targetPos.Z) - startPos).Unit
	local dist = math.min((Vector3.new(targetPos.X, startPos.Y, targetPos.Z) - startPos).Magnitude, maxRange)
	local landPos = startPos + direction * dist

	local originalSpeed = humanoidSelf.WalkSpeed
	humanoidSelf.WalkSpeed = 0

	-- 跳跃到目标位置（抛物线）
	local jumpTime = 0.5
	local jumpHeight = 10
	local jumpStart = os.clock()

	local jumpConn
	jumpConn = game:GetService("RunService").Heartbeat:Connect(function()
		local t = math.clamp((os.clock() - jumpStart) / jumpTime, 0, 1)
		local flatPos = startPos:Lerp(landPos, t)
		local yOffset = jumpHeight * 4 * t * (1 - t)
		rootPart.CFrame = CFrame.new(flatPos.X, flatPos.Y + yOffset, flatPos.Z) * CFrame.Angles(0, math.atan2(direction.X, direction.Z), 0)

		if t >= 1 then
			jumpConn:Disconnect()
		end
	end)

	task.wait(jumpTime)

	-- 3次锤击配置
	local hits = {
		{ damage = baseDamage * 1.0, slow = 0.15, knockupTime = 0, interval = 0 },
		{ damage = baseDamage * 1.5, slow = 0.30, knockupTime = 0, interval = 0.6 },
		{ damage = baseDamage * 2.5, slow = 0,    knockupTime = 1, interval = 0.6 },
	}

	for hitIndex, hitData in ipairs(hits) do
		if hitIndex > 1 then
			task.wait(hitData.interval)
		end

		if not character or not character.Parent or not rootPart or not rootPart.Parent then break end

		local slamPos = rootPart.Position

		-- 上下位移动画
		local upHeight = 4 + hitIndex * 2
		local currentPos = rootPart.Position
		local upPos = currentPos + Vector3.new(0, upHeight, 0)

		-- 上升
		TweenService:Create(rootPart, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = CFrame.new(upPos) * CFrame.Angles(0, math.atan2(direction.X, direction.Z), 0)
		}):Play()
		task.wait(0.15)

		-- 砸下
		TweenService:Create(rootPart, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			CFrame = CFrame.new(currentPos) * CFrame.Angles(0, math.atan2(direction.X, direction.Z), 0)
		}):Play()
		task.wait(0.1)

		-- 地面碎裂VFX
		createSlamVFX(slamPos, radius, hitIndex)

		-- 范围伤害 — PvP: 使用 CombatUtils 统一检测
		local enemies = CombatUtils.getEnemiesInRange(player, slamPos, radius, character)
		for _, model in ipairs(enemies) do
			local humanoid = model:FindFirstChild("Humanoid")
			local targetRoot = model:FindFirstChild("HumanoidRootPart")
			if humanoid and targetRoot then
				local d = (targetRoot.Position - slamPos).Magnitude
				-- 中心区域额外伤害
				local centerBonus = (d <= radius * 0.4) and 1.5 or 1
				model:SetAttribute("LastDamagePlayer", player.Name)
				humanoid:TakeDamage(hitData.damage * centerBonus)

				if hitData.knockupTime > 0 then
					knockup(targetRoot, hitData.knockupTime)
				elseif hitData.slow > 0 then
					applySlow(humanoid, hitData.slow, 2)
				end
			end
		end
	end

	-- 恢复移动
	if humanoidSelf and humanoidSelf.Parent then
		humanoidSelf.WalkSpeed = originalSpeed
	end
end

return LianPoR
