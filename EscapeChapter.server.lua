-- Chapter two: courier van -> tunnel ambush/key -> gate -> ranger house.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Builder = require(ServerScriptService:WaitForChild("EscapeHouseBuilder"))
local Mutants = require(ServerScriptService:WaitForChild("EscapeMutants"))
local Vehicle = require(ServerScriptService:WaitForChild("CourierVehicle"))
local forest = workspace:WaitForChild("ForestTunnel")
local floor = forest:WaitForChild("VanFloor")
local gate = forest:WaitForChild("GateLeaf")
local gatePosition = gate.Position -- the gate later slides upward
local road = forest:WaitForChild("AsphaltRoad")
local groundY = floor.Position.Y - 0.75
local CFG = {
	FenceDamage = 20, FenceCooldown = 2, RefillCooldown = 8,
	PromptDistance = 9, ThinkSeconds = 0.1, AmbushDelay = 7,
	HouseOrigin = CFrame.new(road.Position.X, groundY, gatePosition.Z + 16),
	TunnelStopZ = floor.Position.Z - 36,
}
local house = Builder.Build(CFG.HouseOrigin)
local oldActors = house:FindFirstChild("Actors")
if oldActors then oldActors:Destroy() end
local actors = Instance.new("Folder")
actors.Name, actors.Parent = "Actors", house
local sleeper = Mutants.Create(actors, "BedMutant", house.SleeperSpawn.CFrame, true)
local remote = ReplicatedStorage:WaitForChild("CourierRemote")
local weapon = ReplicatedStorage:WaitForChild("SurvivalWeapon")
local weaponConfig = require(weapon:WaitForChild("Config"))
local addAmmo = weapon:WaitForChild("AddAmmo")
local van = workspace:WaitForChild("CourierWorld"):WaitForChild("CourierVan")
local vehicle
local runner, ambushQueued, runnerDefeated = nil, false, false
local previous, shocks, refills = {}, {}, {}
local function notify(player, text, kind)
	remote:FireClient(player, "Notice", text, kind or "info")
end
local function alive(player)
	local character = player.Character
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if hum and root and hum.Health > 0 then return character, hum, root end
end
local function near(player, part)
	local character, hum, root = alive(player)
	if root and (root.Position - part.Position).Magnitude <= CFG.PromptDistance + 1 then return character, hum, root end
end
local function checkpoint(player, position)
	player:SetAttribute("EscapeCheckpoint", CFrame.lookAt(position, position + Vector3.new(0, 0, 1)))
end
local function objective(player)
	local stage = player:GetAttribute("EscapeStage") or 0
	local text, pos
	if stage == 1 then text, pos = "Enter the courier van. Drive to the evacuation tunnel.", vehicle.Seat.Position
	elseif stage == 2 then text, pos = "Drive to the tunnel. W/S accelerate and brake; A/D steer.", Vector3.new(road.Position.X, groundY + 3, CFG.TunnelStopZ)
	elseif stage == 3 then text, pos = "Road blocked. Cross the wrecked van and find the gate key.", forest.GateKey.Position
	elseif stage == 4 then text, pos = "Use the tunnel key, then cross the exit gate.", gatePosition
	elseif stage == 5 then text, pos = "Reach the house through the live fence. Expect a shock.", house.ElectricThreshold.Position
	elseif stage == 6 then text, pos = "Get inside. Refill ammunition at the supply crate.", house.AmmoCrate.Position
	elseif stage == 7 then text, pos = "Kill the charging mutant. Only a HEADSHOT will stop it.", runner and runner.PrimaryPart.Position or house.AttackerSpawn.Position
	elseif stage == 8 then
		if player:GetAttribute("CityStage") then return end
		text = "House secured. Find a vehicle to reach Raccoon City."
	else return end
	player:SetAttribute("Objective", text)
	player:SetAttribute("ObjectivePos", pos)
end
local function advance(player, stage)
	if (player:GetAttribute("EscapeStage") or 0) >= stage then return end
	player:SetAttribute("EscapeStage", stage)
	objective(player)
end
local function complete(player)
	if (player:GetAttribute("EscapeStage") or 0) ~= 7 then return end
	advance(player, 8)
	player:SetAttribute("EscapeComplete", true)
	player:SetAttribute("HouseCleared", true)
	checkpoint(player, house.YardCheckpoint.Position)
	notify(player, "HOUSE SECURED. There is a car in the courtyard.", "item")
end
local function beginAmbush()
	if ambushQueued or runnerDefeated then return end
	ambushQueued = true
	task.delay(CFG.AmbushDelay, function()
		if not house.Parent then return end
		runner = Mutants.Create(actors, "ChargingMutant", house.AttackerSpawn.CFrame, false)
		Mutants.StartChase(runner, house, function(killerId)
			runnerDefeated = true
			house:SetAttribute("RunnerDefeated", true)
			house:SetAttribute("RunnerKilledBy", killerId)
			for _, p in ipairs(Players:GetPlayers()) do
				if (p:GetAttribute("EscapeStage") or 0) == 7 then complete(p) end
			end
		end)
		for _, p in ipairs(Players:GetPlayers()) do
			if (p:GetAttribute("EscapeStage") or 0) == 7 then notify(p, "IT'S COMING! AIM FOR THE HEAD.", "warn") end
		end
	end)
