--[[
	SkillPresenter - Runtime module for skill presentation
	Reads data exported by Skill Editor plugin
	Drives: Animation, VFX events, Sound events, Cancel system

	Usage in Skill_XXXX:

	local SkillPresenter = require(ServerModules.SkillPresenter)
	local data = require(ReplicatedStorage.SkillEditorData.MySkill)

	function MySkill:OnCast(player, targetPos)
		SkillPresenter.Execute(player, data, {
			onCast = function()
				-- your damage/effect logic
			end,
			onCancel = function()
				-- cleanup if interrupted during pre-cast
			end,
		})
	end
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local SkillPresenter = {}

-- Active presentations (for cancel/interrupt)
local activePresentations = {} -- [player] = {cancelled, animTracks, thread}

--[[
	Execute a skill presentation
	@param player - the casting player
	@param data - exported ModuleScript data (module.Animations, module.VFX, module.Sounds, module.Camera)
	@param callbacks - {onCast, onCancel, onEnd}
	@return presentation handle
]]
function SkillPresenter.Execute(player, data, callbacks)
	local character = player.Character
	if not character then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	local animator = humanoid:FindFirstChildOfClass("Animator")

	callbacks = callbacks or {}

	-- Cancel any existing presentation for this player
	SkillPresenter.Cancel(player)

	local presentation = {
		cancelled = false,
		animTracks = {},
		canAct = false, -- true after cancelPoint
	}
	activePresentations[player] = presentation

	-- Main execution thread
	presentation.thread = task.spawn(function()
		local startTime = tick()

		-- ---- ANIMATIONS ----
		if data.Animations and animator then
			for _, animData in ipairs(data.Animations) do
				task.delay(animData.time, function()
					if presentation.cancelled then return end

					-- Load and play animation
					local anim = Instance.new("Animation")
					anim.AnimationId = animData.animId
					local ok, track = pcall(function()
						return animator:LoadAnimation(anim)
					end)
					if not ok or not track then return end

					track:Play()
					track:AdjustSpeed(animData.speed or 1)
					table.insert(presentation.animTracks, track)

					-- Cast point: fire damage/effect callback
					if animData.castPoint and callbacks.onCast then
						task.delay(animData.castPoint / (animData.speed or 1), function()
							if not presentation.cancelled then
								callbacks.onCast()
							end
						end)
					end

					-- Cancel point: allow next action
					if animData.cancelPoint then
						task.delay(animData.cancelPoint / (animData.speed or 1), function()
							presentation.canAct = true
						end)
					end

					-- Auto stop after duration
					local realDur = (animData.duration or 1) / (animData.speed or 1)
					task.delay(realDur, function()
						if track.IsPlaying then
							track:Stop(0.2)
						end
					end)
				end)
			end
		end

		-- ---- VFX (fire to client) ----
		if data.VFX then
			local vfxEvent = ReplicatedStorage:FindFirstChild("SkillVFXEvent")
			if not vfxEvent then
				vfxEvent = Instance.new("RemoteEvent")
				vfxEvent.Name = "SkillVFXEvent"
				vfxEvent.Parent = ReplicatedStorage
			end
			for _, vfx in ipairs(data.VFX) do
				task.delay(vfx.time, function()
					if presentation.cancelled then return end
					vfxEvent:FireClient(player, vfx)
				end)
			end
		end

		-- ---- SOUNDS (fire to client) ----
		if data.Sounds then
			local sndEvent = ReplicatedStorage:FindFirstChild("SkillSoundEvent")
			if not sndEvent then
				sndEvent = Instance.new("RemoteEvent")
				sndEvent.Name = "SkillSoundEvent"
				sndEvent.Parent = ReplicatedStorage
			end
			for _, snd in ipairs(data.Sounds) do
				task.delay(snd.time, function()
					if presentation.cancelled then return end
					sndEvent:FireClient(player, snd)
				end)
			end
		end

		-- ---- CAMERA (fire to client for cinematic) ----
		if data.Camera and #data.Camera >= 2 then
			local camEvent = ReplicatedStorage:FindFirstChild("SkillCameraEvent")
			if not camEvent then
				camEvent = Instance.new("RemoteEvent")
				camEvent.Name = "SkillCameraEvent"
				camEvent.Parent = ReplicatedStorage
			end
			camEvent:FireClient(player, data.Camera)
		end

		-- ---- Wait for completion ----
		local maxTime = 0
		if data.Animations then
			for _, a in ipairs(data.Animations) do
				local endT = a.time + (a.duration or 1) / (a.speed or 1)
				if endT > maxTime then maxTime = endT end
			end
		end
		if data.VFX then
			for _, v in ipairs(data.VFX) do
				local endT = v.time + (v.duration or 0)
				if endT > maxTime then maxTime = endT end
			end
		end

		task.wait(maxTime + 0.1)

		-- End callback
		if callbacks.onEnd and not presentation.cancelled then
			callbacks.onEnd()
		end

		-- Cleanup
		if activePresentations[player] == presentation then
			activePresentations[player] = nil
		end
	end)

	return presentation
end

-- Cancel current presentation (e.g. player got stunned during pre-cast)
function SkillPresenter.Cancel(player)
	local pres = activePresentations[player]
	if not pres then return end
	pres.cancelled = true
	-- Stop all animation tracks
	for _, track in ipairs(pres.animTracks) do
		if track.IsPlaying then track:Stop(0.1) end
	end
	activePresentations[player] = nil
end

-- Check if player can act (past cancelPoint)
function SkillPresenter.CanAct(player)
	local pres = activePresentations[player]
	if not pres then return true end
	return pres.canAct
end

-- Check if player can be interrupted (during pre-cast of interruptible anim)
function SkillPresenter.CanInterrupt(player)
	local pres = activePresentations[player]
	if not pres then return false end
	return not pres.canAct -- still in pre-cast
end

-- Check if player is in presentation
function SkillPresenter.IsActive(player)
	return activePresentations[player] ~= nil
end

return SkillPresenter