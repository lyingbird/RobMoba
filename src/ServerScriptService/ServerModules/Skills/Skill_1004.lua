-- ==========================================
-- Skill_1004: LuxE (透光奇点)
-- Archetype: AreaSkill (CanRecast=true)
-- 效果: 3004(Slow), 3005(Damage)
-- ==========================================
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")

local AreaSkill = require(ServerScriptService:WaitForChild("ServerModules"):WaitForChild("Archetypes"):WaitForChild("AreaSkill"))
local SkillHelper = require(ServerScriptService:WaitForChild("ServerModules"):WaitForChild("SkillHelper"))

local LuxE = setmetatable({}, AreaSkill)
LuxE.__index = LuxE

function LuxE.new(skillID)
	local self = setmetatable(AreaSkill.new(skillID), LuxE)
	self.IsRecastable = true
	return self
end

function LuxE:CanCast()
	if self.WaitingForRecast then
		return true
	end
	return (os.clock() - self.LastCastTime) >= self:GetFinalCD()
end

-- VFX: 区域特效
local function createZoneVFX(position, radius)
	local zone = Instance.new("Part")
	zone.Shape = Enum.PartType.Cylinder
	zone.Material = Enum.Material.Neon
	zone.Color = Color3.fromRGB(255, 245, 180)
	zone.Size = Vector3.new(0.5, radius * 2, radius * 2)
	zone.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	zone.Anchored = true
	zone.CanCollide = false
	zone.Transparency = 0.5
	zone.Parent = workspace

	local orb = Instance.new("Part")
	orb.Shape = Enum.PartType.Ball
	orb.Material = Enum.Material.Neon
	orb.Color = Color3.fromRGB(255, 250, 200)
	orb.Size = Vector3.new(3, 3, 3)
	orb.Position = position + Vector3.new(0, 3, 0)
	orb.Anchored = true
	orb.CanCollide = false
	orb.Transparency = 0.2
	orb.Parent = workspace

	TweenService:Create(orb, TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
		Position = position + Vector3.new(0, 4.5, 0)
	}):Play()

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 245, 180)
	light.Brightness = 3
	light.Range = radius + 5
	light.Parent = orb

	return zone, orb
end

local function createDetonationVFX(position, radius)
	local flash = Instance.new("Part")
	flash.Shape = Enum.PartType.Ball
	flash.Material = Enum.Material.Neon
	flash.Color = Color3.fromRGB(255, 255, 220)
	flash.Size = Vector3.new(2, 2, 2)
	flash.Position = position
	flash.Anchored = true
	flash.CanCollide = false
	flash.Parent = workspace

	TweenService:Create(flash, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(radius * 2, radius * 2, radius * 2),
		Transparency = 1
	}):Play()
	Debris:AddItem(flash, 0.5)

	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.fromRGB(255, 235, 150)
	ring.Size = Vector3.new(0.3, 2, 2)
	ring.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	ring.Anchored = true
	ring.CanCollide = false
	ring.Transparency = 0.3
	ring.Parent = workspace

	TweenService:Create(ring, TweenInfo.new(0.35), {
		Size = Vector3.new(0.3, radius * 3, radius * 3),
		Transparency = 1
	}):Play()
	Debris:AddItem(ring, 0.5)
end

-- 重写 OnCast: 添加飞行弹体动画, 然后调用 AreaSkill 逻辑
function LuxE:OnCast(player, targetPos)
	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then return end

	-- 如果 Recast, 委托父类处理
	if self.WaitingForRecast then
		AreaSkill.OnCast(self, player, targetPos)
		return
	end

	local rootPart = character.HumanoidRootPart
	local startPos = rootPart.Position + Vector3.new(0, 2, 0)
	local landPos = Vector3.new(targetPos.X, targetPos.Y, targetPos.Z)
	local travelSpeed = self.Config.TravelSpeed or 40

	-- 飞行弹体动画
	local travelOrb = Instance.new("Part")
	travelOrb.Shape = Enum.PartType.Ball
	travelOrb.Material = Enum.Material.Neon
	travelOrb.Color = Color3.fromRGB(255, 245, 180)
	travelOrb.Size = Vector3.new(2.5, 2.5, 2.5)
	travelOrb.Position = startPos
	travelOrb.Anchored = true
	travelOrb.CanCollide = false
	travelOrb.Parent = workspace

	local travelDist = (landPos - startPos).Magnitude
	local travelTime = math.clamp(travelDist / travelSpeed, 0.15, 1.2)
	local arcHeight = math.min(travelDist * 0.15, 8)
	local travelStart = os.clock()

	local travelConn
	travelConn = RunService.Heartbeat:Connect(function()
		local t = math.clamp((os.clock() - travelStart) / travelTime, 0, 1)
		local flatPos = startPos:Lerp(landPos, t)
		local yOffset = arcHeight * 4 * t * (1 - t)
		travelOrb.Position = Vector3.new(flatPos.X, flatPos.Y + yOffset, flatPos.Z)
		if t >= 1 then
			travelConn:Disconnect()
			travelOrb:Destroy()
		end
	end)

	task.wait(travelTime)

	-- 调用父类创建区域
	AreaSkill.OnCast(self, player, targetPos)
end

-- 额外 VFX: 区域创建时
function LuxE:OnAreaCreate(player, areaData)
	local zone, orb = createZoneVFX(areaData.position, areaData.radius)
	areaData._vfxZone = zone
	areaData._vfxOrb = orb
end

-- Recast: 引爆区域
function LuxE:OnRecast(player, areaData)
	createDetonationVFX(areaData.position, areaData.radius)
	-- 引爆伤害 (OnExpireEffects)
	local config = self:GetAreaConfig()
	if #config.OnExpireEffects > 0 then
		local character = player.Character
		if character then
			SkillHelper.ApplyAreaEffects(self, character, player, areaData.position, areaData.radius, config.OnExpireEffects)
		end
	end
	-- 清理额外 VFX
	if areaData._vfxZone then areaData._vfxZone:Destroy() end
	if areaData._vfxOrb then areaData._vfxOrb:Destroy() end
end

-- 区域到期: 也引爆
function LuxE:OnAreaExpire(player, areaData)
	createDetonationVFX(areaData.position, areaData.radius)
	if areaData._vfxZone then areaData._vfxZone:Destroy() end
	if areaData._vfxOrb then areaData._vfxOrb:Destroy() end
end

return LuxE
