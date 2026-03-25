local Players = game:GetService("Players")
local player = Players.LocalPlayer

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LevelConfig = require(ReplicatedStorage:WaitForChild("LevelConfig"))

local StatsBinding = {}

local connections = {}
local hudRef = nil

local function clearConnections()
	for _, conn in ipairs(connections) do
		conn:Disconnect()
	end
	connections = {}
end

local function updateHP(character)
	if not hudRef then return end
	local hp = character:GetAttribute("HP") or 0
	local maxHP = character:GetAttribute("MaxHP") or 1
	local ratio = math.clamp(hp / maxHP, 0, 1)

	if hudRef.HpFill then
		hudRef.HpFill.Size = UDim2.new(ratio, 0, 1, 0)
	end
	if hudRef.HpText then
		hudRef.HpText.Text = math.floor(hp) .. " / " .. math.floor(maxHP)
	end
end

local function updateMP(character)
	if not hudRef then return end
	local mp = character:GetAttribute("MP") or 0
	local maxMP = character:GetAttribute("MaxMP") or 1
	local ratio = math.clamp(mp / maxMP, 0, 1)

	if hudRef.MpFill then
		hudRef.MpFill.Size = UDim2.new(ratio, 0, 1, 0)
	end
	if hudRef.MpText then
		hudRef.MpText.Text = math.floor(mp) .. " / " .. math.floor(maxMP)
	end
end

local function updateStat(character, statName)
	if not hudRef or not hudRef.StatLabels then return end
	local label = hudRef.StatLabels[statName]
	if not label then return end

	local value = character:GetAttribute(statName)
	if value == nil then return end

	if type(value) == "number" then
		if value == math.floor(value) then
			label.text.Text = label.icon .. tostring(math.floor(value))
		else
			label.text.Text = label.icon .. string.format("%.1f", value)
		end
	end
end

local function bindCharacter(character)
	clearConnections()

	-- Wait for attributes to be set
	local function waitForAttr(name)
		while character:GetAttribute(name) == nil do
			character:GetAttributeChangedSignal(name):Wait()
		end
	end
	waitForAttr("HP")

	updateHP(character)
	updateMP(character)

	-- Bind HP
	table.insert(connections, character:GetAttributeChangedSignal("HP"):Connect(function()
		updateHP(character)
	end))
	table.insert(connections, character:GetAttributeChangedSignal("MaxHP"):Connect(function()
		updateHP(character)
	end))

	-- Bind MP
	table.insert(connections, character:GetAttributeChangedSignal("MP"):Connect(function()
		updateMP(character)
	end))
	table.insert(connections, character:GetAttributeChangedSignal("MaxMP"):Connect(function()
		updateMP(character)
	end))

	-- Bind all combat stats
	local combatStats = {"ATK", "AP", "DEF", "MR", "MoveSpeed", "AtkSpeed", "CritRate", "CritDmg", "CDR", "HpRegen", "MpRegen", "Penetration"}
	for _, statName in ipairs(combatStats) do
		updateStat(character, statName)
		table.insert(connections, character:GetAttributeChangedSignal(statName):Connect(function()
			updateStat(character, statName)
		end))
	end

	-- Bind Level & XP
	local function updateLevelXP()
		if not hudRef then return end
		local level = character:GetAttribute("Level") or 1
		local totalXP = character:GetAttribute("TotalXP") or 0

		if hudRef.LevelText then
			hudRef.LevelText.Text = tostring(level)
		end
		if hudRef.XpFill then
			local progress = LevelConfig.GetLevelProgress(level, totalXP)
			hudRef.XpFill.Size = UDim2.new(progress, 0, 1, 0)
		end
		if hudRef.XpText then
			if level >= LevelConfig.MaxLevel then
				hudRef.XpText.Text = "MAX"
			else
				local currentLevelXP = LevelConfig.XPToLevel[level]
				local nextLevelXP = LevelConfig.XPToLevel[level + 1]
				hudRef.XpText.Text = (totalXP - currentLevelXP) .. "/" .. (nextLevelXP - currentLevelXP)
			end
		end
	end

	updateLevelXP()
	table.insert(connections, character:GetAttributeChangedSignal("Level"):Connect(updateLevelXP))
	table.insert(connections, character:GetAttributeChangedSignal("TotalXP"):Connect(updateLevelXP))
end

function StatsBinding.Init(hud)
	hudRef = hud

	local function onCharacterAdded(character)
		character:WaitForChild("Humanoid")
		task.defer(bindCharacter, character)
	end

	if player.Character then
		onCharacterAdded(player.Character)
	end
	player.CharacterAdded:Connect(onCharacterAdded)
end

-- REQ-014: 移动端属性绑定(绑定到 MobileHUD 而非 PC HUD)
local mobileHUDRef = nil
local mobileConnections = {}

local function clearMobileConnections()
	for _, conn in ipairs(mobileConnections) do
		conn:Disconnect()
	end
	mobileConnections = {}
end

local function bindMobileCharacter(character)
	clearMobileConnections()
	if not mobileHUDRef then return end

	-- 等待属性就绪
	while character:GetAttribute("HP") == nil do
		character:GetAttributeChangedSignal("HP"):Wait()
	end

	-- 初始更新
	local hp = character:GetAttribute("HP") or 0
	local maxHP = character:GetAttribute("MaxHP") or 1
	mobileHUDRef.UpdateHP(hp, maxHP)

	local mp = character:GetAttribute("MP") or 0
	local maxMP = character:GetAttribute("MaxMP") or 1
	mobileHUDRef.UpdateMP(mp, maxMP)

	local level = character:GetAttribute("Level") or 1
	mobileHUDRef.UpdateLevel(level)

	-- HP 绑定
	table.insert(mobileConnections, character:GetAttributeChangedSignal("HP"):Connect(function()
		local h = character:GetAttribute("HP") or 0
		local mh = character:GetAttribute("MaxHP") or 1
		mobileHUDRef.UpdateHP(h, mh)
	end))
	table.insert(mobileConnections, character:GetAttributeChangedSignal("MaxHP"):Connect(function()
		local h = character:GetAttribute("HP") or 0
		local mh = character:GetAttribute("MaxHP") or 1
		mobileHUDRef.UpdateHP(h, mh)
	end))

	-- MP 绑定
	table.insert(mobileConnections, character:GetAttributeChangedSignal("MP"):Connect(function()
		local m = character:GetAttribute("MP") or 0
		local mm = character:GetAttribute("MaxMP") or 1
		mobileHUDRef.UpdateMP(m, mm)
	end))
	table.insert(mobileConnections, character:GetAttributeChangedSignal("MaxMP"):Connect(function()
		local m = character:GetAttribute("MP") or 0
		local mm = character:GetAttribute("MaxMP") or 1
		mobileHUDRef.UpdateMP(m, mm)
	end))

	-- Level 绑定
	table.insert(mobileConnections, character:GetAttributeChangedSignal("Level"):Connect(function()
		local lv = character:GetAttribute("Level") or 1
		mobileHUDRef.UpdateLevel(lv)
	end))
end

function StatsBinding.InitMobile(mobileHUD)
	clearConnections()       -- 清理PC端绑定(如果有)
	clearMobileConnections() -- 清理旧的移动端绑定
	mobileHUDRef = mobileHUD

	local function onMobileCharacterAdded(character)
		character:WaitForChild("Humanoid")
		task.defer(bindMobileCharacter, character)
	end

	if player.Character then
		onMobileCharacterAdded(player.Character)
	end
	table.insert(mobileConnections, player.CharacterAdded:Connect(onMobileCharacterAdded))
end

return StatsBinding
