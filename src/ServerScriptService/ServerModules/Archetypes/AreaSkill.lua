-- ==========================================
-- AreaSkill: 区域技能 Archetype 基类
-- 覆盖: ~25% 技能 (LuxE, HouYiW, LianPoR)
-- Template Method: OnCast → GetAreaConfig → 通用区域逻辑
-- ==========================================
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local BaseSkill = require(ServerScriptService:WaitForChild("ServerModules"):WaitForChild("BaseSkill"))
local SkillHelper = require(ServerScriptService:WaitForChild("ServerModules"):WaitForChild("SkillHelper"))

local AreaSkill = setmetatable({}, BaseSkill)
AreaSkill.__index = AreaSkill

-- 每个玩家的活跃区域（用于 Recast）
local activeAreas = {}

function AreaSkill.new(skillID)
	return setmetatable(BaseSkill.new(skillID), AreaSkill)
end

--- 子类可重写: 返回区域配置（默认从 Config 读取）
function AreaSkill:GetAreaConfig()
	return {
		Radius = self.Config.Radius or 12,
		Duration = self.Config.Duration or 3,
		TickInterval = self.Config.TickInterval or 0.5,
		TickEffects = self.Config.TickEffects or {},
		OnEnterEffects = self.Config.OnEnterEffects or {},
		OnExpireEffects = self.Config.OnExpireEffects or {},
		CanRecast = self.Config.CanRecast or false,
	}
end

--- 子类可选重写
function AreaSkill:OnAreaCreate(player, area) end
function AreaSkill:OnAreaTick(player, area, targets) end
function AreaSkill:OnAreaExpire(player, area) end
function AreaSkill:OnRecast(player, area) end

--- 创建区域标记 Part
function AreaSkill:_createArea(position, radius)
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
	return zone
end

--- 清理区域
function AreaSkill:_cleanup(areaData)
	if areaData.cleaned then return end
	areaData.cleaned = true

	if areaData.heartbeatConn then
		areaData.heartbeatConn:Disconnect()
		areaData.heartbeatConn = nil
	end
	if areaData.zonePart and areaData.zonePart.Parent then
		areaData.zonePart:Destroy()
	end
end

--- 标准区域释放
function AreaSkill:OnCast(player, targetPos)
	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then return end
	local userId = player.UserId

	local config = self:GetAreaConfig()

	-- Recast: 如果已有活跃区域，触发引爆
	if config.CanRecast and activeAreas[userId] and not activeAreas[userId].cleaned then
		self:OnRecast(player, activeAreas[userId])
		self:_cleanup(activeAreas[userId])
		activeAreas[userId] = nil
		self.WaitingForRecast = false
		return
	end

	local position = Vector3.new(targetPos.X, targetPos.Y, targetPos.Z)
	local zonePart = self:_createArea(position, config.Radius)

	local areaData = {
		position = position,
		radius = config.Radius,
		zonePart = zonePart,
		heartbeatConn = nil,
		cleaned = false,
		config = config,
		startTime = os.clock(),
		lastTickTime = os.clock(),
	}

	self:OnAreaCreate(player, areaData)

	-- Heartbeat Tick 循环
	areaData.heartbeatConn = RunService.Heartbeat:Connect(function()
		if areaData.cleaned then return end
		local now = os.clock()
		local elapsed = now - areaData.startTime

		-- 到期检查
		if elapsed >= config.Duration then
			-- 到期效果
			if #config.OnExpireEffects > 0 then
				SkillHelper.ApplyAreaEffects(self, character, player, position, config.Radius, config.OnExpireEffects)
			end
			self:OnAreaExpire(player, areaData)
			self:_cleanup(areaData)
			if activeAreas[userId] == areaData then
				activeAreas[userId] = nil
				self.WaitingForRecast = false
			end
			return
		end

		-- Tick 检查
		if now - areaData.lastTickTime >= config.TickInterval then
			areaData.lastTickTime = now
			local targets = {}
			if #config.TickEffects > 0 then
				targets = SkillHelper.ApplyAreaEffects(self, character, player, position, config.Radius, config.TickEffects)
			end
			self:OnAreaTick(player, areaData, targets)
		end
	end)

	-- 注册 Recast
	if config.CanRecast then
		activeAreas[userId] = areaData
	end

	-- 安全兜底: Debris 清理
	Debris:AddItem(zonePart, config.Duration + 1)
end

return AreaSkill
