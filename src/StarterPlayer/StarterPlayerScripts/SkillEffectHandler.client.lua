--[[
	SkillEffectHandler - Client-side handler for SkillPresenter RemoteEvents
	Handles: Camera, VFX (flash/shake/blur/colorShift/asset), Sound
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local cam = workspace.CurrentCamera

-- RemoteEvents
local vfxEvent = ReplicatedStorage:WaitForChild("SkillVFXEvent", 5)
local sndEvent = ReplicatedStorage:WaitForChild("SkillSoundEvent", 5)
local camEvent = ReplicatedStorage:WaitForChild("SkillCameraEvent", 5)

-- ===================== CAMERA =====================
if camEvent then
	camEvent.OnClientEvent:Connect(function(cameraData)
		if not cameraData or #cameraData < 2 then return end

		local savedType = cam.CameraType
		cam.CameraType = Enum.CameraType.Scriptable

		for j = 1, #cameraData - 1 do
			local prevKf = cameraData[j]
			local nextKf = cameraData[j + 1]
			local segDur = nextKf.time - prevKf.time
			if segDur <= 0 then continue end

			local style = Enum.EasingStyle[nextKf.easing] or Enum.EasingStyle.Sine
			local dir = Enum.EasingDirection[nextKf.easingDir] or Enum.EasingDirection.InOut

			local startT = tick()
			while true do
				local elapsed = tick() - startT
				if elapsed >= segDur then break end
				local t = elapsed / segDur
				local eased = TweenService:GetValue(t, style, dir)
				cam.CFrame = prevKf.cframe:Lerp(nextKf.cframe, eased)
				cam.FieldOfView = prevKf.fov + (nextKf.fov - prevKf.fov) * eased
				RunService.RenderStepped:Wait()
			end
		end

		-- Set final position
		local last = cameraData[#cameraData]
		cam.CFrame = last.cframe
		cam.FieldOfView = last.fov

		-- Restore after short delay
		task.delay(0.5, function()
			cam.CameraType = savedType
		end)
	end)
end

-- ===================== VFX =====================
if vfxEvent then
	vfxEvent.OnClientEvent:Connect(function(vfxData)
		if not vfxData then return end

		for _, vfx in ipairs(vfxData) do
			task.delay(vfx.time or 0, function()
				if vfx.type == "flash" then
					local cc = Instance.new("ColorCorrectionEffect")
					cc.Name = "_SkillFlash"; cc.Parent = Lighting
					cc.Brightness = vfx.intensity or 1
					local tw = TweenService:Create(cc, TweenInfo.new(vfx.duration or 0.3), {Brightness = 0})
					tw:Play()
					tw.Completed:Once(function() cc:Destroy() end)

				elseif vfx.type == "shake" then
					local int = vfx.intensity or 1
					local dur = vfx.duration or 0.3
					local sStart = tick()
					local conn
					conn = RunService.RenderStepped:Connect(function()
						local e = tick() - sStart
						if e >= dur then conn:Disconnect(); return end
						local decay = 1 - e / dur
						cam.CFrame = cam.CFrame * CFrame.new(
							math.sin(e * 25) * int * decay * 0.1,
							math.cos(e * 32) * int * decay * 0.1, 0)
					end)

				elseif vfx.type == "blur" then
					local blurFx = Instance.new("BlurEffect")
					blurFx.Name = "_SkillBlur"; blurFx.Parent = Lighting
					blurFx.Size = (vfx.intensity or 1) * 20
					local tw = TweenService:Create(blurFx, TweenInfo.new(vfx.duration or 0.3), {Size = 0})
					tw:Play()
					tw.Completed:Once(function() blurFx:Destroy() end)

				elseif vfx.type == "colorShift" then
					local cc = Instance.new("ColorCorrectionEffect")
					cc.Name = "_SkillColor"; cc.Parent = Lighting
					cc.TintColor = Color3.fromRGB(255, 200, 200)
					cc.Saturation = vfx.intensity or 1
					local tw = TweenService:Create(cc, TweenInfo.new(vfx.duration or 0.3), {
						TintColor = Color3.fromRGB(255, 255, 255), Saturation = 0
					})
					tw:Play()
					tw.Completed:Once(function() cc:Destroy() end)

				elseif vfx.type == "asset" and vfx.assetPath then
					-- Resolve asset from path and clone to target
					local parts = string.split(vfx.assetPath, ".")
					local obj = game
					for k = 2, #parts do
						obj = obj:FindFirstChild(parts[k])
						if not obj then break end
					end
					if obj then
						local clone = obj:Clone()
						local char = player.Character
						if char then
							local root = char:FindFirstChild("HumanoidRootPart")
							if root then
								clone.Parent = root
								if clone:IsA("ParticleEmitter") then clone.Enabled = true end
								task.delay(vfx.duration or 1, function()
									if clone:IsA("ParticleEmitter") then
										clone.Enabled = false
										task.delay(clone.Lifetime.Max, function() clone:Destroy() end)
									else
										clone:Destroy()
									end
								end)
							end
						end
					end
				end
			end)
		end
	end)
end

-- ===================== SOUND =====================
if sndEvent then
	sndEvent.OnClientEvent:Connect(function(soundData)
		if not soundData then return end

		for _, snd in ipairs(soundData) do
			task.delay(snd.time or 0, function()
				local s = Instance.new("Sound")
				s.SoundId = snd.soundId or ""
				s.Volume = snd.volume or 1
				s.PlaybackSpeed = snd.pitch or 1
				s.Parent = workspace
				s:Play()
				s.Ended:Once(function() s:Destroy() end)
			end)
		end
	end)
end

print("[SkillEffectHandler] Ready")
