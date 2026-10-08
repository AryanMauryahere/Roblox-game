-- New script created by Ropilot
-- Replace this with your code
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Debris = game:GetService("Debris")
local player = Players.LocalPlayer
local package = ReplicatedStorage:WaitForChild("SurvivalWeapon")
local Config = require(package:WaitForChild("Config"))
local remote = package:WaitForChild("Action")
local hud = player:WaitForChild("PlayerGui"):WaitForChild("SurvivalWeaponHUD")
local panel = hud:WaitForChild("Panel")
local reticle = hud:WaitForChild("Reticle")
local ammo = panel:WaitForChild("Ammo")
local status = panel:WaitForChild("Status")
local reloadTrack = panel:WaitForChild("ReloadTrack")
local controls = panel:WaitForChild("Controls")
local aiming = false
local localCooldown = 0
local notice = ""
local noticeUntil = 0
local hitUntil = 0
local cameraActive = false
local cameraYaw = 0
local cameraPitch = 0
local stick = Vector2.zero
local touchDelta = Vector2.zero
local lookTouch
local currentHumanoid
local originalOffset
local originalAutoRotate
local originalMouseIcon = UserInputService.MouseIconEnabled
local originalMouseBehavior = UserInputService.MouseBehavior
local cameraStates = {}
local poseCaches = {}
local connections = {}
local nextVehicleInput = 0

local function inform(message)
	notice = message
	noticeUntil = os.clock() + 1.8
end
local function alive()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return humanoid and humanoid.Health > 0 and root ~= nil, humanoid, root
end
local function armed()
	return player:GetAttribute("WeaponArmed") == true
end
local function reloading()
	return player:GetAttribute("WeaponReloading") == true
end
local function seated()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return player:GetAttribute("DrivingCourierVan") == true
		or (humanoid and (humanoid.SeatPart ~= nil or humanoid.Sit))
end
local function canInput()
	return not UserInputService:GetFocusedTextBox() and not GuiService.MenuIsOpen
end
local function restoreCamera()
	if not cameraActive then return end
	cameraActive = false
	aiming = false
	UserInputService.MouseBehavior = originalMouseBehavior
	UserInputService.MouseIconEnabled = originalMouseIcon
	if currentHumanoid and currentHumanoid.Parent then
		currentHumanoid.CameraOffset = originalOffset
		currentHumanoid.AutoRotate = originalAutoRotate
	end
	for camera, state in pairs(cameraStates) do
		if camera.Parent then
			camera.FieldOfView = state.fov
			camera.CameraType = state.cameraType
		end
	end
	table.clear(cameraStates)
end
local function action(name, state, input)
	-- Let VehicleSeat own the movement/gamepad controls while driving.
	if seated() then aiming = false return Enum.ContextActionResult.Pass end
	if not canInput() then return Enum.ContextActionResult.Pass end
	local living = alive()
	if not living then return Enum.ContextActionResult.Pass end
	if name == "WeaponHolster" then
		if state == Enum.UserInputState.Begin then
			aiming = false
			remote:FireServer("Holster")
		end
		return Enum.ContextActionResult.Sink
	end
	if not armed() then return Enum.ContextActionResult.Pass end
	if name == "WeaponAim" then
		if input.UserInputType == Enum.UserInputType.Touch then
			if state == Enum.UserInputState.Begin then aiming = not aiming end
		else
			aiming = state == Enum.UserInputState.Begin
		end
	elseif state == Enum.UserInputState.Begin then
		if name == "WeaponReload" then
			remote:FireServer("Reload")
		elseif name == "WeaponFire" then
			if reloading() then inform("RELOADING â€” WAIT") return Enum.ContextActionResult.Sink end
			if not aiming then inform("AIM BEFORE FIRING") return Enum.ContextActionResult.Sink end
			local now = os.clock()
			if now < localCooldown then return Enum.ContextActionResult.Sink end
			local camera = workspace.CurrentCamera
			if camera then
				localCooldown = now + Config.ShotInterval
				remote:FireServer("Fire", camera.CFrame.Position, camera.CFrame.LookVector)
			end
		end
	end
	return Enum.ContextActionResult.Sink
