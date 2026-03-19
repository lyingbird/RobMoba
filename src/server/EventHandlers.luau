--[[
    EventHandlers.luau
    原子事件处理函数集合
    
    设计：可扩展的注册式
    - registerHandler(eventType, handlerFn) 注册处理函数
    - executeEvent(context, event) 执行单个事件
    
    每个处理函数签名: function(context, event) -> cleanupFn?
    context = {
        caster: Model,            -- 施法者
        direction: Vector3,       -- 施法方向
        targetPosition: Vector3?, -- 目标位置（Position类技能）
        skillId: string,          -- 技能ID
        bullets: {},              -- 当前技能上下文中的弹体引用
        cancelled: boolean,       -- 是否已取消
    }
]]

local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")

local EventHandlers = {}

local handlers = {} -- { [eventType] = handlerFn }
local remotes = nil
local combatManager = nil
local statusEffectManager = nil
local skillSystemRef = nil  -- 缓存 SkillSystem 引用（init 后由 setSkillSystem 注入）

--============================================================
-- 初始化
--============================================================

function EventHandlers.init(remotesRef, combatManagerRef, statusEffectManagerRef)
    remotes = remotesRef
    combatManager = combatManagerRef
    statusEffectManager = statusEffectManagerRef
end

-- 延迟注入 SkillSystem 引用（由 init.server.luau 在所有模块初始化后调用）
function EventHandlers.setSkillSystem(skillSystemRefParam)
    skillSystemRef = skillSystemRefParam
end

--============================================================
-- 注册 / 执行
--============================================================

function EventHandlers.registerHandler(eventType: string, handlerFn)
    handlers[eventType] = handlerFn
end

function EventHandlers.executeEvent(context, event)
    local handler = handlers[event.type]
    if not handler then
        warn("[EventHandlers] 未注册的事件类型: " .. tostring(event.type))
        return nil
    end
    return handler(context, event)
end

function EventHandlers.hasHandler(eventType: string): boolean
    return handlers[eventType] ~= nil
end

--============================================================
-- 辅助函数
--============================================================

local function getCasterRootPart(context)
    return context.caster and context.caster:FindFirstChild("HumanoidRootPart")
end

local function getTargetsInArea(position: Vector3, shape: string, params, excludeModel)
    local targets = {}
    local overlapParams = OverlapParams.new()
    overlapParams.FilterType = Enum.RaycastFilterType.Exclude
    -- 排除施法者自身减少无用碰撞检测
    if excludeModel then
        overlapParams.FilterDescendantsInstances = { excludeModel }
    else
        overlapParams.FilterDescendantsInstances = {}
    end

    local parts = {}
    if shape == "Sphere" then
        parts = workspace:GetPartBoundsInRadius(position, params.radius or 5, overlapParams)
    elseif shape == "Box" then
        local size = params.size or Vector3.new(5, 5, 5)
        local cf = CFrame.new(position)
        if params.direction then
            cf = CFrame.lookAt(position, position + params.direction)
        end
        parts = workspace:GetPartBoundsInBox(cf, size, overlapParams)
    end

    -- 过滤出有 Humanoid 的目标
    local found = {}
    for _, part in ipairs(parts) do
        local model = part.Parent
        if model and not found[model] then
            local humanoid = model:FindFirstChildOfClass("Humanoid")
            if humanoid and humanoid.Health > 0 then
                found[model] = true
                table.insert(targets, model)
            end
        end
    end

    return targets
end

-- 过滤掉施法者自身 + 友军（只保留敌方目标和假人）
local function filterTargets(targets, caster)
    local Players = game:GetService("Players")
    local Teams = game:GetService("Teams")
    
    local casterPlayer = Players:GetPlayerFromCharacter(caster)
    local casterTeam = casterPlayer and casterPlayer.Team
    
    local filtered = {}
    for _, t in ipairs(targets) do
        if t == caster then continue end -- 排除自身
        
        -- 假人始终可被攻击
        local dummyTag = t:FindFirstChild("IsDummy")
        if dummyTag and dummyTag:IsA("BoolValue") and dummyTag.Value then
            table.insert(filtered, t)
            continue
        end
        
        -- 基地始终可被攻击
        local baseTag = t:FindFirstChild("TeamBase")
        if baseTag then
            -- 不攻击己方基地
            if casterTeam and baseTag.Value == casterTeam.Name then
                continue
            end
            table.insert(filtered, t)
            continue
        end
        
        -- 玩家角色：判断敌友
        local targetPlayer = Players:GetPlayerFromCharacter(t)
        if targetPlayer then
            local targetTeam = targetPlayer.Team
            if casterTeam and targetTeam and casterTeam == targetTeam then
                continue -- 同队友军，跳过
            end
        end
        
        table.insert(filtered, t)
    end
    return filtered
