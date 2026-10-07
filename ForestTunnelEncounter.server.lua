-- Imported forest assets live in Workspace; all encounter decisions run on the server.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local CFG = {
	Damage = 25,
	PromptDistance = 7,
	PollSeconds = 0.05,
	GateSeconds = 2.5,
	AmbushHalfSize = Vector3.new(3.85, 4.2, 1.8),
}

local world = workspace:WaitForChild("ForestTunnel", 30)
if not world then warn("ForestTunnel assets are missing; encounter not started") return end
local key = world:WaitForChild("GateKey")
local gate = world:WaitForChild("GateLeaf")
local mutant = world:WaitForChild("AmbushMutant")
local floor = world:WaitForChild("VanFloor")
local runtime = world:FindFirstChild("EncounterRuntime")
if runtime then runtime:Destroy() end
runtime = Instance.new("Folder")
runtime.Name = "EncounterRuntime"
runtime.Parent = world

local function notify(player, message, kind)
	local remote = ReplicatedStorage:FindFirstChild("CourierRemote")
	if remote then remote:FireClient(player, "Notice", message, kind or "info") end
end

local function prompt(parent, name, objectText, actionText, hold)
	local previous = parent:FindFirstChild(name)
	if previous then previous:Destroy() end
	local result = Instance.new("ProximityPrompt")
	result.Name = name
	result.ObjectText = objectText
	result.ActionText = actionText
	result.HoldDuration = hold
	result.MaxActivationDistance = CFG.PromptDistance
	result.RequiresLineOfSight = false
	result.KeyboardKeyCode = Enum.KeyCode.E
	result.Parent = parent
	return result
end

local function aliveNear(player, position)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then return end
	if (root.Position - position).Magnitude > CFG.PromptDistance + 1 then return end
	return character, humanoid, root
end

-- Floor position anchors the encounter even if the imported model is moved.
local origin = Vector3.new(floor.Position.X, floor.Position.Y - 0.75, floor.Position.Z - 125)
local function point(x, y, distance)
	return origin + Vector3.new(x, y, distance)
end
local function block(name, center, size)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.Position = center
	part.Transparency = 1
	part.CanCollide = true
	part.CanQuery = false
	part.CanTouch = false
	part.Parent = runtime
	return part
end

-- Joined scenery meshes have broad collision hulls; dedicated invisible boundaries
-- leave the van aisle clear and prevent jumping across the pile-up or locked gate.
for _, object in ipairs(world:GetChildren()) do
	if object:IsA("MeshPart") then
		object.Anchored = true
		object.DoubleSided = true
		if object.Name:match("^Pines_") or object.Name:match("^RockRidge_")
			or object == mutant or object == key or object.Name == "FadedRoadMarkings" then
			object.CanCollide = false
		end
	end
end
local plate = workspace:WaitForChild("Baseplate")
local west = plate.Position.X - plate.Size.X / 2
local east = plate.Position.X + plate.Size.X / 2
local function crossBarrier(prefix, distance, halfGap)
	local leftEdge = origin.X - halfGap
	local rightEdge = origin.X + halfGap
	block(prefix .. "West", Vector3.new((west + leftEdge) / 2, origin.Y + 40, origin.Z + distance),
		Vector3.new(math.max(1, leftEdge - west), 80, 2))
	block(prefix .. "East", Vector3.new((east + rightEdge) / 2, origin.Y + 40, origin.Z + distance),
		Vector3.new(math.max(1, east - rightEdge), 80, 2))
end
crossBarrier("WreckBarrier", 125, 4)
block("WreckOverhead", point(0, 44, 125), Vector3.new(8, 72, 2))
crossBarrier("GateBoundary", 174, 7.6)
local gateBlock = block("LockedGate", point(0, 40, 174), Vector3.new(15.2, 80, 1))

local keyPrompt = prompt(key, "TakeGateKey", "Tunnel gate key", "Take key", 0)
local gateAttachment = Instance.new("Attachment")
gateAttachment.Name = "GateInteraction"
gateAttachment.Position = gate.CFrame:PointToObjectSpace(point(0, 3.5, 172.5))
gateAttachment.Parent = gate
local gatePrompt = prompt(gateAttachment, "UnlockGate", "Forest exit gate", "Unlock with key", 1)
world:SetAttribute("GateOpen", false)
world:SetAttribute("AmbushDamage", CFG.Damage)

local function lamp(parent, color, brightness, range)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = brightness
	light.Range = range
	light.Shadows = false
	light.Parent = parent
end
lamp(key, Color3.fromRGB(231, 190, 105), 1.5, 10)
lamp(world:WaitForChild("TunnelSign"), Color3.fromRGB(172, 191, 190), 1.4, 24)
lamp(world:WaitForChild("VanRoof"), Color3.fromRGB(165, 185, 160), 0.8, 16)

