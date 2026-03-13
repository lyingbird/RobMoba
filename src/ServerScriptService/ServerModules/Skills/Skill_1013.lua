-- 廉颇 W: 熔岩重击
-- 获得护盾，1秒后地面崩裂范围伤害，距离中心越近伤害越高
-- 范围内有敌人时刷新Q冷却，减速敌人，拉拽非英雄单位

local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseSkill = require(ServerScriptService:WaitForChild("ServerModules"):WaitForChild("BaseSkill"))
local CombatUtils = require(ServerScriptService:WaitForChild("ServerModules"):WaitForChild("CombatUtils"))

local LianPoW = setmetatable({}, BaseSkill)
LianPoW.__index = LianPoW

function LianPoW.new(skillID)
	return setmetatable(BaseSkill.new(skillID), LianPoW)
end

local function createChargeVFX(position, radius)
	-- 蓄力地面能量聚集圈
	local chargeRing = Instance.new("Part")
	chargeRing.Shape = Enum.PartType.Cylinder
	chargeRing.Material = Enum.Material.Neon
	chargeRing.Color = Color3.fromRGB(255, 160, 0)
	chargeRing.Size = Vector3.new(0.3, radius * 2.5, radius * 2.5)
	chargeRing.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	chargeRing.Anchored = true
	chargeRing.CanCollide = false
	chargeRing.Transparency = 0.8
	chargeRing.Parent = workspace

	-- 圈收缩蓄力（从大到小）
	TweenService:Create(chargeRing, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Size = Vector3.new(0.3, 3, 3),
		Transparency = 0.2,
		Color = Color3.fromRGB(255, 80, 0)
	}):Play()

	-- 蓄力光源
	local chargeLight = Instance.new("PointLight")
	chargeLight.Color = Color3.fromRGB(255, 140, 0)
	chargeLight.Brightness = 2
	chargeLight.Range = radius
	chargeLight.Parent = chargeRing

	TweenService:Create(chargeLight, TweenInfo.new(0.8), { Brightness = 8, Range = radius * 2 }):Play()

	-- 地面能量粒子向中心聚集
	local chargeDust = Instance.new("Part")
	chargeDust.Size = Vector3.new(1, 1, 1)
	chargeDust.Position = position + Vector3.new(0, 0.5, 0)
	chargeDust.Anchored = true
	chargeDust.CanCollide = false
	chargeDust.Transparency = 1
	chargeDust.Parent = workspace

	local dustAttach = Instance.new("Attachment")
	dustAttach.Parent = chargeDust

	local dustParticles = Instance.new("ParticleEmitter")
	dustParticles.Color = ColorSequence.new(Color3.fromRGB(200, 150, 60), Color3.fromRGB(255, 100, 0))
	dustParticles.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 0)})
	dustParticles.Lifetime = NumberRange.new(0.4, 0.8)
	dustParticles.Rate = 60
	dustParticles.Speed = NumberRange.new(3, 8)
	dustParticles.SpreadAngle = Vector2.new(360, 20)
	dustParticles.LightEmission = 0.5
	dustParticles.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1)})
	dustParticles.Parent = dustAttach

	-- 0.8秒后停止蓄力粒子
	task.delay(0.8, function()
		dustParticles.Enabled = false
	end)

	-- 1秒后清理
	Debris:AddItem(chargeRing, 1.2)
	Debris:AddItem(chargeDust, 1.5)
end

local function createShieldVFX(character, duration)
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	local shield = Instance.new("Part")
	shield.Shape = Enum.PartType.Ball
	shield.Material = Enum.Material.ForceField
	shield.Color = Color3.fromRGB(200, 160, 80)
	shield.Size = Vector3.new(8, 8, 8)
	shield.CFrame = CFrame.new(rootPart.Position)
	shield.Anchored = true
	shield.CanCollide = false
	shield.Transparency = 0.5
	shield.Parent = workspace

	local followConn
	followConn = game:GetService("RunService").Heartbeat:Connect(function()
		if rootPart and rootPart.Parent then
			shield.CFrame = CFrame.new(rootPart.Position)
		else
			followConn:Disconnect()
			shield:Destroy()
		end
	end)

	task.delay(duration, function()
		followConn:Disconnect()
		TweenService:Create(shield, TweenInfo.new(0.3), { Transparency = 1 }):Play()
		Debris:AddItem(shield, 0.4)
	end)
end

