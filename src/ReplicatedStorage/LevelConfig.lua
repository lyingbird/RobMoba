local LevelConfig = {}

LevelConfig.XPToLevel = {
	[1] = 0, [2] = 280, [3] = 660, [4] = 1140, [5] = 1720,
	[6] = 2400, [7] = 3180, [8] = 4060, [9] = 5040, [10] = 6120,
	[11] = 7300, [12] = 8580, [13] = 9960, [14] = 11440, [15] = 13020,
	[16] = 14700, [17] = 16480, [18] = 18360,
}

LevelConfig.MaxLevel = 18

LevelConfig.StatGrowth = {
	MaxHP = 92, MaxMP = 40, ATK = 3.5, AP = 0,
	DEF = 4.2, MR = 1.3, HpRegen = 0.5, MpRegen = 0.2,
}

LevelConfig.BaseEnemyXP = 60

function LevelConfig.GetStatsForLevel(level)
	local growth = {}
	for stat, perLevel in pairs(LevelConfig.StatGrowth) do
		growth[stat] = perLevel * (level - 1)
	end
	return growth
end

function LevelConfig.GetXPForNextLevel(level)
	if level >= LevelConfig.MaxLevel then return 0 end
	return LevelConfig.XPToLevel[level + 1] - LevelConfig.XPToLevel[level]
end

function LevelConfig.GetLevelProgress(level, totalXP)
	if level >= LevelConfig.MaxLevel then return 1 end
	local currentLevelXP = LevelConfig.XPToLevel[level]
	local nextLevelXP = LevelConfig.XPToLevel[level + 1]
	local needed = nextLevelXP - currentLevelXP
	if needed <= 0 then return 1 end
	return math.clamp((totalXP - currentLevelXP) / needed, 0, 1)
end

function LevelConfig.GetLevelFromXP(totalXP)
	for lvl = LevelConfig.MaxLevel, 1, -1 do
		if totalXP >= LevelConfig.XPToLevel[lvl] then
			return lvl
		end
	end
	return 1
end

return LevelConfig
