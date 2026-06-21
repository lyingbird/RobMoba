-- ==========================================
-- 服务端：普攻管理器 (Auto Attack Manager)
-- 职责：处理普攻伤害、冷却、特效
-- ==========================================
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local function ensureRemoteEvent(name)
	local event = ReplicatedStorage:FindFirstChild(name)
	if not event then
		event = Instance.new("RemoteEvent")
		event.Name = name
		event.Parent = ReplicatedStorage
	end
	return event
end

local AttackTargetEvent = ensureRemoteEvent("AttackTargetEvent")
local CombatUtils = require(ServerScriptService.ServerModules:WaitForChild("CombatUtils"))
local PassiveSystem = require(ServerScriptService.ServerModules:WaitForChild("PassiveSystem"))
local EnergySystem = require(ServerScriptService.ServerModules:WaitForChild("EnergySystem"))
local EnergyConfig = require(ReplicatedStorage:WaitForChild("EnergyConfig"))

local ATTACK_RANGE = 12
local ATTACK_INTERVAL = 0.8

local playerLastAttack = {}
local playerAnimating = {}

local ATTACK_ALLOWED_STATES = {
	DUELING = true,
	TRAINING = true,
}

local function getPlayerState(player)
	if shared.LobbyManager then
		return shared.LobbyManager.GetPlayerState(player)
	end
	return "LOBBY"
end

local function canPlayerAutoAttack(player)
	local state = getPlayerState(player)
	if not ATTACK_ALLOWED_STATES[state] then
		return false
	end

	if state == "DUELING" then
		if not shared.DuelManager or not shared.DuelManager.IsPlayerInActiveBattle(player) then
			return false
		end
	end

	local character = player.Character
	if not character then return false end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not rootPart or humanoid.Health <= 0 then
		return false
	end

	if humanoid:GetAttribute("CanAutoAttack") == false then
		return false
	end

	return true, character, humanoid, rootPart
end

