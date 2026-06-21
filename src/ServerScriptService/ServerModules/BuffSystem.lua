-- ==========================================
-- BuffSystem: Buff 运行时管理器
-- 职责: 效果施加/移除/叠加/互斥/Tick/到期清理
-- 驱动方式: RunService.Heartbeat（不使用 task.delay）
-- 运行位置: 服务端 (ServerScriptService)
-- ==========================================
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EffectConfig = require(ReplicatedStorage:WaitForChild("EffectConfig"))

local BuffSystem = {}

-- ========== 数据结构 ==========
-- activeBuffs[characterModel][instanceId] = BuffInstance
local activeBuffs = {}
local nextInstanceId = 1

-- EffectExecutor 延迟加载（避免循环依赖）
local EffectExecutor = nil
local function getEffectExecutor()
	if not EffectExecutor then
		EffectExecutor = require(script.Parent:WaitForChild("EffectExecutor"))
	end
	return EffectExecutor
end

-- ========== 内部工具 ==========

local function generateInstanceId()
	local id = "buff_" .. nextInstanceId
	nextInstanceId = nextInstanceId + 1
	return id
end

local function getCharacterBuffs(target)
	if not activeBuffs[target] then
		activeBuffs[target] = {}
	end
	return activeBuffs[target]
end

-- ========== 叠加规则处理 ==========

function BuffSystem:_handleStacking(target, effectId, effectCfg)
	local stacking = effectCfg.Stacking or "Replace"
	local buffs = getCharacterBuffs(target)

	if stacking == "Replace" then
		-- 移除同 effectId 的旧 Buff
		for instId, buff in pairs(buffs) do
			if buff.effectId == effectId then
				self:_expireBuff(target, buff)
				buffs[instId] = nil
			end
		end
		return nil -- 创建新实例

	elseif stacking == "Stack" then
		-- 查找已有同 effectId 的 Buff，增加层数
		for _, buff in pairs(buffs) do
			if buff.effectId == effectId then
				local maxStacks = effectCfg.MaxStacks or 1
				if buff.stacks < maxStacks then
					buff.stacks = buff.stacks + 1
				end
				-- 刷新持续时间
				buff.startTime = os.clock()
				return buff -- 返回已有实例，不创建新的
			end
		end
		return nil -- 没找到已有的，创建新实例

	elseif stacking == "Refresh" then
		-- 查找已有同 effectId 的 Buff，只刷新持续时间
		for _, buff in pairs(buffs) do
			if buff.effectId == effectId then
				buff.startTime = os.clock()
				return buff -- 返回已有实例
			end
		end
		return nil -- 没找到已有的，创建新实例

	elseif stacking == "Independent" then
		return nil -- 总是创建新实例
	end

	return nil
end

-- ========== 互斥组检查 ==========

function BuffSystem:_checkMutex(target, effectId)
	local effectCfg = EffectConfig[effectId]
	if not effectCfg or not effectCfg.MutexGroup then return end

	local mutexGroup = effectCfg.MutexGroup
	local buffs = getCharacterBuffs(target)

	-- 收集同互斥组的旧 Buff
	local toRemove = {}
	for instId, buff in pairs(buffs) do
		local oldCfg = EffectConfig[buff.effectId]
		if oldCfg and oldCfg.MutexGroup == mutexGroup then
			table.insert(toRemove, { instId = instId, buff = buff })
		end
	end

	-- 移除旧 Buff
	for _, item in ipairs(toRemove) do
		self:_expireBuff(target, item.buff)
		buffs[item.instId] = nil
	end
end

-- ========== Buff 到期处理 ==========

function BuffSystem:_expireBuff(target, buff)
	local effectCfg = EffectConfig[buff.effectId]
	if not effectCfg then return end

	local executor = getEffectExecutor()

	-- 恢复 CC 效果
	if effectCfg.Type == "CC" then
		executor:_revertCC(target, effectCfg.CCType, buff)
	end

	-- 恢复 StatMod 效果
	if effectCfg.Type == "StatMod" then
		executor:_revertStatMod(target, effectCfg.Stat, buff)
	end

	-- 移除 Shield
	if effectCfg.Type == "Shield" then
		executor:_revertShield(target, buff)
	end
end

-- ========== Tick 处理 ==========

function BuffSystem:_tickBuff(target, buff, now)
	local effectCfg = EffectConfig[buff.effectId]
	if not effectCfg then return end

	if effectCfg.Type == "DoT" or effectCfg.Type == "HoT" then
		if effectCfg.TickInterval and buff.lastTickTime then
			if now - buff.lastTickTime >= effectCfg.TickInterval then
				local executor = getEffectExecutor()
				if effectCfg.Type == "DoT" then
					executor:_executeDoT(buff.source, target, effectCfg)
				elseif effectCfg.Type == "HoT" then
					executor:_executeHoT(buff.source, target, effectCfg)
				end
				buff.lastTickTime = now
			end
		end
	end
end

-- ========== Heartbeat 循环 ==========

