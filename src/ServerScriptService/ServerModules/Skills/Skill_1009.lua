-- ==========================================
-- Skill_1009: HouYiQ (多重箭矢)
-- Archetype: InstantSkill
-- 效果: 3040(StatMod +2 AttackCount)
-- 特殊: OnInstantCast 创建5把环绕浮剑自动追踪
-- ==========================================
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")

local InstantSkill = require(ServerScriptService:WaitForChild("ServerModules"):WaitForChild("Archetypes"):WaitForChild("InstantSkill"))
local CombatUtils = require(ServerScriptService:WaitForChild("ServerModules"):WaitForChild("CombatUtils"))
local SkillHelper = require(ServerScriptService:WaitForChild("ServerModules"):WaitForChild("SkillHelper"))
local BuffSystem = require(ServerScriptService:WaitForChild("ServerModules"):WaitForChild("BuffSystem"))

local HouYiQ = setmetatable({}, InstantSkill)
HouYiQ.__index = HouYiQ

function HouYiQ.new(skillID)
	return setmetatable(InstantSkill.new(skillID), HouYiQ)
end

-- ===== VFX: 创建浮剑 =====

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

-- ===== 重写 OnInstantCast: 创建环绕浮剑 + 自动追踪 =====
function HouYiQ:OnInstantCast(player, targetPos)
	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then return end
	local rootPart = character.HumanoidRootPart

	local swordCount = self.Config.SwordCount or 5
	local duration = self.Config.Duration or 6
	local detectRadius = self.Config.DetectRadius or 20
	-- 浮剑伤害通过 SkillHelper → BuffSystem 管线
	-- SelfEffects (3040 = +2 AttackCount) 已在父类 OnCast 中施加

	-- 创建剑
	local swords = {}
	for i = 1, swordCount do
		local sword = createSword()
		table.insert(swords, { part = sword, alive = true, angle = (i - 1) * (2 * math.pi / swordCount) })
	end

	local orbitRadius = 4
	local orbitSpeed = 2
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
		local nearestEnemy = CombatUtils.getNearestEnemy(player, center, detectRadius, character)

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
						nearestEnemy:SetAttribute("LastDamagePlayer", player.Name)
						-- 浮剑命中: 施加 SwordEffects (3045 = Damage 150)
						local swordEffects = self.Config.SwordEffects or {}
						if #swordEffects > 0 then
							SkillHelper.ApplyEffects(self, character, nearestEnemy, swordEffects)
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
