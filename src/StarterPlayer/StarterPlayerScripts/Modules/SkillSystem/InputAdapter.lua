-- InputAdapter: 输入适配层
-- 路径: StarterPlayerScripts/Modules/SkillSystem/InputAdapter.lua
-- 职责: 追踪同一根手指（或鼠标按下）从 Down → Drag → Up 的完整生命周期

local UserInputService = game:GetService("UserInputService")

local InputAdapter = {}
InputAdapter.__index = InputAdapter

function InputAdapter.new()
	local self = setmetatable({}, InputAdapter)

	-- 回调（由 SkillButtonManager 设置）
	self.onInputBegan   = nil  -- function(screenPos: Vector2)
	self.onInputChanged = nil  -- function(screenPos: Vector2)
	self.onInputEnded   = nil  -- function(screenPos: Vector2)

	-- 内部状态
	self._activeInput = nil    -- 当前追踪的 InputObject 引用
	self._connections = {}     -- RBXScriptConnection 数组

	return self
end

-- Start: 注册全局输入监听（游戏开始时调用一次）
function InputAdapter:Start()
	-- 追踪 InputChanged（手指/鼠标移动）
	-- 重要: PC 鼠标场景下, InputChanged 收到的是 MouseMovement 类型的 InputObject,
	-- 与 BeginTracking 存的 MouseButton1 InputObject 是不同对象。
	-- 因此对鼠标不能用引用比较,改为: 只要正在追踪(activeInput ~= nil) + 是鼠标移动就分发。
	-- 触屏场景下仍用引用比较(同一根手指的 Touch InputObject 保持一致)。
	local changedConn = UserInputService.InputChanged:Connect(function(inputObject, gameProcessed)
		if not self._activeInput then return end

		if inputObject.UserInputType == Enum.UserInputType.Touch then
			-- 触屏: 必须是同一根手指
			if inputObject ~= self._activeInput then return end
			if self.onInputChanged then
				self.onInputChanged(Vector2.new(
					inputObject.Position.X,
					inputObject.Position.Y
				))
			end
		elseif inputObject.UserInputType == Enum.UserInputType.MouseMovement then
			-- PC 鼠标: 正在追踪 MouseButton1 时, 接受 MouseMovement 事件
			if self._activeInput.UserInputType == Enum.UserInputType.MouseButton1 then
				if self.onInputChanged then
					self.onInputChanged(Vector2.new(
						inputObject.Position.X,
						inputObject.Position.Y
					))
				end
			end
		end
	end)
	table.insert(self._connections, changedConn)

	-- 追踪 InputEnded（手指抬起/鼠标松开）
	local endedConn = UserInputService.InputEnded:Connect(function(inputObject, gameProcessed)
		if inputObject ~= self._activeInput then return end

		self._activeInput = nil

		if self.onInputEnded then
			self.onInputEnded(Vector2.new(
				inputObject.Position.X,
				inputObject.Position.Y
			))
		end
	end)
	table.insert(self._connections, endedConn)
end

-- BeginTracking: 开始追踪指定 InputObject
-- 由 SkillButtonManager 在按钮 InputBegan 时调用
function InputAdapter:BeginTracking(inputObject)
	self._activeInput = inputObject
	if self.onInputBegan then
		self.onInputBegan(Vector2.new(
			inputObject.Position.X,
			inputObject.Position.Y
		))
	end
end

-- IsTracking: 当前是否在追踪
function InputAdapter:IsTracking()
	return self._activeInput ~= nil
end

-- CancelTracking: 强制取消追踪
function InputAdapter:CancelTracking()
	self._activeInput = nil
end

-- Destroy: 清理所有连接
function InputAdapter:Destroy()
	for _, conn in ipairs(self._connections) do
		conn:Disconnect()
	end
	self._connections = {}
	self._activeInput = nil
end

return InputAdapter
