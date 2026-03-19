--[[
    init.server.luau
    服务端入口脚本
    
    初始化流程：
    1. 创建 Remotes
    2. 初始化 MapGenerator 生成 MOBA 对称地图
    3. 初始化 TeamManager（队伍管理）
    4. 初始化 StatusEffectManager
    5. 初始化 CombatManager
    6. 初始化 EventHandlers
    7. 初始化 EventScheduler
    8. 初始化 SkillSystem
    9. 初始化 HeroManager（英雄生命周期）
    10. 初始化 GameManager（游戏流程）
    11. 监听 PlayerAdded / PlayerRemoving
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- 等待 Shared 模块加载
local shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(shared:WaitForChild("Remotes"))

-- 引用服务端模块（init.server.luau 编译为 Server 自身，子模块在 script 下）
local MapGenerator = require(script:WaitForChild("MapGenerator"))
local TeamManager = require(script:WaitForChild("TeamManager"))
local HeroManager = require(script:WaitForChild("HeroManager"))
local CombatManager = require(script:WaitForChild("CombatManager"))
local StatusEffectManager = require(script:WaitForChild("StatusEffectManager"))
local EventHandlers = require(script:WaitForChild("EventHandlers"))
local EventScheduler = require(script:WaitForChild("EventScheduler"))
local SkillSystem = require(script:WaitForChild("SkillSystem"))
local GameManager = require(script:WaitForChild("GameManager"))

print("========================================")
print("[Server] MOBA 游戏系统初始化开始...")
print("========================================")

-- 1. 创建 Remotes
local remotes = Remotes.createRemotes()
print("[Server] Remotes 创建完成")

-- 2. 生成 MOBA 对称地图
MapGenerator.init(remotes)
MapGenerator.generate()

-- 3. 初始化 TeamManager
TeamManager.init(remotes)

-- 4. 初始化 StatusEffectManager
StatusEffectManager.init(remotes)
print("[Server] StatusEffectManager 初始化完成")

-- 5. 初始化 CombatManager
CombatManager.init(remotes, StatusEffectManager)
print("[Server] CombatManager 初始化完成")

-- 6. 初始化 EventHandlers
EventHandlers.init(remotes, CombatManager, StatusEffectManager)
print("[Server] EventHandlers 初始化完成")

-- 7. 初始化 EventScheduler
EventScheduler.init(EventHandlers)
print("[Server] EventScheduler 初始化完成")

-- 8. 初始化 SkillSystem
SkillSystem.init(remotes, EventScheduler, StatusEffectManager)
print("[Server] SkillSystem 初始化完成")

-- 8.5. 延迟注入：解决循环依赖
CombatManager.setSkillSystem(SkillSystem)
EventHandlers.setSkillSystem(SkillSystem)
StatusEffectManager.setEventScheduler(EventScheduler)

-- 9. 初始化 HeroManager
HeroManager.init(remotes, TeamManager, MapGenerator, StatusEffectManager, SkillSystem)
print("[Server] HeroManager 初始化完成")

-- 10. 初始化 GameManager
GameManager.init({
    remotes = remotes,
    teamManager = TeamManager,
    heroManager = HeroManager,
    mapGenerator = MapGenerator,
    combatManager = CombatManager,
    statusEffectManager = StatusEffectManager,
    skillSystem = SkillSystem,
    eventScheduler = EventScheduler,
    eventHandlers = EventHandlers,
})

-- 10.5. 注入 GameManager 到 HeroManager（击杀记录需要调用 GameManager.recordKill）
HeroManager.setGameManager(GameManager)

-- 11. 监听玩家连接
Players.PlayerAdded:Connect(function(player)
    GameManager.onPlayerAdded(player)
end)

Players.PlayerRemoving:Connect(function(player)
    GameManager.onPlayerRemoving(player)
end)

-- 处理已有玩家（开发模式下可能在脚本执行前就有玩家）
for _, player in ipairs(Players:GetPlayers()) do
    task.spawn(function()
        GameManager.onPlayerAdded(player)
    end)
end

print("========================================")
print("[Server] MOBA 游戏系统初始化完成!")
print("[Server] 等待玩家加入...")
print("========================================")
