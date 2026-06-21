-- ==========================================
-- ProjectileSkill: 弹道技能 Archetype 基类
-- 覆盖: ~40% 技能 (Fireball, LuxQ, LuxW, AngelaQ, AngelaW, HouYiR)
-- Template Method: OnCast → GetProjectileConfig → 通用弹道逻辑
-- ==========================================
local ServerScriptService = game:GetService("ServerScriptService")
local Debris = game:GetService("Debris")

local BaseSkill = require(ServerScriptService:WaitForChild("ServerModules"):WaitForChild("BaseSkill"))
local CombatUtils = require(ServerScriptService:WaitForChild("ServerModules"):WaitForChild("CombatUtils"))
local SkillHelper = require(ServerScriptService:WaitForChild("ServerModules"):WaitForChild("SkillHelper"))

local ProjectileSkill = setmetatable({}, BaseSkill)
ProjectileSkill.__index = ProjectileSkill

function ProjectileSkill.new(skillID)
	return setmetatable(BaseSkill.new(skillID), ProjectileSkill)
end

local function getSafeFlatDirection(fromPos, targetPos, fallbackCFrame)
	local flatOffset = Vector3.new(targetPos.X - fromPos.X, 0, targetPos.Z - fromPos.Z)
	if flatOffset.Magnitude >= 0.001 then
		return flatOffset.Unit
	end

	local fallback = fallbackCFrame and fallbackCFrame.LookVector or Vector3.new(0, 0, -1)
	fallback = Vector3.new(fallback.X, 0, fallback.Z)
	if fallback.Magnitude >= 0.001 then
		return fallback.Unit
	end

	return Vector3.new(0, 0, -1)
end

--- 子类必须实现: 返回弹道配置
function ProjectileSkill:GetProjectileConfig()
	return {
		Speed = self.Config.Speed or 60,
		Size = self.Config.Size or Vector3.new(1.5, 1.5, 1.5),
		Color = self.Config.Color or Color3.fromRGB(255, 120, 0),
		Material = self.Config.Material or Enum.Material.Neon,
		MaxLifetime = self.Config.MaxLifetime or 3,
		MaxPierceCount = self.Config.MaxPierceCount or 1,
		OnHitEffects = self.Config.OnHitEffects or {},
		OnHitCC = self.Config.OnHitCC or {},
	}
end

--- 子类可选重写: 弹道命中回调
function ProjectileSkill:OnProjectileHit(player, target, hitPos)
end

--- 子类可选重写: 穿透命中回调
function ProjectileSkill:OnProjectilePierce(player, target, hitPos, count)
end

--- 子类可选重写: 弹道消失回调
function ProjectileSkill:OnProjectileExpire(player, lastPos)
end

--- 创建弹体 Part
function ProjectileSkill:_createBullet(config, startPos, direction)
	local bullet = Instance.new("Part")
	bullet.Size = config.Size
	bullet.Material = config.Material
	bullet.Color = config.Color
	bullet.CFrame = CFrame.new(startPos + direction * 3, startPos + direction * 4)
	bullet.CanCollide = false
	bullet.Anchored = false
	bullet.Parent = workspace

	local attachment = Instance.new("Attachment")
	attachment.Parent = bullet

	local lv = Instance.new("LinearVelocity")
	lv.Attachment0 = attachment
	lv.VectorVelocity = direction * config.Speed
	lv.MaxForce = math.huge
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.Parent = bullet

	Debris:AddItem(bullet, config.MaxLifetime)
	return bullet
end

--- 标准弹道释放
function ProjectileSkill:OnCast(player, targetPos)
	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then return end
	local rootPart = character.HumanoidRootPart

	local config = self:GetProjectileConfig()
	local maxRange = self.Config.Range or self.Config.BaseRange or 50

	local startPos = rootPart.Position
	local direction = getSafeFlatDirection(startPos, targetPos, rootPart.CFrame)

	local bullet = self:_createBullet(config, startPos, direction)

	local hitCount = 0
	local maxHits = config.MaxPierceCount
	local hitTargets = {}
	local destroyed = false

	-- 碰撞检测
	bullet.Touched:Connect(function(hit)
		if destroyed or hit:IsDescendantOf(character) then return end

		-- 查找目标 Model
		local targetModel = hit.Parent
		local humanoid = targetModel and targetModel:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			targetModel = hit.Parent and hit.Parent.Parent
			humanoid = targetModel and targetModel:FindFirstChildOfClass("Humanoid")
		end

		if humanoid and not hitTargets[targetModel] then
			-- 敌我判定
			if not CombatUtils.isEnemy(player, targetModel) then return end

			hitTargets[targetModel] = true
			hitCount = hitCount + 1

			-- 效果施加
			local allEffects = {}
			for _, id in ipairs(config.OnHitEffects) do table.insert(allEffects, id) end
			for _, id in ipairs(config.OnHitCC) do table.insert(allEffects, id) end
			SkillHelper.ApplyEffects(self, character, targetModel, allEffects)

			targetModel:SetAttribute("LastDamagePlayer", player.Name)

			-- 回调
			if hitCount >= 2 then
				self:OnProjectilePierce(player, targetModel, bullet.Position, hitCount)
			else
				self:OnProjectileHit(player, targetModel, bullet.Position)
			end

			-- 穿透检查
			if hitCount >= maxHits then
				destroyed = true
				bullet:Destroy()
			end
		elseif not humanoid and hit.CanCollide then
			-- 碰墙
			destroyed = true
			self:OnProjectileExpire(player, bullet.Position)
			bullet:Destroy()
		end
	end)

	-- 超距离销毁
	task.spawn(function()
		while not destroyed and bullet and bullet.Parent do
			if (bullet.Position - startPos).Magnitude >= maxRange then
				destroyed = true
				self:OnProjectileExpire(player, bullet.Position)
				bullet:Destroy()
				break
			end
			task.wait(0.05)
		end
	end)
end

return ProjectileSkill
