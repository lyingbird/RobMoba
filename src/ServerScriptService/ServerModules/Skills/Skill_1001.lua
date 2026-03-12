local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local BaseSkill = require(ServerScriptService:WaitForChild("ServerModules"):WaitForChild("BaseSkill"))

local FireballSkill = setmetatable({}, BaseSkill)
FireballSkill.__index = FireballSkill

function FireballSkill.new(skillID)
	return setmetatable(BaseSkill.new(skillID), FireballSkill)
end

local function playExplosionVFX(hitPosition, scale)
	local explosion = Instance.new("Part")
	explosion.Shape = Enum.PartType.Ball
	explosion.Material = Enum.Material.Neon
	explosion.Color = Color3.fromRGB(255, 60, 0)
	explosion.Size = Vector3.new(2, 2, 2) * scale
	explosion.Position = hitPosition
	explosion.Anchored = true
	explosion.CanCollide = false
	explosion.Parent = workspace

	local tween = TweenService:Create(explosion, TweenInfo.new(0.3), {
		Size = Vector3.new(12, 12, 12) * scale,
		Transparency = 1
	})
	tween:Play()
	tween.Completed:Connect(function() explosion:Destroy() end)
end

function FireballSkill:OnCast(player, targetPos)
	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then return end
	local rootPart = character.HumanoidRootPart

	local extraShots = self:GetRuneStat("MultiShot")
	local damageBoost = self:GetRuneStat("DamageBoost")

	local bulletCount = 1 + extraShots
	local powerScale = (damageBoost > 0) and damageBoost or 1
	local finalDamage = (self.Config.BaseDamage or 20) * powerScale
	local maxRange = self.Config.BaseRange or 100

	for i = 1, bulletCount do
		local offsetAngle = 0
		if bulletCount > 1 then
			offsetAngle = (i - (bulletCount + 1) / 2) * 20
		end

		local startPos = rootPart.Position
		local baseDirection = (Vector3.new(targetPos.X, startPos.Y, targetPos.Z) - startPos).Unit
		local rotatedDirection = CFrame.Angles(0, math.rad(offsetAngle), 0) * baseDirection

		local fireball = Instance.new("Part")
		fireball.Size = Vector3.new(1.5, 1.5, 1.5) * powerScale
		fireball.Material = Enum.Material.Neon
		fireball.Color = Color3.fromRGB(255, 120, 0)
		fireball.CFrame = CFrame.new(startPos + rotatedDirection * 3, startPos + rotatedDirection * 4)
		fireball.CanCollide = false
		fireball.Parent = workspace

		local attachment = Instance.new("Attachment")
		attachment.Parent = fireball

		local lv = Instance.new("LinearVelocity")
		lv.Attachment0 = attachment
		lv.VectorVelocity = rotatedDirection * (self.Config.Speed or 60)
		lv.MaxForce = math.huge
		lv.RelativeTo = Enum.ActuatorRelativeTo.World
		lv.Parent = fireball

		local hitTriggered = false

		task.spawn(function()
			while not hitTriggered and fireball and fireball.Parent do
				if (fireball.Position - startPos).Magnitude >= maxRange then
					if not hitTriggered then
						hitTriggered = true
						fireball:Destroy()
					end
					break
				end
				task.wait(0.1)
			end
		end)

		fireball.Touched:Connect(function(hit)
			if hitTriggered or hit:IsDescendantOf(character) then return end
			local humanoid = hit.Parent:FindFirstChild("Humanoid") or hit.Parent.Parent:FindFirstChild("Humanoid")

			if humanoid then
				hitTriggered = true
				humanoid:TakeDamage(finalDamage)
				playExplosionVFX(fireball.Position, powerScale)
				fireball:Destroy()
			elseif hit.CanCollide then
				hitTriggered = true
				playExplosionVFX(fireball.Position, powerScale * 0.5)
				fireball:Destroy()
			end
		end)

		Debris:AddItem(fireball, 3)
	end
end

return FireballSkill