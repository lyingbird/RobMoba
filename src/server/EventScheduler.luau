--[[
    EventScheduler.luau
    事件时间轴调度器（核心引擎）
    
    职责：
    - 接收技能事件时间轴配置
    - 按 startTime 排序事件
    - 使用 task.delay 调度 Tick 事件、task.spawn 驱动 Duration 事件
    - 管理技能执行上下文（施法者/方向/目标）
    - 支持提前终止（被控制打断 / 手动取消）
]]

local EventScheduler = {}

local EventHandlers = nil
local EventTypes = nil

-- 当前活跃的技能执行: { [Model] = { context, cleanups, ... } }
local activeSkills = {}

--============================================================
-- 初始化
--============================================================

function EventScheduler.init(eventHandlersRef)
    EventHandlers = eventHandlersRef
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local shared = ReplicatedStorage:WaitForChild("Shared")
    EventTypes = require(shared:WaitForChild("EventTypes"))
end

--============================================================
-- 执行技能时间轴
--============================================================

--[[
    executeTimeline(params)
    params = {
        caster: Model,
        direction: Vector3,
        targetPosition: Vector3?,
        skillId: string,
        timeline: { totalDuration, events },
    }
]]
function EventScheduler.executeTimeline(params)
    local caster = params.caster
    local timeline = params.timeline
    
    if not timeline or not timeline.events then
        warn("[EventScheduler] 无效的时间轴配置: " .. tostring(params.skillId))
        return
    end

    -- 如果角色已有正在执行的技能，取消旧技能
    if activeSkills[caster] then
        EventScheduler.cancelSkill(caster)
    end

    -- 创建执行上下文
    local context = {
        caster = caster,
        direction = params.direction,
        targetPosition = params.targetPosition,
        skillId = params.skillId,
        bullets = {},
        cancelled = false,
        startTime = tick(),
    }

    -- 存储活跃技能
    local skillExecution = {
        context = context,
        cleanups = {},      -- Duration 事件的 cleanup 函数列表
        delayThreads = {},  -- task.delay 返回的线程列表
    }
    activeSkills[caster] = skillExecution

    -- 按 startTime 排序事件
    local sortedEvents = {}
    for _, event in ipairs(timeline.events) do
        table.insert(sortedEvents, event)
    end
    table.sort(sortedEvents, function(a, b)
        return a.startTime < b.startTime
    end)

    -- 调度每个事件
    for _, event in ipairs(sortedEvents) do
        local startTime = event.startTime or 0
        
        if startTime <= 0 then
            -- 立即执行
            task.spawn(function()
                if context.cancelled then return end
                EventScheduler._executeEvent(skillExecution, context, event)
            end)
        else
            -- 延迟执行
            local thread = task.delay(startTime, function()
                if context.cancelled then return end
                EventScheduler._executeEvent(skillExecution, context, event)
            end)
            table.insert(skillExecution.delayThreads, thread)
        end
    end

    -- 设定技能总时长结束后清理
    if timeline.totalDuration and timeline.totalDuration > 0 then
        local thread = task.delay(timeline.totalDuration + 0.1, function()
            EventScheduler._finishSkill(caster)
        end)
        table.insert(skillExecution.delayThreads, thread)
    end
end

--============================================================
-- 内部：执行单个事件
--============================================================

function EventScheduler._executeEvent(skillExecution, context, event)
    if context.cancelled then return end
    
    local isDuration = EventTypes.isDuration(event.type)
    
    -- 执行事件处理函数
    local cleanupFn = EventHandlers.executeEvent(context, event)
    
    if isDuration and cleanupFn then
        table.insert(skillExecution.cleanups, cleanupFn)
        
        -- Duration 事件到期后执行 cleanup
        if event.duration and event.duration > 0 then
            local thread = task.delay(event.duration, function()
                if not context.cancelled then
                    cleanupFn()
                end
            end)
            table.insert(skillExecution.delayThreads, thread)
        end
    end
end

--============================================================
-- 取消技能
--============================================================

function EventScheduler.cancelSkill(caster)
    local execution = activeSkills[caster]
    if not execution then return end
    
    -- 标记取消
    execution.context.cancelled = true
    
    -- 执行所有 cleanup 函数
    for _, cleanup in ipairs(execution.cleanups) do
        pcall(cleanup)
    end
    
    -- 取消所有延迟任务
    for _, thread in ipairs(execution.delayThreads) do
        pcall(task.cancel, thread)
    end
    
    -- 清理弹体
    for _, bullet in pairs(execution.context.bullets) do
        if bullet and bullet.Parent then
            bullet:Destroy()
        end
    end
    
    activeSkills[caster] = nil
end

--============================================================
-- 技能执行完成
--============================================================

function EventScheduler._finishSkill(caster)
    local execution = activeSkills[caster]
    if not execution then return end
    
    -- 不取消已完成的 cleanup
    activeSkills[caster] = nil
end

--============================================================
-- 查询接口
--============================================================

-- 角色是否正在执行技能
function EventScheduler.isCasting(caster): boolean
    return activeSkills[caster] ~= nil
end

-- 获取当前正在释放的技能 ID
function EventScheduler.getCurrentSkillId(caster): string?
    local execution = activeSkills[caster]
    if execution then
        return execution.context.skillId
    end
    return nil
end

-- 被控制打断当前技能（霸体免疫打断）
function EventScheduler.interruptByControl(caster, statusEffectManagerRef)
    local execution = activeSkills[caster]
    if not execution then return end
    
    -- 霸体免疫控制打断
    if statusEffectManagerRef and statusEffectManagerRef.hasEffect(caster, "SuperArmor") then
        return -- 霸体中，技能不被打断
    end
    
    EventScheduler.cancelSkill(caster)
end

return EventScheduler
