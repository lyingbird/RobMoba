-- ==========================================
-- MovementState: 服务端移动速度状态聚合
-- 统一处理基础移速、技能锁移动、减速/加速，避免多个效果互相覆盖 WalkSpeed
-- ==========================================

local MovementState = {}

local DEFAULT_WALK_SPEED = 16
local states = setmetatable({}, { __mode = "k" })
local nextTokenSerial = 0

local function isFiniteNumber(value)
	return typeof(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function disposeState(humanoid, state)
	if not humanoid then return end

	states[humanoid] = nil
	if state and state.diedConn then
		state.diedConn:Disconnect()
	end
	if state and state.ancestryConn then
		state.ancestryConn:Disconnect()
	end
	humanoid:SetAttribute("MovementLockCount", 0)
	humanoid:SetAttribute("MovementBaseSpeed", nil)
end

local function getState(humanoid)
	local state = states[humanoid]
	if not state then
		state = {
			baseSpeed = DEFAULT_WALK_SPEED,
			locks = {},
			modifiers = {},
		}
		states[humanoid] = state

		state.diedConn = humanoid.Died:Connect(function()
			disposeState(humanoid, state)
		end)
		state.ancestryConn = humanoid.AncestryChanged:Connect(function(_, parent)
			if not parent then
				disposeState(humanoid, state)
			end
		end)
	end
	return state
end

local function resolveBaseSpeed(humanoid, state)
	local character = humanoid.Parent
	local characterSpeed = character and character:GetAttribute("MoveSpeed")
	if isFiniteNumber(characterSpeed) then
		return math.max(0, characterSpeed)
	end

	local attrSpeed = humanoid:GetAttribute("MovementBaseSpeed")
	if isFiniteNumber(attrSpeed) then
		return math.max(0, attrSpeed)
	end

	if state and isFiniteNumber(state.baseSpeed) then
		return math.max(0, state.baseSpeed)
	end

	if isFiniteNumber(humanoid.WalkSpeed) and humanoid.WalkSpeed > 0 then
		return humanoid.WalkSpeed
	end

	return DEFAULT_WALK_SPEED
end

local function countKeys(map)
	local count = 0
	for _ in pairs(map) do
		count = count + 1
	end
	return count
end

function MovementState.Refresh(humanoid)
	if not humanoid or not humanoid.Parent then return end

	local state = getState(humanoid)
	local baseSpeed = resolveBaseSpeed(humanoid, state)
	state.baseSpeed = baseSpeed
	humanoid:SetAttribute("MovementBaseSpeed", baseSpeed)

	local lockCount = countKeys(state.locks)
	humanoid:SetAttribute("MovementLockCount", lockCount)
	if lockCount > 0 then
		humanoid.WalkSpeed = 0
		return
	end

	local flatBonus = 0
	local multiplier = 1
	for _, modifier in pairs(state.modifiers) do
		flatBonus = flatBonus + (modifier.flat or 0)
		multiplier = multiplier * math.max(0, 1 + (modifier.percent or 0))
	end

	humanoid.WalkSpeed = math.max(0, (baseSpeed + flatBonus) * multiplier)
end

function MovementState.SetBaseSpeed(humanoid, baseSpeed)
	if not humanoid or not humanoid.Parent or not isFiniteNumber(baseSpeed) then return end

	local state = getState(humanoid)
	state.baseSpeed = math.max(0, baseSpeed)
	if humanoid.Parent then
		humanoid.Parent:SetAttribute("MoveSpeed", state.baseSpeed)
	end
	humanoid:SetAttribute("MovementBaseSpeed", state.baseSpeed)
	MovementState.Refresh(humanoid)
end

function MovementState.NewLockToken(prefix, player, skillId)
	nextTokenSerial = nextTokenSerial + 1
	return string.format(
		"%s_%s_%s_%d",
		tostring(prefix or "lock"),
		tostring(player and player.UserId or "server"),
		tostring(skillId or "effect"),
		nextTokenSerial
	)
end

function MovementState.PushLock(humanoid, token)
	if not humanoid or not humanoid.Parent or token == nil then return end

	local state = getState(humanoid)
	if state.locks[token] then return token end

	state.locks[token] = true
	MovementState.Refresh(humanoid)
	return token
end

function MovementState.PopLock(humanoid, token)
	if not humanoid or not humanoid.Parent or token == nil then return end

	local state = states[humanoid]
	if not state or not state.locks[token] then return end

	state.locks[token] = nil
	MovementState.Refresh(humanoid)
end

function MovementState.SetModifier(humanoid, token, flat, percent)
	if not humanoid or not humanoid.Parent or token == nil then return end

	local state = getState(humanoid)
	state.modifiers[token] = {
		flat = isFiniteNumber(flat) and flat or 0,
		percent = isFiniteNumber(percent) and percent or 0,
	}
	MovementState.Refresh(humanoid)
end

function MovementState.ClearModifier(humanoid, token)
	if not humanoid or not humanoid.Parent or token == nil then return end

	local state = states[humanoid]
	if not state or not state.modifiers[token] then return end

	state.modifiers[token] = nil
	MovementState.Refresh(humanoid)
end

function MovementState.Clear(humanoid)
	local state = states[humanoid]
	disposeState(humanoid, state)
	if humanoid and humanoid.Parent then
		humanoid:SetAttribute("MovementLockCount", 0)
		local baseSpeed = resolveBaseSpeed(humanoid, state)
		humanoid:SetAttribute("MovementBaseSpeed", baseSpeed)
		humanoid.WalkSpeed = baseSpeed
	end
end

return MovementState
