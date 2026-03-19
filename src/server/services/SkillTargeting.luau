local SkillTargeting = {}

function SkillTargeting.normalizeDirection(rawDirection): Vector3
    local direction = rawDirection
    if typeof(direction) ~= "Vector3" then
        direction = Vector3.new(0, 0, -1)
    end

    direction = Vector3.new(direction.X, 0, direction.Z)
    if direction.Magnitude > 0 then
        return direction.Unit
    end

    return Vector3.new(0, 0, -1)
end

function SkillTargeting.normalizeTargetPosition(rawTargetPosition): Vector3?
    if rawTargetPosition and typeof(rawTargetPosition) == "Vector3" then
        return rawTargetPosition
    end
    return nil
end

return SkillTargeting
