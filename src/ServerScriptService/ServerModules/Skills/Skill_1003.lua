-- 拉克丝 W: 曲光屏障 (Prismatic Barrier)
-- 向前投出光之权杖，经过的友方获得护盾，返回时再次叠加

local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")

local BaseSkill = require(ServerScriptService:WaitForChild("ServerModules"):WaitForChild("BaseSkill"))
local CombatUtils = require(ServerScriptService:WaitForChild("ServerModules"):WaitForChild("CombatUtils"))

local LuxW = setmetatable({}, BaseSkill)
LuxW.__index = LuxW

function LuxW.new(skillID)
	return setmetatable(BaseSkill.new(skillID), LuxW)
end

local function createShieldVFX(character, duration)
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	-- 护盾球体
	local shield = Instance.new("Part")
	shield.Shape = Enum.PartType.Ball
	shield.Material = Enum.Material.ForceField
	shield.Color = Color3.fromRGB(180, 220, 255)
	shield.Size = Vector3.new(8, 8, 8)
	shield.CFrame = CFrame.new(rootPart.Position)
	shield.Anchored = true
	shield.CanCollide = false
	shield.Transparency = 0.6
	shield.Parent = workspace

	-- 跟随目标
	local followConn
	followConn = game:GetService("RunService").Heartbeat:Connect(function()
		if rootPart and rootPart.Parent then
			shield.CFrame = CFrame.new(rootPart.Position)
		else
			followConn:Disconnect()
			shield:Destroy()
		end
	end)

	-- 光粒子
	local attach = Instance.new("Attachment")
	attach.Parent = shield

	local particles = Instance.new("ParticleEmitter")
	particles.Color = ColorSequence.new(Color3.fromRGB(200, 235, 255))
	particles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 0),
	})
	particles.Lifetime = NumberRange.new(0.3, 0.6)
	particles.Rate = 20
	particles.Speed = NumberRange.new(1, 3)
	particles.SpreadAngle = Vector2.new(360, 360)
	particles.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(1, 1),
	})
	particles.LightEmission = 1
	particles.Parent = attach

	-- 消散
	task.delay(duration - 0.5, function()
		particles.Enabled = false
		TweenService:Create(shield, TweenInfo.new(0.5), { Transparency = 1, Size = Vector3.new(10, 10, 10) }):Play()
		task.delay(0.5, function()
			followConn:Disconnect()
			shield:Destroy()
		end)
	end)
end

local function applyShield(humanoid, amount, duration)
	-- 用 ForceField 模拟护盾效果
	local existingFF = humanoid.Parent:FindFirstChildOfClass("ForceField")
	if existingFF then existingFF:Destroy() end

	local ff = Instance.new("ForceField")
	ff.Visible = false
	ff.Parent = humanoid.Parent
	Debris:AddItem(ff, duration)

	-- 存储护盾值到 attribute
	local character = humanoid.Parent
	local currentShield = character:GetAttribute("Shield") or 0
	character:SetAttribute("Shield", currentShield + amount)

	task.delay(duration, function()
		if character and character.Parent then
			local s = character:GetAttribute("Shield") or 0
			character:SetAttribute("Shield", math.max(0, s - amount))
		end
	end)
end

function LuxW:OnCast(player, targetPos)
	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then return end
	local rootPart = character.HumanoidRootPart

	local damageBoost = self:GetRuneStat("DamageBoost")
	local powerScale = (damageBoost > 0) and damageBoost or 1
	-- MultiShot: 增加护盾量
	local extraShots = self:GetRuneStat("MultiShot")
	local multiScale = 1 + extraShots * 0.3
	local shieldAmount = (self.Config.ShieldAmount or 150) * powerScale * multiScale
	local maxRange = self.Config.BaseRange or 45
	local speed = self.Config.Speed or 50
	local shieldDuration = 3

	local startPos = rootPart.Position
	local direction = (Vector3.new(targetPos.X, startPos.Y, targetPos.Z) - startPos).Unit

	-- 先给自己一层护盾
	local selfHumanoid = character:FindFirstChild("Humanoid")
	if selfHumanoid then
		applyShield(selfHumanoid, shieldAmount, shieldDuration)
		createShieldVFX(character, shieldDuration)
	end

	-- 飞行光杖
	local wand = Instance.new("Part")
	wand.Size = Vector3.new(0.5, 0.5, 3)
	wand.Material = Enum.Material.Neon
	wand.Color = Color3.fromRGB(180, 230, 255)
	wand.CFrame = CFrame.new(startPos + direction * 3, startPos + direction * 4)
	wand.CanCollide = false
	wand.Anchored = false
	wand.Parent = workspace

	-- 尾迹
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0, -1.5)
	a0.Parent = wand
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, 0, 1.5)
	a1.Parent = wand

	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(Color3.fromRGB(180, 230, 255), Color3.fromRGB(100, 160, 220))
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.Lifetime = 0.4
	trail.FaceCamera = true
	trail.LightEmission = 0.8
	trail.Parent = wand

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(180, 230, 255)
	light.Brightness = 1.5
	light.Range = 10
	light.Parent = wand

	local attachment = Instance.new("Attachment")
	attachment.Parent = wand

	local lv = Instance.new("LinearVelocity")
	lv.Attachment0 = attachment
	lv.VectorVelocity = direction * speed
	lv.MaxForce = math.huge
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.Parent = wand

	local shieldedOnOutward = {}

	-- 去程检测友方
	wand.Touched:Connect(function(hit)
		if hit:IsDescendantOf(character) then return end
		local targetModel = hit.Parent
		local humanoid = targetModel and targetModel:FindFirstChild("Humanoid")

		if humanoid then
			-- PvP: 只给同队友方加盾
			if CombatUtils.isAlly(player, targetModel) and not shieldedOnOutward[targetModel] then
				shieldedOnOutward[targetModel] = true
				applyShield(humanoid, shieldAmount, shieldDuration)
				createShieldVFX(targetModel, shieldDuration)
			end
		end
	end)

	-- 到达最大距离后返回
	task.spawn(function()
		while wand and wand.Parent do
			if (wand.Position - startPos).Magnitude >= maxRange then
				break
			end
			task.wait(0.05)
		end

		if not wand or not wand.Parent then return end

		-- 返回
		local shieldedOnReturn = {}
		local returnConn
		returnConn = wand.Touched:Connect(function(hit)
			if hit:IsDescendantOf(character) then return end
			local targetModel = hit.Parent
			local humanoid = targetModel and targetModel:FindFirstChild("Humanoid")
			if humanoid then
				-- PvP: 只给同队友方加盾
				if CombatUtils.isAlly(player, targetModel) and not shieldedOnReturn[targetModel] then
					shieldedOnReturn[targetModel] = true
					applyShield(humanoid, shieldAmount, shieldDuration)
				end
			end
		end)

		-- 反向飞回
		while wand and wand.Parent do
			local returnDir = (rootPart.Position - wand.Position)
			if returnDir.Magnitude < 3 then
				wand:Destroy()
				break
			end
			lv.VectorVelocity = returnDir.Unit * speed
			task.wait(0.05)
		end

		if returnConn then returnConn:Disconnect() end
	end)

	Debris:AddItem(wand, 5)
end

return LuxW