local function createGroundSlamVFX(position, radius)
	-- 地面裂缝
	local crack = Instance.new("Part")
	crack.Shape = Enum.PartType.Cylinder
	crack.Material = Enum.Material.Neon
	crack.Color = Color3.fromRGB(255, 120, 0)
	crack.Size = Vector3.new(0.3, 2, 2)
	crack.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	crack.Anchored = true
	crack.CanCollide = false
	crack.Transparency = 0.2
	crack.Parent = workspace

	TweenService:Create(crack, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.3, radius * 2.5, radius * 2.5),
		Transparency = 0.5
	}):Play()

	task.delay(0.8, function()
		TweenService:Create(crack, TweenInfo.new(0.5), { Transparency = 1 }):Play()
	end)
	Debris:AddItem(crack, 1.5)

	-- 岩石飞溅粒子
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
	particles.Color = ColorSequence.new(Color3.fromRGB(180, 140, 80), Color3.fromRGB(100, 80, 50))
	particles.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 0)})
	particles.Lifetime = NumberRange.new(0.4, 0.8)
	particles.Rate = 0
	particles.Speed = NumberRange.new(10, 25)
	particles.SpreadAngle = Vector2.new(360, 40)
	particles.LightEmission = 0.2
	particles.Parent = attach
	particles:Emit(40)

	Debris:AddItem(dustPart, 1.5)
end

function LianPoW:OnCast(player, targetPos)
	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then return end
	local rootPart = character.HumanoidRootPart
	local humanoidSelf = character:FindFirstChild("Humanoid")

	local damageBoost = self:GetRuneStat("DamageBoost")
	local powerScale = (damageBoost > 0) and damageBoost or 1
	local baseDamage = (self.Config.BaseDamage or 400) * powerScale
	local radius = self.Config.AreaRadius or 14
	local shieldAmount = self.Config.ShieldAmount or 500
	local slowPercent = self.Config.SlowPercent or 0.25
	local slowDuration = self.Config.SlowDuration or 2

	-- 获得护盾
	if humanoidSelf then
		local ff = Instance.new("ForceField")
		ff.Visible = false
		ff.Parent = character
		Debris:AddItem(ff, 3)
		character:SetAttribute("Shield", (character:GetAttribute("Shield") or 0) + shieldAmount)
		task.delay(3, function()
			if character and character.Parent then
				local s = character:GetAttribute("Shield") or 0
				character:SetAttribute("Shield", math.max(0, s - shieldAmount))
			end
		end)
	end

	createShieldVFX(character, 3)

	local castPos = rootPart.Position

	-- 蓄力特效（地面能量聚集）
	createChargeVFX(castPos, radius)

	-- 1秒后地面崩裂
	task.delay(1, function()
		if not character or not character.Parent then return end
		local slamPos = rootPart.Position

		createGroundSlamVFX(slamPos, radius)

		local hitEnemy = false

		-- PvP: 使用 CombatUtils 统一检测范围内敌方
		local enemies = CombatUtils.getEnemiesInRange(player, slamPos, radius, character)
		for _, model in ipairs(enemies) do
			local humanoid = model:FindFirstChild("Humanoid")
			local targetRoot = model:FindFirstChild("HumanoidRootPart")
			if humanoid and targetRoot then
				hitEnemy = true
				local dist = (targetRoot.Position - slamPos).Magnitude

				-- 距离中心越近伤害越高，最高200%
				local distRatio = 1 - (dist / radius)
				local dmgMultiplier = 1 + distRatio -- 1x到 2x
				model:SetAttribute("LastDamagePlayer", player.Name)
				humanoid:TakeDamage(baseDamage * dmgMultiplier)

				-- 减速
				local origSpeed = humanoid.WalkSpeed
				humanoid.WalkSpeed = origSpeed * (1 - slowPercent)
				task.delay(slowDuration, function()
					if humanoid and humanoid.Parent then
						humanoid.WalkSpeed = origSpeed
					end
				end)

				-- 非英雄单位拉向中心
				local isPlayer = Players:GetPlayerFromCharacter(model)
				if not isPlayer and targetRoot then
					local pullDir = (slamPos - targetRoot.Position).Unit
					local pullDist = math.min(dist, 5)
					TweenService:Create(targetRoot, TweenInfo.new(0.3), {
						CFrame = CFrame.new(targetRoot.Position + pullDir * pullDist) * (targetRoot.CFrame - targetRoot.CFrame.Position)
					}):Play()
				end
			end
		end

		-- 范围内有敌人时刷新Q冷却
		if hitEnemy then
			local SyncCooldownEvent = ReplicatedStorage:FindFirstChild("SyncCooldownEvent")
			-- 通过PlayerSkillManager重置Q的冷却
			-- 发送CD为0给客户端
			if SyncCooldownEvent then
				SyncCooldownEvent:FireClient(player, "Q", 0, 1012)
			end
		end
	end)
end

return LianPoW
