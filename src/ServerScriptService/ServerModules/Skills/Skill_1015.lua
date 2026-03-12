-- 廉颇 终极特写: 天崩地裂·终极
-- 带电影特写的大招，服务端处理伤害+VFX，客户端处理镜头

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local BaseSkill = require(ServerScriptService:WaitForChild("ServerModules"):WaitForChild("BaseSkill"))

local LianPoCinematic = setmetatable({}, BaseSkill)
LianPoCinematic.__index = LianPoCinematic

function LianPoCinematic.new(skillID)
	return setmetatable(BaseSkill.new(skillID), LianPoCinematic)
end

local function createGroundCrack(position, radius)
	for i = 1, 10 do
		local angle = (i / 10) * math.pi * 2
		local crack = Instance.new("Part")
		crack.Size = Vector3.new(0.6, 0.3, radius * 0.8)
		crack.CFrame = CFrame.new(position) * CFrame.Angles(0, angle, 0) * CFrame.new(0, -2, -radius * 0.4)
		crack.Anchored = true
		crack.CanCollide = false
		crack.Material = Enum.Material.Neon
		crack.Color = Color3.fromRGB(255, 100, 0)
		crack.Transparency = 0.2
		crack.Parent = workspace

		TweenService:Create(crack, TweenInfo.new(2), {Transparency = 1}):Play()
		Debris:AddItem(crack, 2.5)
	end
end

local function createShockwave(position, maxRadius)
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.4, 2, 2)
	ring.CFrame = CFrame.new(position.X, position.Y - 2, position.Z) * CFrame.Angles(0, 0, math.rad(90))
	ring.Anchored = true
	ring.CanCollide = false
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.fromRGB(255, 150, 50)
	ring.Transparency = 0.2
	ring.Parent = workspace

	TweenService:Create(ring, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.4, maxRadius * 2, maxRadius * 2),
		Transparency = 1
	}):Play()
	Debris:AddItem(ring, 0.8)
end

local function createDebrisRocks(position, count)
	for i = 1, count do
		local rock = Instance.new("Part")
		rock.Size = Vector3.new(
			math.random(10, 20) / 10,
			math.random(10, 20) / 10,
			math.random(10, 20) / 10
		)
		local angle = math.random() * math.pi * 2
		local dist = math.random(2, 8)
		rock.Position = position + Vector3.new(math.cos(angle) * dist, math.random(1, 5), math.sin(angle) * dist)
		rock.Anchored = false
		rock.CanCollide = true
		rock.Material = Enum.Material.Slate
		rock.Color = Color3.fromRGB(80, 60, 40)
		rock.Parent = workspace

		local upForce = Instance.new("VectorForce")
		local att = Instance.new("Attachment")
		att.Parent = rock
		upForce.Attachment0 = att
		upForce.Force = Vector3.new(
			(math.random() - 0.5) * 200,
			math.random(300, 600),
			(math.random() - 0.5) * 200
		)
		upForce.RelativeTo = Enum.ActuatorRelativeTo.World
		upForce.Parent = rock
		Debris:AddItem(upForce, 0.15)

		task.delay(2, function()
			if rock and rock.Parent then
				TweenService:Create(rock, TweenInfo.new(0.5), {Transparency = 1}):Play()
				Debris:AddItem(rock, 0.6)
			end
		end)
		Debris:AddItem(rock, 4)
	end
end

local function dealAreaDamage(position, radius, damage)
	local enemiesFolder = workspace:FindFirstChild("敌人")
	if not enemiesFolder then return end
	for _, enemy in ipairs(enemiesFolder:GetChildren()) do
		if enemy:IsA("Model") and enemy:FindFirstChild("HumanoidRootPart") and enemy:FindFirstChild("Humanoid") then
			local dist = (enemy.HumanoidRootPart.Position - position).Magnitude
			if dist <= radius then
				enemy.Humanoid:TakeDamage(damage)
			end
		end
	end
end

function LianPoCinematic:OnCast(player, targetPos)
	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then return end
	local rootPart = character.HumanoidRootPart

	local damage = self.Config.BaseDamage or 300
	local radius = self.Config.AreaRadius or 15

	-- 发送电影事件给客户端
	local CinematicEvent = ReplicatedStorage:FindFirstChild("CinematicEvent")
	if CinematicEvent then
		CinematicEvent:FireClient(player, "LianPoUltimate", targetPos)
	end

	-- 第1次砸地 (t=1.6s)
	task.delay(1.6, function()
		if not rootPart or not rootPart.Parent then return end
		local pos = rootPart.Position
		dealAreaDamage(pos, radius, damage)
		createGroundCrack(pos, radius * 0.5)
		createShockwave(pos, radius)
		createDebrisRocks(pos, 5)
	end)

	-- 第2次砸地 (t=2.5s)
	task.delay(2.5, function()
		if not rootPart or not rootPart.Parent then return end
		local pos = rootPart.Position
		dealAreaDamage(pos, radius, damage * 1.5)
		createGroundCrack(pos, radius * 0.7)
		createShockwave(pos, radius * 1.3)
		createDebrisRocks(pos, 8)
	end)

	-- 第3次砸地 - 终极一击 (t=3.3s)
	task.delay(3.3, function()
		if not rootPart or not rootPart.Parent then return end
		local pos = rootPart.Position
		dealAreaDamage(pos, radius * 1.5, damage * 2.5)
		createGroundCrack(pos, radius * 1.2)
		createShockwave(pos, radius * 2)
		createDebrisRocks(pos, 12)
	end)
end

return LianPoCinematic
