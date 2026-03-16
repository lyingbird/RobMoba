-- ==========================================
-- Skill_1003: LuxW (曲光屏障)
-- Archetype: ProjectileSkill (特殊: 对友方施加护盾, 返回)
-- 效果: 3003(Shield 150, 3s)
-- 注: 完全重写 OnCast — 去程/回程对友方施加效果
-- ==========================================
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")

local ProjectileSkill = require(ServerScriptService:WaitForChild("ServerModules"):WaitForChild("Archetypes"):WaitForChild("ProjectileSkill"))
local CombatUtils = require(ServerScriptService:WaitForChild("ServerModules"):WaitForChild("CombatUtils"))
local SkillHelper = require(ServerScriptService:WaitForChild("ServerModules"):WaitForChild("SkillHelper"))

local LuxW = setmetatable({}, ProjectileSkill)
LuxW.__index = LuxW

function LuxW.new(skillID)
	return setmetatable(ProjectileSkill.new(skillID), LuxW)
end

-- ===== VFX =====

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
	followConn = RunService.Heartbeat:Connect(function()
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

-- ===== 完全重写 OnCast: 去程/回程对友方施加护盾 =====
function LuxW:OnCast(player, targetPos)
	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then return end
	local rootPart = character.HumanoidRootPart

	local maxRange = self.Config.Range or 45
	local speed = self.Config.Speed or 50
	local shieldDuration = 3 -- 与 EffectConfig[3003].Duration 一致
	local selfEffects = self.Config.SelfEffects or {}
	local onHitEffects = self.Config.OnHitEffects or {}

	local startPos = rootPart.Position
	local direction = (Vector3.new(targetPos.X, startPos.Y, targetPos.Z) - startPos).Unit

	-- 先给自己护盾 (通过 BuffSystem)
	if #selfEffects > 0 then
		SkillHelper.ApplyEffects(self, character, character, selfEffects)
		createShieldVFX(character, shieldDuration)
	end

	-- 飞行光杖 (复用 _createBullet 框架)
	local config = self:GetProjectileConfig()
	local wand = self:_createBullet(config, startPos, direction)

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

	local shieldedOnOutward = {}

	-- 去程: 对友方施加护盾 (通过 BuffSystem)
	wand.Touched:Connect(function(hit)
		if hit:IsDescendantOf(character) then return end
		local targetModel = hit.Parent
		local humanoid = targetModel and targetModel:FindFirstChild("Humanoid")
		if humanoid then
			if CombatUtils.isAlly(player, targetModel) and not shieldedOnOutward[targetModel] then
				shieldedOnOutward[targetModel] = true
				SkillHelper.ApplyEffects(self, character, targetModel, onHitEffects)
				createShieldVFX(targetModel, shieldDuration)
			end
		end
	end)

	-- 查找 LinearVelocity
	local lv = wand:FindFirstChildOfClass("LinearVelocity")

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
				if CombatUtils.isAlly(player, targetModel) and not shieldedOnReturn[targetModel] then
					shieldedOnReturn[targetModel] = true
					SkillHelper.ApplyEffects(self, character, targetModel, onHitEffects)
					createShieldVFX(targetModel, shieldDuration)
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
			if lv then
				lv.VectorVelocity = returnDir.Unit * speed
			end
			task.wait(0.05)
		end

		if returnConn then returnConn:Disconnect() end
	end)

	Debris:AddItem(wand, 5)
end

return LuxW
