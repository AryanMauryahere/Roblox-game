-- Self-contained wilderness creatures. Create APIs take a GROUND CFrame, not a root CFrame.
-- The ordinary server-raycast handgun can damage every visible body part; Head remains a real hitbox.
local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Wilderness = {}

local CONFIG = {
	Giant = { Health = 300, RootHeight = 8, PatrolSpeed = 7, ChaseSpeed = 11,
		Damage = 28, AttackCooldown = 2, Reach = 8.5, Sight = 58, Radius = 3.3,
		Height = 15, BoundMargin = 5.5, SweepSize = Vector3.new(6.4, 10.5, 5.8), SweepOffset = Vector3.new(0, 0.6, -0.3) },
	Dog = { Health = 120, RootHeight = 2.25, PatrolSpeed = 6, ChaseSpeed = 16,
		Damage = 18, AttackCooldown = 1.4, Reach = 7.2, Sight = 43, Radius = 2,
		Height = 5.2, BoundMargin = 6.2, SweepSize = Vector3.new(3.4, 4.6, 11.8), SweepOffset = Vector3.new(0, 0.15, 0.15) },
}
local COLOR = {
	Skin = Color3.fromRGB(74, 88, 69), Bruise = Color3.fromRGB(57, 53, 63),
	Growth = Color3.fromRGB(104, 109, 70), Dark = Color3.fromRGB(25, 29, 26),
	Bone = Color3.fromRGB(173, 165, 123), Cloth = Color3.fromRGB(41, 48, 47),
	Strap = Color3.fromRGB(75, 60, 44), Eye = Color3.fromRGB(247, 165, 45),
	Dog = Color3.fromRGB(65, 70, 56), Wound = Color3.fromRGB(101, 64, 60),
}

local function part(model, name, size, cf, color, shape, decorative)
	local p = Instance.new(shape == "Wedge" and "WedgePart" or "Part")
	p.Name, p.Size, p.CFrame, p.Color = name, size, cf, color
	p.Material = Enum.Material.SmoothPlastic
	p.CanCollide, p.CanTouch, p.CanQuery, p.Massless = false, false, not decorative, true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	if shape == "Ball" then p.Shape = Enum.PartType.Ball end
	p.Parent = model
	return p
end
local function attach(model, parent, name, size, offset, color, shape, decorative, animatedKind, phase)
	local p = part(model, name, size, parent.CFrame * offset, color, shape, decorative)
	local motor = Instance.new("Motor6D")
	motor.Name, motor.Part0, motor.Part1, motor.C0 = name .. "Joint", parent, p, offset
	if animatedKind then
		motor:SetAttribute("Motion", animatedKind)
		motor:SetAttribute("Rest", offset)
		motor:SetAttribute("Phase", phase or 1)
	end
	motor.Parent = parent
	return p, motor
end
local function base(parent, kind, groundCf)
	assert(typeof(groundCf) == "CFrame", "Wilderness creature spawn must be a ground CFrame")
	local cfg = CONFIG[kind]
	local model = Instance.new("Model")
	model.Name = kind == "Giant" and "ForestGiant" or "MutantHound"
	model:SetAttribute("WildernessKind", kind)
	model:SetAttribute("HeadshotOnly", false)
	model:SetAttribute("CreatureState", "Idle")
	local root = part(model, "HumanoidRootPart", kind == "Giant" and Vector3.new(2, 3, 2) or Vector3.new(1, 1, 1),
		groundCf + Vector3.new(0, cfg.RootHeight, 0), COLOR.Dark, nil, true)
	root.Transparency, root.Anchored, root.Massless = 1, true, false
	model.PrimaryPart = root
	local hum = Instance.new("Humanoid")
	hum.MaxHealth, hum.Health, hum.WalkSpeed = cfg.Health, cfg.Health, cfg.PatrolSpeed
	hum.RequiresNeck, hum.BreakJointsOnDeath = false, false
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HipHeight = kind == "Giant" and 0.1 or 0
	hum.AutoRotate = kind == "Giant"
	hum.Parent = model
	return model, root, hum
