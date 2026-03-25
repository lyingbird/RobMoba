-- SkillValidator: 服务端技能校验模块
-- 路径: ServerScriptService/ServerModules/SkillValidator.lua
-- 职责: 校验客户端发来的技能请求（防作弊）
--
-- 校验项:
--   1. 技能配置是否存在
--   2. CD 是否就绪（委托现有系统）
--   3. 蓝量是否足够（委托 EnergySystem）
--   4. 是否被控制状态（委托 BuffSystem）
--   5. 目标距离是否在施法范围内（含10%容差）
--   6. 参数类型合法性

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SkillRegistry = require(ReplicatedStorage:WaitForChild("SkillRegistry"))

local SV = {}
SV.__index = SV

function SV.new()
	return setmetatable({}, SV)
end

--------------------------------------------------------------------------------
-- Validate: 校验技能释放请求
-- player: Player
-- param: { slotType, skillId, rangeType, targetPosition?, targetDirection?, targetActorId?, trackPoints? }
-- 返回: (boolean, string?) — (通过, 失败原因)
--------------------------------------------------------------------------------
function SV:Validate(player, param)
	-- ① 参数类型基础校验
	if typeof(param) ~= "table" then
		return false, "INVALID_PARAM"
	end

	if param.skillId == nil then
		return false, "MISSING_SKILL_ID"
	end

	-- 普攻不做详细校验（slotType=0, skillId=0）
	if param.slotType == 0 then
		return true, nil
	end

	-- ② 配置校验
	local cfg = SkillRegistry[param.skillId]
	if not cfg then
		return false, "INVALID_SKILL"
	end

	-- ③ 目标位置距离校验（有位置参数时）
	if param.targetPosition and typeof(param.targetPosition) == "Vector3" then
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hrp then
			local castRange = cfg.Range or 50
			local dist = (param.targetPosition - hrp.Position).Magnitude
			-- 10% 容差（网络延迟）+ 最小20studs
			local maxAllowed = math.max(castRange * 1.1, 20)
			if dist > maxAllowed then
				return false, "OUT_OF_RANGE"
			end
		end
	end

	-- ④ 方向参数校验（有方向时必须是 Vector3）
	if param.targetDirection ~= nil and typeof(param.targetDirection) ~= "Vector3" then
		return false, "INVALID_DIRECTION"
	end

	-- ⑤ 轨迹点校验（Track 型）
	if param.trackPoints ~= nil then
		if typeof(param.trackPoints) ~= "table" then
			return false, "INVALID_TRACK_POINTS"
		end
		if #param.trackPoints > 50 then
			return false, "TOO_MANY_TRACK_POINTS"
		end
	end

	-- 通过
	return true, nil
end

--------------------------------------------------------------------------------
-- ValidateRate: 速率限制（防刷技能）
-- 返回 true = 允许, false = 被限速
--------------------------------------------------------------------------------
local playerLastCastTime = {}
local MIN_CAST_INTERVAL = 0.1  -- 最小施法间隔 100ms

function SV:ValidateRate(player)
	local userId = player.UserId
	local now = os.clock()
	local last = playerLastCastTime[userId] or 0

	if now - last < MIN_CAST_INTERVAL then
		return false
	end

	playerLastCastTime[userId] = now
	return true
end

-- 清理
function SV:OnPlayerRemoving(player)
	playerLastCastTime[player.UserId] = nil
end

return SV
