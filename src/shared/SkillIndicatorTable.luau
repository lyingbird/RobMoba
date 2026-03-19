--[[
    SkillIndicatorTable.luau
    技能指示器配置表
    定义各种指示器的形状、颜色、尺寸等参数
    客户端 SkillIndicator 模块根据此表渲染指示器
]]

local SkillIndicatorTable = {
    --============================================================
    -- 箭头型指示器（方向型弹道）
    --============================================================
    arrow_line = {
        type   = "Arrow",
        color  = Color3.fromRGB(100, 200, 255),
        alpha  = 0.4,
        params = {
            length = 20,   -- 指示器长度
            width  = 1.5,  -- 指示器宽度
        },
    },

    arrow_long = {
        type   = "Arrow",
        color  = Color3.fromRGB(255, 180, 50),
        alpha  = 0.35,
        params = {
            length = 50,
            width  = 3.5,
        },
    },

    arrow_dash = {
        type   = "Arrow",
        color  = Color3.fromRGB(100, 180, 255),
        alpha  = 0.4,
        params = {
            length = 25,
            width  = 3.5,
            showArrowHead = true,  -- 显示箭头头部（冲锋方向）
        },
    },

    --============================================================
    -- 圆形指示器（AOE）
    --============================================================
    circle_aoe = {
        type   = "Circle",
        color  = Color3.fromRGB(255, 100, 100),
        alpha  = 0.35,
        params = {
            radius      = 3,     -- 外圈半径
            innerRadius = nil,   -- 内圈半径（可选，后羿W有内外圈）
            innerColor  = Color3.fromRGB(255, 50, 50),
        },
    },

    --============================================================
    -- 扇形指示器（扇形散射）
    --============================================================
    fan_spread = {
        type   = "Fan",
        color  = Color3.fromRGB(180, 100, 255),
        alpha  = 0.35,
        params = {
            range = 15,   -- 射程
            angle = 20,   -- 扇形角度（度）
        },
    },

    --============================================================
    -- 矩形指示器（持续施法区域）
    --============================================================
    rectangle_channel = {
        type   = "Rectangle",
        color  = Color3.fromRGB(150, 180, 255),
        alpha  = 0.3,
        params = {
            length = 12.5,  -- 矩形长度
            width  = 2,     -- 矩形宽度
        },
    },

    --============================================================
    -- 自身圆形指示器（自身为中心AOE）
    --============================================================
    self_aoe = {
        type   = "SelfCircle",
        color  = Color3.fromRGB(100, 200, 100),
        alpha  = 0.3,
        params = {
            radius = 5,
        },
    },

    --============================================================
    -- 持续施法方向型指示器（安琪拉E - 炽热光辉）
    --============================================================
    arrow_channel = {
        type   = "Arrow",
        color  = Color3.fromRGB(220, 120, 255),
        alpha  = 0.35,
        params = {
            length = 12.5,  -- 光束长度
            width  = 3,     -- 光束宽度
        },
    },
}

-- 获取指示器配置
function SkillIndicatorTable.getIndicator(indicatorId: string)
    return SkillIndicatorTable[indicatorId]
end

return SkillIndicatorTable