end
ContextActionService:BindAction("WeaponAim", action, true, Enum.UserInputType.MouseButton2, Enum.KeyCode.ButtonL2)
ContextActionService:BindAction("WeaponFire", action, true, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)
ContextActionService:BindAction("WeaponReload", action, true, Enum.KeyCode.R, Enum.KeyCode.ButtonY)
ContextActionService:BindAction("WeaponHolster", action, true, Enum.KeyCode.V, Enum.KeyCode.DPadDown)
for name, info in pairs({
	WeaponAim = {"Aim", Vector2.new(0.58, 0.48)},
	WeaponFire = {"Fire", Vector2.new(0.81, 0.48)},
	WeaponReload = {"Reload", Vector2.new(0.58, 0.73)},
	WeaponHolster = {"Holster", Vector2.new(0.4, 0.73)},
}) do
	ContextActionService:SetTitle(name, info[1])
	ContextActionService:SetPosition(name, UDim2.fromScale(info[2].X, info[2].Y))
end
table.insert(connections, UserInputService.WindowFocusReleased:Connect(function() aiming = false end))
table.insert(connections, GuiService.MenuOpened:Connect(function() aiming = false end))
table.insert(connections, UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.UserInputType == Enum.UserInputType.Touch then
		local camera = workspace.CurrentCamera
		if camera and input.Position.X > camera.ViewportSize.X * 0.4 then
			lookTouch = input
		end
	end
end))
table.insert(connections, UserInputService.InputChanged:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.Thumbstick2 then
		local raw = Vector2.new(input.Position.X,input.Position.Y)
		stick = raw.Magnitude > 0.15 and raw or Vector2.zero
	elseif input == lookTouch then
		touchDelta = touchDelta + Vector2.new(input.Delta.X,input.Delta.Y)
	end
end))
table.insert(connections, UserInputService.InputEnded:Connect(function(input)
	if input == lookTouch then lookTouch = nil end
	if input.KeyCode == Enum.KeyCode.Thumbstick2 then stick = Vector2.zero end
end))

local function updateLabels()
	local magazine = player:GetAttribute("WeaponMagazine") or 0
	local reserve = player:GetAttribute("WeaponReserve") or 0
	ammo.Text = string.format("%02d  /  %02d SPARE", magazine, reserve)
	ammo.TextColor3 = magazine == 0 and Color3.fromRGB(222,132,121) or Color3.fromRGB(223,229,236)
end
for _, attribute in ipairs({"WeaponMagazine","WeaponReserve"}) do
	table.insert(connections, player:GetAttributeChangedSignal(attribute):Connect(updateLabels))
end
updateLabels()
local function updateControls()
	if seated() then
		if UserInputService.PreferredInput == Enum.PreferredInput.Touch then
			controls.Text = "MOVEMENT STICK: DRIVE / STEER  |  JUMP: GET OUT"
		elseif UserInputService.PreferredInput == Enum.PreferredInput.Gamepad then
			controls.Text = "LEFT STICK: DRIVE / STEER  |  A OR X: GET OUT"
		else
			controls.Text = "W/S: DRIVE / REVERSE  |  A/D: STEER  |  SPACE/E: GET OUT"
		end
		return
	end
	if UserInputService.PreferredInput == Enum.PreferredInput.Touch then
		controls.Text = "TAP AIM TO TOGGLE  â€¢  FIRE  â€¢  RELOAD"
	elseif UserInputService.PreferredInput == Enum.PreferredInput.Gamepad then
		controls.Text = "LT AIM  â€¢  RT FIRE  â€¢  Y RELOAD  â€¢  â†“ HOLSTER"
	else
		controls.Text = "RMB AIM  â€¢  LMB FIRE  â€¢  R RELOAD  â€¢  V HOLSTER"
	end
end
updateControls()
table.insert(connections, UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(updateControls))
table.insert(connections, player:GetAttributeChangedSignal("DrivingCourierVan"):Connect(updateControls))

