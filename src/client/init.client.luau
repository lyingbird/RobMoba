--[[
    init.client.luau
    客户端入口脚本
    
    初始化流程：
    1. 获取 Remotes
    2. 初始化 InputHandler（输入处理 + 技能指示器）
    3. 初始化 SkillBarUI（技能栏）
    4. 初始化 HealthBarUI（血条）
    5. 初始化 CombatUI（战斗提示）
    6. 初始化 VFXController（特效播放）
    7. 初始化 HeroSelectUI（英雄选择）
    8. 监听游戏状态变更
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer

-- 等待 Shared 模块加载
local shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(shared:WaitForChild("Remotes"))
local GameConfig = require(shared:WaitForChild("GameConfig"))

-- 引用客户端模块（init.client.luau 编译为 Client 自身，子模块在 script 下）
local CameraController = require(script:WaitForChild("CameraController"))
local MovementController = require(script:WaitForChild("MovementController"))
local InputHandler = require(script:WaitForChild("InputHandler"))
local SkillBarUI = require(script:WaitForChild("SkillBarUI"))
local HealthBarUI = require(script:WaitForChild("HealthBarUI"))
local CombatUI = require(script:WaitForChild("CombatUI"))
local VFXController = require(script:WaitForChild("VFXController"))
local HeroSelectUI = require(script:WaitForChild("HeroSelectUI"))

print("========================================")
print("[Client] 客户端初始化开始...")
print("========================================")

-- 1. 获取 Remotes
local ok, remotesOrError = pcall(Remotes.getRemotes)
if not ok then
    error("[Client] Remote initialization failed: " .. tostring(remotesOrError))
end

local remotes = remotesOrError
print("[Client] Remotes 获取完成")

-- 1.3. 初始化 CameraController（LOL 固定俯视角，必须在其他模块之前设置 Scriptable 摄像机）
CameraController.init()

-- 1.5. 初始化 MovementController（LOL风格鼠标移动，必须在 InputHandler 之前）
MovementController.init()

-- 2. 初始化 InputHandler
InputHandler.init(remotes)

-- 3. 初始化 SkillBarUI
SkillBarUI.init(remotes)

-- 4. 初始化 HealthBarUI
HealthBarUI.init(remotes)

-- 5. 初始化 CombatUI
CombatUI.init(remotes)

-- 6. 初始化 VFXController
VFXController.init(remotes)

-- 7. 初始化 HeroSelectUI
HeroSelectUI.init(remotes)

-- 8. 监听游戏状态变更
if remotes.GameStateChanged then
    remotes.GameStateChanged.OnClientEvent:Connect(function(data)
        if not data then return end
        local state = data.state
        
        if state == GameConfig.Game.States.Waiting then
            print("[Client] 等待其他玩家...")
            
        elseif state == GameConfig.Game.States.HeroSelect then
            print("[Client] 英雄选择阶段")
            HeroSelectUI.show()
            
        elseif state == GameConfig.Game.States.Countdown then
            print("[Client] 游戏即将开始! 倒计时: " .. tostring(data.countdown or 5))
            
            HeroSelectUI.hide()

        elseif state == GameConfig.Game.States.InProgress then
            print("[Client] 游戏开始！英雄切换面板已就绪")
            -- 测试模式：自动展开英雄选择面板
            HeroSelectUI.hide()
            
        elseif state == GameConfig.Game.States.Ended then
            print("[Client] 游戏结束! 获胜方: " .. tostring(data.winner or "?"))
            HeroSelectUI.hide()
        end
    end)
end

-- 9. 监听队伍分配
if remotes.TeamAssigned then
    remotes.TeamAssigned.OnClientEvent:Connect(function(data)
        if not data then return end
        print("[Client] 已分配到 " .. tostring(data.teamId) .. " 队")
    end)
end

-- 10. 监听镜头震动（通过 CameraController 实现，保持固定俯视角）
if remotes.CameraShake then
    remotes.CameraShake.OnClientEvent:Connect(function(data)
        if not data then return end
        local intensity = data.intensity or 1
        local duration = data.duration or 0.3
        CameraController.shake(intensity, duration)
    end)
end

-- 11. 监听持续施法进度条（已由 CombatUI 内部处理）

-- 12. 监听持续施法被打断
if remotes.ChannelInterrupt then
    remotes.ChannelInterrupt.OnClientEvent:Connect(function(data)
        print("[Client] 持续施法被打断!")
    end)
end

print("========================================")
print("[Client] 客户端初始化完成!")
print("========================================")
