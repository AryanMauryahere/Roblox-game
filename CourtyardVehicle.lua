-- Abandoned courtyard sedan. VehicleSeat controls are relayed by the existing
-- SurvivalWeaponClient through DriverSeat.CourierDriveInput.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Vehicle = {}
local DEFAULTS = {
	StartX = 34, StartZ = 55, ReverseZ = 45, GateZ = 120,
	CityDistance = 640, CityParkingOffset = 12,
	CourtyardHalfWidth = 7, RoadHalfWidth = 5,
	HalfLength = 6.65, HalfWidth = 2.9,
	ForwardSpeed = 38, ReverseSpeed = 12,
	Acceleration = 13, Braking = 24,
	SteeringRate = math.rad(34), MaxHeading = math.rad(18), RoadMaxHeading = math.rad(10),
	InputTimeout = 0.6, MaxInputRate = 40, PromptDistance = 10,
	GateDiscoveryDistance = 48, GateStopDistance = 7, GateCrashSpeed = 13,
	GateWreckDistance = 5, GroundOffset = 0,
}

local function approach(current, target, amount)
	return current < target and math.min(current + amount, target) or math.max(current - amount, target)
end

local function finite(value)
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end

function Vehicle.Create(parent, houseOrigin, options)
	assert(typeof(parent) == "Instance", "CourtyardVehicle.Create needs a parent")
	if typeof(houseOrigin) == "Vector3" then houseOrigin = CFrame.new(houseOrigin) end
	assert(typeof(houseOrigin) == "CFrame", "CourtyardVehicle.Create needs a CFrame or Vector3 origin")
	local cfg = table.clone(DEFAULTS)
	for key, value in pairs(options or {}) do cfg[key] = value end
	local cityZ = cfg.GateZ + cfg.CityDistance - cfg.CityParkingOffset
	if cfg.CityStopZ then
		local road = houseOrigin:PointToWorldSpace(Vector3.new(cfg.StartX, 0, 0))
		cityZ = houseOrigin:PointToObjectSpace(Vector3.new(road.X, houseOrigin.Position.Y, cfg.CityStopZ)).Z
	end
	assert(cityZ > cfg.GateZ + 20, "CityStopZ must be beyond the courtyard gate")

	local model = Instance.new("Model")
	model.Name = "CourtyardSedan"
	model:SetAttribute("CourtyardVehicle", true)
	model:SetAttribute("Wrecked", false)
	model:SetAttribute("GateOpen", false)
	model:SetAttribute("AtCity", false)
	model:SetAttribute("ExitedGate", false)
	model:SetAttribute("Speed", 0)
	local C = {
		Paint = Color3.fromRGB(68, 81, 64), DarkPaint = Color3.fromRGB(48, 59, 49),
		Rust = Color3.fromRGB(101, 60, 40), Metal = Color3.fromRGB(98, 106, 104),
		Dark = Color3.fromRGB(23, 27, 25), Glass = Color3.fromRGB(68, 87, 91),
		Seat = Color3.fromRGB(67, 57, 43), Lamp = Color3.fromRGB(235, 215, 151),
	}
	local initial = houseOrigin * CFrame.new(cfg.StartX, cfg.GroundOffset, cfg.StartZ)
	local function part(name, size, offset, color, material, collidable)
		local item = Instance.new("Part")
		item.Name, item.Size = name, size
		item.CFrame = initial * offset
		item.Anchored = true
		item.CanCollide = collidable == true
		item.CanQuery = collidable == true
		item.CanTouch = false
		item.Color = color or C.Paint
		item.Material = material or Enum.Material.Metal
		item.TopSurface, item.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		item.Parent = model
		return item
	end
	local chassis = part("Chassis", Vector3.new(5.4, 0.6, 12.2), CFrame.new(0, 1.1, 0), C.Dark, nil, true)
	model.PrimaryPart = chassis
	part("Hood", Vector3.new(5.5, 0.65, 3.6), CFrame.new(0, 2.05, 4.4), C.Paint, nil, true)
	part("TrunkBody", Vector3.new(5.5, 1.2, 3.1), CFrame.new(0, 1.8, -4.65), C.DarkPaint, nil, true)
	local lid = part("TrunkLid", Vector3.new(5.45, 0.16, 3.1), CFrame.new(0, 2.48, -4.65), C.Paint)
	lid:SetAttribute("ClosedCFrame", lid.CFrame)
	part("CabRoof", Vector3.new(5.0, 0.22, 5.5), CFrame.new(0, 4.95, -0.1), C.DarkPaint)
	for _, side in ipairs({ -1, 1 }) do
		part("DoorPanel", Vector3.new(0.2, 1.1, 5.1), CFrame.new(side * 2.64, 1.9, -0.15), C.Paint)
		part("DoorRubStrip", Vector3.new(0.24, 0.15, 5.15), CFrame.new(side * 2.67, 2.02, -0.15), C.Dark)
		part("DoorHandle", Vector3.new(0.16, 0.14, 0.65), CFrame.new(side * 2.8, 2.46, -1.0), C.Metal)
		for _, z in ipairs({ -2.7, 2.6 }) do
			part("WindowPillar", Vector3.new(0.18, 2.5, 0.2), CFrame.new(side * 2.43, 3.61, z), C.DarkPaint)
		end
		for _, z in ipairs({ -4.1, 4.1 }) do
			local tire = part("Tire", Vector3.new(0.7, 2.35, 2.35), CFrame.new(side * 2.7, 1.2, z), C.Dark, Enum.Material.Rubber)
			tire.Shape = Enum.PartType.Cylinder
			local hub = part("Hubcap", Vector3.new(0.74, 1.24, 1.24), CFrame.new(side * 2.73, 1.2, z), C.Metal)
			hub.Shape = Enum.PartType.Cylinder
		end
		part("MirrorArm", Vector3.new(0.6, 0.12, 0.14), CFrame.new(side * 2.8, 3.05, 1.9), C.Metal)
		part("Mirror", Vector3.new(0.25, 0.6, 0.7), CFrame.new(side * 3.1, 3.05, 1.9), C.Dark)
	end
	for _, z in ipairs({ -2.78, 2.7 }) do
		local glass = part("Windscreen", Vector3.new(4.75, 2.22, 0.13), CFrame.new(0, 3.62, z), C.Glass, Enum.Material.Glass)
		glass.Transparency = 0.52
	end
	part("Dashboard", Vector3.new(4.8, 0.6, 0.7), CFrame.new(0, 2.42, 2.1), C.Dark)
	part("RearSeat", Vector3.new(4.55, 0.5, 1.65), CFrame.new(0, 1.7, -1.85), C.Seat, Enum.Material.Fabric)
	part("RearBackrest", Vector3.new(4.55, 1.4, 0.35), CFrame.new(0, 2.42, -2.5), C.Seat, Enum.Material.Fabric)
	part("PassengerSeat", Vector3.new(1.7, 0.4, 1.8), CFrame.new(-1.2, 1.65, 0.1), C.Seat, Enum.Material.Fabric)
	part("PassengerBackrest", Vector3.new(1.7, 1.5, 0.35), CFrame.new(-1.2, 2.5, -0.8), C.Seat, Enum.Material.Fabric)
	part("FrontBumper", Vector3.new(5.8, 0.45, 0.32), CFrame.new(0, 1.32, 6.45), C.Metal, nil, true)
	part("RearBumper", Vector3.new(5.8, 0.45, 0.3), CFrame.new(0, 1.3, -6.3), C.Rust, nil, true)
	part("RadiatorGrille", Vector3.new(2.8, 0.8, 0.12), CFrame.new(0, 2.0, 6.25), C.Dark)
	for x = -1.15, 1.15, 0.46 do
		part("GrilleSlat", Vector3.new(0.08, 0.65, 0.14), CFrame.new(x, 2.0, 6.34), C.Metal)
	end
	local headlamps = {}
	for _, side in ipairs({ -1, 1 }) do
		local lamp = part("Headlight", Vector3.new(1.05, 0.68, 0.15), CFrame.new(side * 2.03, 2.03, 6.31), C.Lamp, Enum.Material.Neon)
		local light = Instance.new("SpotLight")
		light.Face = Enum.NormalId.Back
		light.Range, light.Angle, light.Brightness = 46, 68, 1.4
		light.Color, light.Shadows, light.Enabled = C.Lamp, false, false
		light.Parent = lamp
		table.insert(headlamps, light)
		part("TailLight", Vector3.new(1.0, 0.55, 0.12), CFrame.new(side * 2.0, 2.0, -6.23), Color3.fromRGB(121, 37, 27), Enum.Material.Glass)
	end
	-- Hand-placed corrosion and a luggage rack distinguish this from the courier van.
	part("HoodRust", Vector3.new(1.1, 0.02, 2.0), CFrame.new(-1.7, 2.386, 4.25), C.Rust, Enum.Material.CorrodedMetal)
	part("TrunkRust", Vector3.new(1.35, 0.025, 0.7), CFrame.new(1.55, 2.57, -5.5), C.Rust, Enum.Material.CorrodedMetal)
	for _, x in ipairs({ -1.8, 1.8 }) do
		part("RoofRack", Vector3.new(0.12, 0.2, 4.4), CFrame.new(x, 5.16, -0.15), C.Metal)
	end
	for _, z in ipairs({ -1.7, 1.5 }) do
		part("RoofCrossbar", Vector3.new(3.9, 0.12, 0.14), CFrame.new(0, 5.27, z), C.Metal)
	end
	local smokePart = part("DamagedEngine", Vector3.new(0.25, 0.25, 0.25), CFrame.new(0.7, 2.5, 4.8), C.Dark)
	smokePart.Transparency = 1
	local smoke = Instance.new("Smoke")
	smoke.Name, smoke.Enabled = "EngineSmoke", false
	smoke.Color, smoke.Size, smoke.Opacity, smoke.RiseVelocity = Color3.fromRGB(82, 86, 83), 3.2, 0.22, 3
	smoke.Parent = smokePart

	local seat = Instance.new("VehicleSeat")
	seat.Name, seat.Size = "DriverSeat", Vector3.new(1.75, 0.45, 1.8)
	seat.CFrame = initial * CFrame.new(1.2, 1.7, 0.1) * CFrame.Angles(0, math.pi, 0)
	seat.Color, seat.Material = C.Seat, Enum.Material.Fabric
	seat.Anchored, seat.CanTouch, seat.CanCollide, seat.CanQuery = true, false, true, true
	seat.HeadsUpDisplay, seat.MaxSpeed, seat.Torque, seat.TurnSpeed = false, cfg.ForwardSpeed, 0, 0
	seat.Parent = model
	local driveInput = Instance.new("RemoteEvent")
	driveInput.Name, driveInput.Parent = "CourierDriveInput", seat
	local door = part("DriverDoor", Vector3.new(0.25, 0.25, 0.25), CFrame.new(3.25, 2.7, 0.1))
	door.Transparency = 1
	local trunk = part("TrunkPart", Vector3.new(3.8, 1.8, 0.3), CFrame.new(0, 2.1, -6.55))
	trunk.Transparency = 1
	local function prompt(parentPart, name, text, distance)
		local p = Instance.new("ProximityPrompt")
		p.Name, p.ObjectText, p.ActionText = name, "Abandoned sedan", text
		p.KeyboardKeyCode, p.GamepadKeyCode = Enum.KeyCode.E, Enum.KeyCode.ButtonX
		p.MaxActivationDistance, p.HoldDuration, p.RequiresLineOfSight = distance, 0, false
		p.Parent = parentPart
		return p
	end
	local enterPrompt = prompt(door, "EnterCar", "Drive", cfg.PromptDistance)
	local exitPrompt = prompt(seat, "ExitCar", "Get out", 6)
	exitPrompt.Enabled = false
	model.Parent = parent

	local localX, localZ, heading, speed = cfg.StartX, cfg.StartZ, 0, 0
	local inputThrottle, inputSteer, inputAt = 0, 0, -math.huge
	local driver, humanoid, deathConnection, removingConnection
	local gateOpen, wrecked, atCity, exitedGate, destroyed, releasing = false, false, false, false, false, false
	local wreckTilt = CFrame.identity
	local connections, gateSeen = {}, {}
	local function pose()
		return houseOrigin * CFrame.new(localX, cfg.GroundOffset, localZ) * CFrame.Angles(0, heading, 0) * wreckTilt
	end
	local function moveCar()
		model:SetPrimaryPartCFrame(pose() * CFrame.new(0, 1.1, 0))
	end
	local function call(name, player)
		if type(cfg[name]) == "function" then
			local ok, err = pcall(cfg[name], player)
			if not ok then warn("CourtyardVehicle " .. name .. ": " .. tostring(err)) end
		end
	end
	local function notify(player, text, kind)
		if cfg.Notify and player and player.Parent then cfg.Notify(player, text, kind or "info") end
	end
	local function clearDriver()
		if deathConnection then deathConnection:Disconnect() deathConnection = nil end
		if removingConnection then removingConnection:Disconnect() removingConnection = nil end
		if driver and driver.Parent then
			driver:SetAttribute("DrivingCourierVan", false)
			driver:SetAttribute("CourtyardDriving", false)
		end
		driver, humanoid = nil, nil
		speed, inputThrottle, inputSteer, inputAt = 0, 0, 0, -math.huge
		model:SetAttribute("Speed", 0)
		enterPrompt.Enabled = not (wrecked or atCity or destroyed)
		exitPrompt.Enabled = false
		for _, light in ipairs(headlamps) do light.Enabled = false end
	end
	local function dismount(reason)
		if releasing then return nil end
		releasing = true
		local oldDriver, oldHumanoid = driver, humanoid or seat.Occupant
		local character = oldHumanoid and oldHumanoid.Parent
		clearDriver()
		if oldHumanoid then
			oldHumanoid.Sit = false
			local weld = seat:FindFirstChild("SeatWeld")
			if weld then weld:Destroy() end
			if oldHumanoid.Health > 0 then oldHumanoid:ChangeState(Enum.HumanoidStateType.GettingUp) end
		end
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and oldHumanoid.Health > 0 then
			local exitLocal
			if reason == "crash" then
				exitLocal = Vector3.new(cfg.StartX - 5.7, cfg.GroundOffset + 3.5, cfg.GateZ - 14)
			elseif reason == "city" then
				exitLocal = Vector3.new(cfg.StartX - 3.6, cfg.GroundOffset + 3.5, cityZ + 8)
			else
				local side = localX > cfg.StartX and -1 or 1
				exitLocal = Vector3.new(localX + side * 4.5, cfg.GroundOffset + 3.5, localZ - 0.8)
			end
			local destination = houseOrigin:PointToWorldSpace(exitLocal)
			character.PrimaryPart = root
			character:SetPrimaryPartCFrame(CFrame.lookAt(destination, destination + houseOrigin.ZVector))
			root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
		end
		releasing = false
		return oldDriver
	end
	local function crash()
		if wrecked then return end
		wrecked = true
		localX, localZ, heading = cfg.StartX, cfg.GateZ - cfg.GateWreckDistance, math.rad(-9)
		wreckTilt = CFrame.Angles(math.rad(-4), 0, math.rad(5))
		model:SetAttribute("Wrecked", true)
		smoke.Enabled = true
		moveCar()
		local player = dismount("crash")
		notify(player, "THE ENGINE IS WRECKED. GET THROUGH THE GATE ON FOOT.", "warn")
		if player then call("OnCrash", player) end
	end

	table.insert(connections, enterPrompt.Triggered:Connect(function(player)
		if destroyed or wrecked or atCity or driver or seat.Occupant then return end
		local character = player.Character
		local candidate = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not candidate or candidate.Health <= 0 or candidate.SeatPart or not root then return end
		if (root.Position - door.Position).Magnitude > cfg.PromptDistance + 3 then return end
		local ok, allowed, explanation = pcall(function()
			if type(cfg.CanEnter) ~= "function" then return false end
			return cfg.CanEnter(player)
		end)
		if not ok or allowed ~= true then
			notify(player, type(explanation) == "string" and explanation or "FIND THE CAR KEY INSIDE THE HOUSE.", "warn")
			return
		end
		driver, humanoid = player, candidate
		player:SetAttribute("DrivingCourierVan", true)
		player:SetAttribute("CourtyardDriving", true)
		enterPrompt.Enabled, exitPrompt.Enabled = false, true
		for _, light in ipairs(headlamps) do light.Enabled = true end
		deathConnection = candidate.Died:Connect(function() dismount("death") end)
		removingConnection = player.CharacterRemoving:Connect(function(oldCharacter)
			if oldCharacter == character then dismount("respawn") end
		end)
		seat:Sit(candidate)
		notify(player, "USE MOVEMENT CONTROLS TO DRIVE. JUMP OR USE THE EXIT PROMPT TO GET OUT.")
		task.delay(0.65, function()
			if not destroyed and driver == player and seat.Occupant ~= candidate then dismount("seat_failed") end
		end)
	end))
	table.insert(connections, exitPrompt.Triggered:Connect(function(player)
		if player == driver then dismount("exit") end
	end))
	table.insert(connections, seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		if releasing then return end
		local occupant = seat.Occupant
		if not occupant then
			if driver then dismount("jump") end
		elseif occupant ~= humanoid then
			occupant.Sit = false
			local weld = seat:FindFirstChild("SeatWeld")
			if weld then weld:Destroy() end
		end
	end))
	table.insert(connections, Players.PlayerRemoving:Connect(function(player)
		if player == driver then dismount("left") end
		gateSeen[player.UserId] = nil
	end))
	table.insert(connections, driveInput.OnServerEvent:Connect(function(player, throttle, steer)
		if player ~= driver or not humanoid or humanoid.Health <= 0 or seat.Occupant ~= humanoid
			or player.Character ~= humanoid.Parent or destroyed or wrecked or atCity then return end
		if not finite(throttle) or not finite(steer) then return end
		local now = os.clock()
		if now - inputAt < 1 / cfg.MaxInputRate then return end
		inputAt, inputThrottle, inputSteer = now, math.clamp(throttle, -1, 1), math.clamp(steer, -1, 1)
	end))

	local castParams = RaycastParams.new()
	castParams.FilterType, castParams.RespectCanCollide = Enum.RaycastFilterType.Exclude, true
	local function ignoredInstances()
		local list = { model }
		if humanoid and humanoid.Parent then table.insert(list, humanoid.Parent) end
		if typeof(cfg.Gate) == "Instance" then table.insert(list, cfg.Gate) end
		for _, item in ipairs(cfg.CollisionIgnore or {}) do
			if typeof(item) == "Instance" then table.insert(list, item) end
		end
		return list
	end
	table.insert(connections, RunService.Heartbeat:Connect(function(dt)
		if destroyed or wrecked or atCity or not driver or not humanoid then return end
		if humanoid.Health <= 0 or driver.Character ~= humanoid.Parent then dismount("death") return end
		if seat.Occupant ~= humanoid then return end
		dt = math.min(dt, 0.1)
		if not gateOpen and localZ >= cfg.GateZ - cfg.GateDiscoveryDistance and not gateSeen[driver.UserId] then
			gateSeen[driver.UserId] = true
			model:SetAttribute("GateSeen", true)
			call("OnGateSeen", driver)
		end
		if not driver or not humanoid or seat.Occupant ~= humanoid then return end
		local fresh = os.clock() - inputAt <= cfg.InputTimeout
		local throttle, steer = fresh and inputThrottle or 0, fresh and inputSteer or 0
		local desiredSpeed = throttle >= 0 and throttle * cfg.ForwardSpeed or throttle * cfg.ReverseSpeed
		-- Ease down into the city stop instead of abruptly parking at road speed.
		if desiredSpeed > 0 then desiredSpeed = math.min(desiredSpeed, math.sqrt(math.max(0, 2 * cfg.Braking * (cityZ - localZ)))) end
		local braking = throttle == 0 or speed * desiredSpeed < 0 or math.abs(desiredSpeed) < math.abs(speed)
		speed = approach(speed, desiredSpeed, (braking and cfg.Braking or cfg.Acceleration) * dt)
		if math.abs(speed) < 0.03 then speed = 0 end
		local nearGate = localZ > cfg.GateZ - cfg.GateDiscoveryDistance
		local limit = nearGate and cfg.RoadMaxHeading or cfg.MaxHeading
		heading = math.clamp(heading - steer * cfg.SteeringRate * dt * math.clamp(speed / 10, -1, 1), -limit, limit)
		if math.abs(steer) < 0.05 then heading = approach(heading, 0, dt * 0.3) end
		local halfRoad = nearGate and cfg.RoadHalfWidth or cfg.CourtyardHalfWidth
		local footprint = math.abs(math.sin(heading)) * cfg.HalfLength + math.cos(heading) * cfg.HalfWidth
		local clearance = math.max(0, halfRoad - footprint - 0.15)
		local nextX = math.clamp(localX + math.sin(heading) * speed * dt, cfg.StartX - clearance, cfg.StartX + clearance)
		local nextZ = math.clamp(localZ + math.cos(heading) * speed * dt, cfg.ReverseZ, cityZ)
		if not gateOpen and speed > 0 and nextZ >= cfg.GateZ - cfg.GateStopDistance then
			if speed >= cfg.GateCrashSpeed then crash() return end
			nextZ, speed = cfg.GateZ - cfg.GateStopDistance, 0
		end
		local displacement = houseOrigin:VectorToWorldSpace(Vector3.new(nextX - localX, 0, nextZ - localZ))
		if displacement.Magnitude > 0.001 then
			castParams.FilterDescendantsInstances = ignoredInstances()
			local hit = workspace:Blockcast(pose() * CFrame.new(0, 3.05, 0), Vector3.new(5.5, 3.5, 12.4), displacement, castParams)
			if hit then
				speed = 0
			else
				localX, localZ = nextX, nextZ
				moveCar()
			end
		end
		model:SetAttribute("Speed", math.floor(math.abs(speed)))
		if gateOpen and not exitedGate and localZ >= cfg.GateZ + cfg.HalfLength + 1 then
			exitedGate = true
			model:SetAttribute("ExitedGate", true)
			call("OnExitedGate", driver)
		end
		if localZ >= cityZ - 0.1 then
			localZ, atCity = cityZ, true
			model:SetAttribute("AtCity", true)
			moveCar()
			local player = dismount("city")
			notify(player, "CITY OUTSKIRTS. CONTINUE ON FOOT.", "item")
			if player then call("OnCityArrived", player) end
		end
	end))

	local controller = { Model = model, Seat = seat, Trunk = trunk, TrunkLid = lid, EnterPrompt = enterPrompt }
	function controller.GetPosition() return pose().Position end
	function controller.GetState()
		return { Driver = driver, Wrecked = wrecked, GateOpen = gateOpen, AtCity = atCity, ExitedGate = exitedGate, Speed = speed }
	end
	function controller.ExitDriver(reason) return dismount(reason or "exit") end
	function controller.SetGateOpen()
		gateOpen = true
		model:SetAttribute("GateOpen", true)
	end
	function controller.Destroy()
		if destroyed then return end
		destroyed = true
		dismount("destroy")
		for _, connection in ipairs(connections) do connection:Disconnect() end
		enterPrompt.Enabled, exitPrompt.Enabled = false, false
	end
	table.insert(connections, model.Destroying:Connect(controller.Destroy))
	return controller
end

return Vehicle