-- 程序攻击动画：身体前倾 + 右臂挥砍
local function playAttackAnimation(character, targetRoot)
	local humanoid = character:FindFirstChild("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not rootPart then return end

	-- 检测骨骼类型
	local isR6 = character:FindFirstChild("Torso") ~= nil
	local torso = isR6 and character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
	if not torso then return end

	-- 找到 RootJoint（身体前倾用）
	local rootJoint
	if isR6 then
		rootJoint = rootPart:FindFirstChild("RootJoint")
	else
		local lowerTorso = character:FindFirstChild("LowerTorso")
		if lowerTorso then
			rootJoint = lowerTorso:FindFirstChild("Root")
		end
	end

	-- 找到右臂 Motor6D
	local rightShoulder
	if isR6 then
		rightShoulder = torso:FindFirstChild("Right Shoulder")
	else
		local rightUpperArm = character:FindFirstChild("RightUpperArm")
		if rightUpperArm then
			rightShoulder = rightUpperArm:FindFirstChild("RightShoulder")
		end
	end

	-- 暂停默认动画
	local animator = humanoid:FindFirstChildOfClass("Animator")
	local pausedTracks = {}
	if animator then
		for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
			track:AdjustSpeed(0)
			table.insert(pausedTracks, track)
		end
	end

	-- 保存原始 C0
	local origRootC0 = rootJoint and rootJoint.C0 or nil
	local origShoulderC0 = rightShoulder and rightShoulder.C0 or nil

	-- 阶段1：快速前倾 + 手臂举起 (0.08s)
	local tweenInfoFast = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	if rootJoint and origRootC0 then
		local leanC0 = origRootC0 * CFrame.Angles(math.rad(-15), 0, 0)
		TweenService:Create(rootJoint, tweenInfoFast, {C0 = leanC0}):Play()
	end

	if rightShoulder and origShoulderC0 then
		local raiseC0 = origShoulderC0 * CFrame.Angles(math.rad(-120), math.rad(-20), 0)
		TweenService:Create(rightShoulder, tweenInfoFast, {C0 = raiseC0}):Play()
	end

	task.delay(0.08, function()
		-- 阶段2：挥砍下劈 (0.1s)
		local tweenInfoSwing = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

		if rightShoulder and origShoulderC0 then
			local swingC0 = origShoulderC0 * CFrame.Angles(math.rad(30), math.rad(20), 0)
			TweenService:Create(rightShoulder, tweenInfoSwing, {C0 = swingC0}):Play()
		end

		task.delay(0.15, function()
			-- 阶段3：恢复原位 (0.2s)
			local tweenInfoRecover = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

			if rootJoint and origRootC0 then
				TweenService:Create(rootJoint, tweenInfoRecover, {C0 = origRootC0}):Play()
			end
			if rightShoulder and origShoulderC0 then
				TweenService:Create(rightShoulder, tweenInfoRecover, {C0 = origShoulderC0}):Play()
			end

			-- 恢复默认动画
			task.delay(0.2, function()
				for _, track in ipairs(pausedTracks) do
					if track.IsPlaying then
						track:AdjustSpeed(1)
					end
				end
			end)
		end)
	end)
end

local function createSlashVFX(originRoot, targetRoot)
	local offset = targetRoot.Position - originRoot.Position
	local direction = offset.Magnitude >= 0.001 and offset.Unit or originRoot.CFrame.LookVector
	if direction.Magnitude < 0.001 then
		direction = Vector3.new(0, 0, -1)
	end
	local midPoint = originRoot.Position + direction * 3

	local slash = Instance.new("Part")
	slash.Size = Vector3.new(4, 4, 0.3)
	slash.CFrame = CFrame.lookAt(midPoint, targetRoot.Position) * CFrame.Angles(0, 0, math.rad(math.random(-30, 30)))
	slash.Anchored = true
	slash.CanCollide = false
	slash.Material = Enum.Material.Neon
	slash.Color = Color3.fromRGB(255, 255, 200)
	slash.Transparency = 0.3
	slash.Parent = workspace

	TweenService:Create(slash, TweenInfo.new(0.3), {
		Transparency = 1,
		Size = Vector3.new(6, 6, 0.3)
	}):Play()

	Debris:AddItem(slash, 0.4)
end

AttackTargetEvent.OnServerEvent:Connect(function(player, targetModel)
	if not targetModel or not targetModel:IsA("Model") then return end

	local canAttack, character, _, rootPart = canPlayerAutoAttack(player)
	if not canAttack then return end

	-- 使用 CombatUtils 统一验证：目标必须是敌方（NPC 或敌方玩家）
	if not CombatUtils.isEnemy(player, targetModel) then return end

	local targetHumanoid = targetModel:FindFirstChild("Humanoid")
	local targetRoot = targetModel:FindFirstChild("HumanoidRootPart")
	if not targetHumanoid or not targetRoot or targetHumanoid.Health <= 0 then return end

	local dist = (rootPart.Position - targetRoot.Position).Magnitude
	if dist > ATTACK_RANGE then return end

	local userId = player.UserId
	local now = os.clock()
	if playerLastAttack[userId] and (now - playerLastAttack[userId]) < ATTACK_INTERVAL then return end
	playerLastAttack[userId] = now

	-- 读取角色 ATK 属性计算伤害（如没有则回退到默认 65）
	local atk = character:GetAttribute("ATK") or 65
	local damage = atk

	-- 暴击判定
	local critRate = character:GetAttribute("CritRate") or 0
	local critDmg = character:GetAttribute("CritDmg") or 1.5
	if math.random() < critRate then
		damage = damage * critDmg
	end

	-- 目标防御减伤（物理防御）
	local targetDef = targetModel:GetAttribute("DEF") or 0
	local penetration = character:GetAttribute("Penetration") or 0
	local effectiveDef = math.max(0, targetDef - penetration)
	damage = damage * (100 / (100 + effectiveDef))

	local damageReduction = targetHumanoid:GetAttribute("DamageReduction") or 0
	if damageReduction > 0 then
		damage = damage * (1 - math.clamp(damageReduction, 0, 0.9))
	end

	-- 记录伤害来源（用于击杀归属）
	targetModel:SetAttribute("LastDamagePlayer", player.Name)

	targetHumanoid:TakeDamage(math.floor(damage))
	playAttackAnimation(character, targetRoot)
	createSlashVFX(rootPart, targetRoot)

	-- REQ-007: 被动事件派发 (普攻命中 → OnHit)
	PassiveSystem:OnEvent("OnHit", player, {
		target = targetModel,
		damage = math.floor(damage),
		damageType = "Physical",
	})

	-- REQ-007: Rage 能量获取 (普攻命中)
	local rageGain = EnergyConfig.Rage and EnergyConfig.Rage.GainOnHit or 0
	if rageGain > 0 then
		EnergySystem:AddEnergy(player, rageGain, "hit")
	end
end)

Players.PlayerRemoving:Connect(function(player)
	playerLastAttack[player.UserId] = nil
end)
