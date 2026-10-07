-- House enemies share the existing server-raycast weapon system.
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Mutants = {}
local CFG = {
	Health = 100, Speed = 11, Damage = 15, Reach = 4.5, AttackCooldown = 1.4,
	RepathSeconds = 0.8, ThinkSeconds = 0.12, TargetRadius = 65,
	SpawnLift = 1.5, WaypointReach = 1.6,
	Skin = Color3.fromRGB(104, 116, 94), Cloth = Color3.fromRGB(55, 62, 57),
	RootSize = Vector3.new(2, 2, 1), TorsoSize = Vector3.new(2.6, 2.5, 1.3),
	HeadSize = Vector3.new(1.6, 1.6, 1.5), LimbSize = Vector3.new(0.9, 2.3, 1),
}
local function part(model, name, size, cf, color, collides)
	local p = Instance.new("Part")
	p.Name, p.Size, p.CFrame, p.Color = name, size, cf, color
	p.Material = Enum.Material.SmoothPlastic
	p.CanCollide, p.CanTouch, p.Massless = collides or false, false, true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end
local function joint(parent, name, a, b, offset)
	local m = Instance.new("Motor6D")
	m.Name, m.Part0, m.Part1, m.C0 = name, a, b, offset
	m.Parent = parent
	return m
end
function Mutants.Create(parent, name, cf, sleeping)
	-- Authored standing markers sit at player-root height; this longer-legged rig needs clearance.
	if not sleeping then cf += Vector3.new(0, CFG.SpawnLift, 0) end
	local model = Instance.new("Model")
	model.Name = name
	model:SetAttribute("HeadshotOnly", true)
	model:SetAttribute("Dormant", sleeping)
	local root = part(model, "HumanoidRootPart", CFG.RootSize, cf, CFG.Cloth, false)
	root.Transparency, root.CanQuery, root.Massless, root.Anchored = 1, false, false, true
	model.PrimaryPart = root
	local torso = part(model, "Torso", CFG.TorsoSize, cf, CFG.Cloth, true)
	joint(root, "RootJoint", root, torso, CFrame.new())
	local headOffset = CFrame.new(0, 1.95, -0.15)
	local head = part(model, "Head", CFG.HeadSize, cf * headOffset, CFG.Skin)
	joint(torso, "Neck", torso, head, headOffset)
	local motors = {}
	for _, side in ipairs({-1, 1}) do
		local armOffset = CFrame.new(side * 1.7, -0.1, -0.1)
		local arm = part(model, side == -1 and "Left Arm" or "Right Arm", CFG.LimbSize, cf * armOffset, CFG.Skin)
		local armJoint = joint(torso, "Shoulder", torso, arm, armOffset)
		local legOffset = CFrame.new(side * 0.7, -2.1, 0)
		local leg = part(model, side == -1 and "Left Leg" or "Right Leg", CFG.LimbSize, cf * legOffset, CFG.Cloth)
		local legJoint = joint(torso, "Hip", torso, leg, legOffset)
		table.insert(motors, {arm = armJoint, leg = legJoint, armOffset = armOffset, legOffset = legOffset, side = side})
		local eye = part(model, "Eye", Vector3.new(0.22, 0.16, 0.08), head.CFrame * CFrame.new(side * 0.4, 0.18, -0.77), Color3.fromRGB(235, 174, 53))
		eye.Material, eye.CanQuery = Enum.Material.Neon, false
		joint(head, "EyeWeld", head, eye, CFrame.new(side * 0.4, 0.18, -0.77))
	end
	local mouth = part(model, "Mouth", Vector3.new(0.85, 0.18, 0.08), head.CFrame * CFrame.new(0, -0.35, -0.77), Color3.fromRGB(44, 35, 31))
	mouth.CanQuery = false
	joint(head, "MouthWeld", head, mouth, CFrame.new(0, -0.35, -0.77))
	local hum = Instance.new("Humanoid")
	hum.MaxHealth, hum.Health, hum.WalkSpeed = CFG.Health, CFG.Health, CFG.Speed
	hum.HipHeight, hum.RequiresNeck, hum.BreakJointsOnDeath = 0.2, false, false
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.Parent = model
	model.Parent = parent
	if sleeping then
		for _, p in ipairs(model:GetDescendants()) do
			if p:IsA("BasePart") then p.Anchored = true; p.CanCollide = false end
		end
	end
	return model, hum, motors
