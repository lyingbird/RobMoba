--[[
    Remotes.luau
    RemoteEvent 统一注册/获取模块
    服务端调用 createRemotes() 创建所有事件
    客户端调用 getRemotes() 获取所有事件引用
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local REMOTE_NAMES = {
    -- 客户端 → 服务端
    "SkillCast",          -- 技能释放请求 { skillId, direction, targetPosition? }
    "BasicAttack",        -- 普攻请求 { direction, targetPosition }
    "HeroSelect",         -- 英雄选择 { heroId }
    "HeroSwitch",         -- 随时切换英雄 { heroId }（测试模式，立刻重生新英雄）
    "ChannelCancel",      -- 持续施法手动取消 { skillId }
    "ChannelDirection",   -- 持续施法方向更新 { direction }

    -- 服务端 → 客户端
    "DamageDealt",        -- 伤害数字 { targetModel, amount, damageType, position }
    "PlayVFX",            -- 播放特效 { templateId, position, direction?, params }
    "PlayAnim",           -- 播放动画 { targetModel, animId, speed?, duration?, loopCount? }
    "StopAnim",           -- 停止动画 { targetModel, animId }
    "CooldownUpdate",     -- 技能冷却 { skillId, cooldownTime }
    "TargetDied",         -- 目标死亡 { targetModel, respawnTime }
    "StatusEffectUpdate", -- 状态效果更新 { targetModel, effectType, action, duration?, value? }
    "ChannelInterrupt",   -- 持续施法被打断 { playerId }
    "CameraShake",        -- 镜头震动 { intensity, duration }
    "ChannelBarUpdate",   -- 持续施法进度条 { playerId, progress, maxDuration }
    "SkillBarUpdate",     -- 技能栏更新(英雄切换后) { skills }
    "MarkUpdate",         -- 印记层数更新 { targetModel, markId, stacks, maxStacks }
    "GameStateChanged",   -- 游戏状态变更 { state, data }
    "HeroRespawned",      -- 英雄复活 { playerName }
    "TeamAssigned",       -- 队伍分配 { teamId, teamColor }
    "KillFeed",           -- 击杀信息 { killerName, victimName, skillName }
    "ZhanYiUpdate",       -- 廉颇战意值更新 { playerModel, value, maxValue, hasFullBonus }
}

local Remotes = {}

-- 服务端调用：创建所有 RemoteEvent 到 ReplicatedStorage
function Remotes.createRemotes()
    local folder = ReplicatedStorage:FindFirstChild("Remotes")
    if folder and not folder:IsA("Folder") then
        error("[Remotes] ReplicatedStorage.Remotes exists but is not a Folder")
    end

    if not folder then
        folder = Instance.new("Folder")
        folder.Name = "Remotes"
        folder.Parent = ReplicatedStorage
    end

    local remotes = {}
    for _, name in ipairs(REMOTE_NAMES) do
        local remote = folder:FindFirstChild(name)
        if remote and not remote:IsA("RemoteEvent") then
            error("[Remotes] Remotes." .. name .. " exists but is not a RemoteEvent")
        end

        if not remote then
            remote = Instance.new("RemoteEvent")
            remote.Name = name
            remote.Parent = folder
        end

        remotes[name] = remote
    end

    return remotes
end

-- 客户端调用：获取所有 RemoteEvent 引用
function Remotes.getRemotes()
    local folder = ReplicatedStorage:WaitForChild("Remotes", 10)
    if not folder then
        warn("[Remotes] 无法找到 Remotes 文件夹")
        error("[Remotes] Missing ReplicatedStorage.Remotes folder")
    end

    local remotes = {}
    local missing = {}
    for _, name in ipairs(REMOTE_NAMES) do
        remotes[name] = folder:WaitForChild(name, 5)
        if not remotes[name] then
            table.insert(missing, name)
            warn("[Remotes] 无法找到 Remote: " .. name)
        end
    end

    if #missing > 0 then
        error("[Remotes] Missing required remotes: " .. table.concat(missing, ", "))
    end

    return remotes
end

-- 获取所有远程事件名称列表
function Remotes.getRemoteNames()
    return REMOTE_NAMES
end

return Remotes