function BuffSystem:_onHeartbeat(dt)
	local now = os.clock()

	-- 收集无效/空的角色条目（遍历后统一清理）
	local toCleanTargets = {}

	for target, buffs in pairs(activeBuffs) do
		-- 安全检查：目标是否还有效
		if not target or not target.Parent then
			table.insert(toCleanTargets, target)
			continue
		end

		-- 收集到期的 Buff（遍历中不直接删除）
		local toExpire = {}

		for instId, buff in pairs(buffs) do
			-- Tick 检查
			self:_tickBuff(target, buff, now)

			-- Shield 破碎检查
			local effectCfg = EffectConfig[buff.effectId]
			if effectCfg and effectCfg.Type == "Shield" then
				local humanoid = target:FindFirstChildOfClass("Humanoid")
				if humanoid then
					local shieldAmount = humanoid:GetAttribute("ShieldAmount") or 0
					if shieldAmount <= 0 then
						table.insert(toExpire, instId)
						continue
					end
				end
			end

			-- 到期检查
			local elapsed = now - buff.startTime
			if buff.duration and elapsed >= buff.duration then
				table.insert(toExpire, instId)
			end
		end

		-- 统一移除到期 Buff
		for _, instId in ipairs(toExpire) do
			local buff = buffs[instId]
			if buff then
				self:_expireBuff(target, buff)
				buffs[instId] = nil
			end
		end

		-- 清理空的角色条目
		if not next(buffs) then
			table.insert(toCleanTargets, target)
		end
	end

	-- 统一清理无效/空的角色条目
	for _, target in ipairs(toCleanTargets) do
		activeBuffs[target] = nil
	end
end

-- ========== 核心 API ==========

--- 施加效果
-- @param source Model 施加者角色
-- @param target Model 目标角色
-- @param effectId number EffectConfig 中的效果 ID
-- @return string|nil 成功返回 buffInstanceId，失败返回 nil
function BuffSystem:ApplyEffect(source, target, effectId)
	local effectCfg = EffectConfig[effectId]
	if not effectCfg then
		warn("[BuffSystem] 未知效果 ID: " .. tostring(effectId))
		return nil
	end

	-- 互斥组检查
	self:_checkMutex(target, effectId)

	-- 叠加规则处理
	local existingBuff = self:_handleStacking(target, effectId, effectCfg)
	if existingBuff then
		-- 已有 Buff 被更新（Stack/Refresh），不需要创建新实例
		return existingBuff.instanceId
	end

	-- 创建新 Buff 实例
	local now = os.clock()
	local instanceId = generateInstanceId()
	local buff = {
		instanceId = instanceId,
		effectId = effectId,
		source = source,
		target = target,
		startTime = now,
		duration = effectCfg.Duration or nil,
		stacks = 1,
		lastTickTime = now,
	}

	-- 注册到 activeBuffs
	local buffs = getCharacterBuffs(target)
	buffs[instanceId] = buff

	-- 执行即时效果
	local executor = getEffectExecutor()
	executor:Execute(source, target, effectCfg, buff)

	return instanceId
end

--- 移除指定效果
function BuffSystem:RemoveEffect(target, effectId)
	local buffs = activeBuffs[target]
	if not buffs then return false end

	local removed = false
	local toRemove = {}
	for instId, buff in pairs(buffs) do
		if buff.effectId == effectId then
			table.insert(toRemove, instId)
		end
	end

	for _, instId in ipairs(toRemove) do
		local buff = buffs[instId]
		if buff then
			self:_expireBuff(target, buff)
			buffs[instId] = nil
			removed = true
		end
	end

	return removed
end

--- 移除目标所有效果
function BuffSystem:RemoveAllEffects(target)
	local buffs = activeBuffs[target]
	if not buffs then return end

	for instId, buff in pairs(buffs) do
		self:_expireBuff(target, buff)
	end
	activeBuffs[target] = nil
end

--- 查询是否有指定效果
function BuffSystem:HasEffect(target, effectId)
	local buffs = activeBuffs[target]
	if not buffs then return false end

	for _, buff in pairs(buffs) do
		if buff.effectId == effectId then
			return true
		end
	end
	return false
end

--- 查询是否被某种 CC 控制
function BuffSystem:HasCCType(target, ccType)
	local buffs = activeBuffs[target]
	if not buffs then return false end

	for _, buff in pairs(buffs) do
		local effectCfg = EffectConfig[buff.effectId]
		if effectCfg and effectCfg.Type == "CC" and effectCfg.CCType == ccType then
			return true
		end
	end
	return false
end

--- 获取叠加层数
function BuffSystem:GetBuffStacks(target, effectId)
	local buffs = activeBuffs[target]
	if not buffs then return 0 end

	for _, buff in pairs(buffs) do
		if buff.effectId == effectId then
			return buff.stacks or 1
		end
	end
	return 0
end

--- 获取所有活跃 Buff 列表
function BuffSystem:GetActiveBuffs(target)
	local buffs = activeBuffs[target]
	if not buffs then return {} end

	local result = {}
	for _, buff in pairs(buffs) do
		table.insert(result, {
			instanceId = buff.instanceId,
			effectId = buff.effectId,
			stacks = buff.stacks,
			remainingTime = buff.duration and (buff.duration - (os.clock() - buff.startTime)) or nil,
		})
	end
	return result
end

-- ========== 生命周期 ==========

function BuffSystem:Init()
	-- 连接 Heartbeat
	RunService.Heartbeat:Connect(function(dt)
		self:_onHeartbeat(dt)
	end)

	-- 角色死亡清理
	local function onCharacterAdded(character)
		local humanoid = character:WaitForChild("Humanoid", 5)
		if humanoid then
			humanoid.Died:Connect(function()
				self:RemoveAllEffects(character)
			end)
		end
	end

	-- 监听所有玩家的角色
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(onCharacterAdded)
		if player.Character then
			onCharacterAdded(player.Character)
		end
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		player.CharacterAdded:Connect(onCharacterAdded)
		if player.Character then
			onCharacterAdded(player.Character)
		end
	end

	-- 玩家离开清理
	Players.PlayerRemoving:Connect(function(player)
		if player.Character then
			self:RemoveAllEffects(player.Character)
		end
	end)

	print("[BuffSystem] 初始化完成")
end

-- 自动初始化
BuffSystem:Init()

return BuffSystem