end

-- 执行 onHit 子事件链（传递 hitDetect 参数用于距离眩晕等）
local function executeOnHitChain(context, onHitEvents, target, hitDetectParams)
    if not onHitEvents then return end
    for _, subEvent in ipairs(onHitEvents) do
        -- 创建子上下文（target 作为当前命中目标）
        local subContext = {
            caster = context.caster,
            direction = context.direction,
            targetPosition = context.targetPosition,
            skillId = context.skillId,
            bullets = context.bullets,
            hitTarget = target,
            cancelled = context.cancelled,
            -- 传递递减伤害倍率
            _diminishingMultiplier = context._diminishingMultiplier,
            -- 传递距离眩晕参数
            _distanceStunMin = hitDetectParams and hitDetectParams.distanceStunMin,
            _distanceStunMax = hitDetectParams and hitDetectParams.distanceStunMax,
            _distanceStunRange = hitDetectParams and hitDetectParams.distanceStunRange,
        }
        EventHandlers.executeEvent(subContext, subEvent)
    end
end

--============================================================
-- 注册所有核心事件处理函数
--============================================================

-- SetAttackDir: 锁定攻击朝向
EventHandlers.registerHandler("SetAttackDir", function(context, event)
    local rootPart = getCasterRootPart(context)
    if not rootPart then return end
    -- 锁定朝向到施法方向
    local dir = context.direction
    if dir and dir.Magnitude > 0 then
        local lookAt = rootPart.Position + Vector3.new(dir.X, 0, dir.Z)
        rootPart.CFrame = CFrame.lookAt(rootPart.Position, lookAt)
    end
end)

-- ForbidAbility: 禁止移动/技能
EventHandlers.registerHandler("ForbidAbility", function(context, event)
    local params = event.params or {}
    local humanoid = context.caster:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    
    local originalWalkSpeed = humanoid.WalkSpeed
    local originalJumpPower = humanoid.JumpPower
    
    if params.forbidMove then
        humanoid.WalkSpeed = 0
        humanoid.JumpPower = 0
    end
    
    -- 返回 cleanup 函数
    return function()
        if humanoid and humanoid.Parent then
            if params.forbidMove then
                humanoid.WalkSpeed = originalWalkSpeed
                humanoid.JumpPower = originalJumpPower
            end
        end
    end
end)

-- TriggerCD: 触发技能冷却（或重置/减少其他技能的冷却）
EventHandlers.registerHandler("TriggerCD", function(context, event)
    local params = event.params or {}
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local shared = ReplicatedStorage:WaitForChild("Shared")
    local SkillTable = require(shared:WaitForChild("SkillTable"))
    
    -- 重置或减少其他技能的 CD（如廉颇 W 重置 Q、廉颇强化普攻减 Q CD 2秒）
    if params.resetCD and params.targetSkillId then
        local cdFolder = context.caster:FindFirstChild("Cooldowns")
        if cdFolder then
            local cdValue = cdFolder:FindFirstChild(params.targetSkillId)
            if cdValue and cdValue:IsA("NumberValue") then
                if params.cdReduction and params.cdReduction > 0 then
                    -- 减少指定秒数（不低于当前时间，即不能变成负数CD）
                    cdValue.Value = math.max(tick(), cdValue.Value - params.cdReduction)
                else
                    -- 完全重置
                    cdValue.Value = 0
                end
            end
        end
        -- 通知客户端 CD 更新
        local Players = game:GetService("Players")
        local player = Players:GetPlayerFromCharacter(context.caster)
        if player and remotes and remotes.CooldownUpdate then
            local remainingCD = 0
            local cdFolder2 = context.caster:FindFirstChild("Cooldowns")
            if cdFolder2 then
                local cdValue2 = cdFolder2:FindFirstChild(params.targetSkillId)
                if cdValue2 and cdValue2:IsA("NumberValue") then
                    remainingCD = math.max(0, cdValue2.Value - tick())
                end
            end
            remotes.CooldownUpdate:FireClient(player, {
                skillId = params.targetSkillId,
                cooldownTime = remainingCD,
            })
        end
        return
    end
    
    local skillConfig = SkillTable.getSkill(context.skillId)
    if not skillConfig then return end
    
    local cdTime = params.cdOverride or skillConfig.cooldown
    
    -- 记录冷却到施法者（存储在角色上）
    local cdFolder = context.caster:FindFirstChild("Cooldowns")
    if not cdFolder then
        cdFolder = Instance.new("Folder")
        cdFolder.Name = "Cooldowns"
        cdFolder.Parent = context.caster
    end
    
    local cdValue = cdFolder:FindFirstChild(context.skillId)
    if not cdValue then
        cdValue = Instance.new("NumberValue")
        cdValue.Name = context.skillId
        cdValue.Parent = cdFolder
    end
    cdValue.Value = tick() + cdTime
    
    -- 通知客户端
    local Players = game:GetService("Players")
    local player = Players:GetPlayerFromCharacter(context.caster)
    if player and remotes and remotes.CooldownUpdate then
        remotes.CooldownUpdate:FireClient(player, {
            skillId = context.skillId,
            cooldownTime = cdTime,
        })
    end
end)

