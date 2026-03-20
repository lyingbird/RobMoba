--[[
    Client bootstrap.

    The client keeps remotes as a hard requirement, but each feature module
    is initialized behind a protected boundary so one failure does not blank
    the entire mobile UI stack.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer

local shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(shared:WaitForChild("Remotes"))
local GameConfig = require(shared:WaitForChild("GameConfig"))

local modules = {}

local ready = {
    camera = false,
    movement = false,
    input = false,
    skillBar = false,
    healthBar = false,
    combat = false,
    vfx = false,
    heroSelect = false,
}

local function safeRequire(label: string, childName: string)
    local ok, result = pcall(function()
        return require(script:WaitForChild(childName))
    end)

    if not ok then
        warn(string.format("[Client] %s load failed: %s", label, tostring(result)))
        return nil
    end

    return result
end

local function safeInit(label: string, callback, ...)
    if type(callback) ~= "function" then
        warn(string.format("[Client] %s init skipped: missing callback", label))
        return false
    end

    local ok, err = pcall(callback, ...)
    if not ok then
        warn(string.format("[Client] %s init failed: %s", label, tostring(err)))
        return false
    end

    return true
end

print("========================================")
print("[Client] bootstrap start")
print("========================================")

local ok, remotesOrError = pcall(Remotes.getRemotes)
if not ok then
    error("[Client] Remote initialization failed: " .. tostring(remotesOrError))
end

local remotes = remotesOrError
print("[Client] remotes ready")

modules.camera = safeRequire("CameraController", "CameraController")
modules.movement = safeRequire("MovementController", "MovementController")
modules.input = safeRequire("InputHandler", "InputHandler")
modules.skillBar = safeRequire("SkillBarUI", "SkillBarUI")
modules.healthBar = safeRequire("HealthBarUI", "HealthBarUI")
modules.combat = safeRequire("CombatUI", "CombatUI")
modules.vfx = safeRequire("VFXController", "VFXController")
modules.heroSelect = safeRequire("HeroSelectUI", "HeroSelectUI")

ready.camera = safeInit("CameraController", modules.camera and modules.camera.init)
ready.movement = safeInit("MovementController", modules.movement and modules.movement.init)
ready.input = safeInit("InputHandler", modules.input and modules.input.init, remotes)
ready.skillBar = safeInit("SkillBarUI", modules.skillBar and modules.skillBar.init, remotes)
ready.healthBar = safeInit("HealthBarUI", modules.healthBar and modules.healthBar.init, remotes)
ready.combat = safeInit("CombatUI", modules.combat and modules.combat.init, remotes)
ready.vfx = safeInit("VFXController", modules.vfx and modules.vfx.init, remotes)
ready.heroSelect = safeInit("HeroSelectUI", modules.heroSelect and modules.heroSelect.init, remotes)

if remotes.GameStateChanged then
    remotes.GameStateChanged.OnClientEvent:Connect(function(data)
        if not data then
            return
        end

        local state = data.state

        if state == GameConfig.Game.States.Waiting then
            print("[Client] waiting for more players")
        elseif state == GameConfig.Game.States.HeroSelect then
            print("[Client] hero select")
            if ready.heroSelect then
                modules.heroSelect.show()
            end
        elseif state == GameConfig.Game.States.Countdown then
            print("[Client] countdown:", tostring(data.countdown or 5))
            if ready.heroSelect then
                modules.heroSelect.hide()
            end
        elseif state == GameConfig.Game.States.InProgress then
            print("[Client] in progress")
            if ready.heroSelect then
                modules.heroSelect.hide()
            end
        elseif state == GameConfig.Game.States.Ended then
            print("[Client] ended:", tostring(data.winner or "?"))
            if ready.heroSelect then
                modules.heroSelect.hide()
            end
        end
    end)
end

if remotes.TeamAssigned then
    remotes.TeamAssigned.OnClientEvent:Connect(function(data)
        if not data then
            return
        end

        print("[Client] assigned team:", tostring(data.teamId))
    end)
end

if remotes.CameraShake then
    remotes.CameraShake.OnClientEvent:Connect(function(data)
        if not data or not ready.camera then
            return
        end

        modules.camera.shake(data.intensity or 1, data.duration or 0.3)
    end)
end

if remotes.ChannelInterrupt then
    remotes.ChannelInterrupt.OnClientEvent:Connect(function()
        print("[Client] channel interrupted")
    end)
end

print("========================================")
print("[Client] bootstrap complete for", localPlayer.Name)
print("========================================")
