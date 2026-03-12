-- 安琪拉 Q: 火球术
-- 5颗火球从面前横排生成，汇聚向目标点
-- 近距离分散，远距离汇聚

local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local BaseSkill = require(ServerScriptService:WaitForChild("ServerModules"):WaitForChild("BaseSkill"))

local AngelaQ = setmetatable({}, BaseSkill)
AngelaQ.__index = AngelaQ

function AngelaQ.new(skillID)
	return setmetatable(BaseSkill.new(skillID), AngelaQ)
end

local function playHitVFX(position)
	local flash = Instance.new("Part")
	flash.Shape = Enum.PartType.Ball
	flash.Material = Enum.Material.Neon
	flash.Color = Color3.fromRGB(255, 80, 0)
	flash.Size = Vector3.new(2, 2, 2)
	flash.Position = position
	flash.Anchored = true
	flash.CanCollide = false
	flash.Parent = workspace

	TweenService:Create(flash, TweenInfo.new(0.3), {
		Size = Vector3.new(6, 6, 6),
		Transparency = 1
	}):Play()
	Debris:AddItem(flash, 0.4)
end

local function checkHit(fireball, character, finalDamage)
	local hitTriggered = false
	local enemiesFolder = workspace:FindFirstChild("敌人")
	if not enemiesFolder then return function() return hitTriggered end end

	local conn
	conn = RunService.Heartbeat:Connect(function()
		if hitTriggered or not fireball or not fireball.Parent then
			if conn then conn:Disconnect() end
			return
		end
		for _, enemy in ipairs(enemiesFolder:GetChildren()) do
			if enemy:IsA("Model") and enemy:FindFirstChild("HumanoidRootPart") and enemy:FindFirstChild("Humanoid") then
				local dist = (enemy.HumanoidRootPart.Position - fireball.Position).Magnitude
				if dist < 4 then
					hitTriggered = true
					enemy.Humanoid:TakeDamage(finalDamage)
					playHitVFX(fireball.Position)
					fireball:Destroy()
					conn:Disconnect()
					return
				end
			end
		end
	end)

	return function() return hitTriggered end
end

function AngelaQ:OnCast(player, targetPos)
	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then return end
	local rootPart = character.HumanoidRootPart

	local damageBoost = self:GetRuneStat("DamageBoost")
	local powerScale = (damageBoost > 0) and damageBoost or 1
	local finalDamage = (self.Config.BaseDamage or 300) * powerScale
	local maxRange = self.Config.BaseRange or 45
	local speed = self.Config.Speed or 55
	local bulletCount = self.Config.BulletCount or 5

	local startPos = rootPart.Position
	local flatTarget = Vector3.new(targetPos.X, startPos.Y, targetPos.Z)
	local baseDirection = (flatTarget - startPos).Unit
	local rightDir = baseDirection:Cross(Vector3.new(0, 1, 0)).Unit

	local SPREAD_WIDTH = 8 -- 横排总宽度
	local SPAWN_FORWARD = 3 -- 生成点前移距离

	for i = 1, bulletCount do
		local lateralOffset = (i - (bulletCount + 1) / 2) * (SPREAD_WIDTH / (bulletCount - 1))
		local spawnPos = startPos + baseDirection * SPAWN_FORWARD + rightDir * lateralOffset

		-- 每颗火球从自己的生成点直线飞向目标点
		local toTarget = (flatTarget - spawnPos)
		local dir = toTarget.Unit

		local fireball = Instance.new("Part")
		fireball.Shape = Enum.PartType.Ball
		fireball.Size = Vector3.new(1.8, 1.8, 1.8)
		fireball.Material = Enum.Material.Neon
		fireball.Color = Color3.fromRGB(255, 100, 0)
		fireball.CFrame = CFrame.new(spawnPos, spawnPos + dir)
		fireball.Anchored = true
		fireball.CanCollide = false
		fireball.Parent = workspace

		-- 火焰拖尾
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(0, 0, -0.5)
		a0.Parent = fireball
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(0, 0, 0.5)
		a1.Parent = fireball

		local trail = Instance.new("Trail")
		trail.Attachment0 = a0
		trail.Attachment1 = a1
		trail.Color = ColorSequence.new(Color3.fromRGB(255, 150, 0), Color3.fromRGB(255, 30, 0))
		trail.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1)})
		trail.Lifetime = 0.3
		trail.FaceCamera = true
		trail.LightEmission = 1
		trail.Parent = fireball

		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 120, 0)
		light.Brightness = 2
		light.Range = 8
		light.Parent = fireball

		-- 硬编碰撞检测 + Heartbeat移动
		local isHit = checkHit(fireball, character, finalDamage)

		task.spawn(function()
			local currentPos = spawnPos
			local conn
			conn = RunService.Heartbeat:Connect(function(dt)
				if isHit() or not fireball or not fireball.Parent then
					if conn then conn:Disconnect() end
					return
				end

				currentPos = currentPos + dir * speed * dt
				fireball.CFrame = CFrame.new(currentPos, currentPos + dir)

				if (currentPos - startPos).Magnitude >= maxRange then
					conn:Disconnect()
					if not isHit() then
						playHitVFX(currentPos)
						fireball:Destroy()
					end
				end
			end)
		end)

		Debris:AddItem(fireball, 3)
	end
end

return AngelaQ