-- SuperArmor: 霸体
EventHandlers.registerHandler("SuperArmor", function(context, event)
    statusEffectManager.applyEffect({
        target = context.caster,
        buffType = "SuperArmor",
        duration = event.duration or 1,
        source = context.caster,
    })
    
    return function()
        statusEffectManager.removeEffect(context.caster, "SuperArmor")
    end
end)

-- PlayAnim: 播放动画（通知客户端）
EventHandlers.registerHandler("PlayAnim", function(context, event)
    local params = event.params or {}
    if remotes and remotes.PlayAnim then
        remotes.PlayAnim:FireAllClients({
            targetModel = context.caster,
            animId = params.animId,
            speed = params.speed or 1.0,
            duration = event.duration,
            loopCount = params.loopCount,
            blendTime = params.blendTime,
            priority = params.priority,
        })
    end
    
    return function()
        if remotes and remotes.StopAnim then
            remotes.StopAnim:FireAllClients({
                targetModel = context.caster,
                animId = params.animId,
            })
        end
    end
end)

-- PlayVFX: 播放特效（通知客户端）
EventHandlers.registerHandler("PlayVFX", function(context, event)
    local params = event.params or {}
    local rootPart = getCasterRootPart(context)
    if not rootPart then return end
    
    -- 确定特效位置
    local position = rootPart.Position
    if params.useTargetPosition and context.targetPosition then
        position = context.targetPosition
    end
    if context.hitTarget then
        local targetRoot = context.hitTarget:FindFirstChild("HumanoidRootPart")
        if targetRoot then
            position = targetRoot.Position
        end
    end
    
    -- 弹体附着
    local bulletRef = nil
    if params.attachToBullet and params.bulletId and context.bullets then
        bulletRef = context.bullets[params.bulletId]
    end
    
    if remotes and remotes.PlayVFX then
        remotes.PlayVFX:FireAllClients({
            templateId = params.templateId,
            position = position,
            direction = context.direction,
            casterModel = context.caster,
            attachToSelf = params.attachToSelf,
            attachToBullet = params.attachToBullet,
            bulletRef = bulletRef,
            duration = params.duration,
            scale = params.scale,
            color = params.color,
            offset = params.offset,
        })
    end
end)

-- CameraShake: 镜头震动（通知所有客户端）
EventHandlers.registerHandler("CameraShake", function(context, event)
    local params = event.params or {}
    if remotes and remotes.CameraShake then
        remotes.CameraShake:FireAllClients({
            intensity = params.intensity or 0.3,
            duration = event.duration or 0.3,
            position = getCasterRootPart(context) and getCasterRootPart(context).Position,
        })
    end
end)

-- SpawnBullet: 生成弹体
EventHandlers.registerHandler("SpawnBullet", function(context, event)
    local params = event.params or {}
    local rootPart = getCasterRootPart(context)
    if not rootPart then return end
    
    -- 计算弹体方向（考虑角度偏移）
    local dir = context.direction
    if params.angle and params.angle ~= 0 then
        local angleRad = math.rad(params.angle)
        dir = CFrame.Angles(0, angleRad, 0) * CFrame.new(Vector3.zero, dir)
        dir = dir.LookVector
    end
    
    -- 创建弹体 Part
    local bullet = Instance.new("Part")
    bullet.Name = params.bulletId or "Bullet"
    bullet.Size = params.size or Vector3.new(1, 1, 1)
    bullet.CFrame = CFrame.lookAt(rootPart.Position + dir * 2, rootPart.Position + dir * 10)
    bullet.Anchored = true
    bullet.CanCollide = false
    bullet.Transparency = 0.5
    bullet.Material = Enum.Material.Neon
    bullet.Color = Color3.fromRGB(255, 200, 100)
    bullet.CastShadow = false
    bullet.Parent = workspace
    
    -- 标记弹体属性
    local ownerTag = Instance.new("ObjectValue")
    ownerTag.Name = "Owner"
    ownerTag.Value = context.caster
    ownerTag.Parent = bullet
    
    -- 添加到上下文
    if not context.bullets then
        context.bullets = {}
    end
    context.bullets[params.bulletId or "Bullet"] = bullet
    
    -- 自动清理
    Debris:AddItem(bullet, (params.maxDist or 30) / (params.speed or 50) + 1)
end)

