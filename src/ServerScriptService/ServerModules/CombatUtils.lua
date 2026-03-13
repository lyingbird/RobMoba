-- ==========================================
-- 统一战斗目标验证工具 (Combat Utilities)
-- 职责：判断敌我关系、范围敌方查找
-- 所有技能和普攻统一通过此模块验证目标
-- ==========================================
local Players = game:GetService("Players")

local CombatUtils = {}

-- 获取敌人 NPC 文件夹（延迟获取，兼容文件夹不存在的情况）
local enemiesFolder = workspace:FindFirstChild("敌人")
if not enemiesFolder then
	task.spawn(function()
		enemiesFolder = workspace:WaitForChild("敌人", 10)
	end)
end

--- 从 Model 反查所属 Player
--- @param model Model 需要查询的角色模型
--- @return Player? 如果是玩家角色则返回 Player，否则 nil
function CombatUtils.getPlayerFromModel(model: Model): Player?
	if not model or not model:IsA("Model") then
		return nil
	end
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character == model then
			return player
		end
	end
	return nil
end

--- 判断 targetModel 是否为 attackerPlayer 的敌人
--- 规则：
---   1. NPC（workspace.敌人 的子物体）对所有玩家都是敌方
---   2. 不同 Team 的玩家角色互为敌方
---   3. 自己、同 Team 队友、死亡目标 → 不是敌人
--- @param attackerPlayer Player 攻击者
--- @param targetModel Model 目标模型
--- @return boolean 是否为敌方
function CombatUtils.isEnemy(attackerPlayer: Player, targetModel: Model): boolean
	if not attackerPlayer or not targetModel then
		return false
	end

	-- 检查目标是否有有效的 Humanoid（活着的）
	local targetHumanoid = targetModel:FindFirstChild("Humanoid")
	if not targetHumanoid or targetHumanoid.Health <= 0 then
		return false
	end

	-- 规则1：NPC 敌人对所有玩家都是敌方
	if enemiesFolder and targetModel:IsDescendantOf(enemiesFolder) then
		return true
	end

	-- 规则2：检查是否为敌方玩家
	local targetPlayer = CombatUtils.getPlayerFromModel(targetModel)
	if not targetPlayer then
		return false -- 既不是 NPC 也不是玩家角色
	end

	-- 不能攻击自己
	if targetPlayer == attackerPlayer then
		return false
	end

	-- 使用 Team 判断敌我
	local attackerTeam = attackerPlayer.Team
	local targetTeam = targetPlayer.Team

	-- 没有 Team 分配时，不允许攻击（安全默认）
	if not attackerTeam or not targetTeam then
		return false
	end

	-- 不同 Team = 敌方
	return attackerTeam ~= targetTeam
end

--- 判断 targetModel 是否为 casterPlayer 的友方（同队玩家）
--- 用于护盾等友方技能
--- @param casterPlayer Player 施法者
--- @param targetModel Model 目标模型
--- @return boolean 是否为友方
function CombatUtils.isAlly(casterPlayer: Player, targetModel: Model): boolean
	if not casterPlayer or not targetModel then
		return false
	end

	local targetHumanoid = targetModel:FindFirstChild("Humanoid")
	if not targetHumanoid or targetHumanoid.Health <= 0 then
		return false
	end

	local targetPlayer = CombatUtils.getPlayerFromModel(targetModel)
	if not targetPlayer then
		return false
	end

	-- 自己也算友方
	if targetPlayer == casterPlayer then
		return true
	end

	local casterTeam = casterPlayer.Team
	local targetTeam = targetPlayer.Team

	if not casterTeam or not targetTeam then
		return false
	end

	return casterTeam == targetTeam
end

--- 获取范围内所有敌方目标（包含 NPC 和敌方玩家）
--- @param casterPlayer Player 施法者
--- @param position Vector3 范围中心点
--- @param radius number 范围半径
--- @param excludeModel Model? 可选，排除的模型（通常是施法者自己）
--- @return {Model} 范围内的敌方目标列表
function CombatUtils.getEnemiesInRange(
	casterPlayer: Player,
	position: Vector3,
	radius: number,
	excludeModel: Model?
): { Model }
	local enemies = {}
	local radiusSq = radius * radius -- 用平方比较避免 sqrt

	-- 检查 NPC 敌人
	if enemiesFolder then
		for _, npc in ipairs(enemiesFolder:GetChildren()) do
			if npc:IsA("Model") and npc ~= excludeModel then
				local humanoid = npc:FindFirstChild("Humanoid")
				local rootPart = npc:FindFirstChild("HumanoidRootPart")
				if humanoid and rootPart and humanoid.Health > 0 then
					local distSq = (rootPart.Position - position).Magnitude
					distSq = distSq * distSq
					if distSq <= radiusSq then
						table.insert(enemies, npc)
					end
				end
			end
		end
	end

	-- 检查敌方玩家
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		if character and character ~= excludeModel then
			local humanoid = character:FindFirstChild("Humanoid")
			local rootPart = character:FindFirstChild("HumanoidRootPart")
			if humanoid and rootPart and humanoid.Health > 0 then
				-- 检查是否为敌方
				if CombatUtils.isEnemy(casterPlayer, character) then
					local distSq = (rootPart.Position - position).Magnitude
					distSq = distSq * distSq
					if distSq <= radiusSq then
						table.insert(enemies, character)
					end
				end
			end
		end
	end

	return enemies
end

--- 获取范围内最近的敌方目标
--- @param casterPlayer Player 施法者
--- @param position Vector3 范围中心点
--- @param radius number 搜索半径
--- @param excludeModel Model? 排除的模型
--- @return Model? 最近的敌方目标，没有则 nil
function CombatUtils.getNearestEnemy(
	casterPlayer: Player,
	position: Vector3,
	radius: number,
	excludeModel: Model?
): Model?
	local nearest = nil
	local nearestDistSq = radius * radius

	-- 检查 NPC 敌人
	if enemiesFolder then
		for _, npc in ipairs(enemiesFolder:GetChildren()) do
			if npc:IsA("Model") and npc ~= excludeModel then
				local humanoid = npc:FindFirstChild("Humanoid")
				local rootPart = npc:FindFirstChild("HumanoidRootPart")
				if humanoid and rootPart and humanoid.Health > 0 then
					local distSq = (rootPart.Position - position).Magnitude
					distSq = distSq * distSq
					if distSq <= nearestDistSq then
						nearestDistSq = distSq
						nearest = npc
					end
				end
			end
		end
	end

	-- 检查敌方玩家
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		if character and character ~= excludeModel then
			local humanoid = character:FindFirstChild("Humanoid")
			local rootPart = character:FindFirstChild("HumanoidRootPart")
			if humanoid and rootPart and humanoid.Health > 0 then
				if CombatUtils.isEnemy(casterPlayer, character) then
					local distSq = (rootPart.Position - position).Magnitude
					distSq = distSq * distSq
					if distSq <= nearestDistSq then
						nearestDistSq = distSq
						nearest = character
					end
				end
			end
		end
	end

	return nearest
end

return CombatUtils
