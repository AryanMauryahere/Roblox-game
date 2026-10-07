-- CourierGame (Script, ServerScriptService)
-- 1) Objective chain: reach hospital -> staff keycard -> unlock stairwell door -> specimen case (2nd floor) -> courier van
-- 2) Pickups: handgun ammo, first aid spray, keycard, specimen case
-- 3) Survival: no health regen (see Health script), first aid spray, limp at low health, checkpoints
--
-- World positions are built relative to the hospital origin, using the same math as HospitalLayout.
-- If you change HospitalLayout (cell size, offsets, rooms), update the LOCAL coordinates below.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local CFG = {
	MaxHealth = 100,
	MedkitHeal = 50,
	MedkitCooldown = 1.5,
	MaxMedkits = 3,
	AmmoPerPickup = 4,
	DefaultMaxReserve = 24,
	BaseWalkSpeed = 16,
	LimpWalkSpeed = 11,
	LimpBelow = 0.30, -- fraction of max health
	RespawnTime = 5,
}

pcall(function()
	Players.RespawnTime = CFG.RespawnTime
end)

----------------------------------------------------------------------
-- Remote + weapon hooks
----------------------------------------------------------------------
local remote = ReplicatedStorage:FindFirstChild("CourierRemote")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "CourierRemote"
	remote.Parent = ReplicatedStorage
end

local weaponPackage = ReplicatedStorage:WaitForChild("SurvivalWeapon")
local weaponConfig = require(weaponPackage:WaitForChild("Config"))
local addAmmo = weaponPackage:WaitForChild("AddAmmo", 15) -- BindableEvent made by SurvivalWeaponServer
local MAX_RESERVE = weaponConfig.MaxReserve or CFG.DefaultMaxReserve

local function notify(player, text, kind)
	remote:FireClient(player, "Notice", text, kind or "info")
end

----------------------------------------------------------------------
-- Hospital origin (same math as HospitalLayout)
----------------------------------------------------------------------
local baseplate = workspace:WaitForChild("Baseplate")
local origin = baseplate.CFrame * CFrame.new(
	math.clamp(90, -baseplate.Size.X / 2 + 4, baseplate.Size.X / 2 - 60),
	baseplate.Size.Y / 2,
	math.clamp(24, -baseplate.Size.Z / 2 + 53, baseplate.Size.Z / 2 - 11)
)

local function L(x, y, z)
	return origin * CFrame.new(x, y, z)
end

local function LP(x, y, z)
	return L(x, y, z).Position
end

local FLOOR = 0.5   -- floor 1 walking surface, in local hospital space
local FLOOR2 = 11.5 -- floor 2 walking surface (matches HospitalLayout: floor1 + wall height + slab)

-- Key locations (local hospital coordinates; x east, z negative = north)
local ENTRANCE_POS = LP(7, 1, 5)
local KEYCARD_CF = L(29.5, 3.5 + 0.04, -50)       -- on the nurses' counter, dead-end corridor
local PACKAGE_CF = L(42, FLOOR2 + 3 + 0.6, -52)  -- on the specimen table, 2nd-floor isolation ward
local DOOR_CF = L(14, FLOOR + 4, -31.5)           -- stairwell doorway off the corridor
local VAN_CF = L(-9, 0, 17)                       -- outside, beside the entrance

local LOBBY_CHECKPOINT = CFrame.lookAt(LP(7, FLOOR, -7), LP(7, FLOOR, -20))
local UPPER_CHECKPOINT = CFrame.lookAt(LP(14, FLOOR2, -63), LP(14, FLOOR2, -50)) -- 2nd-floor landing

-- The old standalone ward is gone, so start the player near the courier van.
local spawn = workspace:FindFirstChildOfClass("SpawnLocation")
if spawn then
	local spawnPos = LP(-30, 0.5, 26)
	local lookAt = LP(7, 0, 6)
	spawn.CFrame = CFrame.lookAt(spawnPos, Vector3.new(lookAt.X, spawnPos.Y, lookAt.Z))
end

----------------------------------------------------------------------
-- Build helpers
----------------------------------------------------------------------
local oldWorld = workspace:FindFirstChild("CourierWorld")
if oldWorld then
	oldWorld:Destroy()
end
local world = Instance.new("Folder")
world.Name = "CourierWorld"
world.Parent = workspace

