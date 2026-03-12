local CameraManager = {}

local RunService = game:GetService("RunService")
local camera = workspace.CurrentCamera

-- 配置参数
local CAMERA_HEIGHT = 30
local CAMERA_DEPTH = 20

-- 【优化 1】：把固定的偏移量在开机前就算好，死循环里直接用这个常数！
local CAMERA_OFFSET = Vector3.new(0, CAMERA_HEIGHT, CAMERA_DEPTH)

-- 状态变量
local targetCharacter = nil
local targetRootPart = nil -- 【优化 2】：新增一个变量，专门用来存演员的"躯干"
local updateConnection = nil
local isPaused = false

function CameraManager.SetSpaceLock(isLocked)
end

function CameraManager.SetPaused(paused)
	isPaused = paused
end

function CameraManager.IsPaused()
	return isPaused
end

function CameraManager.Init(character)
	targetCharacter = character

	-- 【优化 2】：找一次就够了！把它死死攥在手里（缓存起来）
	targetRootPart = character:WaitForChild("HumanoidRootPart")

	local cameraLookTarget = targetRootPart.Position
	camera.CameraType = Enum.CameraType.Scriptable

	-- 【优化 1】：这里直接加上 CAMERA_OFFSET
	camera.CFrame = CFrame.new(cameraLookTarget + CAMERA_OFFSET, cameraLookTarget)

	if updateConnection then
		updateConnection:Disconnect()
	end

	updateConnection = RunService.RenderStepped:Connect(function(deltaTime)
		CameraManager.Update(deltaTime)
	end)
end

function CameraManager.Update(deltaTime)
	if isPaused then return end

	if camera.CameraType ~= Enum.CameraType.Scriptable then
		camera.CameraType = Enum.CameraType.Scriptable
	end

	-- 【优化 2】：现在不需要用 FindFirstChild 查户口了！
	-- 只需要判断 targetRootPart 还在不在（是不是被删除了）
	if not targetRootPart or not targetRootPart.Parent then
		return
	end

	local cameraLookTarget = targetRootPart.Position

	-- 【优化 1 & 2】：没有任何新建对象的运算，纯粹的极速读取！
	camera.CFrame = CFrame.new(cameraLookTarget + CAMERA_OFFSET, cameraLookTarget)
end

return CameraManager