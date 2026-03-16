-- ==========================================
-- Skill_1006: AngelaQ (火球术)
-- Archetype: ProjectileSkill (特殊: 5弹散射, 重写OnCast)
-- 效果: 3020(Damage 300/弹)
-- ==========================================
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local ProjectileSkill = require(ServerScriptService:WaitForChild("ServerModules"):WaitForChild("Archetypes"):WaitForChild("ProjectileSkill"))
local CombatUtils = require(ServerScriptService:WaitForChild("ServerModules"):WaitForChild("CombatUtils"))
local SkillHelper = require(ServerScriptService:WaitForChild("ServerModules"):WaitForChild("SkillHelper"))

local AngelaQ = setmetatable({}, ProjectileSkill)
AngelaQ.__index = AngelaQ

function AngelaQ.new(skillID)
	return setmetatable(ProjectileSkill.new(skillID), AngelaQ)
end

-- ===== VFX =====

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

local function createFireTrail(fireball)
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
end

-- ===== 完全重写 OnCast: 5弹散射 =====
function AngelaQ:OnCast(player, targetPos)
	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then return end
	local rootPart = character.HumanoidRootPart

	local config = self:GetProjectileConfig()
	local maxRange = self.Config.Range or 45
	local speed = config.Speed
	local bulletCount = self.Config.BulletCount or 5
	local onHitEffects = config.OnHitEffects
	local onHitCC = config.OnHitCC

	local startPos = rootPart.Position
	local flatTarget = Vector3.new(targetPos.X, startPos.Y, targetPos.Z)
	local baseDirection = (flatTarget - startPos).Unit
	local rightDir = baseDirection:Cross(Vector3.new(0, 1, 0)).Unit

	local SPREAD_WIDTH = self.Config.SpreadWidth or 8
	local SPAWN_FORWARD = 3

	for i = 1, bulletCount do
		local lateralOffset = (i - (bulletCount + 1) / 2) * (SPREAD_WIDTH / (bulletCount - 1))
		local spawnPos = startPos + baseDirection * SPAWN_FORWARD + rightDir * lateralOffset
		local toTarget = (flatTarget - spawnPos)
		local dir = toTarget.Unit

		-- 创建火球 (Anchored=true, Heartbeat移动)
		local fireball = Instance.new("Part")
		fireball.Shape = Enum.PartType.Ball
		fireball.Size = config.Size
		fireball.Material = config.Material
		fireball.Color = config.Color
		fireball.CFrame = CFrame.new(spawnPos, spawnPos + dir)
		fireball.Anchored = true
		fireball.CanCollide = false
		fireball.Parent = workspace

		createFireTrail(fireball)

		-- Heartbeat碰撞检测 + 效果施加
		local hitTriggered = false

		local checkConn
		checkConn = RunService.Heartbeat:Connect(function()
			if hitTriggered or not fireball or not fireball.Parent then
				if checkConn then checkConn:Disconnect() end
				return
			end
			local enemies = CombatUtils.getEnemiesInRange(player, fireball.Position, 4, character)
			for _, enemy in ipairs(enemies) do
				local humanoid = enemy:FindFirstChild("Humanoid")
				if humanoid then
					hitTriggered = true
					-- 效果施加 (通过 SkillHelper → BuffSystem)
					local allEffects = {}
					for _, id in ipairs(onHitEffects) do table.insert(allEffects, id) end
					for _, id in ipairs(onHitCC) do table.insert(allEffects, id) end
					SkillHelper.ApplyEffects(self, character, enemy, allEffects)
					enemy:SetAttribute("LastDamagePlayer", player.Name)
					playHitVFX(fireball.Position)
					fireball:Destroy()
					checkConn:Disconnect()
					return
				end
			end
		end)

		-- Heartbeat 移动
		task.spawn(function()
			local currentPos = spawnPos
			local moveConn
			moveConn = RunService.Heartbeat:Connect(function(dt)
				if hitTriggered or not fireball or not fireball.Parent then
					if moveConn then moveConn:Disconnect() end
					return
				end

				currentPos = currentPos + dir * speed * dt
				fireball.CFrame = CFrame.new(currentPos, currentPos + dir)

				if (currentPos - startPos).Magnitude >= maxRange then
					moveConn:Disconnect()
					if not hitTriggered then
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