end
local function eye(model, head, offset, size)
	local p = attach(model, head, "SunkenEye", size, offset, COLOR.Eye, "Ball", true)
	p.Material = Enum.Material.Neon
	local light = Instance.new("PointLight")
	light.Color, light.Brightness, light.Range = COLOR.Eye, 0.5, 4
	light.Parent = p
end

function Wilderness.CreateGiant(parent, groundCf)
	local model, root = base(parent, "Giant", groundCf)
	local torso = attach(model, root, "Torso", Vector3.new(4.6, 5.6, 3.1),
		CFrame.new(0, 0.8, 0.2) * CFrame.Angles(math.rad(-12), 0, 0), COLOR.Skin, nil, false, "Breath")
	torso.CanCollide = true
	attach(model, torso, "HunchedShoulderMass", Vector3.new(5.2, 3.2, 3.4), CFrame.new(0.1, 2.1, 0.65), COLOR.Growth, "Ball")
	local head = attach(model, torso, "Head", Vector3.new(2.6, 2.8, 2.5),
		CFrame.new(-0.25, 4.7, -1.3) * CFrame.Angles(math.rad(12), 0, 0), COLOR.Skin)
	attach(model, head, "HeavyBrow", Vector3.new(2.7, 0.5, 0.5), CFrame.new(0, 0.5, -1.18), COLOR.Dark, nil, true)
	attach(model, head, "SplitJaw", Vector3.new(2.3, 0.75, 1.5), CFrame.new(0.1, -1.15, -0.65), COLOR.Bruise, nil, true)
	attach(model, head, "MouthShadow", Vector3.new(1.95, 0.55, 0.15), CFrame.new(0, -0.6, -1.28), COLOR.Dark, nil, true)
	for _, side in ipairs({-1, 1}) do
		eye(model, head, CFrame.new(side * 0.7, 0.17, -1.28), Vector3.new(0.32, 0.24, 0.2))
		for tooth = 1, 3 do
			attach(model, head, "BrokenFang", Vector3.new(0.2, 0.42, 0.2),
				CFrame.new(side * tooth * 0.25, -0.46, -1.4) * CFrame.Angles(0, 0, side * 0.15), COLOR.Bone, "Wedge", true)
		end
		local hip = attach(model, root, side == -1 and "Left Leg" or "Right Leg", Vector3.new(1.8, 6.4, 2.1),
			CFrame.new(side * 1.3, -4.6, 0.2), COLOR.Cloth, nil, false, "GiantLeg", side)
		attach(model, hip, "BareKnee", Vector3.new(1.9, 1.5, 2.25), CFrame.new(0, 0, -0.13), COLOR.Skin, "Ball")
		attach(model, hip, "HeavyFoot", Vector3.new(2.15, 0.8, 3.2), CFrame.new(0, -2.8, -0.55), COLOR.Dark)
		local large = side == 1
		local arm = attach(model, torso, side == -1 and "Left Arm" or "Right Arm",
			large and Vector3.new(2.4, 7.5, 2.5) or Vector3.new(1.7, 6.1, 1.8),
			CFrame.new(side * (large and 3.5 or 3), -1.1, -0.1) * CFrame.Angles(-0.12, 0, side * 0.13),
			large and COLOR.Growth or COLOR.Skin, nil, false, "GiantArm", side)
		local fist = attach(model, arm, "ClawedHand", large and Vector3.new(2.8, 2.1, 2.6) or Vector3.new(1.9, 1.7, 2),
			CFrame.new(0, large and -4.1 or -3.25, -0.2), COLOR.Bruise, "Ball")
		for finger = 1, 3 do
			attach(model, fist, "LongClaw", Vector3.new(0.25, large and 1.6 or 1.1, 0.6),
				CFrame.new((finger - 2) * (large and 0.75 or 0.5), -1.2, -0.75) * CFrame.Angles(-0.3, 0, 0), COLOR.Bone, "Wedge")
		end
		attach(model, torso, "TornStrap", Vector3.new(0.52, 5.7, 0.16),
			CFrame.new(side * 1.2, 0.15, -1.6) * CFrame.Angles(0, 0, side * 0.3), COLOR.Strap)
	end
	attach(model, torso, "RaggedWaist", Vector3.new(4.9, 1.15, 3.3), CFrame.new(0, -2.4, 0), COLOR.Cloth)
	for index = 1, 5 do
		attach(model, torso, "SpinalPlate", Vector3.new(0.9, 1.5, 1.6),
			CFrame.new(0, -1.9 + index * 0.92, 1.75) * CFrame.Angles(math.rad(18), 0, 0), COLOR.Bone, "Wedge")
	end
	for index = 1, 7 do
		attach(model, torso, "FungalGrowth", Vector3.new(0.55 + index % 3 * 0.25, 0.65, 0.45),
			CFrame.new((index % 3 - 1) * 1.4, -1.6 + index * 0.57, -1.52), COLOR.Growth, "Ball")
	end
	model.Parent = parent
	return model