-- Shoulder camera sweeps a small sphere from the character to prevent wall clipping.
RunService:BindToRenderStep("SurvivalShoulderCamera", Enum.RenderPriority.Camera.Value, function(dt)
	local living, humanoid, root = alive()
	local camera = workspace.CurrentCamera
	if not armed() or not living or not camera or seated() then
		restoreCamera()
		reticle.Visible = false
		touchDelta = Vector2.zero
		return
	end
	if not cameraActive or currentHumanoid ~= humanoid then
		restoreCamera()
		cameraActive = true
		currentHumanoid = humanoid
		originalOffset = humanoid.CameraOffset
		originalAutoRotate = humanoid.AutoRotate
		local look = camera.CFrame.LookVector
		cameraYaw = math.atan2(-look.X, -look.Z)
		cameraPitch = math.asin(math.clamp(look.Y,-1,1))
	end
	if not cameraStates[camera] then
		cameraStates[camera] = {fov = camera.FieldOfView, cameraType = camera.CameraType}
	end
	camera.CameraType = Enum.CameraType.Scriptable
	humanoid.AutoRotate = false
	if canInput() then
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		UserInputService.MouseIconEnabled = false
		local delta = UserInputService:GetMouseDelta() + touchDelta
		cameraYaw = cameraYaw - delta.X * Config.MouseSensitivity
			- stick.X * Config.GamepadSensitivity * dt
		cameraPitch = math.clamp(cameraPitch - delta.Y * Config.MouseSensitivity
			+ stick.Y * Config.GamepadSensitivity * dt, math.rad(-65), math.rad(65))
	else
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
	end
	touchDelta = Vector2.zero
	local rotation = CFrame.Angles(0,cameraYaw,0) * CFrame.Angles(cameraPitch,0,0)
	local offset = aiming and Config.AimCameraOffset or Config.CameraOffset
	local focus = root.Position + Vector3.new(0,1.5,0)
	local desired = focus + rotation.RightVector * offset.X + Vector3.new(0,offset.Y,0)
		+ rotation.ZVector * Config.CameraDistance
	local cast = desired - focus
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {player.Character}
	local hit = workspace:Spherecast(focus, Config.CameraCollisionRadius, cast, params)
	local position = hit and focus + cast.Unit * math.max(0,hit.Distance-0.1) or desired
	camera.CFrame = CFrame.new(position) * rotation
	camera.Focus = CFrame.new(focus)
	root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0,cameraYaw,0)
	local fov = aiming and Config.AimFieldOfView or Config.FieldOfView
	camera.FieldOfView = camera.FieldOfView + (fov - camera.FieldOfView) * (1 - math.exp(-8 * dt))
	local now = workspace:GetServerTimeNow()
	local velocity = root.AssemblyLinearVelocity
	local speed = Vector3.new(velocity.X,0,velocity.Z).Magnitude
	local direction = Config.ShotDirection(camera.CFrame.LookVector, now, speed)
	local screen, onScreen = camera:WorldToViewportPoint(camera.CFrame.Position + direction * 100)
	reticle.Position = UDim2.fromOffset(screen.X, screen.Y)
	reticle.Visible = aiming and not reloading() and onScreen and canInput()
	reticle.Text = os.clock() < hitUntil and "Ã—" or "+"
	reticle.TextColor3 = os.clock() < hitUntil and Color3.fromRGB(233,160,135) or Color3.fromRGB(231,235,238)
end)

