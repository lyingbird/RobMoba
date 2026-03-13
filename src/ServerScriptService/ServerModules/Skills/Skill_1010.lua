-- 后羿 W: 日之塔
-- 指定位置圆形范围持续2秒伤害

local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local BaseSkill = require(ServerScriptService:WaitForChild("ServerModules"):WaitForChild("BaseSkill"))
local CombatUtils = require(ServerScriptService:WaitForChild("ServerModules"):WaitForChild("CombatUtils"))

local HouYiW = setmetatable({}, BaseSkill)
HouYiW.__index = HouYiW

function HouYiW.new(skillID)
	return setmetatable(BaseSkill.new(skillID), HouYiW)
end

local function createTowerVFX(position, radius, duration)
	-- 地面光圈
	local zone = Instance.new("Part")
	zone.Shape = Enum.PartType.Cylinder
	zone.Material = Enum.Material.Neon
	zone.Color = Color3.fromRGB(255, 180, 50)
	zone.Size = Vector3.new(0.5, radius * 2, radius * 2)
	zone.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	zone.Anchored = true
	zone.CanCollide = false
	zone.Transparency = 0.4
	zone.Parent = workspace

	-- 光柱
	local pillar = Instance.new("Part")
	pillar.Shape = Enum.PartType.Cylinder
	pillar.Material = Enum.Material.Neon
	pillar.Color = Color3.fromRGB(255, 220, 100)
	pillar.Size = Vector3.new(30, radius * 0.8, radius * 0.8)
	pillar.CFrame = CFrame.new(position + Vector3.new(0, 15, 0)) * CFrame.Angles(0, 0, math.rad(90))
	pillar.Anchored = true
	pillar.CanCollide = false
	pillar.Transparency = 0.5
	pillar.Parent = workspace

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 200, 50)
	light.Brightness = 5
	light.Range = radius * 2
	light.Parent = zone

	-- 粒子
	local particlePart = Instance.new("Part")
	particlePart.Size = Vector3.new(1, 1, 1)
	particlePart.Position = position + Vector3.new(0, 2, 0)
	particlePart.Anchored = true
	particlePart.CanCollide = false
	particlePart.Transparency = 1
	particlePart.Parent = workspace

	local attach = Instance.new("Attachment")
	attach.Parent = particlePart

	local particles = Instance.new("ParticleEmitter")
	particles.Color = ColorSequence.new(Color3.fromRGB(255, 200, 50), Color3.fromRGB(255, 100, 0))
	particles.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0)})
	particles.Lifetime = NumberRange.new(0.3, 0.6)
	particles.Rate = 50
	particles.Speed = NumberRange.new(2, 8)
	particles.SpreadAngle = Vector2.new(360, 30)
	particles.LightEmission = 1
	particles.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1)})
	particles.Parent = attach

	task.delay(duration - 0.3, function()
		particles.Enabled = false
		TweenService:Create(zone, TweenInfo.new(0.3), { Transparency = 1 }):Play()
		TweenService:Create(pillar, TweenInfo.new(0.3), { Transparency = 1 }):Play()
		TweenService:Create(light, TweenInfo.new(0.3), { Brightness = 0 }):Play()
	end)

	Debris:AddItem(zone, duration + 0.5)
	Debris:AddItem(pillar, duration + 0.5)
	Debris:AddItem(particlePart, duration + 0.5)
end

function HouYiW:OnCast(player, targetPos)
	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then return end
	local rootPart = character.HumanoidRootPart

	local damageBoost = self:GetRuneStat("DamageBoost")
	local powerScale = (damageBoost > 0) and damageBoost or 1
	local damagePerTick = (self.Config.BaseDamage or 120) * powerScale
	local maxRange = self.Config.BaseRange or 45
	local radius = self.Config.AreaRadius or 12
	local duration = self.Config.Duration or 2
	local tickCount = self.Config.TickCount or 4

	local startPos = rootPart.Position
	local dist = (Vector3.new(targetPos.X, startPos.Y, targetPos.Z) - startPos).Magnitude
	local castPos = dist <= maxRange and Vector3.new(targetPos.X, startPos.Y, targetPos.Z) or (startPos + (Vector3.new(targetPos.X, startPos.Y, targetPos.Z) - startPos).Unit * maxRange)

	createTowerVFX(castPos, radius, duration)

	local tickInterval = duration / tickCount
	for tick = 1, tickCount do
		task.delay(tickInterval * (tick - 1), function()
			-- PvP: 使用 CombatUtils 统一检测范围内敌方
			local enemies = CombatUtils.getEnemiesInRange(player, castPos, radius, character)
			for _, model in ipairs(enemies) do
				local humanoid = model:FindFirstChild("Humanoid")
				if humanoid then
					model:SetAttribute("LastDamagePlayer", player.Name)
					humanoid:TakeDamage(damagePerTick)
				end
			end
		end)
	end
end

return HouYiW
