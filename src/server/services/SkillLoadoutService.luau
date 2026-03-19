local SkillLoadoutService = {}

local DataManager = nil

local playerHeroes = {}
local skillReplacements = {}

function SkillLoadoutService.init(dataManagerRef)
    DataManager = dataManagerRef
end

function SkillLoadoutService.clearPlayer(player)
    playerHeroes[player] = nil
    skillReplacements[player] = nil
end

function SkillLoadoutService.syncPlayerHero(player, heroId: string): boolean
    if not DataManager then
        return false
    end

    local heroData = DataManager.getHero(heroId)
    if not heroData then
        return false
    end

    playerHeroes[player] = heroId
    skillReplacements[player] = nil
    return true
end

function SkillLoadoutService.getPlayerHero(player): string?
    return playerHeroes[player]
end

function SkillLoadoutService.setSkillReplacement(player, key: string, newSkillId: string)
    if not skillReplacements[player] then
        skillReplacements[player] = {}
    end
    skillReplacements[player][key] = newSkillId
end

function SkillLoadoutService.revertSkillReplacement(player, key: string)
    if skillReplacements[player] then
        skillReplacements[player][key] = nil
    end
end

function SkillLoadoutService.getSkillReplacements(player)
    return skillReplacements[player]
end

return SkillLoadoutService
