-- ==========================================
-- LightingSetup.server.lua
-- 职责: 设置场景光照参数, 防止过曝
-- ==========================================
local Lighting = game:GetService("Lighting")

-- 基础光照参数
Lighting.Brightness = 1                                    -- 太阳亮度(默认2太亮)
Lighting.Ambient = Color3.fromRGB(0, 0, 0)                -- 室内环境光
Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 140)   -- 室外环境光(降低)
Lighting.ClockTime = 14                                    -- 下午2点
Lighting.ExposureCompensation = 0                          -- 曝光补偿归零(默认0.4太亮)
Lighting.EnvironmentDiffuseScale = 0.5                     -- 环境漫反射减半
Lighting.EnvironmentSpecularScale = 0.5                    -- 环境高光反射减半
Lighting.GlobalShadows = true                              -- 保留全局阴影
Lighting.ColorShift_Top = Color3.fromRGB(0, 0, 0)         -- 无色偏
Lighting.ColorShift_Bottom = Color3.fromRGB(0, 0, 0)      -- 无色偏
