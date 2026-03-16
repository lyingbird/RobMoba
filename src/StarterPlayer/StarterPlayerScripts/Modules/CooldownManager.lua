local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CooldownManager = {}
local cooldowns = {} -- { [skillID] = { EndTime, TotalDuration } }
local recastSkills = {} -- { [skillID] = true } tracks skills waiting for recast

function CooldownManager.Start(skillID, duration)
	cooldowns[skillID] = {
		EndTime = os.clock() + duration,
		TotalDuration = duration,
	}
end

function CooldownManager.IsOnCooldown(skillID)
	local cd = cooldowns[skillID]
	return cd ~= nil and os.clock() < cd.EndTime
end

function CooldownManager.GetRemaining(skillID)
	local cd = cooldowns[skillID]
	if not cd then return 0, 0 end
	local remaining = math.max(0, cd.EndTime - os.clock())
	return remaining, cd.TotalDuration
end

function CooldownManager.GetInfo(skillID)
	return cooldowns[skillID]
end

function CooldownManager.SetRecast(skillID, state)
	recastSkills[skillID] = state or nil
end

function CooldownManager.IsInRecast(skillID)
	return recastSkills[skillID] == true
end

-- REQ-013: 重置所有技能冷却（训练场CD开关等场景使用）
function CooldownManager.ResetAll()
	for skillID, cd in pairs(cooldowns) do
		cd.EndTime = 0
	end
end

local SyncCooldownEvent = ReplicatedStorage:WaitForChild("SyncCooldownEvent", 10)
if SyncCooldownEvent then
	SyncCooldownEvent.OnClientEvent:Connect(function(_key, duration, skillID)
		-- REQ-013: 服务端发送 "ALL" 标记时，重置所有技能CD
		if _key == "ALL" then
			CooldownManager.ResetAll()
			return
		end
		if skillID then
			CooldownManager.Start(skillID, duration)
			-- When real cooldown starts, clear recast state
			CooldownManager.SetRecast(skillID, false)
		end
	end)
end

local SyncRecastEvent = ReplicatedStorage:WaitForChild("SyncRecastEvent", 10)
if SyncRecastEvent then
	SyncRecastEvent.OnClientEvent:Connect(function(skillID, isRecast)
		CooldownManager.SetRecast(skillID, isRecast)
	end)
end

return CooldownManager