--[[
	UI_MatchButton - 右下角匹配按钮
	REQ-004: 大厅模式匹配入口
	状态: idle → matching → matched → hidden
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Theme = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("UITheme"))

local UI_MatchButton = {}

local screenGui = nil
local mainButton = nil
local statusLabel = nil
local currentState = "idle" -- "idle" | "matching" | "matched" | "hidden"

-- ========== 颜色常量 ==========
local COLOR_IDLE = Color3.fromRGB(30, 100, 200)     -- 蓝色
local COLOR_MATCHING = Color3.fromRGB(200, 50, 50)   -- 红色
local COLOR_MATCHED = Color3.fromRGB(200, 170, 30)   -- 金色
local COLOR_DISABLED = Color3.fromRGB(80, 80, 80)    -- 灰色

-- ========== 初始化 ==========
function UI_MatchButton.Init()
	if screenGui then return end

	-- 获取 MatchmakingEvent
	local MatchmakingEvent = ReplicatedStorage:FindFirstChild("MatchmakingEvent")

	-- ScreenGui
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "MatchButtonScreen"
	screenGui.DisplayOrder = 5
	screenGui.ResetOnSpawn = false
	screenGui.Parent = playerGui

	-- 主按钮
	mainButton = Instance.new("TextButton")
	mainButton.Name = "MatchButton"
	mainButton.Size = UDim2.new(0, 160, 0, 50)
	mainButton.Position = UDim2.new(1, -170, 1, -130)
	mainButton.AnchorPoint = Vector2.new(0, 0)
	mainButton.BackgroundColor3 = COLOR_IDLE
	mainButton.BorderSizePixel = 0
	mainButton.Text = "⚔️ 开始匹配"
	mainButton.TextColor3 = Color3.new(1, 1, 1)
	mainButton.TextSize = 18
	mainButton.Font = Enum.Font.GothamBold
	mainButton.Parent = screenGui
	Theme.corner(mainButton, 10)
	Theme.shadow(mainButton, 4, 16)

	-- 状态文字 (按钮下方)
	statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "StatusLabel"
	statusLabel.Size = UDim2.new(0, 160, 0, 20)
	statusLabel.Position = UDim2.new(1, -170, 1, -76)
	statusLabel.AnchorPoint = Vector2.new(0, 0)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Text = ""
	statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	statusLabel.TextSize = 12
	statusLabel.Font = Enum.Font.GothamMedium
	statusLabel.Parent = screenGui

	-- 点击事件
	mainButton.MouseButton1Click:Connect(function()
		if not MatchmakingEvent then
			MatchmakingEvent = ReplicatedStorage:FindFirstChild("MatchmakingEvent")
		end
		if not MatchmakingEvent then return end

		if currentState == "idle" then
			MatchmakingEvent:FireServer({ action = "join" })
			UI_MatchButton.SetState("matching")
		elseif currentState == "matching" then
			MatchmakingEvent:FireServer({ action = "leave" })
			UI_MatchButton.SetState("idle")
		end
		-- matched/hidden 状态不响应点击
	end)

	-- 监听服务端匹配状态
	if MatchmakingEvent then
		MatchmakingEvent.OnClientEvent:Connect(function(data)
			if not data then return end

			if data.status == "queued" then
				UI_MatchButton.SetState("matching")
				UI_MatchButton.UpdateQueueInfo(data.queueSize or 0)
			elseif data.status == "cancelled" then
				UI_MatchButton.SetState("idle")
				if data.message then
					statusLabel.Text = data.message
					task.delay(3, function()
						if statusLabel and currentState == "idle" then
							statusLabel.Text = ""
						end
					end)
				end
			elseif data.status == "matched" then
				UI_MatchButton.SetState("matched")
			end
		end)
	end

	-- 监听 DuelEvent 隐藏/显示
	local DuelEvent = ReplicatedStorage:FindFirstChild("DuelEvent")
	if DuelEvent then
		DuelEvent.OnClientEvent:Connect(function(data)
			if not data or not data.type then return end

			if data.type == "start" then
				UI_MatchButton.SetVisible(false)
			elseif data.type == "result" then
				-- 对决结束，延迟后重新显示
				task.delay(5, function()
					UI_MatchButton.SetState("idle")
					UI_MatchButton.SetVisible(true)
				end)
			end
		end)
	end

	print("[UI_MatchButton] Initialized")
end

-- ========== 设置状态 ==========
function UI_MatchButton.SetState(state)
	currentState = state

	if not mainButton then return end

	if state == "idle" then
		mainButton.Text = "⚔️ 开始匹配"
		mainButton.BackgroundColor3 = COLOR_IDLE
		mainButton.Active = true
		statusLabel.Text = ""
	elseif state == "matching" then
		mainButton.Text = "❌ 取消匹配"
		mainButton.BackgroundColor3 = COLOR_MATCHING
		mainButton.Active = true
	elseif state == "matched" then
		mainButton.Text = "对手已找到！"
		mainButton.BackgroundColor3 = COLOR_MATCHED
		mainButton.Active = false
		statusLabel.Text = "即将传送..."
	elseif state == "hidden" then
		UI_MatchButton.SetVisible(false)
	end
end

-- ========== 更新队列信息 ==========
function UI_MatchButton.UpdateQueueInfo(queueSize)
	if statusLabel and currentState == "matching" then
		statusLabel.Text = ("匹配中... %d/2"):format(queueSize or 0)
	end
end

-- ========== 显示/隐藏 ==========
function UI_MatchButton.SetVisible(visible)
	if screenGui then
		screenGui.Enabled = visible
	end
end

return UI_MatchButton
