-- Courtyard escape: a hidden trunk key or a permanently wrecked car, then the city.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Vehicle = require(ServerScriptService:WaitForChild("CourtyardVehicle"))
local CityBuilder = require(ServerScriptService:WaitForChild("RaccoonCityBuilder"))
local Mutants = require(ServerScriptService:WaitForChild("WildernessMutants"))
local preview = workspace:FindFirstChild("CourtyardExpansionPreview")
if preview and preview:GetAttribute("GeneratedExpansionPreview") then preview:Destroy() end
local house
repeat
	house = workspace:FindFirstChild("EscapeHouse")
	if not house or (house:GetAttribute("LayoutVersion") or 0) < 2 or not house:GetAttribute("EscapeRuntimeReady") then
		house = nil
		task.wait(0.1)
	end
until house
local origin = house:GetAttribute("Origin")
local CFG = {
	PromptDistance = 8, TrunkDistance = 4, PollSeconds = 0.15, GateSeconds = 1.6,
	RoadCheckpointRadius = 24, CityArrivalRadius = 34, HeadquartersRadius = 12,
	GiantOffset = Vector3.new(24, 0, 65),
}
local city = CityBuilder.Build(origin)
local gate = house:WaitForChild("ExitGate")
local gatePosition = gate.PrimaryPart.Position
local remote = ReplicatedStorage:WaitForChild("CourierRemote")
local car, gatePrompt, trunkPrompt
local opening = false
house:SetAttribute("CourtyardGateOpen", false)
house:SetAttribute("CourtyardCarWrecked", false)
local function notify(player, message, kind)
	if player and player.Parent == Players then remote:FireClient(player, "Notice", message, kind or "info") end