end
function Mutants.StartChase(model, house, onKilled)
	local hum, root = model.Humanoid, model.PrimaryPart
	local home = root.CFrame
	local houseOrigin = house:GetAttribute("Origin") or CFrame.identity
	root.Anchored = false
	root:SetNetworkOwner(nil)
	local lastAttack, nextPath, thinking, clock = {}, 0, false, 0
	local waypoints, waypoint = {}, 1
	local activeCharacter, pathVersion, stopped, usingFallback = nil, 0, false, false
	local connection
	local function clearPath()
		pathVersion += 1
		waypoints, waypoint, nextPath = {}, 1, 0
		usingFallback = false
	end
	local function stop()
		stopped = true
		clearPath()
		if connection then connection:Disconnect(); connection = nil end
	end
	local function planarDistance(a, b)
		local delta = a - b
		return Vector3.new(delta.X, 0, delta.Z).Magnitude
	end
	local function fallbackPath(destination)
		-- The authored floorplan has a central entrance and bedroom doorway.
		-- These short corridor waypoints remain usable before the navmesh is ready.
		local from = houseOrigin:PointToObjectSpace(root.Position)
		local to = houseOrigin:PointToObjectSpace(destination)
		local points = {}
		local function add(z)
			table.insert(points, {Position = houseOrigin:PointToWorldSpace(Vector3.new(0, 4.5, z))})
		end
		if from.Z > 39 and to.Z < 39 then add(41); add(38); add(35) end
		if from.Z >= 19 and to.Z < 19 then add(22); add(19); add(16) end
		if from.Z < 19 and to.Z >= 19 then add(16); add(19); add(22) end
		if from.Z < 39 and to.Z >= 39 then add(35); add(38); add(41) end
		table.insert(points, {Position = destination})
		return points
	end
	hum.Died:Connect(function()
		stop()
		model:SetAttribute("Defeated", true)
		for _, p in ipairs(model:GetDescendants()) do
			if p:IsA("BasePart") then p.CanCollide = false; p.CanQuery = false end
		end
		root.Anchored = true
		model:SetPrimaryPartCFrame(root.CFrame * CFrame.Angles(math.rad(85), 0, 0) - Vector3.new(0, 1.7, 0))
		if model:GetAttribute("HeadshotKilled") then onKilled(model:GetAttribute("LastHitUserId")) end
	end)
	connection = RunService.Heartbeat:Connect(function(dt)
		if not model.Parent then stop(); return end
		clock += dt
		if clock < CFG.ThinkSeconds or hum.Health <= 0 then return end
		clock = 0
		local target, distance
		for _, p in ipairs(Players:GetPlayers()) do
			local character = p.Character
			local h = character and character:FindFirstChildOfClass("Humanoid")
			local r = character and character:FindFirstChild("HumanoidRootPart")
			local stage = p:GetAttribute("EscapeStage") or 0
			if r and h and h.Health > 0 and stage >= 6 and stage < 8
				and planarDistance(r.Position, home.Position) <= CFG.TargetRadius then
				local d = (r.Position - root.Position).Magnitude
				if d < CFG.TargetRadius and (not distance or d < distance) then target, distance = p, d end
			end
		end
		local targetCharacter = target and target.Character
		local targetRoot = targetCharacter and targetCharacter:FindFirstChild("HumanoidRootPart")
		local targetHum = targetCharacter and targetCharacter:FindFirstChildOfClass("Humanoid")
		if targetCharacter ~= activeCharacter then
			activeCharacter = targetCharacter
			clearPath()
		end
		local destination = targetRoot and targetRoot.Position or home.Position
		if not targetRoot and planarDistance(root.Position, destination) <= CFG.WaypointReach then
			hum:MoveTo(root.Position)
			return
		end
		local ray = RaycastParams.new()
		ray.FilterType = Enum.RaycastFilterType.Exclude
		ray.FilterDescendantsInstances = {model}
		local obstruction = workspace:Raycast(root.Position, destination - root.Position, ray)
		local visible = not obstruction or (targetCharacter and obstruction.Instance:IsDescendantOf(targetCharacter))
		if visible then
			hum:MoveTo(destination)
		elseif os.clock() >= nextPath and not thinking then
			thinking = true
			nextPath = os.clock() + CFG.RepathSeconds
			local requestVersion = pathVersion
			local pathStart, pathEnd = root.Position, destination
			task.spawn(function()
				local path = PathfindingService:CreatePath({AgentRadius = 1.7, AgentHeight = 6, AgentCanJump = false, WaypointSpacing = 3})
				local ok = pcall(function() path:ComputeAsync(pathStart, pathEnd) end)
				thinking = false
				if stopped or not model.Parent or requestVersion ~= pathVersion then return end
				if ok and path.Status == Enum.PathStatus.Success then
					waypoints, waypoint = path:GetWaypoints(), 2
					usingFallback = false
				else
					if usingFallback and waypoints[waypoint] then
						-- Keep doorway progress when repeated navmesh requests fail.
						waypoints[#waypoints].Position = pathEnd
					else
						waypoints, waypoint = fallbackPath(pathEnd), 1
					end
					usingFallback = true
				end
			end)
		end
		if not visible and waypoints[waypoint] then
			if planarDistance(root.Position, waypoints[waypoint].Position) < CFG.WaypointReach then waypoint += 1 end
			if waypoints[waypoint] then hum:MoveTo(waypoints[waypoint].Position) end
		end
		if targetHum and visible and distance <= CFG.Reach and os.clock() - (lastAttack[target] or -math.huge) >= CFG.AttackCooldown then
			lastAttack[target] = os.clock()
			targetHum:TakeDamage(CFG.Damage)
		end
		-- Procedural stride replicates from server without an external animation asset.
		local moving = root.AssemblyLinearVelocity.Magnitude > 1
		for _, motor in ipairs(model.Torso:GetChildren()) do
			if motor:IsA("Motor6D") and motor.Name == "Hip" then
				local side = motor.Part1.Name == "Left Leg" and -1 or 1
				motor.C0 = CFrame.new(side * 0.7, -2.1, 0) * CFrame.Angles(moving and math.sin(os.clock() * 9) * side * 0.5 or 0, 0, 0)
			elseif motor:IsA("Motor6D") and motor.Name == "Shoulder" then
				local side = motor.Part1.Name == "Left Arm" and -1 or 1
				motor.C0 = CFrame.new(side * 1.7, -0.1, -0.1) * CFrame.Angles(-0.8, 0, side * 0.18)
			end
		end
	end)
	return stop
end
return Mutants
