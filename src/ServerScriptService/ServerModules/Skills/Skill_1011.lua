-- 后羿 R: 烈日裁决
-- 向指定方向射出火焰箭，命中眩晕+范围爆炸

local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local BaseSkill = require(ServerScriptService:WaitForChild("ServerModules"):WaitForChild("BaseSkill"))
local CombatUtils = require(ServerScriptService:WaitForChild("ServerModules"):WaitForChild("CombatUtils"))

local HouYiR = setmetatable({}, BaseSkill)
HouYiR.__index = HouYiR

function HouYiR.new(skillID)
	return setmetatable(BaseSkill.new(skillID), HouYiR)
end

local function applyStun(humanoid, stunDuration)
	local originalSpeed = humanoid.WalkSpeed
	local originalJump = humanoid.JumpPower
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	task.delay(stunDuration, function()
		if humanoid and humanoid.Parent then
			humanoid.WalkSpeed = originalSpeed
			humanoid.JumpPower = originalJump
		end
	end)
end

local function createExplosionVFX(position, radius)
	local flash = Instance.new("Part")
	flash.Shape = Enum.PartType.Ball
	flash.Material = Enum.Material.Neon
	flash.Color = Color3.fromRGB(255, 150, 0)
	flash.Size = Vector3.new(3, 3, 3)
	flash.Position = position
	flash.Anchored = true
	flash.CanCollide = false
	flash.Parent = workspace

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 150, 0)
	light.Brightness = 8
	light.Range = radius * 2
	light.Parent = flash

	TweenService:Create(flash, TweenInfo.new(0.4), {
		Size = Vector3.new(radius * 2, radius * 2, radius * 2),
		Transparency = 1
	}):Play()
	TweenService:Create(light, TweenInfo.new(0.4), { Brightness = 0 }):Play()

	-- 冲击波
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.fromRGB(255, 180, 50)
	ring.Size = Vector3.new(0.3, 2, 2)
	ring.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	ring.Anchored = true
	ring.CanCollide = false
	ring.Transparency = 0.3
	ring.Parent = workspace

	TweenService:Create(ring, TweenInfo.new(0.4), {
		Size = Vector3.new(0.3, radius * 3, radius * 3),
		Transparency = 1
	}):Play()

	Debris:AddItem(flash, 0.5)
	Debris:AddItem(ring, 0.5)
end

function HouYiR:OnCast(player, targetPos)
	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then return end
	local rootPart = character.HumanoidRootPart

	local damageBoost = self:GetRuneStat("DamageBoost")
	local powerScale = (damageBoost > 0) and damageBoost or 1
	local finalDamage = (self.Config.BaseDamage or 500) * powerScale
	local explosionDamage = (self.Config.ExplosionDamage or 250) * powerScale
	local maxRange = self.Config.BaseRange or 100
	local speed = self.Config.Speed or 65
	local stunDuration = self.Config.StunDuration or 1.5
	local explosionRadius = self.Config.ExplosionRadius or 12

	local startPos = rootPart.Position
	local direction = (Vector3.new(targetPos.X, startPos.Y, targetPos.Z) - startPos).Unit

	-- 火焰箭
	local arrow = Instance.new("Part")
	arrow.Size = Vector3.new(0.6, 0.6, 4)
	arrow.Material = Enum.Material.Neon
	arrow.Color = Color3.fromRGB(255, 120, 0)
	arrow.CFrame = CFrame.new(startPos + direction * 3, startPos + direction * 4)
	arrow.CanCollide = false
	arrow.Anchored = false
	arrow.Parent = workspace

	-- 拖尾
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0, -2)
	a0.Parent = arrow
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, 0, 2)
	a1.Parent = arrow

	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(Color3.fromRGB(255, 180, 50), Color3.fromRGB(255, 50, 0))
	trail.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1)})
	trail.Lifetime = 0.5
	trail.FaceCamera = true
	trail.LightEmission = 1
	trail.WidthScale = NumberSequence.new({NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 0)})
	trail.Parent = arrow

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 150, 0)
	light.Brightness = 4
	light.Range = 15
	light.Parent = arrow

	local att = Instance.new("Attachment")
	att.Parent = arrow
	local lv = Instance.new("LinearVelocity")
	lv.Attachment0 = att
	lv.VectorVelocity = direction * speed
	lv.MaxForce = math.huge
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.Parent = arrow

	local hitTriggered = false

	local function explode(pos)
		if hitTriggered then return end
		hitTriggered = true

		createExplosionVFX(pos, explosionRadius)
		arrow:Destroy()

		-- PvP: 使用 CombatUtils 统一检测范围内敌方
		local enemies = CombatUtils.getEnemiesInRange(player, pos, explosionRadius, character)
		for _, model in ipairs(enemies) do
			local humanoid = model:FindFirstChild("Humanoid")
			if humanoid then
				model:SetAttribute("LastDamagePlayer", player.Name)
				humanoid:TakeDamage(explosionDamage)
				applyStun(humanoid, stunDuration)
			end
		end
	end

	arrow.Touched:Connect(function(hit)
		if hitTriggered or hit:IsDescendantOf(character) then return end
		local targetModel = hit.Parent
		local humanoid = targetModel and targetModel:FindFirstChild("Humanoid")
		if not humanoid then
			targetModel = hit.Parent and hit.Parent.Parent
			humanoid = targetModel and targetModel:FindFirstChild("Humanoid")
		end

		if humanoid then
			-- PvP: 只对敌方目标直接命中
			if not CombatUtils.isEnemy(player, targetModel) then return end
			targetModel:SetAttribute("LastDamagePlayer", player.Name)
			humanoid:TakeDamage(finalDamage)
			applyStun(humanoid, stunDuration)
			explode(arrow.Position)
		elseif hit.CanCollide then
			explode(arrow.Position)
		end
	end)

	task.spawn(function()
		while not hitTriggered and arrow and arrow.Parent do
			if (arrow.Position - startPos).Magnitude >= maxRange then
				explode(arrow.Position)
				break
			end
			task.wait(0.05)
		end
	end)

	Debris:AddItem(arrow, 5)
end

return HouYiR
