-- ==========================================
-- GM_Commands — MCP 测试用后台 GM 命令注册表 (REQ-019)
-- ==========================================
-- 使用 BindableFunction 作为跨上下文桥梁
-- execute_luau (CoreGui上下文) 无法直接 require 客户端模块的缓存实例
-- 但可以通过 BindableFunction:Invoke() 跨上下文调用
--
-- 用法 (在 execute_luau 中):
--   local bf = game.Players:GetPlayers()[1].PlayerScripts.Modules:FindFirstChild("GM_ForceHeroConfirm")
--   bf:Invoke("LianPo")  -- 或 bf:Invoke() 默认使用 LianPo
--
-- 或使用快捷方式:
--   local mods = game.Players:GetPlayers()[1].PlayerScripts.Modules
--   mods:WaitForChild("GM_ForceHeroConfirm", 5):Invoke()
-- ==========================================

local GM_Commands = {}
local commands = {}

local playerScripts = script.Parent -- Modules 的父级是 PlayerScripts

--- 注册一个 GM 命令
--- 创建 BindableFunction 挂载在 PlayerScripts 下，名为 "GM_<name>"
function GM_Commands._register(name, fn)
	commands[name] = fn
	GM_Commands[name] = fn

	-- 创建 BindableFunction 桥梁
	local bfName = "GM_" .. name
	-- 清理旧的（重载时）
	local existing = playerScripts:FindFirstChild(bfName)
	if existing then existing:Destroy() end

	local bf = Instance.new("BindableFunction")
	bf.Name = bfName
	bf.OnInvoke = function(...)
		return fn(...)
	end
	bf.Parent = playerScripts

	print("[GM_Commands] Registered:", bfName)
end

--- 列出所有已注册的 GM 命令
function GM_Commands.List()
	local list = {}
	for name, _ in pairs(commands) do
		table.insert(list, name)
	end
	return list
end

return GM_Commands