local function newPart(parent, name, size, cf, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function solid(part)
	part.CanCollide = true
	part.CanQuery = true
	return part
end

local function addLight(part, color, brightness, range)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = brightness
	light.Range = range
	light.Shadows = false
	light.Parent = part
	return light
end

local function addPrompt(part, objectText, actionText, hold, distance)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText = objectText
	prompt.ActionText = actionText
	prompt.HoldDuration = hold or 0
	prompt.MaxActivationDistance = distance or 7
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = part
	return prompt
end

local PING = "rbxasset://sounds/electronicpingshort.wav"
local function playSound(part, id, volume)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume or 0.6
	s.RollOffMaxDistance = 60
	s.Parent = part
	s:Play()
	task.delay(3, function()
		s:Destroy()
	end)
end

----------------------------------------------------------------------
-- Objective tracking (stored as Player attributes so the HUD can read them)
----------------------------------------------------------------------
local doorOpened = false

local function updateObjective(player)
	local text, pos
	if player:GetAttribute("Delivered") then
		-- The escape chapter owns objectives once the specimen is loaded.
		if player:GetAttribute("EscapeStage") then return end
		text = "Enter the courier van and drive to the tunnel."
	elseif player:GetAttribute("HasPackage") then
		local van = world:FindFirstChild("CourierVan")
		local dropoff = van and van:FindFirstChild("DropOff")
		text, pos = "Get the specimen case back to your courier van.", dropoff and dropoff.Position or VAN_CF.Position
	elseif doorOpened then
		text, pos = "Retrieve the specimen case from the isolation ward upstairs.", PACKAGE_CF.Position
	elseif player:GetAttribute("HasKeycard") then
		text, pos = "Unlock the stairwell door.", DOOR_CF.Position
	elseif player:GetAttribute("ReachedLobby") then
		text, pos = "Find a staff keycard. Try the nurses' station.", KEYCARD_CF.Position
	else
		text, pos = "Reach the hospital.", ENTRANCE_POS
	end
	player:SetAttribute("Objective", text)
	player:SetAttribute("ObjectivePos", pos) -- nil clears it
end

local function updateAllObjectives()
	for _, player in ipairs(Players:GetPlayers()) do
		updateObjective(player)
	end
end

----------------------------------------------------------------------
-- Checkpoints (respawn position is applied when the new character loads)
----------------------------------------------------------------------
local checkpoints = {}

local function setCheckpoint(player, cf)
	checkpoints[player] = cf
end

----------------------------------------------------------------------
-- Pickups
----------------------------------------------------------------------
local function buildPickup(kind, cf)
	local model = Instance.new("Model")
	model.Name = kind .. "Pickup"
	model.Parent = world

	local main, objectText, actionText

	if kind == "Ammo" then
		main = newPart(model, "Box", Vector3.new(0.9, 0.45, 0.55), cf, Color3.fromRGB(70, 82, 58), Enum.Material.Metal)
		local label = newPart(model, "Label", Vector3.new(0.5, 0.05, 0.3), cf * CFrame.new(0, 0.24, 0),
			Color3.fromRGB(214, 176, 70), Enum.Material.Neon)
		addLight(label, Color3.fromRGB(214, 176, 70), 0.7, 7)
		objectText, actionText = "Handgun ammo", "Take"
	elseif kind == "Medkit" then
		main = newPart(model, "Case", Vector3.new(0.9, 0.55, 0.9), cf, Color3.fromRGB(225, 228, 230))
		local red = Color3.fromRGB(205, 30, 30)
		local crossA = newPart(model, "CrossA", Vector3.new(0.5, 0.05, 0.14), cf * CFrame.new(0, 0.29, 0), red, Enum.Material.Neon)
		newPart(model, "CrossB", Vector3.new(0.14, 0.05, 0.5), cf * CFrame.new(0, 0.29, 0), red, Enum.Material.Neon)
		addLight(crossA, Color3.fromRGB(255, 90, 90), 0.7, 7)
		objectText, actionText = "First aid spray", "Take"
	elseif kind == "Keycard" then
		main = newPart(model, "Card", Vector3.new(0.9, 0.06, 0.6), cf, Color3.fromRGB(70, 220, 130), Enum.Material.Neon)
		newPart(model, "Stripe", Vector3.new(0.9, 0.07, 0.14), cf * CFrame.new(0, 0, 0.12), Color3.fromRGB(20, 20, 20))
		addLight(main, Color3.fromRGB(70, 220, 130), 1.2, 9)
		objectText, actionText = "Staff keycard", "Take"
	elseif kind == "Package" then
		main = newPart(model, "Case", Vector3.new(2.2, 1.2, 1.4), cf, Color3.fromRGB(46, 50, 56), Enum.Material.Metal)
		newPart(model, "StripeA", Vector3.new(0.25, 1.22, 1.42), cf * CFrame.new(-0.6, 0, 0), Color3.fromRGB(220, 180, 40))
		newPart(model, "StripeB", Vector3.new(0.25, 1.22, 1.42), cf * CFrame.new(0.6, 0, 0), Color3.fromRGB(220, 180, 40))
		local led = newPart(model, "Led", Vector3.new(0.3, 0.12, 0.3), cf * CFrame.new(0, 0.66, 0), Color3.fromRGB(255, 40, 40), Enum.Material.Neon)
		addLight(led, Color3.fromRGB(255, 60, 60), 1.5, 12)
		objectText, actionText = "Specimen case", "Take"
	end

	model.PrimaryPart = main
	local prompt = addPrompt(main, objectText, actionText, kind == "Package" and 0.8 or 0.25, 7)
	local taken = false

	prompt.Triggered:Connect(function(player)
		if taken then
			return
		end

		if kind == "Ammo" then
			if (player:GetAttribute("WeaponReserve") or 0) >= MAX_RESERVE then
				notify(player, "SPARE AMMUNITION FULL", "warn")
				return
			end
			if not addAmmo then
				return
			end
			taken = true
			addAmmo:Fire(player, CFG.AmmoPerPickup)
			notify(player, "HANDGUN AMMO  +" .. CFG.AmmoPerPickup, "item")
		elseif kind == "Medkit" then
			local count = player:GetAttribute("Medkits") or 0
			if count >= CFG.MaxMedkits then
				notify(player, "CAN'T CARRY ANY MORE", "warn")
				return
			end
			taken = true
			player:SetAttribute("Medkits", count + 1)
			notify(player, "FIRST AID SPRAY  (H to use)", "item")
		elseif kind == "Keycard" then
			taken = true
			player:SetAttribute("HasKeycard", true)
			notify(player, "STAFF KEYCARD ACQUIRED", "item")
			updateObjective(player)
		elseif kind == "Package" then
			taken = true
			player:SetAttribute("HasPackage", true)
			setCheckpoint(player, UPPER_CHECKPOINT)
			notify(player, "SPECIMEN CASE SECURED", "item")
			updateObjective(player)
		end

		-- Hide immediately, destroy a moment later so the pickup sound can finish.
		prompt.Enabled = false
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Transparency = 1
			elseif d:IsA("PointLight") then
				d.Enabled = false
			end
		end
		playSound(main, PING, 0.5)
		task.delay(1.5, function()
			model:Destroy()
		end)
	end)

	return model
end

-- Handgun ammo
buildPickup("Ammo", L(12.2, 3.5 + 0.225, -9.6))      -- reception desk, lobby
buildPickup("Ammo", L(22, FLOOR + 0.225, -30.6))     -- corridor bend
buildPickup("Ammo", L(52.5, 2.5 + 0.225, -46.5))     -- bed, maternity ward (floor 1)
buildPickup("Ammo", L(34.5, FLOOR2 + 2 + 0.225, -55)) -- bed, isolation ward (floor 2)
-- First aid sprays
buildPickup("Medkit", L(0, 2.0 + 0.275, -3))         -- waiting bench, lobby
buildPickup("Medkit", L(38.5, 2.5 + 0.275, -34.5))   -- bed, maternity ward (floor 1)
buildPickup("Medkit", L(49.5, FLOOR2 + 2 + 0.275, -55)) -- bed, isolation ward (floor 2)
-- Objective items
buildPickup("Keycard", KEYCARD_CF)
buildPickup("Package", PACKAGE_CF)

----------------------------------------------------------------------
-- Locked stairwell door (floor 1 corridor -> stairs up)
----------------------------------------------------------------------
local door = solid(newPart(world, "StairwellDoor", Vector3.new(5, 8, 0.6), DOOR_CF,
	Color3.fromRGB(60, 66, 74), Enum.Material.Metal))

-- Keycard reader on the corridor-facing wall, just east of the doorway.
local readerCF = L(18.4, 4.6, -30.9)
newPart(world, "KeycardReader", Vector3.new(0.5, 0.9, 0.2), readerCF, Color3.fromRGB(30, 33, 38), Enum.Material.Metal)
local readerLed = newPart(world, "ReaderLed", Vector3.new(0.2, 0.2, 0.22), readerCF * CFrame.new(0, 0.2, 0.01),
	Color3.fromRGB(255, 40, 40), Enum.Material.Neon)
local readerLight = addLight(readerLed, Color3.fromRGB(255, 40, 40), 0.9, 8)

local doorPrompt = addPrompt(door, "Stairwell", "Open", 0, 8)
doorPrompt.Triggered:Connect(function(player)
	if doorOpened then
		return
	end
	if not player:GetAttribute("HasKeycard") then
		notify(player, "LOCKED  -  STAFF KEYCARD REQUIRED", "warn")
		return
	end
	doorOpened = true
	doorPrompt.Enabled = false
	door.CanCollide = false
	door.CanQuery = false
	readerLed.Color = Color3.fromRGB(60, 255, 120)
	readerLight.Color = Color3.fromRGB(60, 255, 120)
	playSound(door, "rbxasset://sounds/switch.wav", 0.7)
	-- Slide the door sideways into the wall beside the doorway.
	local goal = door.CFrame + origin:VectorToWorldSpace(Vector3.new(5.2, 0, 0))
	TweenService:Create(door, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { CFrame = goal }):Play()
	notify(player, "DOOR UNLOCKED", "item")
	updateAllObjectives()
end)

----------------------------------------------------------------------
-- Courier van (delivery point)
----------------------------------------------------------------------
local function buildVan()
	local van = Instance.new("Model")
	van.Name = "CourierVan"
	van.Parent = world

	local bodyColor = Color3.fromRGB(52, 66, 92)
	local dark = Color3.fromRGB(26, 28, 32)

	solid(newPart(van, "Body", Vector3.new(7.5, 4.2, 5.2), VAN_CF * CFrame.new(-1.4, 3.1, 0), bodyColor, Enum.Material.Metal))
	solid(newPart(van, "Cab", Vector3.new(3.4, 3.2, 5.2), VAN_CF * CFrame.new(4.0, 2.6, 0), bodyColor, Enum.Material.Metal))
	newPart(van, "Windshield", Vector3.new(0.2, 1.4, 4.4), VAN_CF * CFrame.new(5.75, 3.3, 0), Color3.fromRGB(20, 26, 32), Enum.Material.Glass)
	solid(newPart(van, "Bumper", Vector3.new(0.5, 0.6, 5.4), VAN_CF * CFrame.new(5.85, 1.2, 0), dark, Enum.Material.Metal))

	for _, x in ipairs({ -4.2, 4.2 }) do
		for _, z in ipairs({ -2.7, 2.7 }) do
			local wheel = newPart(van, "Wheel", Vector3.new(0.9, 2, 2), VAN_CF * CFrame.new(x, 1, z) * CFrame.Angles(0, math.pi / 2, 0), dark)
			wheel.Shape = Enum.PartType.Cylinder
			solid(wheel)
		end
	end

	-- Headlights (also the beacon you can spot through the fog)
	for _, z in ipairs({ -1.8, 1.8 }) do
		local lamp = newPart(van, "Headlight", Vector3.new(0.2, 0.7, 0.7), VAN_CF * CFrame.new(5.9, 1.9, z),
			Color3.fromRGB(255, 232, 170), Enum.Material.Neon)
		local spot = Instance.new("SpotLight")
		spot.Face = Enum.NormalId.Right
		spot.Range = 32
		spot.Angle = 70
		spot.Brightness = 2
		spot.Color = Color3.fromRGB(255, 232, 170)
		spot.Shadows = false
		spot.Parent = lamp
	end
	for _, z in ipairs({ -2, 2 }) do
		newPart(van, "TailLight", Vector3.new(0.2, 0.6, 0.5), VAN_CF * CFrame.new(-5.2, 2.0, z),
			Color3.fromRGB(255, 40, 40), Enum.Material.Neon)
	end

	local dropoff = newPart(van, "DropOff", Vector3.new(1, 3, 4), VAN_CF * CFrame.new(-5.5, 2.6, 0), dark)
	dropoff.Transparency = 1
	local prompt = addPrompt(dropoff, "Courier van", "Load specimen case", 0.6, 9)

	prompt.Triggered:Connect(function(player)
		if player:GetAttribute("Delivered") then
			return
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not root or not humanoid or humanoid.Health <= 0 or (root.Position - dropoff.Position).Magnitude > 11 then return end
		if not player:GetAttribute("HasPackage") then
			notify(player, "NOTHING TO DELIVER YET", "warn")
			return
		end
		player:SetAttribute("HasPackage", false)
		player:SetAttribute("Delivered", true)
		updateObjective(player)
		notify(player, "SPECIMEN LOADED. Enter the driver's seat.", "item")
	end)
end
buildVan()

----------------------------------------------------------------------
-- Survival: first aid spray, limp, deaths, checkpoints
----------------------------------------------------------------------
local lastUse = {}

remote.OnServerEvent:Connect(function(player, action)
	if action ~= "UseMedkit" then
		return
	end
	local now = os.clock()
	if lastUse[player] and now - lastUse[player] < CFG.MedkitCooldown then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	local count = player:GetAttribute("Medkits") or 0
	if count <= 0 then
		notify(player, "NO FIRST AID SPRAY", "warn")
		return
	end
	if humanoid.Health >= humanoid.MaxHealth then
		notify(player, "HEALTH ALREADY FULL", "info")
		return
	end
	lastUse[player] = now
	player:SetAttribute("Medkits", count - 1)
	humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + CFG.MedkitHeal)
	notify(player, "USED FIRST AID SPRAY", "item")
end)

