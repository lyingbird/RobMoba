--[[
    HeroManager.luau
    英雄生命周期管理
    
    职责：
    - 英雄角色生成（设置属性/外观/碰撞组）
    - 死亡处理（启动复活计时器）
    - 复活逻辑（回满血蓝、传送到泉水）
    - 属性同步到客户端
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HeroManager = {}

local remotes = nil
local teamManager = nil
local mapGenerator = nil
local statusEffectManager = nil
local DataManager = nil
local skillSystem = nil
local gameManager = nil  -- 延迟注入（由 init.server.luau 在 GameManager 初始化后设置）

-- 玩家英雄选择: { [Player] = heroId }
local playerHeroes = {}

-- 死亡计数: { [Player] = number }
local deathCounts = {}
local regenThreads = {}

-- 基础复活时间
local BASE_RESPAWN_TIME = 5
local EXTRA_RESPAWN_PER_DEATH = 1
local MAX_RESPAWN_TIME = 15

--============================================================
-- 初始化
--============================================================

function HeroManager.init(remotesRef, teamManagerRef, mapGeneratorRef, statusEffectManagerRef, skillSystemRef)
    remotes = remotesRef
    teamManager = teamManagerRef
    mapGenerator = mapGeneratorRef
    statusEffectManager = statusEffectManagerRef
    skillSystem = skillSystemRef
    
    local shared = ReplicatedStorage:WaitForChild("Shared")
    DataManager = require(shared:WaitForChild("DataManager"))
    
    print("[HeroManager] 初始化完成")
end

-- 延迟注入 GameManager（由 init.server.luau 在 GameManager 初始化后调用）
function HeroManager.setGameManager(gmRef)
    gameManager = gmRef
end

--============================================================
-- 英雄选择
--============================================================

function HeroManager.selectHero(player: Player, heroId: string)
    local heroData = DataManager.getHero(heroId)
    if not heroData then
        warn("[HeroManager] 无效的英雄ID: " .. tostring(heroId))
        return false
    end
    
    playerHeroes[player] = heroId
    deathCounts[player] = deathCounts[player] or 0
    
    -- 同步到 SkillSystem
    if skillSystem then
        skillSystem.syncPlayerHero(player, heroId)
    end
    
    -- 如果角色已存在，立即应用属性
    local character = player.Character
    if character then
        HeroManager._setupHeroStats(character, heroData)
    end
    
    -- 通知客户端更新技能栏
    if remotes and remotes.SkillBarUpdate then
        local skills = {}
        for key, skillId in pairs(heroData.skills) do
            local skillData = DataManager.getSkill(skillId)
            if skillData then
                skills[key] = {
                    id = skillId,
                    name = skillData.name,
                    icon = skillData.icon,
                    cooldown = skillData.cooldown,
                    manaCost = skillData.manaCost,
                    castType = skillData.castType,
                    indicatorId = skillData.indicatorId,
                    description = skillData.description,
                }
            end
        end
        remotes.SkillBarUpdate:FireClient(player, {
            action = "init",
            heroId = heroId,
            skills = skills,
        })
    end
    
    print("[HeroManager] " .. player.Name .. " 选择了 " .. heroData.name)
    return true
end

--============================================================
-- 英雄属性设置
--============================================================

function HeroManager._setupHeroStats(character, heroData)
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    
    -- 设置基础属性
    humanoid.MaxHealth = heroData.maxHP
    humanoid.Health = heroData.maxHP
    humanoid.WalkSpeed = heroData.walkSpeed
    
    -- 存储额外属性
    local function setAttr(name, value)
        local v = character:FindFirstChild(name)
        if not v then
            v = Instance.new("NumberValue")
            v.Name = name
            v.Parent = character
        end
        v.Value = value
    end
    
    setAttr("MaxMP", heroData.maxMP)
    setAttr("MP", heroData.maxMP)
    setAttr("MPRegen", heroData.mpRegen)
    setAttr("HPRegen", heroData.hpRegen)
    setAttr("AttackDamage", heroData.attackDamage)
    setAttr("MagicPower", heroData.magicPower)
    setAttr("Armor", heroData.armor)
    setAttr("MagicResist", heroData.magicResist)
    setAttr("AttackSpeed", heroData.attackSpeed)
    setAttr("AttackRange", heroData.attackRange)
    
    -- 存储英雄ID到角色
    local heroIdTag = character:FindFirstChild("HeroId")
    if not heroIdTag then
        heroIdTag = Instance.new("StringValue")
        heroIdTag.Name = "HeroId"
        heroIdTag.Parent = character
    end
    heroIdTag.Value = heroData.id
    
    -- 设置外观颜色
    if heroData.bodyColors then
        local bodyColors = character:FindFirstChildOfClass("BodyColors")
        if not bodyColors then
            bodyColors = Instance.new("BodyColors")
            bodyColors.Parent = character
        end
        for prop, color in pairs(heroData.bodyColors) do
            pcall(function()
                bodyColors[prop] = color
            end)
        end
    end
    
    -- 自然回复（血量 + 蓝量）— 先取消旧循环避免叠加
    if regenThreads[character] then
        pcall(task.cancel, regenThreads[character])
        regenThreads[character] = nil
    end
    regenThreads[character] = task.spawn(function()
        while character and character.Parent and humanoid and humanoid.Health > 0 do
            task.wait(1)
            if not character or not character.Parent then break end
            if not humanoid or humanoid.Health <= 0 then break end
            
            -- 蓝量回复
            local mp = character:FindFirstChild("MP")
            local maxMP = character:FindFirstChild("MaxMP")
            local mpRegen = character:FindFirstChild("MPRegen")
            if mp and maxMP and mpRegen then
                mp.Value = math.min(maxMP.Value, mp.Value + mpRegen.Value)
            end
            
            -- 血量回复
            local hpRegen = character:FindFirstChild("HPRegen")
            if hpRegen then
                humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + hpRegen.Value)
            end
        end
        -- 循环结束后清理引用
        if regenThreads[character] then
            regenThreads[character] = nil
        end
    end)
end

--============================================================
-- 角色生成
--============================================================

function HeroManager.onCharacterAdded(player: Player, character: Model)
    local humanoid = character:WaitForChild("Humanoid", 10)
    if not humanoid then return end
    local rootPart = character:WaitForChild("HumanoidRootPart", 10)
    if not rootPart then return end
    
    -- 应用英雄属性
    local heroId = playerHeroes[player]
    if heroId then
        local heroData = DataManager.getHero(heroId)
        if heroData then
            HeroManager._setupHeroStats(character, heroData)
        end
    end
    
    -- 传送到队伍出生点
    local teamName = teamManager.getPlayerTeam(player)
    if teamName and mapGenerator then
        local spawnPos = mapGenerator.getSpawnPosition(teamName)
        rootPart.CFrame = CFrame.new(spawnPos + Vector3.new(0, 3, 0))
    end
    
    -- 死亡处理
    humanoid.Died:Connect(function()
        HeroManager._onHeroDied(player, character)
    end)
    
    -- 角色移除时清理
    character.AncestryChanged:Connect(function(_, parent)
        if not parent and statusEffectManager then
            statusEffectManager.cleanup(character)
        end
    end)
    
    print("[HeroManager] " .. player.Name .. " 角色加载完成")
end

--============================================================
-- 死亡处理
--============================================================

function HeroManager._onHeroDied(player: Player, character: Model)
    if regenThreads[character] then
        pcall(task.cancel, regenThreads[character])
        regenThreads[character] = nil
    end

    -- 清理状态效果
    if statusEffectManager then
        statusEffectManager.cleanup(character)
    end
    
    -- 清理战意数据
    if skillSystem and skillSystem.resetZhanYi then
        skillSystem.resetZhanYi(character)
    end
    
    -- 增加死亡计数
    deathCounts[player] = (deathCounts[player] or 0) + 1
    
    -- 计算复活时间
    local respawnTime = math.min(
        MAX_RESPAWN_TIME,
        BASE_RESPAWN_TIME + (deathCounts[player] - 1) * EXTRA_RESPAWN_PER_DEATH
    )
    
    -- 通知所有客户端
    if remotes and remotes.TargetDied then
        remotes.TargetDied:FireAllClients({
            targetModel = character,
            playerName = player.Name,
            respawnTime = respawnTime,
        })
    end
    
    -- 读取击杀者（CombatManager 在 dealDamage 时记录 LastAttacker）
    local killerPlayer = nil
    local killerName = "?"
    local lastAttacker = character:FindFirstChild("LastAttacker")
    if lastAttacker and lastAttacker:IsA("ObjectValue") and lastAttacker.Value then
        killerPlayer = Players:GetPlayerFromCharacter(lastAttacker.Value)
        if killerPlayer then
            killerName = killerPlayer.Name
        end
    end
    
    -- 击杀记录（更新队伍击杀计数 + 胜利条件检查）
    if gameManager and killerPlayer then
        gameManager.recordKill(killerPlayer, player)
    end
    
    -- 击杀信息广播
    if remotes and remotes.KillFeed then
        remotes.KillFeed:FireAllClients({
            killerName = killerName,
            victimName = player.Name,
            skillName = "",
        })
    end
    
    -- 延迟复活
    task.delay(respawnTime, function()
        if player and player.Parent then
            player:LoadCharacter()
            
            -- 通知客户端
            if remotes and remotes.HeroRespawned then
                remotes.HeroRespawned:FireAllClients({
                    playerName = player.Name,
                })
            end
        end
    end)
end

--============================================================
-- 查询接口
--============================================================

function HeroManager.getPlayerHero(player: Player): string?
    return playerHeroes[player]
end

function HeroManager.getHeroData(player: Player)
    local heroId = playerHeroes[player]
    if heroId then
        return DataManager.getHero(heroId)
    end
    return nil
end

function HeroManager.getDeathCount(player: Player): number
    return deathCounts[player] or 0
end

-- 清理玩家数据
function HeroManager.cleanupPlayer(player: Player)
    local character = player.Character
    if character and regenThreads[character] then
        pcall(task.cancel, regenThreads[character])
        regenThreads[character] = nil
    end

    playerHeroes[player] = nil
    deathCounts[player] = nil
end

return HeroManager
