-- Authored continuation environment. Safe to require in Studio and on the server.
-- originCf is the centre of the fence entrance; local +Z leads toward the house.
local CONFIG = {
	Name = "EscapeHouse",
	Version = 1,
	HouseWidth = 30,
	HouseDepth = 32,
	HouseFront = 19,
	HouseBack = 51,
	FloorTop = 0.95,
	FloorThickness = 0.6,
	WallHeight = 10,
	WallThickness = 0.65,
	EntranceWidth = 6,
	DoorHeight = 8,
	BedroomFront = 38,
	BedroomDoorWidth = 7,
	FenceHalfWidth = 24,
	FenceDepth = 62,
	FenceHeight = 9,
	FencePostSpacing = 8,
	FenceWireSpacing = 1.3,
	FenceGateWidth = 8,
	FencePostSize = 0.35,
	FenceWireSize = 0.09,
	RoofHalfSpan = 17,
	RoofRise = 4.4,
	RoofThickness = 0.45,
	RoofOverhang = 2,
	WindowSize = Vector3.new(5, 3.5, 0.16),
	WindowCentreHeight = 6.2,
	WindowTrimSize = 0.16,
	ElectricThresholdSize = Vector3.new(8, 8, 3),
	InteriorTriggerSize = Vector3.new(26, 8, 22),
	MarkerSize = Vector3.new(1, 1, 1),
	AmmoCrateSize = Vector3.new(3.4, 2.6, 2.8),
	MattressSize = Vector3.new(6, 0.8, 9),
	Palette = {
		Snow = Color3.fromRGB(200, 214, 218),
		Wood = Color3.fromRGB(65, 75, 70),
		WoodLight = Color3.fromRGB(92, 101, 91),
		WoodDark = Color3.fromRGB(42, 48, 44),
		Floor = Color3.fromRGB(82, 72, 59),
		Metal = Color3.fromRGB(69, 81, 87),
		Roof = Color3.fromRGB(41, 57, 61),
		Glass = Color3.fromRGB(121, 157, 164),
		Electric = Color3.fromRGB(81, 197, 255),
		Warning = Color3.fromRGB(231, 173, 51),
		Ink = Color3.fromRGB(27, 35, 37),
		Text = Color3.fromRGB(225, 229, 213),
		Bedding = Color3.fromRGB(113, 119, 99),
		Ammo = Color3.fromRGB(77, 91, 57),
		Warm = Color3.fromRGB(255, 203, 131),
	},
}