local function onCharacter(player, character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then
		return
	end
	humanoid.MaxHealth = CFG.MaxHealth

	local escapeCheckpoint = player:GetAttribute("EscapeCheckpoint")
	local cf = escapeCheckpoint or checkpoints[player]
	if cf then
		local root = character:WaitForChild("HumanoidRootPart", 10)
		if root and player.Character == character then
			character.PrimaryPart = root
			character:SetPrimaryPartCFrame(escapeCheckpoint and cf or cf + Vector3.new(0, 3, 0))
		end
	end

	humanoid.Died:Connect(function()
		player:SetAttribute("Deaths", (player:GetAttribute("Deaths") or 0) + 1)
	end)
end

local function initPlayer(player)
	player:SetAttribute("Medkits", 0)
	player:SetAttribute("HasKeycard", false)
	player:SetAttribute("HasPackage", false)
	player:SetAttribute("ReachedLobby", false)
	player:SetAttribute("ReachedUpstairs", false)
	player:SetAttribute("Delivered", false)
	player:SetAttribute("Deaths", 0)
	player:SetAttribute("StartTime", workspace:GetServerTimeNow())
	updateObjective(player)

	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
	if player.Character then
		task.spawn(onCharacter, player, player.Character)
	end
end

Players.PlayerAdded:Connect(initPlayer)
for _, player in ipairs(Players:GetPlayers()) do
	initPlayer(player)
end
Players.PlayerRemoving:Connect(function(player)
	checkpoints[player] = nil
	lastUse[player] = nil
end)

-- Limp when badly hurt. Skips while reloading so it never fights SurvivalWeaponServer's walk-speed handling.
task.spawn(function()
	while true do
		task.wait(0.2)
		for _, player in ipairs(Players:GetPlayers()) do
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 and not player:GetAttribute("WeaponReloading") then
				local hurt = (humanoid.Health / humanoid.MaxHealth) < CFG.LimpBelow
				local target = hurt and CFG.LimpWalkSpeed or CFG.BaseWalkSpeed
				if math.abs(humanoid.WalkSpeed - target) > 0.01 then
					humanoid.WalkSpeed = target
				end
			end
		end
	end
end)

-- Detect entering the lobby / reaching the second floor: advances the objective and sets checkpoints.
task.spawn(function()
	while true do
		task.wait(0.5)
		for _, player in ipairs(Players:GetPlayers()) do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root then
				local p = origin:PointToObjectSpace(root.Position)
				if not player:GetAttribute("ReachedLobby")
					and p.X > -3 and p.X < 17 and p.Z > -17 and p.Z < 3 and p.Y < 8 then
					player:SetAttribute("ReachedLobby", true)
					setCheckpoint(player, LOBBY_CHECKPOINT)
					notify(player, "YOU'RE INSIDE THE HOSPITAL", "info")
					updateObjective(player)
				end
				if not player:GetAttribute("ReachedUpstairs")
					and p.X > 10 and p.X < 70 and p.Z > -75 and p.Z < -58 and p.Y > FLOOR2 + 1 then
					player:SetAttribute("ReachedUpstairs", true)
					if not player:GetAttribute("HasPackage") then
						setCheckpoint(player, UPPER_CHECKPOINT)
					end
					notify(player, "SECOND FLOOR", "info")
				end
			end
		end
	end
end)