-- MoveBullet: 弹体飞行（支持弹体停止标记）
EventHandlers.registerHandler("MoveBullet", function(context, event)
    local params = event.params or {}
    local bulletId = params.bulletId
    local bullet = context.bullets and context.bullets[bulletId]
    if not bullet or not bullet.Parent then return end
    
    local speed = params.speed or 50
    local maxDist = params.maxDist or 30
    local startPos = bullet.Position
    local direction = bullet.CFrame.LookVector
    
    -- 逐帧移动弹体
    local connection
    local totalMoved = 0
    
    connection = RunService.Heartbeat:Connect(function(dt)
        if not bullet or not bullet.Parent or context.cancelled then
            if connection then connection:Disconnect() end
            return
        end
        
        -- 检查弹体是否被 HitDetect 停止
        if context._bulletStopped and context._bulletStopped[bulletId] then
            if connection then connection:Disconnect() end
            return
        end
        
        local moveAmount = speed * dt
        totalMoved += moveAmount
        
        if totalMoved >= maxDist then
            if connection then connection:Disconnect() end
            -- 记录弹体停止位置（供 useBulletStopPosition 使用）
            context._bulletStopPositions = context._bulletStopPositions or {}
            context._bulletStopPositions[bulletId] = bullet.Position
            bullet:Destroy()
            return
        end
        
        bullet.CFrame = bullet.CFrame + direction * moveAmount
    end)
    
    return function()
        if connection then connection:Disconnect() end
        if bullet and bullet.Parent then
            bullet:Destroy()
        end
    end
end)

-- SpawnCollider: 生成碰撞区域（逻辑用，不可见）
EventHandlers.registerHandler("SpawnCollider", function(context, event)
    local params = event.params or {}
    local rootPart = getCasterRootPart(context)
    if not rootPart then return end
    
    -- 碰撞区只是逻辑标记，HitDetect 会使用参数进行空间查询
    -- 这里不需要创建实际 Part（避免性能开销）
    -- 但为了可视化调试，可以创建透明 Part
    
    return nil
end)