end
local function alive(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and root and humanoid.Health > 0 then return character, humanoid, root end
end
local function near(player, position, distance)
	local _, _, root = alive(player)
	return root and (root.Position - position).Magnitude <= distance
end
local function checkpoint(player, position)
	player:SetAttribute("EscapeCheckpoint", CFrame.lookAt(position, position + Vector3.new(0, 0, 1)))
end
local function objective(player)
	local stage = player:GetAttribute("CityStage") or 0
	local text, position
	if stage == 1 then
		text, position = "Find the courtyard car's keys inside the house.", house.InteriorTrigger.Position
	elseif stage == 2 then
		text, position = "Enter the courtyard car and try the exit.", car.Seat.Position
	elseif stage == 3 then
		text, position = "Drive toward the courtyard exit.", house.GateInteraction.Position
	elseif stage == 4 then
		if player:GetAttribute("CourtyardGateKey") then
			text, position = "Use the iron key to unlock the courtyard gate.", house.GateInteraction.Position
		else
			-- Intentionally no waypoint or hint naming the trunk.
			text = "The courtyard gate is locked. Search for a way out."
		end
	elseif stage == 5 then
		if house:GetAttribute("CourtyardCarWrecked") then
			text = "The car is stuck in the railings. Follow the road to Raccoon City on foot."
		elseif player:GetAttribute("CityRouteOnFoot") then
			text = "Follow the forest road to Raccoon City on foot."
		else
			text = "Follow the forest road to Raccoon City."
		end
		position = player:GetAttribute("ReachedRoadCheckpoint") and city.CityArrival.Position or city.RoadCheckpoint.Position
	elseif stage == 6 then
		text, position = "Raccoon City. Find the Butterfly Corps headquarters.", city.ButterflyEntrance.Position
	elseif stage == 7 then
		text = "You reached Butterfly Corps. The next chapter awaits."
	else return end
	player:SetAttribute("Objective", text)
	player:SetAttribute("ObjectivePos", position)
end
local function advance(player, stage)
	if (player:GetAttribute("CityStage") or 0) < stage then player:SetAttribute("CityStage", stage) end
	objective(player)
end
local function begin(player)
	if (player:GetAttribute("EscapeStage") or 0) < 8 or player:GetAttribute("CityStage") then return end
	player:SetAttribute("CityStage", player:GetAttribute("CourtyardCarKey") and 2 or 1)
	local vehicleState = car.GetState()
	if house:GetAttribute("CourtyardCarWrecked") or (house:GetAttribute("CourtyardGateOpen") and (vehicleState.ExitedGate or vehicleState.AtCity)) then
		player:SetAttribute("CityRouteOnFoot", true)
		advance(player, 5)
	end
	objective(player)
end
local function gateSeen(player)
	if (player:GetAttribute("CityStage") or 0) < 1 then return end
	if not player:GetAttribute("CourtyardGateSeen") then
		player:SetAttribute("CourtyardGateSeen", true)
		if not house:GetAttribute("CourtyardGateOpen") and not house:GetAttribute("CourtyardCarWrecked") then
			advance(player, 4)
			notify(player, "THE EXIT IS LOCKED.", "warn")
		end
	end
end
local function part(parent, name, size, cf, color, material)
	local p = Instance.new("Part")
	p.Name, p.Size, p.CFrame, p.Color = name, size, cf, color
	p.Material, p.Anchored = material or Enum.Material.Metal, true
	p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
	p.Parent = parent
	return p
end
local function prompt(parent, name, objectText, action, hold, distance)
	local old = parent:FindFirstChild(name)
	if old then old:Destroy() end
	local p = Instance.new("ProximityPrompt")
	p.Name, p.ObjectText, p.ActionText = name, objectText, action
	p.HoldDuration, p.MaxActivationDistance = hold, distance or CFG.PromptDistance
	p.KeyboardKeyCode, p.GamepadKeyCode = Enum.KeyCode.E, Enum.KeyCode.ButtonX
	p.RequiresLineOfSight = true
	p.Parent = parent
	return p
end
local function smashGate(player)
	if house:GetAttribute("CourtyardCarWrecked") then return end
	house:SetAttribute("CourtyardCarWrecked", true)
	gatePrompt.Enabled = false
	trunkPrompt.Enabled = false
	for _, p in ipairs(gate:GetDescendants()) do
		if p:IsA("BasePart") then p.CanCollide = false; p.CanQuery = false; p.Transparency = 1 end
	end
	local wreck = Instance.new("Model")
	wreck.Name, wreck.Parent = "BentGateRailings", house
	local gateFrame = origin * CFrame.new(34, 0, 120)
	-- Railings fold around the bonnet, leaving a visible walking gap on each side.
	for index = -3, 3 do
		local cf = gateFrame * CFrame.new(index * 0.85, 2.4, -1.5 + math.abs(index) * 0.2)
			* CFrame.Angles(math.rad(60), 0, math.rad(index * 6))
		part(wreck, "BuckledRail", Vector3.new(0.17, 5.6, 0.17), cf, Color3.fromRGB(81, 87, 83))
	end
	part(wreck, "BentCrossbar", Vector3.new(7.8, 0.3, 0.3), gateFrame * CFrame.new(0, 3.7, -3.5) * CFrame.Angles(0, 0, math.rad(9)), Color3.fromRGB(81, 87, 83))
	for _, p in ipairs(Players:GetPlayers()) do
		if (p:GetAttribute("CityStage") or 0) > 0 and (p:GetAttribute("CityStage") or 0) < 6 then
			p:SetAttribute("CityRouteOnFoot", true)
			advance(p, 5)
			checkpoint(p, house.GateExitCheckpoint.Position + Vector3.new(6, 0, 0))
			notify(p, "THE CAR IS WEDGED IN THE RAILINGS. Get out and take the road on foot.", "warn")
		end
	end
end
local function enterRoad(player)
	if player:GetAttribute("LeftCourtyard") then return end
	player:SetAttribute("LeftCourtyard", true)
	advance(player, 5)
	checkpoint(player, house.GateExitCheckpoint.Position + Vector3.new(-6, 0, 0))
end
local function arriveCity(player)
	if (player:GetAttribute("CityStage") or 0) >= 6 then return end
	advance(player, 6)
	player:SetAttribute("ReachedRaccoonCity", true)
	checkpoint(player, city.CityArrival.Position + Vector3.new(-8, 0, 0))
	notify(player, "RACCOON CITY. Look for Butterfly Corps.", "info")
end
car = Vehicle.Create(house, origin, {
	Gate = gate, CityStopZ = city.CityArrival.Position.Z,
	CanEnter = function(player)
		if (player:GetAttribute("EscapeStage") or 0) < 8 then notify(player, "SECURE THE HOUSE FIRST.", "warn"); return false end
		if not player:GetAttribute("CourtyardCarKey") then notify(player, "THE IGNITION IS LOCKED. Search the house.", "warn"); return false end
		return true
	end,
	Notify = notify, OnGateSeen = gateSeen, OnCrash = smashGate,
	OnExitedGate = enterRoad, OnCityArrived = arriveCity,
})
local keys = Instance.new("Model")
keys.Name, keys.Parent = "CourtyardCarKeys", house
local keyPosition = house.CarKeySpot.CFrame
local brass = Color3.fromRGB(189, 157, 74)
local keyMain = part(keys, "Key", Vector3.new(0.14, 0.58, 0.09), keyPosition * CFrame.new(0, -0.15, 0), brass)
keys.PrimaryPart = keyMain
for index = 0, 7 do
	local angle = index * math.pi / 4
	part(keys, "KeyRing", Vector3.new(0.17, 0.07, 0.07), keyPosition * CFrame.new(math.cos(angle) * 0.2, 0.25 + math.sin(angle) * 0.2, 0) * CFrame.Angles(0, 0, angle + math.pi / 2), brass)
end
part(keys, "KeyTeeth", Vector3.new(0.3, 0.12, 0.09), keyPosition * CFrame.new(0.1, -0.38, 0), brass)
local keyPrompt = prompt(keyMain, "TakeCarKeys", "Car keys", "Take", 0.3, 6)
keyPrompt.Triggered:Connect(function(player)
	if (player:GetAttribute("EscapeStage") or 0) < 6 or not near(player, keyMain.Position, 7) then return end
	if player:GetAttribute("CourtyardCarKey") then notify(player, "You already have the car keys."); return end
	player:SetAttribute("CourtyardCarKey", true)
	if player:GetAttribute("CityStage") == 1 then advance(player, 2) end
	notify(player, "CAR KEYS ACQUIRED.", "item")
end)
trunkPrompt = prompt(car.Trunk, "SearchTrunk", "Car trunk", "Search", 1.2, CFG.TrunkDistance)
trunkPrompt.Triggered:Connect(function(player)
	if not near(player, car.Trunk.Position, CFG.TrunkDistance + 1) or not player:GetAttribute("CourtyardCarKey") then return end
	if house:GetAttribute("CourtyardCarWrecked") or not player:GetAttribute("CourtyardGateSeen") then return end
	local _, hum = alive(player)
	if not hum or hum.SeatPart then return end
	if player:GetAttribute("CourtyardGateKey") then notify(player, "The trunk is empty."); return end
	player:SetAttribute("CourtyardGateKey", true)
	local lid = car.Model:FindFirstChild("TrunkLid", true)
	if lid and not car.Model:GetAttribute("TrunkSearched") then
		car.Model:SetAttribute("TrunkSearched", true)
		lid.Transparency = 0.75
	end
	notify(player, "An iron key was tucked under the spare tyre.", "item")
	objective(player)
end)
gatePrompt = prompt(house.GateInteraction, "OpenCourtyardGate", "Courtyard exit", "Unlock", 0.8)
gatePrompt.RequiresLineOfSight = false
gatePrompt.Triggered:Connect(function(player)
	if opening or house:GetAttribute("CourtyardGateOpen") or house:GetAttribute("CourtyardCarWrecked") then return end
	if not near(player, house.GateInteraction.Position, CFG.PromptDistance + 1) or (player:GetAttribute("CityStage") or 0) < 1 then return end
	gateSeen(player)
	if not player:GetAttribute("CourtyardGateKey") then notify(player, "LOCKED. You need the right key.", "warn"); return end
	opening = true
	gatePrompt.Enabled = false
	-- The barrier stays closed until the sliding gate finishes moving.
	local start = gate.PrimaryPart.CFrame
	local goal = start + origin:VectorToWorldSpace(Vector3.new(-18, 0, 0))
	local value = Instance.new("CFrameValue")
	value.Value = start
	local changed = value:GetPropertyChangedSignal("Value"):Connect(function() gate:SetPrimaryPartCFrame(value.Value) end)
	local tween = TweenService:Create(value, TweenInfo.new(CFG.GateSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {Value = goal})
	tween:Play()
	tween.Completed:Wait()
	changed:Disconnect()
	value:Destroy()
	if house:GetAttribute("CourtyardCarWrecked") then opening = false; return end
	gate.PrimaryPart.CanCollide = false
	house:SetAttribute("CourtyardGateOpen", true)
	car.SetGateOpen()
	opening = false
	for _, p in ipairs(Players:GetPlayers()) do
		if (p:GetAttribute("CityStage") or 0) > 0 and (p:GetAttribute("CityStage") or 0) < 5 then advance(p, 5) end
	end
	notify(player, "GATE UNLOCKED. The road leads to Raccoon City.", "item")
end)

-- The two outdoor creatures remain independent of the house headshot encounter.
local actorFolder = Instance.new("Folder")
actorFolder.Name, actorFolder.Parent = "WildernessActors", workspace
local forest = workspace:WaitForChild("ForestTunnel")
local forestStart = Vector3.new(forest.AsphaltRoad.Position.X, origin.Y, forest.AsphaltRoad.Position.Z - forest.AsphaltRoad.Size.Z / 2)
local giant = Mutants.CreateGiant(actorFolder, CFrame.new(forestStart + CFG.GiantOffset))
local giantPoints = {}
for _, point in ipairs({Vector3.new(23, 0, 45), Vector3.new(32, 0, 74), Vector3.new(19, 0, 90), Vector3.new(15, 0, 58)}) do
	table.insert(giantPoints, forestStart + point)
end
Mutants.Start(giant, {
	PatrolPoints = giantPoints, BoundsOrigin = CFrame.new(forestStart + Vector3.new(16, 0, 65)), BoundsHalfSize = Vector3.new(31, 25, 42),
	PlayerEligible = function(p) local stage = p:GetAttribute("EscapeStage") or 0; return stage >= 1 and stage < 5 end,
	Notice = notify,
})
local dogPosition = house.DogSpawn.Position
local dog = Mutants.CreateDog(actorFolder, CFrame.new(dogPosition.X, origin.Y, dogPosition.Z))
local dogPoints = {}
for _, point in ipairs({Vector3.new(-25, 0, 65), Vector3.new(18, 0, 65), Vector3.new(30, 0, 85), Vector3.new(-8, 0, 95)}) do
	table.insert(dogPoints, origin:PointToWorldSpace(point))
end
Mutants.Start(dog, {
	PatrolPoints = dogPoints, BoundsOrigin = origin * CFrame.new(0, 0, 60), BoundsHalfSize = Vector3.new(53, 15, 57),
	PlayerEligible = function(p) return (p:GetAttribute("EscapeStage") or 0) >= 5 and (p:GetAttribute("CityStage") or 0) < 6 end,
	Notice = notify,
})
local function initPlayer(player)
	player:GetAttributeChangedSignal("EscapeStage"):Connect(function() begin(player) end)
	player.CharacterAdded:Connect(function()
		task.defer(function()
			if player.Parent == Players then begin(player); objective(player) end
		end)
	end)
	begin(player)
end
Players.PlayerAdded:Connect(initPlayer)
for _, p in ipairs(Players:GetPlayers()) do initPlayer(p) end
local elapsed = 0
RunService.Heartbeat:Connect(function(dt)
	elapsed += dt
	if elapsed < CFG.PollSeconds then return end
	elapsed = 0
	for _, player in ipairs(Players:GetPlayers()) do
		local _, humanoid, root = alive(player)
		local stage = player:GetAttribute("CityStage") or 0
		if root and stage > 0 then
			if stage == 2 and car.Seat.Occupant == humanoid then advance(player, 3) end
			if stage == 3 and car.Seat.Occupant ~= humanoid and not player:GetAttribute("CourtyardGateSeen") then
				player:SetAttribute("CityStage", 2)
			end
			local localPos = origin:PointToObjectSpace(root.Position)
			if stage < 5 and near(player, house.GateInteraction.Position, 14) then gateSeen(player) end
			if stage <= 5 and not player:GetAttribute("LeftCourtyard") and localPos.Z > 124 and (house:GetAttribute("CourtyardGateOpen") or house:GetAttribute("CourtyardCarWrecked")) then enterRoad(player) end
			stage = player:GetAttribute("CityStage") or 0
			if stage == 5 then
				if root.Position.Z >= city.RoadCheckpoint.Position.Z - 5 and not player:GetAttribute("ReachedRoadCheckpoint") then
					player:SetAttribute("ReachedRoadCheckpoint", true)
					checkpoint(player, city.RestHutCheckpoint.Position)
					notify(player, "ROADSIDE SHELTER. Checkpoint reached.")
				end
				if (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(city.CityArrival.Position.X, 0, city.CityArrival.Position.Z)).Magnitude <= CFG.CityArrivalRadius then
					arriveCity(player)
				end
			elseif stage == 6 and near(player, city.ButterflyEntrance.Position, CFG.HeadquartersRadius) then
				-- Require the player to enter the lobby on foot, not stop outside the wall.
				local doorPosition = city.ButterflyEntrance.CFrame:PointToObjectSpace(root.Position)
				if not humanoid.SeatPart and math.abs(doorPosition.X) < 7 and doorPosition.Z > -4 then
					advance(player, 7)
					player:SetAttribute("ReachedButterflyCorps", true)
					checkpoint(player, city.ButterflyEntrance.Position)
					local finish = workspace:GetServerTimeNow()
					player:SetAttribute("FinishTime", finish)
					remote:FireClient(player, "CityComplete", finish - (player:GetAttribute("StartTime") or finish), player:GetAttribute("Deaths") or 0)
				end
			end
			objective(player)
		end
	end
end)
