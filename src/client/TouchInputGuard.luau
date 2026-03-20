local TouchInputGuard = {}

local consumedUntil = 0

function TouchInputGuard.consume(duration: number?)
    local window = duration or 0.12
    consumedUntil = math.max(consumedUntil, tick() + window)
end

function TouchInputGuard.isConsumed(): boolean
    return tick() < consumedUntil
end

return TouchInputGuard
