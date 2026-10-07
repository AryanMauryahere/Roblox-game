-- Server-controlled courier van. The VehicleSeat supplies Roblox's standard
-- keyboard, touch and gamepad controls; a bounded road keeps the story route safe.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Vehicle = {}
local DEFAULTS = {
	RoadCenterX = 97,
	RoadStartZ = 41,
	StopZ = 124,
	GroundY = 0,
	RoadHalfWidth = 8,
	ForwardSpeed = 24,
	ReverseSpeed = 10,
	Acceleration = 14,
	Braking = 24,
	SteeringRate = math.rad(40),
	MaxHeading = math.rad(18),
	VehicleHalfLength = 6.1,
	VehicleHalfWidth = 2.9,
	PromptDistance = 10,
	InputTimeout = 0.6,
}

local function approach(value, target, amount)
	return value < target and math.min(value + amount, target) or math.max(value - amount, target)
end

function Vehicle.Attach(van, config)
	assert(van and van:IsA("Model"), "CourierVehicle.Attach requires the CourierVan model")
	assert(not van:GetAttribute("DrivableCourier"), "CourierVehicle is already attached")
	local settings = table.clone(DEFAULTS)
	for key, value in pairs(config or {}) do settings[key] = value end
	local body = van:FindFirstChild("Body")
	assert(body and body:IsA("BasePart"), "CourierVan.Body is missing")
	local originalFrame = body.CFrame * CFrame.new(1.4, -3.1, 0)
	van.PrimaryPart = body
	van:SetAttribute("DrivableCourier", true)
	van:SetAttribute("ArrivedAtTunnel", false)
	van:SetAttribute("Speed", 0)

	local function makePart(name, size, offset, color)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.CFrame = originalFrame * offset
		part.Color = color or Color3.fromRGB(52, 66, 92)
		part.Material = Enum.Material.Metal
		part.Anchored = true
		part.CanTouch = false
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Parent = van
		return part
	end

	-- The original delivery prop has a solid cab. Open an actual space to sit in.
	local cab = van:FindFirstChild("Cab")
	if cab then
		cab.Transparency = 1
		cab.CanCollide = false
		cab.CanQuery = false
	end
	makePart("CabRoof", Vector3.new(3.6, 0.25, 5.3), CFrame.new(4, 5.15, 0))
	makePart("CabFloor", Vector3.new(3.6, 0.25, 5.2), CFrame.new(4, 0.95, 0))
	makePart("Dashboard", Vector3.new(0.7, 0.6, 4.7), CFrame.new(5.15, 2.0, 0), Color3.fromRGB(26, 28, 32))
	for _, side in ipairs({ -1, 1 }) do
		makePart("CabSide", Vector3.new(3.5, 0.8, 0.18), CFrame.new(4, 1.5, side * 2.5))
		makePart("WindscreenPillar", Vector3.new(0.2, 3.2, 0.2), CFrame.new(5.65, 3.5, side * 2.5))
	end
	local windshield = van:FindFirstChild("Windshield")
	if windshield then windshield.Transparency = 0.45 end

	local seat = Instance.new("VehicleSeat")
	seat.Name = "DriverSeat"
	seat.Size = Vector3.new(1.9, 0.5, 1.9)
	seat.CFrame = originalFrame * CFrame.new(3.6, 1.6, 0) * CFrame.Angles(0, -math.pi / 2, 0)
	seat.Color = Color3.fromRGB(23, 25, 29)
	seat.Material = Enum.Material.Fabric
	seat.Anchored = true
	seat.CanTouch = false -- boarding is gated by the delivery prompt
	seat.CanCollide = true
	seat.HeadsUpDisplay = false
	seat.MaxSpeed = settings.ForwardSpeed
	seat.Torque = 0
	seat.TurnSpeed = 0
	seat.Parent = van
	-- An explicit bridge also works when the anchored seat has no client
	-- physics ownership. The client reads the normal VehicleSeat controls.
	local inputRemote = Instance.new("RemoteEvent")
	inputRemote.Name = "CourierDriveInput"
	inputRemote.Parent = seat

	local entry = makePart("DriverDoor", Vector3.new(0.3, 0.3, 0.3), CFrame.new(3.6, 2.5, -2.8))
	entry.Transparency = 1
	entry.CanCollide = false
	entry.CanQuery = false
	local function addPrompt(parent, action, distance)
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = action == "Drive" and "EnterVan" or "ExitVan"
		prompt.ObjectText = "Courier van"
		prompt.ActionText = action
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
		prompt.MaxActivationDistance = distance
		prompt.RequiresLineOfSight = false
		prompt.HoldDuration = 0
		prompt.Parent = parent
		return prompt
	end
	local enterPrompt = addPrompt(entry, "Drive", settings.PromptDistance)
	local exitPrompt = addPrompt(seat, "Get out", 6)
	exitPrompt.Enabled = false

	local position = Vector3.new(settings.RoadCenterX, settings.GroundY, settings.RoadStartZ)
	local heading, speed = 0, 0
	local inputThrottle, inputSteer, inputAt = 0, 0, 0
	local driver, driverHumanoid, diedConnection
	local arrived, destroyed, releasing = false, false, false
	local connections = {}
	local function pose()
		return CFrame.new(position) * CFrame.Angles(0, -math.pi / 2 + heading, 0)
	end
	local function moveVan()
		van:SetPrimaryPartCFrame(pose() * CFrame.new(-1.4, 3.1, 0))
	end
	moveVan()
	local function notify(player, message, kind)
		if settings.Notify and player and player.Parent then settings.Notify(player, message, kind or "info") end
	end
	local function clearDriver()
		if diedConnection then diedConnection:Disconnect() diedConnection = nil end
		if driver and driver.Parent then driver:SetAttribute("DrivingCourierVan", false) end
		driver, driverHumanoid = nil, nil
		speed = 0
		inputThrottle, inputSteer, inputAt = 0, 0, 0
		van:SetAttribute("Speed", 0)
		enterPrompt.Enabled = not arrived and not destroyed
		exitPrompt.Enabled = false
	end
	local function dismount(atTunnel)
		if releasing then return end
		releasing = true
		local player = driver
		local humanoid = driverHumanoid or seat.Occupant
		local character = humanoid and humanoid.Parent
		clearDriver()
		if humanoid then
			humanoid.Sit = false
			local weld = seat:FindFirstChild("SeatWeld")
			if weld then weld:Destroy() end
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
		if character and character.Parent and humanoid.Health > 0 then
			local exitPosition
			if atTunnel then
				exitPosition = Vector3.new(settings.RoadCenterX - 5, settings.GroundY + 3.5, settings.StopZ + 6.5)
			else
				-- Exit toward the middle of the road when parked near an edge.
				local side = position.X > settings.RoadCenterX and 1 or -1
				exitPosition = pose():PointToWorldSpace(Vector3.new(3.5, 3.5, side * 4.5))
			end
			local root = character:FindFirstChild("HumanoidRootPart")
			if root then
				character.PrimaryPart = root
				character:SetPrimaryPartCFrame(CFrame.lookAt(exitPosition, exitPosition + Vector3.new(0, 0, 1)))
				root.AssemblyLinearVelocity = Vector3.zero
				root.AssemblyAngularVelocity = Vector3.zero
			end
		end
		releasing = false
		return player
	end

	table.insert(connections, enterPrompt.Triggered:Connect(function(player)
		if arrived or destroyed or seat.Occupant or driver then return end
		if not player:GetAttribute("Delivered") then
			notify(player, "LOAD THE SPECIMEN CASE BEFORE LEAVING", "warn")
			return
		end
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not humanoid or humanoid.Health <= 0 or not root then return end
		if (root.Position - entry.Position).Magnitude > settings.PromptDistance + 4 then return end
		driver, driverHumanoid = player, humanoid
		player:SetAttribute("DrivingCourierVan", true)
		enterPrompt.Enabled = false
		exitPrompt.Enabled = true
		seat:Sit(humanoid)
		diedConnection = humanoid.Died:Connect(function() dismount(false) end)
		notify(player, "DRIVE TO THE TUNNEL. USE MOVEMENT CONTROLS; JUMP OR E TO GET OUT.")
		-- A failed seat request must never leave the vehicle reserved forever.
		task.delay(0.6, function()
			if not destroyed and driver == player and seat.Occupant ~= humanoid then clearDriver() end
		end)
	end))
	table.insert(connections, exitPrompt.Triggered:Connect(function(player)
		if player == driver then dismount(false) end
	end))
	table.insert(connections, seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		if releasing then return end
		local humanoid = seat.Occupant
		if not humanoid then
			if driver then dismount(false) end
		elseif humanoid ~= driverHumanoid then
			-- No bypass through touching or externally calling Sit.
			humanoid.Sit = false
			local weld = seat:FindFirstChild("SeatWeld")
			if weld then weld:Destroy() end
		end
	end))
	table.insert(connections, Players.PlayerRemoving:Connect(function(player)
		if player == driver then dismount(false) end
	end))
	table.insert(connections, inputRemote.OnServerEvent:Connect(function(player, throttle, steer)
		if player ~= driver or not driverHumanoid or driverHumanoid.Health <= 0
			or seat.Occupant ~= driverHumanoid or arrived or destroyed then return end
		if type(throttle) ~= "number" or type(steer) ~= "number"
			or throttle ~= throttle or steer ~= steer
			or math.abs(throttle) == math.huge or math.abs(steer) == math.huge then return end
		local now = os.clock()
		if now - inputAt < 1 / 40 then return end
		inputAt = now
		inputThrottle = math.clamp(throttle, -1, 1)
		inputSteer = math.clamp(steer, -1, 1)
	end))

	local castParams = RaycastParams.new()
	castParams.FilterType = Enum.RaycastFilterType.Exclude
	castParams.RespectCanCollide = true
	table.insert(connections, RunService.Heartbeat:Connect(function(dt)
		if arrived or destroyed or not driverHumanoid then return end
		if driverHumanoid.Health <= 0 or driver.Character ~= driverHumanoid.Parent then
			dismount(false)
			return
		end
		if seat.Occupant ~= driverHumanoid then return end
		dt = math.min(dt, 0.1)
		local freshInput = os.clock() - inputAt <= settings.InputTimeout
		local throttle = freshInput and inputThrottle or 0
		local steer = freshInput and inputSteer or 0
		local desiredSpeed = throttle >= 0 and throttle * settings.ForwardSpeed or throttle * settings.ReverseSpeed
		local braking = throttle == 0 or speed * desiredSpeed < 0
		speed = approach(speed, desiredSpeed, (braking and settings.Braking or settings.Acceleration) * dt)
		if math.abs(speed) < 0.05 then speed = 0 end
		local turn = -steer * settings.SteeringRate * dt * math.clamp(speed / 10, -1, 1)
		heading = math.clamp(heading + turn, -settings.MaxHeading, settings.MaxHeading)
		if math.abs(steer) < 0.05 then heading = approach(heading, 0, dt * 0.22) end
		local direction = Vector3.new(math.sin(heading), 0, math.cos(heading))
		local proposed = position + direction * speed * dt
		local extent = math.abs(math.sin(heading)) * settings.VehicleHalfLength + math.cos(heading) * settings.VehicleHalfWidth
		local sideRoom = math.max(0, settings.RoadHalfWidth - extent - 0.3)
		proposed = Vector3.new(
			math.clamp(proposed.X, settings.RoadCenterX - sideRoom, settings.RoadCenterX + sideRoom),
			settings.GroundY,
			math.clamp(proposed.Z, settings.RoadStartZ, settings.StopZ)
		)
		local displacement = proposed - position
		if displacement.Magnitude > 0.001 then
			castParams.FilterDescendantsInstances = { van, driverHumanoid.Parent }
			-- Sweep the full vehicle footprint so collidable scenery and other
			-- players cannot be driven through. The low road surface is below it.
			local hit = workspace:Blockcast(pose() * CFrame.new(0.3, 2.8, 0), Vector3.new(11.6, 3.0, 5.1), displacement, castParams)
			if hit then
				speed = 0
			else
				position = proposed
				moveVan()
			end
		end
		van:SetAttribute("Speed", math.floor(math.abs(speed)))
		if position.Z >= settings.StopZ - 0.05 then
			arrived = true
			van:SetAttribute("ArrivedAtTunnel", true)
			local player = dismount(true)
			enterPrompt.Enabled = false
			notify(player, "ROAD BLOCKED. CONTINUE THROUGH THE TUNNEL ON FOOT.", "warn")
			if settings.OnArrived and player then settings.OnArrived(player) end
		end
	end))

	local controller = { Seat = seat, EnterPrompt = enterPrompt }
	function controller.GetPosition() return position end
	function controller.GetDropOffPosition()
		local dropoff = van:FindFirstChild("DropOff")
		return dropoff and dropoff.Position or position
	end
	function controller.Destroy()
		if destroyed then return end
		destroyed = true
		dismount(false)
		for _, connection in ipairs(connections) do connection:Disconnect() end
		enterPrompt.Enabled = false
		exitPrompt.Enabled = false
	end
	table.insert(connections, van.Destroying:Connect(controller.Destroy))
	return controller
end

return Vehicle
