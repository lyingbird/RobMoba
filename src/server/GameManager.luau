--[[
    GameManager.luau
    游戏流程管理
    
    职责：
    - 管理游戏状态机 (Waiting → HeroSelect → Countdown → InProgress → Ended)
    - 玩家加入/离开的流程处理
    - 统一调用 TeamManager/HeroManager 的接口
    - 胜利条件判断
    - 泉水回血逻辑
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameManager = {}

-- 依赖模块引用
local remotes = nil
local teamManager = nil
local heroManager = nil
local mapGenerator = nil
local combatManager = nil
local statusEffectManager = nil
local skillSystem = nil
local eventScheduler = nil
local eventHandlers = nil
local GameConfig = nil

-- 游戏状态
local currentState = "Waiting"
local gameStartTime = 0

-- 击杀计数: { Red = 0, Blue = 0 }
local teamKills = { Red = 0, Blue = 0 }

--============================================================
-- 初始化
--============================================================

function GameManager.init(deps)
    remotes           = deps.remotes
    teamManager       = deps.teamManager
    heroManager       = deps.heroManager
    mapGenerator      = deps.mapGenerator
    combatManager     = deps.combatManager
    statusEffectManager = deps.statusEffectManager
    skillSystem       = deps.skillSystem
    eventScheduler    = deps.eventScheduler
    eventHandlers     = deps.eventHandlers
    
    local shared = ReplicatedStorage:WaitForChild("Shared")
    GameConfig = require(shared:WaitForChild("GameConfig"))
    
    -- 监听英雄选择
    if remotes.HeroSelect then
        remotes.HeroSelect.OnServerEvent:Connect(function(player, data)
            if currentState == "HeroSelect" and data and data.heroId then
                heroManager.selectHero(player, data.heroId)
            end
        end)
    end
    
    -- 监听英雄切换（测试模式：随时切换英雄并重生）
    if remotes.HeroSwitch then
        remotes.HeroSwitch.OnServerEvent:Connect(function(player, data)
            if false and data and data.heroId then
                print("[GameManager] " .. player.Name .. " 切换英雄: " .. data.heroId)
                heroManager.selectHero(player, data.heroId)
                -- 重新加载角色以应用新英雄属性
                task.wait(0.1)
                player:LoadCharacter()
            end
        end)
    end
    
    print("[GameManager] 初始化完成")
end

--============================================================
-- 泉水回血（已由 MapGenerator 内置，此处无需重复）
--============================================================

--============================================================
-- 游戏状态机
--============================================================

function GameManager.getState(): string
    return currentState
end

function GameManager._setState(newState: string, data: any?)
    currentState = newState
    print("[GameManager] 状态变更: " .. newState)
    
    -- 广播给所有客户端
    if remotes and remotes.GameStateChanged then
        local broadcastData = data or {}
        broadcastData.state = newState
        remotes.GameStateChanged:FireAllClients(broadcastData)
    end
end

--============================================================
-- 玩家加入处理
--============================================================

function GameManager.onPlayerAdded(player: Player)
    print("[GameManager] 玩家加入: " .. player.Name)
    
    -- 分配队伍
    local teamName = teamManager.assignPlayer(player)
    
    -- 默认选择英雄
    heroManager.selectHero(player, GameConfig.Hero.DefaultHeroId)
    
    -- 监听角色加载
    player.CharacterAdded:Connect(function(character)
        heroManager.onCharacterAdded(player, character)
    end)
    
    -- 首次加载角色
    player:LoadCharacter()

    if currentState == "Waiting" then
        local playerCount = #Players:GetPlayers()
        if playerCount >= GameConfig.Game.MinPlayersToStart then
            task.delay(0.5, function()
                if currentState == "Waiting" then
                    GameManager._startHeroSelect()
                end
            end)
        end
        return
    end

    if remotes and remotes.GameStateChanged then
        if currentState == "HeroSelect" then
            remotes.GameStateChanged:FireClient(player, {
                state = "HeroSelect",
                duration = GameConfig.Game.HeroSelectTime,
            })
            return
        elseif currentState == "Countdown" then
            remotes.GameStateChanged:FireClient(player, {
                state = "Countdown",
                countdown = GameConfig.Game.CountdownTime,
            })
            return
        elseif currentState == "InProgress" then
            remotes.GameStateChanged:FireClient(player, {
                state = "InProgress",
            })
            return
        elseif currentState == "Ended" then
            remotes.GameStateChanged:FireClient(player, {
                state = "Ended",
            })
            return
        end
    end
    
    -- 直接进入游戏状态（跳过等待/英雄选择/倒计时）
    if currentState == "Waiting" then
        currentState = "InProgress"
        gameStartTime = tick()
        print("[GameManager] 直接进入游戏（测试模式）")
        
        -- 通知客户端进入英雄选择（不隐藏，允许随时切换）
        if remotes and remotes.GameStateChanged then
            remotes.GameStateChanged:FireAllClients({
                state = "InProgress",
            })
        end
    end
    
    -- 通知新加入的玩家当前状态
    if currentState == "InProgress" and remotes and remotes.GameStateChanged then
        remotes.GameStateChanged:FireClient(player, {
            state = "InProgress",
        })
    end
end

-- 玩家离开处理
function GameManager.onPlayerRemoving(player: Player)
    print("[GameManager] 玩家离开: " .. player.Name)
    
    teamManager.removePlayer(player)
    heroManager.cleanupPlayer(player)
    
    -- 检查游戏是否需要结束
    if currentState == "InProgress" then
        local playerCount = #Players:GetPlayers() - 1 -- 当前玩家还没移除
        if playerCount <= 0 then
            GameManager._endGame("None", "所有玩家已离开")
        end
    end
end

--============================================================
-- 游戏流程
--============================================================

function GameManager._startHeroSelect()
    GameManager._setState("HeroSelect", {
        duration = GameConfig.Game.HeroSelectTime,
    })
    
    -- 等待选择时间结束后自动开始倒计时
    task.delay(GameConfig.Game.HeroSelectTime, function()
        if currentState == "HeroSelect" then
            GameManager._startCountdown()
        end
    end)
end

function GameManager._startCountdown()
    local countdown = GameConfig.Game.CountdownTime
    
    GameManager._setState("Countdown", {
        countdown = countdown,
    })
    
    -- 倒计时
    task.spawn(function()
        for i = countdown, 1, -1 do
            if currentState ~= "Countdown" then return end
            
            -- 更新倒计时
            if remotes and remotes.GameStateChanged then
                remotes.GameStateChanged:FireAllClients({
                    state = "Countdown",
                    countdown = i,
                })
            end
            
            task.wait(1)
        end
        
        if currentState == "Countdown" then
            GameManager._startGame()
        end
    end)
end

function GameManager._startGame()
    gameStartTime = tick()
    teamKills = { Red = 0, Blue = 0 }
    
    GameManager._setState("InProgress")
    
    -- 最大游戏时间限制
    task.delay(GameConfig.Game.MaxGameTime, function()
        if currentState == "InProgress" then
            -- 时间到，判定击杀数多的队伍获胜
            local winner = teamKills.Red >= teamKills.Blue and "Red" or "Blue"
            GameManager._endGame(winner, "时间到")
        end
    end)
end

function GameManager._endGame(winner: string, reason: string?)
    GameManager._setState("Ended", {
        winner = winner,
        reason = reason or "游戏结束",
        redKills = teamKills.Red,
        blueKills = teamKills.Blue,
    })
    
    print("[GameManager] 游戏结束! 获胜方: " .. winner .. " 原因: " .. (reason or ""))
    
    -- 10秒后重置
    task.delay(10, function()
        GameManager._resetGame()
    end)
end

function GameManager._resetGame()
    teamKills = { Red = 0, Blue = 0 }
    
    GameManager._setState("Waiting")
    
    -- 检查是否可以直接重新开始
    local playerCount = #Players:GetPlayers()
    if playerCount >= GameConfig.Game.MinPlayersToStart then
        task.delay(3, function()
            if currentState == "Waiting" then
                GameManager._startHeroSelect()
            end
        end)
    end
end

--============================================================
-- 击杀记录
--============================================================

function GameManager.recordKill(killerPlayer: Player?, victimPlayer: Player?)
    if not killerPlayer then return end
    
    local killerTeam = teamManager.getPlayerTeam(killerPlayer)
    if killerTeam and teamKills[killerTeam] then
        teamKills[killerTeam] = teamKills[killerTeam] + 1
    end
    
    -- 注意：KillFeed 广播由 HeroManager._onHeroDied 负责，此处不重复发送
    
    -- 检查胜利条件
    if GameConfig.Game.VictoryCondition == "TotalKills" then
        if killerTeam and teamKills[killerTeam] >= GameConfig.Game.TotalKillsToWin then
            GameManager._endGame(killerTeam, killerTeam .. " 队达到击杀目标")
        end
    end
end

function GameManager.getTeamKills(): { Red: number, Blue: number }
    return teamKills
end

--============================================================
-- 查询接口
--============================================================

function GameManager.getGameTime(): number
    if currentState == "InProgress" then
        return tick() - gameStartTime
    end
    return 0
end

return GameManager
