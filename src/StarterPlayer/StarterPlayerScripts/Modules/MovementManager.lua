local MovementManager = {}

local player = game.Players.LocalPlayer
local TweenService = game:GetService("TweenService")

-- 初始化角色状态
function MovementManager.Init(character)
	local humanoid = character:WaitForChild("Humanoid")
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)

	-- 封杀系统默认移动 (WASD)
	local PlayerModule = require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))
	local controls = PlayerModule:GetControls()
	controls:Disable()
end

-- ==========================================
-- 【新增】：急停逻辑
-- ==========================================
-- ==========================================
-- MovementManager 核心修复：彻底切断远距离移动
-- ==========================================
function MovementManager.StopMovement()
	local character = player.Character
	local humanoid = character and character:FindFirstChild("Humanoid")
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")

	if humanoid and rootPart then
		-- 技巧 1：将目标点设为当前坐标，彻底注销之前的 MoveTo 路径
		humanoid:MoveTo(rootPart.Position)

		-- 技巧 2：强制切换到空闲状态，防止惯性滑行
		humanoid:Move(Vector3.new(0, 0, 0))
	end
end
-- ==========================================
-- 核心逻辑：生成 MOBA 点击特效
-- ==========================================
function MovementManager.ShowClickEffect(targetPosition)
	local effectPart = Instance.new("Part")
	effectPart.Shape = Enum.PartType.Cylinder
	effectPart.Size = Vector3.new(0.2, 3, 3)
	effectPart.Orientation = Vector3.new(0, 0, 90)
	effectPart.Position = targetPosition + Vector3.new(0, 0.1, 0)

	effectPart.Anchored = true
	effectPart.CanCollide = false
	effectPart.Material = Enum.Material.Neon
	effectPart.Color = Color3.fromRGB(15, 170, 170)
	effectPart.Transparency = 0.3
	effectPart.Parent = workspace

	local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local goal = {
		Size = Vector3.new(0.2, 0, 0),
		Transparency = 1
	}

	local tween = TweenService:Create(effectPart, tweenInfo, goal)
	tween:Play()

	tween.Completed:Connect(function()
		effectPart:Destroy()
	end)
end

-- 执行移动指令
function MovementManager.MoveToPosition(targetPosition)
	local character = player.Character
	if character and character:FindFirstChild("Humanoid") then
		character.Humanoid:MoveTo(targetPosition)
	end
end

return MovementManager