end
vehicle = Vehicle.Attach(van, {
	RoadCenterX = road.Position.X, RoadStartZ = road.Position.Z - road.Size.Z / 2 + 6,
	StopZ = CFG.TunnelStopZ, GroundY = groundY,
	Notify = notify,
	OnArrived = function(player)
		player:SetAttribute("DroveToTunnel", true)
		advance(player, 3)
		checkpoint(player, Vector3.new(road.Position.X, groundY + 3.5, CFG.TunnelStopZ + 7))
		notify(player, "ROAD BLOCKED. Leave the car and cross the wrecked van.", "warn")
	end,
})
local ammoPrompt = Instance.new("ProximityPrompt")
ammoPrompt.Name, ammoPrompt.ObjectText, ammoPrompt.ActionText = "RefillAmmo", "Ranger ammunition cache", "Refill handgun ammo"
ammoPrompt.HoldDuration, ammoPrompt.MaxActivationDistance = 0.6, CFG.PromptDistance
ammoPrompt.RequiresLineOfSight = false
ammoPrompt.KeyboardKeyCode = Enum.KeyCode.E
ammoPrompt.Parent = house.AmmoCrate
ammoPrompt.Triggered:Connect(function(player)
	if not near(player, house.AmmoCrate) or (player:GetAttribute("EscapeStage") or 0) < 6 then return end
	if os.clock() - (refills[player] or -math.huge) < CFG.RefillCooldown then
		notify(player, "Check the cache again in a moment.")
		return
	end
	refills[player] = os.clock()
	addAmmo:Fire(player, weaponConfig.MaxReserve)
	player:SetAttribute("HouseAmmoRefilled", true)
	notify(player, "AMMO REFILLED. Press R to reload. Aim for the mutant's head.", "item")
	advance(player, 7)
	checkpoint(player, house.YardCheckpoint.Position)
	if runnerDefeated then complete(player) else beginAmbush() end
end)
house:SetAttribute("EscapeRuntimeReady", true)
local function startPlayer(player)
	local function deliveryChanged()
		if player:GetAttribute("Delivered") and not player:GetAttribute("EscapeStage") then
			advance(player, 1)
			checkpoint(player, Vector3.new(vehicle.Seat.Position.X + 6, groundY + 3.5, vehicle.Seat.Position.Z))
			notify(player, "CASE LOADED. Enter the driver's seat to continue.", "item")
		end
	end
	player:GetAttributeChangedSignal("Delivered"):Connect(deliveryChanged)
	player.CharacterAdded:Connect(function() previous[player], shocks[player] = nil, nil end)
	deliveryChanged()
end
Players.PlayerAdded:Connect(startPlayer)
for _, player in ipairs(Players:GetPlayers()) do startPlayer(player) end
Players.PlayerRemoving:Connect(function(player) previous[player], shocks[player], refills[player] = nil, nil, nil end)
local function inside(part, position, margin)
	local p = part.CFrame:PointToObjectSpace(position)
	local half = part.Size / 2 + Vector3.new(margin or 0, margin or 0, margin or 0)
	return math.abs(p.X) <= half.X and math.abs(p.Y) <= half.Y and math.abs(p.Z) <= half.Z
end
local function crossedFence(a, b)
	local threshold = house.ElectricThreshold
	if inside(threshold, b) then return true end
	if not a or (b - a).Magnitude > 40 then return false end
	local localA, localB = threshold.CFrame:PointToObjectSpace(a), threshold.CFrame:PointToObjectSpace(b)
	if localA.Z * localB.Z > 0 or math.abs(localB.Z - localA.Z) < 0.001 then return false end
	local hit = localA:Lerp(localB, -localA.Z / (localB.Z - localA.Z))
	return math.abs(hit.X) <= threshold.Size.X / 2 and math.abs(hit.Y) <= threshold.Size.Y / 2
end
local elapsed = 0
RunService.Heartbeat:Connect(function(dt)
	elapsed += dt
	if elapsed < CFG.ThinkSeconds then return end
	elapsed = 0
	for _, player in ipairs(Players:GetPlayers()) do
		local character, hum, root = alive(player)
		local stage = player:GetAttribute("EscapeStage") or 0
		if root and stage > 0 then
			if stage <= 2 then
				if van:GetAttribute("ArrivedAtTunnel") then
					-- Other couriers can follow the already-cleared drive on foot.
					advance(player, 3)
					checkpoint(player, Vector3.new(road.Position.X, groundY + 3.5, CFG.TunnelStopZ + 7))
				else
					local seated = vehicle.Seat.Occupant == hum
					local targetStage = seated and 2 or 1
					if stage ~= targetStage then player:SetAttribute("EscapeStage", targetStage) end
				end
			elseif stage == 3 and player:GetAttribute("ForestGateKey") then
				advance(player, 4)
				checkpoint(player, Vector3.new(road.Position.X, groundY + 3.5, floor.Position.Z + 22))
			elseif stage == 4 and forest:GetAttribute("GateOpen") and root.Position.Z > gatePosition.Z + 3 then
				advance(player, 5)
				checkpoint(player, Vector3.new(road.Position.X, groundY + 3.5, gatePosition.Z + 7))
				notify(player, "A HOUSE AHEAD. The fence is still powered.", "warn")
			end
			stage = player:GetAttribute("EscapeStage") or 0
			if stage >= 5 then
				if crossedFence(previous[player], root.Position) and os.clock() - (shocks[player] or -math.huge) >= CFG.FenceCooldown then
					shocks[player] = os.clock()
					hum.Health = math.max(0, hum.Health - CFG.FenceDamage)
					character:SetAttribute("ElectricFenceHit", true)
					notify(player, "ELECTRIC SHOCK! -" .. CFG.FenceDamage .. " HEALTH", "warn")
				end
				local localPos = house.ElectricThreshold.CFrame:PointToObjectSpace(root.Position)
				if stage == 5 and character:GetAttribute("ElectricFenceHit") and localPos.Z > 2 and hum.Health > 0 then
					advance(player, 6)
					checkpoint(player, house.YardCheckpoint.Position)
				end
			end
			previous[player] = root.Position
			objective(player)
		end
	end
end)