end

function Wilderness.CreateDog(parent, groundCf)
	local model, root = base(parent, "Dog", groundCf)
	local torso = attach(model, root, "Torso", Vector3.new(2.7, 2, 5), CFrame.new(0, 0.2, 0), COLOR.Dog, nil, false, "DogBody")
	attach(model, torso, "RaisedHaunches", Vector3.new(2.6, 2.35, 2.5), CFrame.new(0, 0.25, 1.1), COLOR.Bruise, "Ball")
	attach(model, torso, "AngularChest", Vector3.new(2.9, 2.1, 1.8), CFrame.new(0, 0.15, -1.65), COLOR.Growth, "Ball")
	local head = attach(model, torso, "Head", Vector3.new(2.2, 1.85, 2.3), CFrame.new(0, 0.5, -3.1), COLOR.Dog, nil, false, "DogHead")
	attach(model, head, "LongMuzzle", Vector3.new(1.6, 0.85, 1.7), CFrame.new(0, -0.05, -1.35), COLOR.Bruise, nil, true)
	attach(model, head, "Nose", Vector3.new(1.2, 0.5, 0.3), CFrame.new(0, 0.1, -2.2), COLOR.Dark, "Ball", true)
	local jaw = attach(model, head, "HingedJaw", Vector3.new(1.65, 0.4, 2),
		CFrame.new(0, -0.75, -1.05) * CFrame.Angles(math.rad(-10), 0, 0), COLOR.Wound, nil, true, "DogJaw")
	for _, side in ipairs({-1, 1}) do
		attach(model, head, "PointedEar", Vector3.new(0.65, 1.7, 0.9),
			CFrame.new(side * 0.85, 1.3, 0.3) * CFrame.Angles(0.15, 0, -side * 0.25), COLOR.Dark, "Wedge", true)
		eye(model, head, CFrame.new(side * 0.93, 0.38, -0.91), Vector3.new(0.28, 0.24, 0.22))
		for tooth = 1, 4 do
			attach(model, head, "UpperFang", Vector3.new(0.16, tooth == 1 and 0.7 or 0.42, 0.2),
				CFrame.new(side * 0.75, -0.5, -0.45 - tooth * 0.37), COLOR.Bone, "Wedge", true)
			attach(model, jaw, "LowerFang", Vector3.new(0.14, 0.34, 0.2),
				CFrame.new(side * 0.65, 0.22, 0.55 - tooth * 0.35) * CFrame.Angles(math.pi, 0, 0), COLOR.Bone, "Wedge", true)
		end
		for _, front in ipairs({true, false}) do
			local phase = side * (front and 1 or -1)
			local upper = attach(model, torso, (front and "Foreleg" or "Hindleg") .. (side == -1 and "Left" or "Right"),
				Vector3.new(0.75, 1.25, 0.95), CFrame.new(side * 1.13, -0.75, front and -1.65 or 1.65),
				COLOR.Dog, nil, false, "DogLeg", phase)
			local shin = attach(model, upper, "BentHock", Vector3.new(0.55, 1.1, 0.65),
				CFrame.new(0, -0.95, front and 0.12 or 0.38) * CFrame.Angles(front and -0.08 or -0.25, 0, 0), COLOR.Bruise)
			local paw = attach(model, shin, "SplayedPaw", Vector3.new(0.85, 0.3, 1.15), CFrame.new(0, -0.6, -0.25), COLOR.Dark)
			for claw = -1, 1 do
				attach(model, paw, "PawClaw", Vector3.new(0.12, 0.15, 0.42), CFrame.new(claw * 0.24, 0, -0.7), COLOR.Bone, "Wedge")
			end
		end
		for rib = 1, 4 do
			attach(model, torso, "ExposedRib", Vector3.new(0.13, 1.2, 0.23),
				CFrame.new(side * 1.37, 0.05, -0.6 + rib * 0.55) * CFrame.Angles(0.1, 0, side * 0.13), COLOR.Bone)
		end
		attach(model, torso, "DiseasedPatch", Vector3.new(0.16, 0.85, 1.25), CFrame.new(side * 1.38, 0.4, -0.6), COLOR.Wound, "Ball")
	end
	local tail = attach(model, torso, "CrookedTail", Vector3.new(0.55, 0.6, 2.7),
		CFrame.new(0, 0.25, 3.4) * CFrame.Angles(-0.3, 0.15, 0), COLOR.Dark, nil, false, "DogTail")
	attach(model, tail, "TailTip", Vector3.new(0.4, 0.4, 1.5), CFrame.new(0, 0.35, 1.65) * CFrame.Angles(-0.25, 0, 0), COLOR.Bruise)
	for index = 1, 5 do
		attach(model, torso, "SpineBristle", Vector3.new(0.22, 0.85, 0.6), CFrame.new(0, 1.35, -1.8 + index * 0.7), COLOR.Bone, "Wedge")
	end
	model.Parent = parent
	return model