local function reloadPose(progress)
	local keys = Config.ReloadPoses
	for i = 2, #keys do
		if progress <= keys[i][1] then
			local a, b = keys[i-1], keys[i]
			local t = math.clamp((progress-a[1])/(b[1]-a[1]),0,1)
			t = t*t*(3-2*t)
			local right, left = {}, {}
			for k = 1,6 do
				right[k] = a[2][k] + (b[2][k]-a[2][k])*t
				left[k] = a[3][k] + (b[3][k]-a[3][k])*t
			end
			return right, left
		end
	end
	return keys[#keys][2], keys[#keys][3]
end
local function restorePose(cache)
	for motor, base in pairs(cache.bases) do
		if motor.Parent then motor.C0 = base motor.Transform = CFrame.identity end
	end
	cache.active = false
	cache.lastTransforms = nil
	cache.blendFrom = nil
	cache.usingReloadTrack = nil
end
local function getPose(character)
	local cache = poseCaches[character]
	if cache then return cache end
	cache = {bases = {}, motors = {}, active = false}
	for _, item in ipairs(character:GetDescendants()) do
		if item:IsA("Motor6D") and (
			item.Name == "RightShoulder" or item.Name == "LeftShoulder"
			or item.Name == "RightElbow" or item.Name == "LeftElbow"
			or item.Name == "RightWrist" or item.Name == "LeftWrist"
			or item.Name == "Right Shoulder" or item.Name == "Left Shoulder"
			or item.Name == "MagazineJoint"
		) then
			cache.motors[item.Name] = item
			cache.bases[item] = item.C0
		end
	end
	-- Don't cache a partially streamed character.
	if not cache.motors.RightShoulder and not cache.motors["Right Shoulder"] then return nil end
	if cache.motors.RightShoulder and not (
		cache.motors.LeftShoulder and cache.motors.RightElbow and cache.motors.LeftElbow
		and cache.motors.RightWrist and cache.motors.LeftWrist
	) then return nil end
	if not cache.motors.MagazineJoint then return nil end
	poseCaches[character] = cache
	return cache
end
local function joint(cache, name, x, y, z)
	local motor = cache.motors[name]
	if not motor then return end
	local base = cache.bases[motor]
	local target = base:Inverse() * CFrame.new(base.Position)
		* CFrame.Angles(math.rad(x),math.rad(y),math.rad(z)) * base.Rotation
	motor.C0 = base
	local previous = cache.blendFrom and cache.blendFrom[motor]
	motor.Transform = previous and previous:Lerp(target, cache.blendAlpha) or target
end
-- Animator owns the upper body during a tracked reload. Blend back into aiming afterward.
table.insert(connections, RunService.PreSimulation:Connect(function()
	local now = workspace:GetServerTimeNow()
	for character, cache in pairs(poseCaches) do
		if not character.Parent then
			restorePose(cache)
			poseCaches[character] = nil
		end
	end
	for _, owner in ipairs(Players:GetPlayers()) do
		local character = owner.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if character and humanoid and root then
			local cache = getPose(character)
			if cache then
				if owner:GetAttribute("WeaponArmed") and humanoid.Health > 0
					and humanoid.SeatPart == nil and not humanoid.Sit
					and not owner:GetAttribute("DrivingCourierVan") then
					cache.active = true
					local right, left = Config.ReloadPoses[1][2], Config.ReloadPoses[1][3]
					local loading = owner:GetAttribute("WeaponReloading")
					local usingTrack = loading and owner:GetAttribute("WeaponReloadUsesTrack") == true
					if cache.usingReloadTrack ~= usingTrack then
						cache.usingReloadTrack = usingTrack
						cache.blendFrom = cache.lastTransforms
						cache.blendStart = now
					end
					cache.blendAlpha = math.clamp((now - (cache.blendStart or now)) / Config.ReloadBlendSeconds, 0, 1)
					local progress = 0
					if loading then
						progress = 1 - ((owner:GetAttribute("WeaponReloadEnd") or now) - now)/Config.ReloadSeconds
						if not usingTrack then right, left = reloadPose(math.clamp(progress,0,1)) end
					end
					local magazineMotor = cache.motors.MagazineJoint
					local withdrawal = 0
					if loading then
						if progress < 0.36 then
							withdrawal = math.clamp((progress-0.2)/0.16,0,1)*0.7
						elseif progress < 0.5 then
							withdrawal = 0.7
						elseif progress < 0.65 then
							withdrawal = 0.7-(progress-0.5)/0.15*0.55
						elseif progress < 0.73 then
							withdrawal = 0.15+(progress-0.65)/0.08*0.15
						else
							withdrawal = math.max(0,0.3-(progress-0.73)/0.1*0.3)
						end
					end
					magazineMotor.C0 = cache.bases[magazineMotor] * CFrame.new(0,-withdrawal,0)
					magazineMotor.Transform = CFrame.identity
					if usingTrack then
						for motor, base in pairs(cache.bases) do
							if motor ~= magazineMotor then
								motor.C0 = base
								local previous = cache.blendFrom and cache.blendFrom[motor]
								if previous and cache.blendAlpha < 1 then
									motor.Transform = previous:Lerp(motor.Transform, cache.blendAlpha)
								end
							end
						end
					else
					local velocity = root.AssemblyLinearVelocity
					local speed = Vector3.new(velocity.X,0,velocity.Z).Magnitude
					local pitch, yaw = Config.Sway(now, speed)
					local age = now - (owner:GetAttribute("WeaponLastShot") or -100)
					local recoil = age >= 0 and age < 0.35 and Config.RecoilDegrees*math.exp(-age*13) or 0
					local aimPitch = 0
					if owner == player and workspace.CurrentCamera and not loading then
						aimPitch = math.deg(math.asin(math.clamp(workspace.CurrentCamera.CFrame.LookVector.Y,-1,1)))
					end
					local extra = loading and 0 or math.deg(pitch) + aimPitch + recoil
					local sideSway = loading and 0 or math.deg(yaw)
					joint(cache, cache.motors.RightShoulder and "RightShoulder" or "Right Shoulder",
						right[1]+extra,right[2]+sideSway,right[3])
					joint(cache, "RightElbow",right[4],0,0)
					joint(cache, "RightWrist",right[5],0,right[6])
					joint(cache, cache.motors.LeftShoulder and "LeftShoulder" or "Left Shoulder",
						left[1]+extra,left[2]+sideSway,left[3])
					joint(cache, "LeftElbow",left[4],0,0)
					joint(cache, "LeftWrist",left[5],0,left[6])
					end
					cache.lastTransforms = {}
					for motor in pairs(cache.bases) do
						if motor ~= magazineMotor then cache.lastTransforms[motor] = motor.Transform end
					end
				elseif cache.active then restorePose(cache) end
			end
		end
	end
end))

table.insert(connections, RunService.Heartbeat:Connect(function()
	local now = workspace:GetServerTimeNow()
	local loading = reloading()
	local driving = seated()
	if driving and os.clock() >= nextVehicleInput then
		nextVehicleInput = os.clock() + 1 / 15
		local _, humanoid = alive()
		local seat = humanoid and humanoid.SeatPart
		local vehicleInput = seat and seat:FindFirstChild("CourierDriveInput")
		if seat and seat:IsA("VehicleSeat") and vehicleInput and vehicleInput:IsA("RemoteEvent") then
			vehicleInput:FireServer(canInput() and seat.ThrottleFloat or 0, canInput() and seat.SteerFloat or 0)
		end
	end
	for _, name in ipairs({"WeaponAim", "WeaponFire", "WeaponReload", "WeaponHolster"}) do
		local button = ContextActionService:GetButton(name)
		if button then button.Visible = not driving end
	end
	reloadTrack.Visible = loading and not driving
	if driving then
		status.Text = player:GetAttribute("CourtyardDriving") and "COURTYARD CAR  /  RACCOON CITY" or "DRIVING TO THE TUNNEL"
	elseif loading then
		local remaining = math.max(0,(player:GetAttribute("WeaponReloadEnd") or now)-now)
		local progress = math.clamp(1-remaining/Config.ReloadSeconds,0,1)
		reloadTrack.Fill.Size = UDim2.fromScale(progress,1)
		local stage = progress < 0.3 and "LOWERING WEAPON"
			or progress < 0.55 and "FUMBLING MAGAZINE"
			or progress < 0.8 and "SEATING MAGAZINE" or "RECOVERING GRIP"
		status.Text = string.format("%s  %.1fs",stage,remaining)
	elseif os.clock() < noticeUntil then
		status.Text = notice
	elseif not armed() then
		status.Text = "HOLSTERED"
	elseif (player:GetAttribute("WeaponMagazine") or 0) == 0 then
		status.Text = (player:GetAttribute("WeaponReserve") or 0) > 0 and "EMPTY â€” RELOAD" or "OUT OF AMMUNITION"
	else
		status.Text = "EVERY ROUND COUNTS"
	end
end))
table.insert(connections, remote.OnClientEvent:Connect(function(event, shooter, start, finish, hit)
	if event == "Notice" then inform(shooter) return end
	if event ~= "Shot" then return end
	local model = shooter.Character and shooter.Character:FindFirstChild("SurvivalPistol")
	local muzzle = model and model:FindFirstChild("Muzzle",true)
	if muzzle and (muzzle.WorldPosition - start).Magnitude < 4 then start = muzzle.WorldPosition end
	local distance = (finish-start).Magnitude
	if distance > 0.01 then
		local tracer = Instance.new("Part")
		tracer.Name = "SurvivalBulletTracer"
		tracer.Anchored = true
		tracer.CanCollide = false
		tracer.CanTouch = false
		tracer.CanQuery = false
		tracer.CastShadow = false
		tracer.Material = Enum.Material.Neon
		tracer.Color = Color3.fromRGB(245,215,160)
		tracer.Transparency = 0.35
		tracer.Size = Vector3.new(0.025,0.025,distance)
		tracer.CFrame = CFrame.lookAt((start+finish)/2,finish)
		tracer.Parent = workspace
		Debris:AddItem(tracer,0.065)
	end
	if muzzle then
		local flash = Instance.new("PointLight")
		flash.Color = Color3.fromRGB(255,209,137)
		flash.Brightness = 4
		flash.Range = 9
		flash.Parent = muzzle
		Debris:AddItem(flash,0.07)
	end
	if shooter == player and hit then hitUntil = os.clock()+0.25 end
end))
script.Destroying:Connect(function()
	restoreCamera()
	RunService:UnbindFromRenderStep("SurvivalShoulderCamera")
	for _, name in ipairs({"WeaponAim","WeaponFire","WeaponReload","WeaponHolster"}) do
		ContextActionService:UnbindAction(name)
	end
	for _, connection in ipairs(connections) do connection:Disconnect() end
	for _, cache in pairs(poseCaches) do restorePose(cache) end
	hud.Enabled = false
end)
