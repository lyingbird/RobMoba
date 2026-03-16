-- ==========================================
-- Skill_10530: LianPoR (天崩地裂)
-- 来源: 王者荣耀 21号表 10530 + 22号表 105300~105392
-- Archetype: AreaSkill (特殊: 3段跺地, 完全重写OnCast)
--
-- 机制:
--   跳到目标位置 → 自身加速50%+免控+减伤20% (2.8s)
--   第1跺: 伤害(100+27%AD) + 减速30%(1s)
--   第2跺: 伤害(150+40%AD) + 减速50%(1s)
--   第3跺: 伤害(200+54%AD) + 击飞1s
-- ==========================================
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")

local AreaSkill = require(ServerScriptService:WaitForChild("ServerModules"):WaitForChild("Archetypes"):WaitForChild("AreaSkill"))
local SkillHelper = require(ServerScriptService:WaitForChild("ServerModules"):WaitForChild("SkillHelper"))
local BuffSystem = require(ServerScriptService:WaitForChild("ServerModules"):WaitForChild("BuffSystem"))
local CombatUtils = require(ServerScriptService:WaitForChild("ServerModules"):WaitForChild("CombatUtils"))

local LianPoR = setmetatable({}, AreaSkill)
LianPoR.__index = LianPoR

function LianPoR.new(skillID)
	return setmetatable(AreaSkill.new(skillID), LianPoR)
end

-- ===== VFX =====

local function createSlamVFX(position, radius, intensity)
	-- 地面碎裂特效 (强度递增)
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

-- ===== 完全重写 OnCast: 跳跃 + 自身Buff + 3段递增跺地 =====
function LianPoR:OnCast(player, targetPos)
	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then return end
	local rootPart = character.HumanoidRootPart
	local humanoidSelf = character:FindFirstChildOfClass("Humanoid")
	if not humanoidSelf then return end

	local maxRange = self.Config.Range or 5
	local radius = self.Config.Radius or 5

	local startPos = rootPart.Position
	local direction = (Vector3.new(targetPos.X, startPos.Y, targetPos.Z) - startPos)
	local dist = math.min(direction.Magnitude, maxRange)
	if dist > 0.1 then
		direction = direction.Unit
	else
		direction = rootPart.CFrame.LookVector
	end
	local landPos = startPos + direction * dist

	local originalSpeed = humanoidSelf.WalkSpeed
	humanoidSelf.WalkSpeed = 0

	-- ① 自身增益Buff: 加速50% + 免控 + 减伤20% (来源: 105303/105310/105311)
	for _, buffId in ipairs(self.Config.SelfBuffOnCast or {}) do
		BuffSystem:ApplyEffect(character, character, buffId)
	end

	-- ② 跳跃到目标位置（抛物线, ~0.5s）
	local jumpTime = 0.5
	local jumpHeight = 10
	local jumpStart = os.clock()

	local jumpConn
	jumpConn = RunService.Heartbeat:Connect(function()
		local t = math.clamp((os.clock() - jumpStart) / jumpTime, 0, 1)
		local flatPos = startPos:Lerp(landPos, t)
		local yOffset = jumpHeight * 4 * t * (1 - t) -- 抛物线
		rootPart.CFrame = CFrame.new(flatPos.X, flatPos.Y + yOffset, flatPos.Z)
			* CFrame.Angles(0, math.atan2(direction.X, direction.Z), 0)

		if t >= 1 then
			jumpConn:Disconnect()
		end
	end)

	task.wait(jumpTime)

	-- ③ 3次跺地: 递增伤害 + 递增减速 + 第3跺击飞
	-- 来源: 22号表 105300/301/302(伤害) + 105390/391/392(CC)
	local stomps = {
		{
			effects = self.Config.Stomp1Effects or { 105300 },
			cc = self.Config.Stomp1CC or { 105390 },
			interval = 0, -- 落地立即第1跺
		},
		{
			effects = self.Config.Stomp2Effects or { 105301 },
			cc = self.Config.Stomp2CC or { 105391 },
			interval = 0.7,
		},
		{
			effects = self.Config.Stomp3Effects or { 105302 },
			cc = self.Config.Stomp3CC or { 105392 },
			interval = 0.7,
		},
	}

	for stompIndex, stomp in ipairs(stomps) do
		if stompIndex > 1 then
			task.wait(stomp.interval)
		end

		if not character or not character.Parent or not rootPart or not rootPart.Parent then break end

		local slamPos = rootPart.Position

		-- 上下位移动画 (上升→砸下)
		local upHeight = 2 + stompIndex * 2
		local currentPos = rootPart.Position

		-- 上升
		TweenService:Create(rootPart, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = CFrame.new(currentPos + Vector3.new(0, upHeight, 0))
				* CFrame.Angles(0, math.atan2(direction.X, direction.Z), 0)
		}):Play()
		task.wait(0.15)

		-- 砸下
		TweenService:Create(rootPart, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			CFrame = CFrame.new(currentPos)
				* CFrame.Angles(0, math.atan2(direction.X, direction.Z), 0)
		}):Play()
		task.wait(0.1)

		-- VFX (强度递增)
		createSlamVFX(slamPos, radius, stompIndex)

		-- 范围伤害 (通过 SkillHelper → BuffSystem)
		if #stomp.effects > 0 then
			SkillHelper.ApplyAreaEffects(self, character, player, slamPos, radius, stomp.effects)
		end

		-- CC效果: 减速(1/2跺) 或 击飞(第3跺)
		if #stomp.cc > 0 then
			local enemies = CombatUtils.getEnemiesInRange(player, slamPos, radius, character)
			for _, enemy in ipairs(enemies) do
				for _, ccId in ipairs(stomp.cc) do
					BuffSystem:ApplyEffect(character, enemy, ccId)
				end
			end
		end
	end

	-- ④ 结束: 移除加速buff + 恢复移动
	for _, removeId in ipairs(self.Config.RemoveBuffOnEnd or {}) do
		-- TODO: BuffSystem:RemoveEffect(character, removeId)
		-- 当前加速buff有Duration会自然过期
	end

	if humanoidSelf and humanoidSelf.Parent then
		humanoidSelf.WalkSpeed = originalSpeed
	end
end

return LianPoR