end

local function horizontal(vector) return Vector3.new(vector.X, 0, vector.Z) end
local function distance(a, b) return horizontal(a - b).Magnitude end

function Wilderness.Start(model, options)
	options = options or {}
	assert(not model:GetAttribute("WildernessActive"), "This wilderness creature is already running")
	local kind = model:GetAttribute("WildernessKind")
	local cfg = assert(CONFIG[kind], "Unknown wilderness creature kind")
	local root, hum = model.PrimaryPart, model:FindFirstChildOfClass("Humanoid")
	assert(root and hum, "Wilderness creature requires a root and Humanoid")
	local dog = kind == "Dog"
	local home = root.Position
	local bounds = options.BoundsOrigin or CFrame.new(home)
	local half = options.BoundsHalfSize or Vector3.new(35, 30, 50)
	local margin = cfg.BoundMargin
	local patrol = options.PatrolPoints or {home}
	if #patrol == 0 then patrol = {home} end
	local function inBounds(position, padding)
		local p = bounds:PointToObjectSpace(position)
		return math.abs(p.X) <= math.max(0, half.X - (padding or margin))
			and math.abs(p.Z) <= math.max(0, half.Z - (padding or margin))
	end
	local function clampBounds(position)
		local p = bounds:PointToObjectSpace(position)
		return bounds:PointToWorldSpace(Vector3.new(math.clamp(p.X, -math.max(0, half.X - margin), math.max(0, half.X - margin)),
			p.Y, math.clamp(p.Z, -math.max(0, half.Z - margin), math.max(0, half.Z - margin))))
	end
	local ray = RaycastParams.new()
	ray.FilterType, ray.FilterDescendantsInstances, ray.RespectCanCollide = Enum.RaycastFilterType.Exclude, {model}, true
	local overlap = OverlapParams.new()
	overlap.FilterType, overlap.FilterDescendantsInstances, overlap.RespectCanCollide = Enum.RaycastFilterType.Exclude, {model}, true
	local stopped, connection, deathConnection = false, nil, nil
	local target, lastSeen, investigateUntil, nextAttack, nextNotice = nil, nil, 0, 0, {}
	local patrolIndex, nextPath, calculating, pathVersion = 1, 0, false, 0
	local waypoints, waypoint, goal, moveTarget, elapsed = {}, 1, nil, nil, 0
	local moving, attackUntil, lastPosition, stuckFor = false, 0, root.Position, 0
	local motors = {}
	for _, item in ipairs(model:GetDescendants()) do
		if item:IsA("Motor6D") and item:GetAttribute("Motion") then table.insert(motors, item) end
	end
	local function resetPath()
		pathVersion += 1
		waypoints, waypoint, nextPath, moveTarget = {}, 1, 0, nil
	end
	local function stop()
		if stopped then return end
		stopped = true
		resetPath()
		if connection then connection:Disconnect() end
		if deathConnection then deathConnection:Disconnect() end
		model:SetAttribute("WildernessActive", false)
		if hum.Health > 0 then hum:MoveTo(root.Position) end
	end
	local function visible(position, character)
		local from = root.Position + Vector3.new(0, dog and 0.5 or 2, 0)
		local hit = workspace:Raycast(from, position - from, ray)
		return not hit or (character and hit.Instance:IsDescendantOf(character))
	end
	local function clearStep(position, direction, length)
		if direction.Magnitude < 0.001 then return true end
		local endPoint = position + direction.Unit * length
		if not inBounds(endPoint) then return false end
		local facing = CFrame.lookAt(position, position + direction)
		local sweepCf = facing + facing:VectorToWorldSpace(cfg.SweepOffset)
		return not workspace:Blockcast(sweepCf, cfg.SweepSize, direction.Unit * length, ray)
	end
	local function steer(destination)
		local delta = horizontal(destination - root.Position)
		if delta.Magnitude < 0.05 then return root.Position end
		local stride = math.min(dog and 4 or 5, delta.Magnitude)
		if clearStep(root.Position, delta, stride) then return destination end
		local unit = delta.Unit
		local best, bestScore
		for _, angle in ipairs({45, -45, 80, -80, 115, -115}) do
			local direction = CFrame.Angles(0, math.rad(angle), 0):VectorToWorldSpace(unit)
			local candidate = root.Position + direction * stride
			if clearStep(root.Position, direction, stride) then
				local score = distance(candidate, destination)
				if not bestScore or score < bestScore then best, bestScore = candidate, score end
			end
		end
		return best or root.Position
	end
	local function requestPath(destination)
		if calculating or os.clock() < nextPath then return end
		calculating, nextPath = true, os.clock() + 0.9
		local version, startPoint = pathVersion, root.Position
		task.spawn(function()
			local path = PathfindingService:CreatePath({AgentRadius = cfg.Radius, AgentHeight = cfg.Height,
				AgentCanJump = false, WaypointSpacing = dog and 4 or 5})
			local ok = pcall(function() path:ComputeAsync(startPoint, destination) end)
			calculating = false
			if stopped or version ~= pathVersion or not model.Parent then return end
			local points = ok and path.Status == Enum.PathStatus.Success and path:GetWaypoints() or {}
			for _, point in ipairs(points) do
				if not inBounds(point.Position) then points = {}; break end
			end
			waypoints, waypoint = points, #points > 1 and 2 or 1
		end)
	end
	local function eligible(player)
		local character = player.Character
		local ph = character and character:FindFirstChildOfClass("Humanoid")
		local pr = character and character:FindFirstChild("HumanoidRootPart")
		if not ph or not pr or ph.Health <= 0 or not inBounds(pr.Position, 0) then return end
		if options.PlayerEligible and not options.PlayerEligible(player) then return end
		return character, ph, pr
	end
	local function animate(now)
		local attacking = now < attackUntil
		for _, motor in ipairs(motors) do
			local motion, rest, phase = motor:GetAttribute("Motion"), motor:GetAttribute("Rest"), motor:GetAttribute("Phase")
			local stride = moving and math.sin(now * (dog and 13 or 5)) * phase or 0
			if motion == "GiantLeg" then motor.C0 = rest * CFrame.Angles(stride * 0.27, 0, 0)
			elseif motion == "GiantArm" then motor.C0 = rest * CFrame.Angles(attacking and -1.1 or -stride * 0.18, 0, 0)
			elseif motion == "Breath" then motor.C0 = rest * CFrame.Angles(math.sin(now * 1.5) * 0.025, 0, 0)
			elseif motion == "DogLeg" then motor.C0 = rest * CFrame.Angles(stride * 0.55, 0, 0)
			elseif motion == "DogBody" then motor.C0 = rest + Vector3.new(0, moving and math.abs(math.sin(now * 13)) * 0.09 or 0, 0)
			elseif motion == "DogHead" then motor.C0 = rest * CFrame.Angles(attacking and -0.2 or math.sin(now * 2) * 0.03, 0, 0)
			elseif motion == "DogJaw" then motor.C0 = rest * CFrame.Angles(attacking and -0.32 or math.sin(now * 3) * 0.035, 0, 0)
			elseif motion == "DogTail" then motor.C0 = rest * CFrame.Angles(0, math.sin(now * 4) * 0.17, 0) end
		end
	end
	model:SetAttribute("WildernessActive", true)
	if dog then
		hum.PlatformStand = true
	else
		root.Anchored = false
		root:SetNetworkOwner(nil)
	end
	local deathHandled = false
	local function handleDeath()
		-- Health can reach zero before a deferred Died signal is dispatched.
		if deathHandled then return end
		deathHandled = true
		stop()
		if not model.Parent then return end
		model:SetAttribute("CreatureState", "Dead")
		model:SetAttribute("Defeated", true)
		root.Anchored = true
		for _, p in ipairs(model:GetDescendants()) do
			if p:IsA("BasePart") then p.CanCollide, p.CanQuery = false, false end
		end
		model:SetPrimaryPartCFrame(root.CFrame * CFrame.Angles(0, 0, math.rad(dog and 80 or 85)) - Vector3.new(0, dog and 0.65 or 5.3, 0))
		task.delay(16, function()
			if not model.Parent then return end
			for _, p in ipairs(model:GetDescendants()) do
				if p:IsA("BasePart") then TweenService:Create(p, TweenInfo.new(4), {Transparency = 1}):Play() end
			end
			task.delay(4, function() if model.Parent then model:Destroy() end end)
		end)
	end
	deathConnection = hum.Died:Connect(handleDeath)
	connection = RunService.Heartbeat:Connect(function(dt)
		if stopped then return end
		if not model.Parent then stop(); return end
		if hum.Health <= 0 then handleDeath(); return end
		local now = os.clock()
		elapsed += dt
		if elapsed >= 0.15 then
			local stepSeconds = elapsed
			elapsed = 0
			local chosen, chosenDistance
			for _, player in ipairs(Players:GetPlayers()) do
				local character, _, pr = eligible(player)
				if character then
					local d = distance(pr.Position, root.Position)
					if d <= cfg.Sight and (not chosenDistance or d < chosenDistance) and visible(pr.Position, character) then
						chosen, chosenDistance = player, d
					end
				end
			end
			if chosen ~= target then target = chosen; resetPath() end
			local character, playerHum, playerRoot
			if target then character, playerHum, playerRoot = eligible(target) end
			local destination, state
			if playerRoot then
				destination, lastSeen, investigateUntil, state = playerRoot.Position, playerRoot.Position, now + 3, "Chase"
				if options.Notice and now >= (nextNotice[target] or 0) then
					nextNotice[target] = now + 25
					options.Notice(target, dog and "A MUTANT HOUND IS HUNTING YOU!" or "SOMETHING HUGE IS MOVING BETWEEN THE TREES!", "warn")
				end
				if chosenDistance <= cfg.Reach and math.abs(playerRoot.Position.Y - root.Position.Y) < (dog and 5 or 9)
					and now >= nextAttack then
					nextAttack, attackUntil = now + cfg.AttackCooldown, now + 0.55
					local attackedPlayer = target
					task.delay(dog and 0.16 or 0.32, function()
						if stopped or hum.Health <= 0 then return end
						local ch, ph, pr = eligible(attackedPlayer)
						if ph and distance(pr.Position, root.Position) <= cfg.Reach and visible(pr.Position, ch) then ph:TakeDamage(cfg.Damage) end
					end)
				end
			elseif lastSeen and now < investigateUntil and distance(root.Position, lastSeen) > 2 then
				destination, state = lastSeen, "Investigate"
			else
				if distance(root.Position, clampBounds(patrol[patrolIndex])) < 3 then patrolIndex = patrolIndex % #patrol + 1; resetPath() end
				destination, state = patrol[patrolIndex], "Patrol"
			end
			destination = clampBounds(destination)
			if goal and distance(goal, destination) > 9 then resetPath() end
			goal = destination
			model:SetAttribute("CreatureState", state)
			hum.WalkSpeed = state == "Chase" and cfg.ChaseSpeed or cfg.PatrolSpeed
			-- Count an unmet movement goal even when collision prevented every physical step.
			local attemptingMovement = distance(root.Position, destination) > 2 and hum.WalkSpeed > 0
			if attemptingMovement and distance(root.Position, lastPosition) < 0.2 then stuckFor += stepSeconds else stuckFor = 0 end
			lastPosition = root.Position
			if stuckFor > 3 then
				resetPath()
				if state == "Patrol" then
					patrolIndex = patrolIndex % #patrol + 1
					destination = clampBounds(patrol[patrolIndex])
					goal = destination
				end
				stuckFor = 0
			end
			local direct = horizontal(destination - root.Position)
			if clearStep(root.Position, direct, math.min(direct.Magnitude, dog and 9 or 11)) then
				moveTarget = destination
			else
				requestPath(destination)
				if waypoints[waypoint] and distance(root.Position, waypoints[waypoint].Position) < 2 then waypoint += 1 end
				moveTarget = steer(waypoints[waypoint] and waypoints[waypoint].Position or destination)
			end
			if not dog then
				if not inBounds(root.Position) then
					local corrected = clampBounds(root.Position)
					model:SetPrimaryPartCFrame(root.CFrame + (corrected - root.Position))
					root.AssemblyLinearVelocity = Vector3.zero
				end
				hum:MoveTo(moveTarget or root.Position)
			end
		end
		if dog and moveTarget then
			local delta = horizontal(moveTarget - root.Position)
			local step = math.min(delta.Magnitude, hum.WalkSpeed * math.min(dt, 0.05))
			moving = step > 0.01
			if moving then
				local direction = delta.Unit
				local candidate = root.Position + direction * step
				local floorHit = workspace:Raycast(candidate + Vector3.new(0, 5, 0), Vector3.new(0, -12, 0), ray)
				if floorHit and floorHit.Normal.Y > 0.55 then
					candidate = Vector3.new(candidate.X, floorHit.Position.Y + cfg.RootHeight, candidate.Z)
					local facing = CFrame.lookAt(candidate, candidate + direction)
					local boxCf = facing + facing:VectorToWorldSpace(cfg.SweepOffset)
					local clear = #workspace:GetPartBoundsInBox(boxCf, cfg.SweepSize, overlap) == 0
					if inBounds(candidate) and math.abs(candidate.Y - root.Position.Y) <= 1.1
						and clear and clearStep(root.Position, direction, step) then
						model:SetPrimaryPartCFrame(facing)
					else moving = false end
				else moving = false end
			end
		elseif not dog then moving = horizontal(root.AssemblyLinearVelocity).Magnitude > 0.7 end
		animate(now)
	end)
	return stop
end

return Wilderness