local function sign(parent, text)
	local surface = Instance.new("SurfaceGui")
	surface.Name = "RouteSign"
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 40
	surface.LightInfluence = 0
	surface.Parent = parent
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(221, 221, 197)
	label.Parent = surface
end
sign(world.TunnelSign, "EVACUATION TUNNEL\nROAD BLOCKED • USE VAN")
sign(world.GateSign, "EXIT GATE\nKEY IN VAN")

-- Keys are personal and survive a respawn. Keep the prop for other players.
local function collectKey(player)
	if (player:GetAttribute("EscapeStage") or 0) < 3 then return end
	local character, _, root = aliveNear(player, key.Position)
	if not character then return end
	local localPosition = root.Position - origin
	if math.abs(localPosition.X) > 3.95 or localPosition.Z < 128 or localPosition.Z > 139 then return end
	if player:GetAttribute("ForestGateKey") then
		notify(player, "You already have the exit key. Reach the gate beyond the tunnel.")
		return
	end
	player:SetAttribute("ForestGateKey", true)
	notify(player, "Exit key collected. Unlock the gate beyond the tunnel.", "success")
end
keyPrompt.Triggered:Connect(collectKey)

local opening = false
local function unlockGate(player)
	if (player:GetAttribute("EscapeStage") or 0) < 3 then return end
	if opening or world:GetAttribute("GateOpen") then return end
	if not aliveNear(player, gateAttachment.WorldPosition) then return end
	if not player:GetAttribute("ForestGateKey") then
		notify(player, "Locked. The exit key is on the shelf inside the van.", "warning")
		return
	end
	opening = true
	gatePrompt.Enabled = false
	notify(player, "Gate unlocked.", "success")
	local tween = TweenService:Create(gate, TweenInfo.new(CFG.GateSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
		{CFrame = gate.CFrame + Vector3.new(0, 10, 0)})
	tween:Play()
	tween.Completed:Wait()
	gate.CanCollide = false
	gateBlock.CanCollide = false
	world:SetAttribute("GateOpen", true)
	opening = false
end
gatePrompt.Triggered:Connect(unlockGate)

local rest = mutant.CFrame
local lunging = false
local function lunge()
	if lunging then return end
	lunging = true
	local strike = TweenService:Create(mutant, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{CFrame = rest + Vector3.new(-1.1, 0, -0.45)})
	strike:Play()
	task.delay(0.4, function()
		if not mutant.Parent then return end
		local retreat = TweenService:Create(mutant, TweenInfo.new(0.65), {CFrame = rest})
		retreat:Play()
		retreat.Completed:Wait()
		lunging = false
	end)
end

local ambushCenter = point(0, 4.2, 125.5)
local previous = setmetatable({}, {__mode = "k"})
-- Swept root segment catches a sprint across the thin trigger between polls.
local function crosses(a, b)
	local low, high = 0, 1
	local delta = b - a
	for _, axis in ipairs({"X", "Y", "Z"}) do
		local start, change, extent = a[axis], delta[axis], CFG.AmbushHalfSize[axis]
		if math.abs(change) < 0.0001 then
			if math.abs(start) > extent then return false end
		else
			local enter, leave = (-extent - start) / change, (extent - start) / change
			if enter > leave then enter, leave = leave, enter end
			low, high = math.max(low, enter), math.min(high, leave)
			if low > high then return false end
		end
	end
	return true
end
local elapsed = 0
RunService.Heartbeat:Connect(function(dt)
	elapsed += dt
	if elapsed < CFG.PollSeconds then return end
	elapsed = 0
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and humanoid and humanoid.Health > 0 and (player:GetAttribute("EscapeStage") or 0) >= 3 then
			local current = root.Position - ambushCenter
			local last = previous[character] or current
			previous[character] = current
			if not character:GetAttribute("VanAmbushHit") and crosses(last, current) then
				character:SetAttribute("VanAmbushHit", true)
				-- This authored ambush intentionally guarantees a single hit, including during spawn protection.
				humanoid.Health = math.max(0, humanoid.Health - CFG.Damage)
				lunge()
				notify(player, "The mutant strikes! -25 health. Find the key inside the van.", "warning")
			end
			-- Walking close to the shelf collects the key without requiring a camera-facing prompt.
			-- collectKey still checks that the player is physically inside the van.
			if not player:GetAttribute("ForestGateKey")
				and character:GetAttribute("VanAmbushHit")
				and (root.Position - key.Position).Magnitude <= 4.5 then
				collectKey(player)
			end
			if player:GetAttribute("ForestGateKey") and not opening and not world:GetAttribute("GateOpen")
				and (root.Position - gateAttachment.WorldPosition).Magnitude <= 5 then
				task.spawn(unlockGate, player)
			end
		end
	end
end)