-- HitDetect: 命中检测（支持方向跟随、递减伤害、弹体命中销毁/停止、弹体停止位置检测）
EventHandlers.registerHandler("HitDetect", function(context, event)
    local params = event.params or {}
    local interval = params.interval or 0
    local maxTargets = params.maxTargets or 32
    local hitTargets = {} -- 已命中的目标（用于避免重复）
    local hitCount = 0
    local segmentIndex = 0
    
    -- 递减伤害追踪 { [targetModel] = hitCount }
    local diminishingHits = {}
    local diminishingTag = params.diminishingTag
    local diminishingRatio = params.diminishingRatio or 0.30
    
    -- 等待弹体停止标记
    local bulletStopped = false
    local bulletStopPosition = nil
    
    local function doDetection()
        if context.cancelled then return end
        
        -- 等待弹体停止模式
        if params.waitForBulletStop and not bulletStopped then
            return -- 还没停下，跳过检测
        end
        
        -- 确定检测位置
        local position
        local detectDirection = context.direction
        
        if params.attachToBullet and params.bulletId and context.bullets then
            local bullet = context.bullets[params.bulletId]
            if bullet and bullet.Parent then
                position = bullet.Position
                detectDirection = bullet.CFrame.LookVector
            else
                -- 弹体已消失
                if params.useBulletStopPosition and bulletStopPosition then
                    position = bulletStopPosition
                else
                    return
                end
            end
        elseif params.useBulletStopPosition and bulletStopPosition then
            position = bulletStopPosition
        elseif params.attachToSelf then
            local rootPart = getCasterRootPart(context)
            if rootPart then
                position = rootPart.Position
                -- 使用施法者当前朝向（用于安琪拉E光束跟随转向）
                if params.useForwardDirection then
                    detectDirection = rootPart.CFrame.LookVector
                end
            end
        elseif params.useTargetPosition and context.targetPosition then
            position = context.targetPosition
        else
            local rootPart = getCasterRootPart(context)
            if rootPart then
                position = rootPart.Position + context.direction * 3
            end
        end
        
        if not position then return end
        
        -- 对 useForwardDirection 的 Box 检测：将 position 偏移到前方
        local adjustedPosition = position
        if params.useForwardDirection and params.shape == "Box" and params.size then
            -- Box 检测时，position 放在施法者前方 size.Z/2 处
            adjustedPosition = position + detectDirection * (params.size.Z / 2)
        end
        
        -- 执行空间查询
        local detectedParams = {
            radius = params.radius,
            size = params.size,
            direction = detectDirection,
        }
        local targets = getTargetsInArea(adjustedPosition, params.shape or "Sphere", detectedParams, context.caster)
        targets = filterTargets(targets, context.caster)
        
        -- 处理命中
        for _, target in ipairs(targets) do
            if hitCount >= maxTargets then break end
            
            local targetKey = target
            if interval > 0 then
                -- 重复检测模式：同一目标可多次命中
                targetKey = tostring(target) .. "_" .. tostring(segmentIndex)
            end
            
            if not hitTargets[targetKey] or interval > 0 then
                hitTargets[targetKey] = true
                hitCount += 1
                
                -- 处理分段伤害
                if params.segmentDamages then
                    segmentIndex = math.min(segmentIndex + 1, #params.segmentDamages)
                    context._currentSegmentDamage = params.segmentDamages[segmentIndex]
                end
                
                -- 递减伤害（如安琪拉Q同目标第2颗起30%）
                if diminishingTag then
                    if not context._diminishingTracker then
                        context._diminishingTracker = {}
                    end
                    local tracker = context._diminishingTracker
                    if not tracker[diminishingTag] then
                        tracker[diminishingTag] = {}
                    end
                    local tagTracker = tracker[diminishingTag]
                    local targetId = tostring(target)
                    if tagTracker[targetId] then
                        -- 已命中过此目标，应用递减
                        context._diminishingMultiplier = diminishingRatio
                    else
                        -- 首次命中此目标，全额伤害
                        context._diminishingMultiplier = 1.0
                    end
                    tagTracker[targetId] = true
                else
                    context._diminishingMultiplier = nil
                end
                
                -- 执行 onHit 子事件链（传递 hitDetect 参数）
                executeOnHitChain(context, event.onHit, target, params)
                
                -- 清除递减标记
                context._diminishingMultiplier = nil
                
                -- 命中后销毁弹体
                if params.destroyBulletOnHit and params.bulletId and context.bullets then
                    local bullet = context.bullets[params.bulletId]
                    if bullet and bullet.Parent then
                        bulletStopPosition = bullet.Position
                        bulletStopped = true
                        bullet:Destroy()
                        context.bullets[params.bulletId] = nil
                    end
                end
                
                -- 命中后停止弹体（不销毁）
                if params.stopBulletOnHit and params.bulletId and context.bullets then
                    local bullet = context.bullets[params.bulletId]
                    if bullet and bullet.Parent then
                        bulletStopPosition = bullet.Position
                        bulletStopped = true
                        bullet.Anchored = true
                        -- 停止 MoveBullet（通过标记）
                        context._bulletStopped = context._bulletStopped or {}
                        context._bulletStopped[params.bulletId] = true
                    end
                end
            end
        end
    end
    
    -- 首次检测
    doDetection()
    
    -- 如果有间隔，设置重复检测
    if interval > 0 and event.duration and event.duration > 0 then
        local elapsed = 0
        local connection
        local lastDetectTime = 0
        
        connection = RunService.Heartbeat:Connect(function(dt)
            if context.cancelled then
                if connection then connection:Disconnect() end
                return
            end
            
            elapsed += dt
            if elapsed >= event.duration then
                if connection then connection:Disconnect() end
                return
            end
            
            -- 检查弹体是否已停止（用于 waitForBulletStop）
            if params.waitForBulletStop and not bulletStopped then
                if params.bulletId and context.bullets then
                    local bullet = context.bullets[params.bulletId]
                    if not bullet or not bullet.Parent then
                        bulletStopped = true
                        -- 已消失（被其他 HitDetect 的 destroyBulletOnHit 销毁或 MoveBullet 结束）
                        if not bulletStopPosition then
                            return -- 没有记录停止位置，无法检测
                        end
                    end
                end
            end
            
            -- 检查弹体是否被 stopBulletOnHit 停止
            if params.bulletId and context._bulletStopped and context._bulletStopped[params.bulletId] then
                if not bulletStopped then
                    local bullet = context.bullets and context.bullets[params.bulletId]
                    if bullet then
                        bulletStopPosition = bullet.Position
                    end
                    bulletStopped = true
                end
            end
            
            lastDetectTime += dt
            if lastDetectTime >= interval then
                lastDetectTime -= interval
                if interval > 0 then
                    hitTargets = {} -- 重置命中列表（允许重复命中）
                    hitCount = 0
                end
                doDetection()
            end
        end)
        
        return function()
            if connection then connection:Disconnect() end
        end
    end
end)

-- DealDamage: 造成伤害（支持攻击力/法强加成、最大生命比例伤害、递减伤害）
EventHandlers.registerHandler("DealDamage", function(context, event)
    local params = event.params or {}
    local target = context.hitTarget
    if not target then return end
    
    local damage = params.damage or 0
    
    -- 使用分段伤害
    if params.useSegmentDamage and context._currentSegmentDamage then
        damage = context._currentSegmentDamage
    end
    
    -- 使用普攻攻击力
    if params.useAttackDamage then
        local adValue = context.caster:FindFirstChild("AttackDamage")
        if adValue and adValue:IsA("NumberValue") then
            damage = adValue.Value
        end
    end
    
    -- 物理攻击加成
    if params.adRatio and params.adRatio > 0 then
        local adValue = context.caster:FindFirstChild("AttackDamage")
        if adValue and adValue:IsA("NumberValue") then
            damage = damage + adValue.Value * params.adRatio
        end
    end
    
    -- 法术强度加成
    if params.apRatio and params.apRatio > 0 then
        local apValue = context.caster:FindFirstChild("MagicPower")
        if apValue and apValue:IsA("NumberValue") then
            damage = damage + apValue.Value * params.apRatio
        end
    end
    
    -- 最大生命值比例伤害
    if params.maxHpRatio and params.maxHpRatio > 0 then
        local humanoid = context.caster:FindFirstChildOfClass("Humanoid")
        if humanoid then
            damage = damage + humanoid.MaxHealth * params.maxHpRatio
        end
    end
    
    -- 递减伤害（如安琪拉Q对同一目标第2颗起30%）
    if context._diminishingMultiplier then
        damage = damage * context._diminishingMultiplier
    end
    
    combatManager.dealDamage({
        attacker = context.caster,
        target = target,
        damage = damage,
        damageType = params.damageType or "Physical",
    })
    
    -- 技能命中后触发被动（安琪拉咒术火焰灼烧叠加）
    -- 排除普攻伤害（普攻的skillId以 basic_attack_ 开头）
    if context.skillId and not string.find(context.skillId, "basic_attack_") and not params.useAttackDamage then
        local heroIdTag = context.caster:FindFirstChild("HeroId")
        if heroIdTag and heroIdTag:IsA("StringValue") then
            if skillSystemRef and skillSystemRef.triggerSkillHitPassive then
                skillSystemRef.triggerSkillHitPassive(context.caster, target, heroIdTag.Value)
            end
        end
    end
end)

-- ApplyBuff: 施加 Buff/Debuff（支持距离眩晕、护盾法强加成、免控）
EventHandlers.registerHandler("ApplyBuff", function(context, event)
    local params = event.params or {}
    local target = params.toSelf and context.caster or context.hitTarget
    if not target then
        if params.toSelf then
            target = context.caster
        else
            return
        end
    end
    
    local duration = params.duration or 0
    local value = params.value or 0
    
    -- 距离眩晕（后羿E：飞行距离越远，眩晕越久）
    if params.useDistanceStun and context.hitTarget then
        local rootPart = getCasterRootPart(context)
        local targetRoot = context.hitTarget:FindFirstChild("HumanoidRootPart")
        if rootPart and targetRoot then
            local dist = (targetRoot.Position - rootPart.Position).Magnitude
            -- 从 HitDetect params 获取距离眩晕参数
            local minStun = context._distanceStunMin or 0.5
            local maxStun = context._distanceStunMax or 3.5
            local maxRange = context._distanceStunRange or 200
            local ratio = math.clamp(dist / maxRange, 0, 1)
            duration = minStun + (maxStun - minStun) * ratio
        end
    end
    
    -- 护盾法术加成
    if params.buffType == "Shield" and params.apRatio then
        local apValue = context.caster:FindFirstChild("MagicPower")
        if apValue and apValue:IsA("NumberValue") then
            value = value + apValue.Value * params.apRatio
        end
    end
    
    statusEffectManager.applyEffect({
        target = target,
        buffType = params.buffType,
        duration = duration,
        value = value,
        source = context.caster,
        subType = params.subType,
    })
    
    -- 免控（安琪拉E护盾期间免控）
    if params.grantImmunity then
        statusEffectManager.applyEffect({
            target = target,
            buffType = "SuperArmor",
            duration = duration,
            source = context.caster,
        })
    end
    
    -- 额外参数传递（如 AttackBuff 的 extraArrows, totalDamageRatio）
    if params.extraArrows or params.totalDamageRatio then
        -- 存储到角色上供攻击系统读取
        local buffData = context.caster:FindFirstChild("CurrentAttackBuff")
        if not buffData then
            buffData = Instance.new("Folder")
            buffData.Name = "CurrentAttackBuff"
            buffData.Parent = context.caster
        end
        if params.extraArrows then
            local v = buffData:FindFirstChild("ExtraArrows")
            if not v then v = Instance.new("NumberValue"); v.Name = "ExtraArrows"; v.Parent = buffData end
            v.Value = params.extraArrows
        end
        if params.totalDamageRatio then
            local v = buffData:FindFirstChild("TotalDamageRatio")
            if not v then v = Instance.new("NumberValue"); v.Name = "TotalDamageRatio"; v.Parent = buffData end
            v.Value = params.totalDamageRatio
        end
        -- 到期后清除
        task.delay(duration, function()
            if buffData and buffData.Parent then
                buffData:Destroy()
            end
        end)
    end
end)

-- RemoveBuff: 移除 Buff
EventHandlers.registerHandler("RemoveBuff", function(context, event)
    local params = event.params or {}
    local target = params.fromSelf and context.caster or context.hitTarget
    if not target then return end
    
    statusEffectManager.removeEffect(target, params.buffType)
end)

-- MoveActor: 角色位移
EventHandlers.registerHandler("MoveActor", function(context, event)
    local params = event.params or {}
    local rootPart = getCasterRootPart(context)
    if not rootPart then return end
    
    local moveType = params.moveType or "direction"
    local speed = params.speed or 50
    local duration = event.duration or 0.5
    
    if moveType == "direction" then
        local distance = params.distance or 10
        local dir = Vector3.new(context.direction.X, 0, context.direction.Z).Unit
        local startPos = rootPart.Position
        local targetPos = startPos + dir * distance
        local moved = 0
        
        local connection
        connection = RunService.Heartbeat:Connect(function(dt)
            if not rootPart or not rootPart.Parent or context.cancelled then
                if connection then connection:Disconnect() end
                return
            end
            
            moved += speed * dt
            if moved >= distance then
                rootPart.CFrame = CFrame.lookAt(targetPos, targetPos + dir)
                if connection then connection:Disconnect() end
                return
            end
            
            local newPos = startPos + dir * moved
            rootPart.CFrame = CFrame.lookAt(newPos, newPos + dir)
        end)
        
        return function()
            if connection then connection:Disconnect() end
        end
        
    elseif moveType == "toPosition" then
        local targetPos = context.targetPosition
        if not targetPos then return end
        -- 调整 Y 到地面高度
        targetPos = Vector3.new(targetPos.X, rootPart.Position.Y, targetPos.Z)
        local dir = (targetPos - rootPart.Position).Unit
        local dist = (targetPos - rootPart.Position).Magnitude
        local moved = 0
        local startPos = rootPart.Position
        
        local connection
        connection = RunService.Heartbeat:Connect(function(dt)
            if not rootPart or not rootPart.Parent or context.cancelled then
                if connection then connection:Disconnect() end
                return
            end
            
            moved += speed * dt
            if moved >= dist then
                rootPart.CFrame = CFrame.lookAt(targetPos, targetPos + dir)
                if connection then connection:Disconnect() end
                return
            end
            
            local newPos = startPos + dir * moved
            rootPart.CFrame = CFrame.lookAt(newPos, newPos + dir)
        end)
        
        return function()
            if connection then connection:Disconnect() end
        end
    end
end)

-- RotateActor: 持续施法期间缓慢跟随鼠标转向（安琪拉E光束）
EventHandlers.registerHandler("RotateActor", function(context, event)
    local params = event.params or {}
    local rotateSpeed = params.rotateSpeed or 90 -- 度/秒
    local rootPart = getCasterRootPart(context)
    if not rootPart then return end
    
    -- 获取施法者对应的玩家
    local Players = game:GetService("Players")
    local player = Players:GetPlayerFromCharacter(context.caster)
    if not player then return end
    
    -- 目标方向（由客户端持续更新）
    local targetDirection = context.direction  -- 初始方向 = 技能施放方向
    
    -- 监听客户端方向更新
    local directionConnection = nil
    if remotes and remotes.ChannelDirection then
        directionConnection = remotes.ChannelDirection.OnServerEvent:Connect(function(sender, data)
            if sender ~= player then return end  -- 只处理施法者的输入
            if not data or not data.direction then return end
            local dir = data.direction
            if typeof(dir) ~= "Vector3" then return end
            dir = Vector3.new(dir.X, 0, dir.Z)
            if dir.Magnitude > 0.01 then
                targetDirection = dir.Unit
            end
        end)
    end
    
    -- 逐帧缓慢转向目标方向
    local connection
    connection = RunService.Heartbeat:Connect(function(dt)
        if not rootPart or not rootPart.Parent or context.cancelled then
            if connection then connection:Disconnect() end
            if directionConnection then directionConnection:Disconnect() end
            return
        end
        
        -- 当前朝向
        local currentLook = rootPart.CFrame.LookVector
        currentLook = Vector3.new(currentLook.X, 0, currentLook.Z)
        if currentLook.Magnitude < 0.01 then return end
        currentLook = currentLook.Unit
        
        -- 计算角度差
        local cross = currentLook:Cross(targetDirection)
        local dot = currentLook:Dot(targetDirection)
        local angleDiff = math.atan2(cross.Y, dot)  -- 有符号角度差
        
        -- 限制单帧最大转向角度
        local maxRotation = math.rad(rotateSpeed) * dt
        local rotation = math.clamp(angleDiff, -maxRotation, maxRotation)
        
        if math.abs(rotation) > 0.001 then
            rootPart.CFrame = rootPart.CFrame * CFrame.Angles(0, rotation, 0)
        end
    end)
    
    return function()
        if connection then connection:Disconnect() end
        if directionConnection then directionConnection:Disconnect() end
    end
end)

-- ChannelBar: 持续施法进度条
EventHandlers.registerHandler("ChannelBar", function(context, event)
    local params = event.params or {}
    local Players = game:GetService("Players")
    local player = Players:GetPlayerFromCharacter(context.caster)
    if not player then return end
    
    local duration = event.duration or 3
    local elapsed = 0
    
    local connection
    connection = RunService.Heartbeat:Connect(function(dt)
        if context.cancelled then
            if connection then connection:Disconnect() end
            return
        end
        elapsed += dt
        if elapsed >= duration then
            if connection then connection:Disconnect() end
            return
        end
        -- 每 0.1s 更新一次进度条
        if math.floor(elapsed * 10) > math.floor((elapsed - dt) * 10) then
            if remotes and remotes.ChannelBarUpdate then
                remotes.ChannelBarUpdate:FireClient(player, {
                    progress = elapsed / duration,
                    maxDuration = duration,
                })
            end
        end
    end)
    
    return function()
        if connection then connection:Disconnect() end
        if remotes and remotes.ChannelBarUpdate then
            remotes.ChannelBarUpdate:FireClient(player, {
                progress = 0,
                maxDuration = 0,
            })
        end
    end
end)

-- ChangeSkill: 临时替换技能
EventHandlers.registerHandler("ChangeSkill", function(context, event)
    local params = event.params or {}
    local Players = game:GetService("Players")
    local player = Players:GetPlayerFromCharacter(context.caster)
    if not player then return end
    
    -- 服务端记录技能替换（SkillSystem 校验时使用）
    if skillSystemRef and params.replaceKey and params.newSkillId then
        skillSystemRef.setSkillReplacement(player, params.replaceKey, params.newSkillId)
    end
    
    -- 通知客户端替换技能按键
    if remotes and remotes.SkillBarUpdate then
        remotes.SkillBarUpdate:FireClient(player, {
            action = "replace",
            key = params.replaceKey,
            newSkillId = params.newSkillId,
        })
    end
    
    -- 定时恢复
    if params.revertTime and params.revertTime > 0 then
        task.delay(params.revertTime, function()
            -- 服务端恢复技能替换
            if skillSystemRef and params.replaceKey then
                skillSystemRef.revertSkillReplacement(player, params.replaceKey)
            end
            
            if remotes and remotes.SkillBarUpdate then
                remotes.SkillBarUpdate:FireClient(player, {
                    action = "revert",
                    key = params.replaceKey,
                })
            end
        end)
    end
end)

-- AddMark: 增加印记
EventHandlers.registerHandler("AddMark", function(context, event)
    local params = event.params or {}
    local target = context.hitTarget
    if not target then return end
    
    statusEffectManager.addMark({
        target = target,
        markId = params.markId,
        amount = params.amount or 1,
        duration = params.duration or 3,
        maxStack = params.maxStack or 10,
    })
end)

-- TriggerMark: 触发印记效果
EventHandlers.registerHandler("TriggerMark", function(context, event)
    local params = event.params or {}
    local target = context.hitTarget
    if not target then return end
    
    local stacks = statusEffectManager.getMarkStacks(target, params.markId)
    local threshold = params.threshold or 10
    
    if stacks >= threshold then
        -- 清除印记
        statusEffectManager.clearMarks(target, params.markId)
        
        -- 执行 onHit 子事件链（如果有配置的话）
        if event.onHit then
            executeOnHitChain(context, event.onHit, target)
        end
    end
end)

return EventHandlers