local function Build(originCf)
	local previous = workspace:FindFirstChild(CONFIG.Name)
	if previous then
		assert(previous:IsA("Model") and previous:GetAttribute("GeneratedEscapeHouse"),
			"EscapeHouse name is already used by an unrelated instance")
		return previous
	end
	assert(typeof(originCf) == "CFrame", "EscapeHouseBuilder.Build requires a CFrame")
	local house = Instance.new("Model")
	house.Name = CONFIG.Name
	house:SetAttribute("GeneratedEscapeHouse", true)
	house:SetAttribute("LayoutVersion", CONFIG.Version)
	house:SetAttribute("Origin", originCf)
	house:SetAttribute("HeadshotsRequired", true)
	local C = CONFIG.Palette
	local wallTop = CONFIG.FloorTop + CONFIG.WallHeight
	local wallCentre = CONFIG.FloorTop + CONFIG.WallHeight / 2
	local centreZ = (CONFIG.HouseFront + CONFIG.HouseBack) / 2

	local function part(name, size, position, color, material, rotation, collide)
		local item = Instance.new("Part")
		item.Name = name
		item.Size = size
		item.CFrame = originCf * CFrame.new(position) * (rotation or CFrame.identity)
		item.Anchored = true
		item.Color = color or C.Wood
		item.Material = material or Enum.Material.WoodPlanks
		item.TopSurface = Enum.SurfaceType.Smooth
		item.BottomSurface = Enum.SurfaceType.Smooth
		item.CanCollide = collide ~= false
		item.CanTouch = false
		item.CanQuery = collide ~= false
		item.Parent = house
		return item
	end

	local function marker(name, position, size, rotation)
		local item = part(name, size or CONFIG.MarkerSize, position, C.Electric,
			Enum.Material.SmoothPlastic, rotation, false)
		item.Transparency = 1
		return item
	end

	local function sign(name, text, size, position, color, rotation, textColor)
		local board = part(name, size, position, color or C.Ink,
			Enum.Material.Metal, rotation, false)
		local gui = Instance.new("SurfaceGui")
		gui.Name = "Lettering"
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 42
		gui.LightInfluence = 0.15
		gui.Parent = board
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(0.92, 0.84)
		label.Position = UDim2.fromScale(0.04, 0.08)
		label.BackgroundTransparency = 1
		label.Text = text
		label.TextColor3 = textColor or C.Text
		label.Font = Enum.Font.GothamBold
		label.TextScaled = true
		label.TextWrapped = true
		label.Parent = gui
		return board
	end

	local function lamp(name, position, color, brightness, range)
		local bulb = part(name, Vector3.new(0.45, 0.3, 0.45), position,
			color, Enum.Material.Neon, nil, false)
		local light = Instance.new("PointLight")
		light.Name = "Light"
		light.Color = color
		light.Brightness = brightness
		light.Range = range
		light.Shadows = false
		light.Parent = bulb
		return bulb
	end

	-- A shallow snowy pad covers the extension beyond the old forest map.
	part("SnowYard", Vector3.new(52, 1, 66), Vector3.new(0, -0.5, 31), C.Snow, Enum.Material.Snow)
	part("ApproachPath", Vector3.new(8, 0.08, 18), Vector3.new(0, 0.045, 8), C.Metal, Enum.Material.Slate)
	part("Foundation", Vector3.new(31, 0.65, 33), Vector3.new(0, 0.25, centreZ), C.Metal, Enum.Material.Concrete)
	part("CabinFloor", Vector3.new(CONFIG.HouseWidth, CONFIG.FloorThickness, CONFIG.HouseDepth),
		Vector3.new(0, CONFIG.FloorTop - CONFIG.FloorThickness / 2, centreZ), C.Floor)
	part("PorchStep", Vector3.new(9, 0.3, 2), Vector3.new(0, 0.15, 14), C.WoodDark)
	part("Porch", Vector3.new(13, 0.6, 4), Vector3.new(0, 0.55, 17), C.WoodLight)
	for _, x in ipairs({-6, 6}) do
		part("PorchPost", Vector3.new(0.4, 9.7, 0.4), Vector3.new(x, 5.65, 15.4), C.WoodDark)
	end
	part("PorchAwning", Vector3.new(14, 0.35, 5), Vector3.new(0, 10.25, 16.4),
		C.Roof, Enum.Material.Metal, CFrame.Angles(math.rad(-5), 0, 0))
	part("PorchSnow", Vector3.new(14, 0.16, 5), Vector3.new(0, 10.48, 16.4),
		C.Snow, Enum.Material.Snow, CFrame.Angles(math.rad(-5), 0, 0), false)

	-- Window openings are real gaps in the walls, filled with thin glass.
	local function windowWall(name, centreX, z, width)
		local winW, winH = CONFIG.WindowSize.X, CONFIG.WindowSize.Y
		local lowerTop = CONFIG.WindowCentreHeight - winH / 2
		local upperBottom = CONFIG.WindowCentreHeight + winH / 2
		part(name .. "Lower", Vector3.new(width, lowerTop - CONFIG.FloorTop, CONFIG.WallThickness),
			Vector3.new(centreX, (lowerTop + CONFIG.FloorTop) / 2, z), C.Wood)
		part(name .. "Upper", Vector3.new(width, wallTop - upperBottom, CONFIG.WallThickness),
			Vector3.new(centreX, (upperBottom + wallTop) / 2, z), C.Wood)
		local sideWidth = (width - winW) / 2
		for _, direction in ipairs({-1, 1}) do
			part(name .. "Side", Vector3.new(sideWidth, winH, CONFIG.WallThickness),
				Vector3.new(centreX + direction * (winW + sideWidth) / 2, CONFIG.WindowCentreHeight, z), C.Wood)
			part(name .. "VerticalTrim", Vector3.new(CONFIG.WindowTrimSize, winH + 0.3, 0.8),
				Vector3.new(centreX + direction * winW / 2, CONFIG.WindowCentreHeight, z), C.WoodDark)
			part(name .. "HorizontalTrim", Vector3.new(winW + 0.3, CONFIG.WindowTrimSize, 0.8),
				Vector3.new(centreX, CONFIG.WindowCentreHeight + direction * winH / 2, z), C.WoodDark)
		end
		local glass = part(name .. "Glass", CONFIG.WindowSize,
			Vector3.new(centreX, CONFIG.WindowCentreHeight, z), C.Glass, Enum.Material.Glass)
		glass.Transparency = 0.55
		part(name .. "Mullion", Vector3.new(0.12, winH, 0.2),
			Vector3.new(centreX, CONFIG.WindowCentreHeight, z - 0.13), C.WoodDark)
	end
	local frontWingWidth = (CONFIG.HouseWidth - CONFIG.EntranceWidth) / 2
	for _, direction in ipairs({-1, 1}) do
		windowWall("FrontWindow", direction * (CONFIG.EntranceWidth + frontWingWidth) / 2,
			CONFIG.HouseFront, frontWingWidth)
		part("SideWall", Vector3.new(CONFIG.WallThickness, CONFIG.WallHeight, CONFIG.HouseDepth),
			Vector3.new(direction * CONFIG.HouseWidth / 2, wallCentre, centreZ), C.Wood)
		part("CornerPost", Vector3.new(0.8, CONFIG.WallHeight + 0.2, 0.8),
			Vector3.new(direction * CONFIG.HouseWidth / 2, wallCentre, CONFIG.HouseFront), C.WoodDark)
		part("CornerPost", Vector3.new(0.8, CONFIG.WallHeight + 0.2, 0.8),
			Vector3.new(direction * CONFIG.HouseWidth / 2, wallCentre, CONFIG.HouseBack), C.WoodDark)
	end
	part("EntranceLintel", Vector3.new(CONFIG.EntranceWidth, CONFIG.WallHeight - CONFIG.DoorHeight, CONFIG.WallThickness),
		Vector3.new(0, CONFIG.FloorTop + CONFIG.DoorHeight + (CONFIG.WallHeight - CONFIG.DoorHeight) / 2, CONFIG.HouseFront), C.WoodDark)
	windowWall("BedroomWindow", 0, CONFIG.HouseBack, CONFIG.HouseWidth)
	-- The old door is held flat against the inside wall, leaving a six-stud passage.
	part("OpenFrontDoor", Vector3.new(0.22, 7.7, 4), Vector3.new(3.25, 4.8, 21.2), C.WoodDark)
	sign("StationSign", "NORTH RIDGE\nRANGER STATION 04", Vector3.new(11, 1.7, 0.16),
		Vector3.new(0, 9.75, 18.53), C.Ink)
	lamp("PorchLamp", Vector3.new(0, 8.65, 18.4), C.Warm, 1.6, 15)

	local bedroomWing = (CONFIG.HouseWidth - CONFIG.BedroomDoorWidth) / 2
	for _, direction in ipairs({-1, 1}) do
		part("BedroomPartition", Vector3.new(bedroomWing, CONFIG.WallHeight, CONFIG.WallThickness),
			Vector3.new(direction * (CONFIG.BedroomDoorWidth + bedroomWing) / 2, wallCentre, CONFIG.BedroomFront), C.WoodLight)
	end
	part("BedroomLintel", Vector3.new(CONFIG.BedroomDoorWidth, 2, CONFIG.WallThickness),
		Vector3.new(0, wallTop - 1, CONFIG.BedroomFront), C.WoodDark)
	sign("BedroomSign", "REST QUARTERS", Vector3.new(6, 0.75, 0.1),
		Vector3.new(0, 9.2, CONFIG.BedroomFront - 0.4), C.WoodDark)

	local roofAngle = math.atan(CONFIG.RoofRise / CONFIG.RoofHalfSpan)
	local roofSlope = math.sqrt(CONFIG.RoofHalfSpan ^ 2 + CONFIG.RoofRise ^ 2)
	for _, direction in ipairs({-1, 1}) do
		local tilt = CFrame.Angles(0, 0, -direction * roofAngle)
		local centre = Vector3.new(direction * CONFIG.RoofHalfSpan / 2, wallTop + CONFIG.RoofRise / 2, centreZ)
		part("SlopedRoof", Vector3.new(roofSlope + 0.2, CONFIG.RoofThickness, CONFIG.HouseDepth + CONFIG.RoofOverhang * 2),
			centre, C.Roof, Enum.Material.Metal, tilt)
		part("RoofSnow", Vector3.new(roofSlope + 0.2, 0.15, CONFIG.HouseDepth + CONFIG.RoofOverhang * 2),
			centre + Vector3.new(0, 0.29, 0), C.Snow, Enum.Material.Snow, tilt, false)
	end
	-- Stepped timber gables sit entirely beneath the pitched roof.
	local gableCourse = 0.5
	for y = gableCourse / 2, CONFIG.RoofRise - gableCourse / 2, gableCourse do
		local width = math.min(CONFIG.HouseWidth, 2 * CONFIG.RoofHalfSpan * (1 - (y + gableCourse / 2) / CONFIG.RoofRise))
		if width > 0 then
			for _, z in ipairs({CONFIG.HouseFront, CONFIG.HouseBack}) do
				part("GableTimber", Vector3.new(width, gableCourse, CONFIG.WallThickness),
					Vector3.new(0, wallTop + y, z), C.Wood)
			end
		end
	end
	part("RoofRidge", Vector3.new(0.5, 0.3, CONFIG.HouseDepth + CONFIG.RoofOverhang * 2),
		Vector3.new(0, wallTop + CONFIG.RoofRise + 0.18, centreZ), C.Metal, Enum.Material.Metal)
	part("Chimney", Vector3.new(2, 5, 2), Vector3.new(-10, 14, 46), C.Metal, Enum.Material.Brick)
	part("ChimneyCap", Vector3.new(2.5, 0.3, 2.5), Vector3.new(-10, 16.6, 46), C.Ink, Enum.Material.Metal)

	-- Supply table and obvious ammunition pickup, away from the navigation aisle.
	part("SupplyTable", Vector3.new(7, 0.3, 4), Vector3.new(-9, 1.55, 26), C.WoodDark)
	for _, x in ipairs({-11.8, -6.2}) do
		part("SupplyTableLeg", Vector3.new(0.35, 0.6, 3), Vector3.new(x, 1.2, 26), C.Metal, Enum.Material.Metal)
	end
	local ammo = part("AmmoCrate", CONFIG.AmmoCrateSize, Vector3.new(-9, 3, 26), C.Ammo, Enum.Material.Metal)
	ammo:SetAttribute("AmmoRefill", true)
	part("AmmoLid", Vector3.new(3.6, 0.18, 3), Vector3.new(-9, 4.4, 26), C.Ammo, Enum.Material.Metal)
	sign("AmmoLabel", "AMMUNITION", Vector3.new(3.2, 0.65, 0.08), Vector3.new(-9, 3.05, 24.54), C.Ink, nil, C.Warning)
	lamp("AmmoIndicator", Vector3.new(-9, 4.6, 26), C.Warm, 1, 9)
	sign("SupplyNotice", "EMERGENCY SUPPLIES\nAIM FOR THE HEAD", Vector3.new(8, 2, 0.1),
		Vector3.new(-9, 6.7, 37.6), C.Ink, nil, C.Warning)
	part("Bench", Vector3.new(2.5, 0.45, 7), Vector3.new(12, 2, 28), C.WoodDark)
	for _, z in ipairs({25.5, 30.5}) do
		part("BenchLeg", Vector3.new(2, 1, 0.35), Vector3.new(12, 1.4, z), C.Metal, Enum.Material.Metal)
	end
	part("Rug", Vector3.new(8, 0.06, 10), Vector3.new(0, CONFIG.FloorTop + 0.035, 29),
		Color3.fromRGB(70, 71, 62), Enum.Material.Fabric, nil, false)
	part("ShelfFrame", Vector3.new(5, 6, 1.1), Vector3.new(-11, 3.95, 35), C.WoodDark)
	for _, y in ipairs({2, 3.6, 5.2}) do
		part("ShelfLip", Vector3.new(5.4, 0.18, 1.6), Vector3.new(-11, y, 34.5), C.WoodLight)
		for _, x in ipairs({-12.4, -10.8, -9.2}) do
			part("SupplyTin", Vector3.new(0.55, 0.8, 0.6), Vector3.new(x, y + 0.48, 34.3), C.Metal, Enum.Material.Metal, nil, false)
		end
	end
	lamp("FrontRoomLamp", Vector3.new(0, 10.4, 28), C.Warm, 1.7, 25)
	lamp("BedroomLamp", Vector3.new(-2, 10.4, 45), Color3.fromRGB(173, 192, 188), 1, 21)

	-- The sleeper's head points toward the rear wall (+Z).
	part("BedFrame", Vector3.new(6.3, 0.5, 9.3), Vector3.new(8, 1.5, 43), C.WoodDark)
	part("Bed", CONFIG.MattressSize, Vector3.new(8, 2, 43), C.Bedding, Enum.Material.Fabric)
	part("BedHeadboard", Vector3.new(6.5, 3.3, 0.35), Vector3.new(8, 2.6, 47.6), C.WoodDark)
	part("Pillow", Vector3.new(3.8, 0.45, 1.5), Vector3.new(8, 2.62, 46.2),
		Color3.fromRGB(164, 162, 136), Enum.Material.Fabric, nil, false)
	for _, x in ipairs({5.5, 10.5}) do
		for _, z in ipairs({39.2, 46.8}) do
			part("BedLeg", Vector3.new(0.4, 0.4, 0.4), Vector3.new(x, 1.15, z), C.Metal, Enum.Material.Metal)
		end
	end
	part("BedsideCabinet", Vector3.new(2, 2.2, 2.5), Vector3.new(12.5, 2.05, 46), C.WoodLight)
	part("Wardrobe", Vector3.new(3.5, 6, 2), Vector3.new(-11.5, 3.95, 49), C.WoodDark)
	sign("QuarantineNote", "DO NOT WAKE\nTHE PATIENT", Vector3.new(4, 1.4, 0.1),
		Vector3.new(8, 5.5, 50.55), C.Ink, nil, C.Warning)

	-- Fence collisions close the perimeter; the energized entrance remains passable.
	local fenceWire = CONFIG.FenceWireSize
	local function fencePost(x, z)
		part("FencePost", Vector3.new(CONFIG.FencePostSize, CONFIG.FenceHeight, CONFIG.FencePostSize),
			Vector3.new(x, CONFIG.FenceHeight / 2, z), C.Metal, Enum.Material.Metal)
		part("Insulator", Vector3.new(0.48, 0.2, 0.48), Vector3.new(x, CONFIG.FenceHeight - 0.7, z),
			C.Electric, Enum.Material.Neon, nil, false)
	end
	local function fencePanel(name, from, to)
		local delta = to - from
		local length = delta.Magnitude
		local alongX = math.abs(delta.X) > math.abs(delta.Z)
		local middle = (from + to) / 2
		local barrierSize = alongX and Vector3.new(length, CONFIG.FenceHeight, 0.12)
			or Vector3.new(0.12, CONFIG.FenceHeight, length)
		local barrier = part(name .. "Barrier", barrierSize,
			Vector3.new(middle.X, CONFIG.FenceHeight / 2, middle.Z), C.Metal, Enum.Material.Metal)
		barrier.Transparency = 1
		-- Invisible character collision must not stop bullets through the wire grid.
		barrier.CanQuery = false
		local wireSize = alongX and Vector3.new(length, fenceWire, fenceWire)
			or Vector3.new(fenceWire, fenceWire, length)
		for y = 0.7, CONFIG.FenceHeight - 0.2, CONFIG.FenceWireSpacing do
			part(name .. "Wire", wireSize, Vector3.new(middle.X, y, middle.Z), C.Metal, Enum.Material.Metal, nil, false)
		end
		local crossCount = math.floor(length / CONFIG.FenceWireSpacing)
		for index = 1, crossCount do
			local pos = from:Lerp(to, index / (crossCount + 1))
			part(name .. "CrossWire", Vector3.new(fenceWire, CONFIG.FenceHeight - 0.6, fenceWire),
				Vector3.new(pos.X, CONFIG.FenceHeight / 2, pos.Z), C.Metal, Enum.Material.Metal, nil, false)
		end
	end
	for _, x in ipairs({-CONFIG.FenceHalfWidth, CONFIG.FenceHalfWidth}) do
		for z = 0, CONFIG.FenceDepth, CONFIG.FencePostSpacing do fencePost(x, z) end
		fencePost(x, CONFIG.FenceDepth)
		fencePanel("SideFence", Vector3.new(x, 0, 0), Vector3.new(x, 0, CONFIG.FenceDepth))
	end
	for x = -CONFIG.FenceHalfWidth + CONFIG.FencePostSpacing, CONFIG.FenceHalfWidth - CONFIG.FencePostSpacing, CONFIG.FencePostSpacing do
		fencePost(x, CONFIG.FenceDepth)
		if math.abs(x) > CONFIG.FenceGateWidth / 2 then fencePost(x, 0) end
	end
	for _, x in ipairs({-CONFIG.FenceGateWidth / 2, CONFIG.FenceGateWidth / 2}) do fencePost(x, 0) end
	fencePanel("BackFence", Vector3.new(-CONFIG.FenceHalfWidth, 0, CONFIG.FenceDepth), Vector3.new(CONFIG.FenceHalfWidth, 0, CONFIG.FenceDepth))
	fencePanel("FrontFence", Vector3.new(-CONFIG.FenceHalfWidth, 0, 0), Vector3.new(-CONFIG.FenceGateWidth / 2, 0, 0))
	fencePanel("FrontFence", Vector3.new(CONFIG.FenceGateWidth / 2, 0, 0), Vector3.new(CONFIG.FenceHalfWidth, 0, 0))
	for _, y in ipairs({1.2, 2.8, 4.4, 6, 7.6}) do
		part("LiveEntranceWire", Vector3.new(CONFIG.FenceGateWidth, 0.065, 0.065),
			Vector3.new(0, y, 0), C.Electric, Enum.Material.Neon, nil, false)
	end
	for _, x in ipairs({-4, 4}) do lamp("FenceWarningLamp", Vector3.new(x, 9.2, 0), C.Electric, 1.6, 11) end
	sign("ElectricWarning", "DANGER\nELECTRIC FENCE", Vector3.new(5.8, 2.4, 0.16), Vector3.new(-8, 6.3, -0.25), C.Warning, nil, C.Ink)
	sign("ShelterDirection", "SHELTER / SUPPLIES\nKEEP MOVING", Vector3.new(5.8, 2.4, 0.16), Vector3.new(8, 6.3, -0.25), C.Ink)
	part("PowerBox", Vector3.new(1.5, 2.5, 0.7), Vector3.new(-4.7, 3, -0.3), C.Metal, Enum.Material.Metal)
	lamp("PowerIndicator", Vector3.new(-4.7, 3.5, -0.72), C.Electric, 0.6, 5)

	marker("ElectricThreshold", Vector3.new(0, 4, 0), CONFIG.ElectricThresholdSize)
	marker("YardCheckpoint", Vector3.new(0, 3, 10))
	marker("InteriorTrigger", Vector3.new(0, 4, 31), CONFIG.InteriorTriggerSize)
	marker("AttackerSpawn", Vector3.new(-7, 3, 45))
	marker("SleeperSpawn", Vector3.new(8, 3.35, 43), nil, CFrame.Angles(math.pi / 2, 0, 0))
	house.Parent = workspace
	return house
end

return { Build = Build, Config = CONFIG }
