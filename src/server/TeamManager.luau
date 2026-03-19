--[[
    TeamManager.luau
    队伍管理模块
    
    职责：
    - 自动均衡分配新玩家到红队/蓝队
    - 维护队伍成员列表
    - 提供队伍查询接口（队友/敌方）
    - 管理 Roblox Team 对象用于颜色标识
]]

local Players = game:GetService("Players")
local Teams = game:GetService("Teams")

local TeamManager = {}

local remotes = nil

-- 队伍数据: { Red = { Player, ... }, Blue = { Player, ... } }
local teams = {
    Red  = {},
    Blue = {},
}

-- 玩家 -> 队伍映射
local playerTeam = {} -- { [Player] = "Red" | "Blue" }

-- Roblox Team 对象
local robloxTeams = {}

--============================================================
-- 初始化
--============================================================

function TeamManager.init(remotesRef)
    remotes = remotesRef
    
    -- 创建 Roblox Team 对象（用于队伍颜色和 SpawnLocation 关联）
    local teamsService = Teams
    
    local redTeam = Instance.new("Team")
    redTeam.Name = "Red"
    redTeam.TeamColor = BrickColor.new("Bright red")
    redTeam.AutoAssignable = false
    redTeam.Parent = teamsService
    robloxTeams.Red = redTeam
    
    local blueTeam = Instance.new("Team")
    blueTeam.Name = "Blue"
    blueTeam.TeamColor = BrickColor.new("Bright blue")
    blueTeam.AutoAssignable = false
    blueTeam.Parent = teamsService
    robloxTeams.Blue = blueTeam
    
    print("[TeamManager] 初始化完成")
end

--============================================================
-- 队伍分配
--============================================================

-- 自动分配玩家到人数较少的队伍
function TeamManager.assignPlayer(player: Player): string
    local redCount = #teams.Red
    local blueCount = #teams.Blue
    
    local teamName
    if redCount <= blueCount then
        teamName = "Red"
    else
        teamName = "Blue"
    end
    
    table.insert(teams[teamName], player)
    playerTeam[player] = teamName
    
    -- 设置 Roblox Team
    player.Team = robloxTeams[teamName]
    
    -- 通知客户端
    if remotes and remotes.TeamAssigned then
        local teamColor
        if teamName == "Red" then
            teamColor = Color3.fromRGB(255, 80, 80)
        else
            teamColor = Color3.fromRGB(80, 130, 255)
        end
        remotes.TeamAssigned:FireClient(player, {
            teamId = teamName,
            teamColor = teamColor,
        })
    end
    
    print("[TeamManager] " .. player.Name .. " 分配到 " .. teamName .. " 队")
    return teamName
end

-- 移除玩家
function TeamManager.removePlayer(player: Player)
    local teamName = playerTeam[player]
    if not teamName then return end
    
    local teamList = teams[teamName]
    for i, p in ipairs(teamList) do
        if p == player then
            table.remove(teamList, i)
            break
        end
    end
    
    playerTeam[player] = nil
end

--============================================================
-- 查询接口
--============================================================

-- 获取玩家所在队伍
function TeamManager.getPlayerTeam(player: Player): string?
    return playerTeam[player]
end

-- 获取队伍所有成员
function TeamManager.getTeamPlayers(teamName: string): { Player }
    return teams[teamName] or {}
end

-- 获取玩家的队友（不含自己）
function TeamManager.getTeammates(player: Player): { Player }
    local teamName = playerTeam[player]
    if not teamName then return {} end
    
    local result = {}
    for _, p in ipairs(teams[teamName]) do
        if p ~= player then
            table.insert(result, p)
        end
    end
    return result
end

-- 获取玩家的敌方队伍成员
function TeamManager.getEnemies(player: Player): { Player }
    local teamName = playerTeam[player]
    if not teamName then return {} end
    
    local enemyTeam = teamName == "Red" and "Blue" or "Red"
    return teams[enemyTeam] or {}
end

-- 判断两个玩家是否同队
function TeamManager.isSameTeam(player1: Player, player2: Player): boolean
    return playerTeam[player1] ~= nil and playerTeam[player1] == playerTeam[player2]
end

-- 判断两个角色模型是否同队
function TeamManager.isSameTeamByCharacter(char1: Model, char2: Model): boolean
    local p1 = Players:GetPlayerFromCharacter(char1)
    local p2 = Players:GetPlayerFromCharacter(char2)
    if not p1 or not p2 then return false end
    return TeamManager.isSameTeam(p1, p2)
end

-- 判断角色是否是敌方
function TeamManager.isEnemy(attackerChar: Model, targetChar: Model): boolean
    -- 假人永远是敌方
    local dummyTag = targetChar:FindFirstChild("IsDummy")
    if dummyTag and dummyTag:IsA("BoolValue") and dummyTag.Value then
        return true
    end
    
    local p1 = Players:GetPlayerFromCharacter(attackerChar)
    local p2 = Players:GetPlayerFromCharacter(targetChar)
    if not p1 or not p2 then return true end -- 无法识别的目标视为敌方
    return not TeamManager.isSameTeam(p1, p2)
end

-- 获取队伍人数
function TeamManager.getTeamCount(teamName: string): number
    return #(teams[teamName] or {})
end

-- 获取队伍颜色
function TeamManager.getTeamColor(teamName: string): Color3
    if teamName == "Red" then
        return Color3.fromRGB(255, 80, 80)
    else
        return Color3.fromRGB(80, 130, 255)
    end
end

return TeamManager
