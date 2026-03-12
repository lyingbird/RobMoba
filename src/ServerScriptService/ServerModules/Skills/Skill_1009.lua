-- 后羿 Q: 多重箭矢
-- 5把剑特效围绕自身，自动追踪范围内敌人

local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")

local BaseSkill = require(ServerScriptService:WaitForChild("ServerModules"):WaitForChild("BaseSkill"))

local HouYiQ = setmetatable({}, BaseSkill)
HouYiQ.__index = HouYiQ

function HouYiQ.new(skillID)
	return setmetatable(BaseSkill.new(skillID), HouYiQ)
end

local function createSword()
	local sword = Instance.new("Part")
	sword.Size = Vector3.new(0.3, 3, 0.8)
	sword.Material = Enum.Material.Neon
	sword.Color = Color3.fromRGB(255, 200, 50)
	sword.Anchored = true
	sword.CanCollide = false
	sword.Parent = workspace

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 200, 50)
	light.Brightness = 1.5
	light.Range = 6
	light.Parent = sword

	return sword
end

function HouYiQ:OnCast(player, targetPos)
	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then return end
	local rootPart = character.HumanoidRootPart

	local damageBoost = self:GetRuneStat("DamageBoost")
	local powerScale = (damageBoost > 0) and damageBoost or 1
	local finalDamage = (self.Config.BaseDamage or 150) * powerScale
	local swordCount = self.Config.SwordCount or 5
	local duration = self.Config.Duration or 6
	local detectRadius = self.Config.DetectRadius or 20

	-- 创建剑
	local swords = {}
	for i = 1, swordCount do
		local sword = createSword()
		table.insert(swords, { part = sword, alive = true, angle = (i - 1) * (2 * math.pi / swordCount) })
	end

	local orbitRadius = 4
	local orbitSpeed = 2 -- 弧度/秒
	local startTime = os.clock()
	local swordCooldowns = {}

	local heartbeatConn
	heartbeatConn = RunService.Heartbeat:Connect(function(dt)
		if not character or not character.Parent or not rootPart or not rootPart.Parent then
			heartbeatConn:Disconnect()
			for _, s in ipairs(swords) do if s.part then s.part:Destroy() end end
			return
		end

		if os.clock() - startTime >= duration then
			heartbeatConn:Disconnect()
			for _, s in ipairs(swords) do
				if s.part and s.part.Parent then
					TweenService:Create(s.part, TweenInfo.new(0.3), { Transparency = 1 }):Play()
					Debris:AddItem(s.part, 0.4)
				end
			end
			return
		end

		local center = rootPart.Position

		-- 检测范围内敌人
		local nearestEnemy = nil
		local nearestDist = detectRadius

		local function findNearest(parent)
			for _, model in ipairs(parent:GetChildren()) do
				local humanoid = model:FindFirstChild("Humanoid")
				local targetRoot = model:FindFirstChild("HumanoidRootPart")
				if humanoid and targetRoot and model ~= character and humanoid.Health > 0 then
					local dist = (targetRoot.Position - center).Magnitude
					if dist < nearestDist then
						nearestDist = dist
						nearestEnemy = model
					end
				end
			end
		end

		findNearest(workspace)
		local enemyFolder = workspace:FindFirstChild("敌人")
		if enemyFolder then findNearest(enemyFolder) end

		for i, s in ipairs(swords) do
			if not s.alive or not s.part or not s.part.Parent then continue end

			if nearestEnemy and (not swordCooldowns[i] or os.clock() - swordCooldowns[i] > 1) then
				-- 追踪敌人
				local enemyRoot = nearestEnemy:FindFirstChild("HumanoidRootPart")
				if enemyRoot then
					local dir = (enemyRoot.Position - s.part.Position).Unit
					local newPos = s.part.Position + dir * 40 * dt
					s.part.CFrame = CFrame.lookAt(newPos, newPos + dir)

					-- 检测命中
					if (s.part.Position - enemyRoot.Position).Magnitude < 3 then
						local humanoid = nearestEnemy:FindFirstChild("Humanoid")
						if humanoid then
							humanoid:TakeDamage(finalDamage)
						end
						swordCooldowns[i] = os.clock()
					end
				end
			else
				-- 环绕旋转
				s.angle = s.angle + orbitSpeed * dt
				local x = center.X + math.cos(s.angle) * orbitRadius
				local z = center.Z + math.sin(s.angle) * orbitRadius
				local pos = Vector3.new(x, center.Y + 1, z)
				local tangent = Vector3.new(-math.sin(s.angle), 0, math.cos(s.angle))
				s.part.CFrame = CFrame.lookAt(pos, pos + tangent) * CFrame.Angles(0, 0, math.rad(90))
			end
		end
	end)
end

return HouYiQ
