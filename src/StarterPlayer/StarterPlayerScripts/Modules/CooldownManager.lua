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

local SyncCooldownEvent = ReplicatedStorage:WaitForChild("SyncCooldownEvent", 10)
if SyncCooldownEvent then
	SyncCooldownEvent.OnClientEvent:Connect(function(_key, duration, skillID)
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