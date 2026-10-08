-- Grounded service road and an explorable Butterfly Corps arrival lobby.
-- Coordinates are relative to EscapeHouseBuilder's entrance origin.
local CONFIG = {
	Name = "RaccoonCity",
	Version = 1,
	GateOffset = Vector3.new(34, 0, 120),
	RouteLength = 640,
	RoadWidth = 22,
	ShoulderWidth = 130,
	CityGroundSize = Vector3.new(360, 2, 420),
	HeadquartersWidth = 64,
	HeadquartersDepth = 80,
	HeadquartersHeight = 95,
	HeadquartersFront = 105,
	LobbyHeight = 16,
	LobbyFloor = 1.2,
	EntranceWidth = 10,
	Palette = {
		Snow = Color3.fromRGB(190, 206, 213),
		Road = Color3.fromRGB(40, 46, 50),
		Pavement = Color3.fromRGB(112, 123, 126),
		Concrete = Color3.fromRGB(108, 121, 129),
		PaleConcrete = Color3.fromRGB(167, 176, 178),
		Metal = Color3.fromRGB(48, 63, 72),
		Glass = Color3.fromRGB(63, 102, 124),
		Text = Color3.fromRGB(225, 230, 223),
		Yellow = Color3.fromRGB(197, 165, 76),
		Blue = Color3.fromRGB(89, 176, 205),
		Pine = Color3.fromRGB(42, 65, 57),
		Trunk = Color3.fromRGB(61, 61, 53),
		Warm = Color3.fromRGB(241, 201, 151),
		Dark = Color3.fromRGB(27, 37, 43),
	},
}

local function Build(houseOrigin)
	assert(typeof(houseOrigin) == "CFrame", "RaccoonCityBuilder.Build requires the house origin CFrame")
	local previous = workspace:FindFirstChild(CONFIG.Name)
	if previous then
		assert(previous:IsA("Model") and previous:GetAttribute("GeneratedRaccoonCity"),
			"RaccoonCity name is already used by an unrelated instance")
		if previous:GetAttribute("LayoutVersion") == CONFIG.Version then return previous end
		previous:Destroy()
	end
	local start = (houseOrigin * CFrame.new(CONFIG.GateOffset)).Position
	local roadOrigin = CFrame.new(start)
	local cityOrigin = CFrame.new(start.X, start.Y, start.Z + CONFIG.RouteLength)
	local city = Instance.new("Model")
	city.Name = CONFIG.Name
	city:SetAttribute("GeneratedRaccoonCity", true)
	city:SetAttribute("LayoutVersion", CONFIG.Version)
	city:SetAttribute("HouseOrigin", houseOrigin)
	city:SetAttribute("RoadOrigin", roadOrigin)
	city:SetAttribute("CityOrigin", cityOrigin)
	city:SetAttribute("RouteLength", CONFIG.RouteLength)
	local C = CONFIG.Palette
	local currentOrigin = roadOrigin
	local currentParent = city

	local function part(name, size, position, color, material, rotation, collide)
		local item = Instance.new("Part")
		item.Name = name
		item.Size = size
		item.CFrame = currentOrigin * CFrame.new(position) * (rotation or CFrame.identity)
		item.Anchored = true
		item.Material = material or Enum.Material.Concrete
		item.Color = color or C.Concrete
		item.TopSurface = Enum.SurfaceType.Smooth
		item.BottomSurface = Enum.SurfaceType.Smooth
		item.CanCollide = collide ~= false
		item.CanTouch = false
		item.CanQuery = collide ~= false
		item.Parent = currentParent
		return item
	end

	local function marker(name, position, size)
		local item = part(name, size or Vector3.new(1, 1, 1), position, C.Blue, Enum.Material.SmoothPlastic, nil, false)
		item.Transparency = 1
		item.Parent = city
		return item
	end

	local function sign(name, text, position, size, color, rotation, textColor)
		local board = part(name, size, position, color or C.Dark, Enum.Material.Metal, rotation, false)
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 32
		gui.LightInfluence = 0.2
		gui.Parent = board
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(0.92, 0.85)
		label.Position = UDim2.fromScale(0.04, 0.075)
		label.Text = text
		label.TextColor3 = textColor or C.Text
		label.Font = Enum.Font.GothamBold
		label.TextScaled = true
		label.TextWrapped = true
		label.Parent = gui
		return board
	end

	local function light(name, position, range, brightness, color)
		local lens = part(name, Vector3.new(1.6, 0.22, 1), position,
			color or C.Warm, Enum.Material.Neon, nil, false)
		local bulb = Instance.new("PointLight")
		bulb.Color = color or C.Warm
		bulb.Range = range
		bulb.Brightness = brightness
		bulb.Shadows = false
		bulb.Parent = lens
		return lens
	end

	local function streetLamp(x, z, road)
		local poleHeight = road and 17 or 19
		part("StreetLampBase", Vector3.new(1.3, 0.8, 1.3), Vector3.new(x, 0.4, z), C.Metal)
		part("StreetLampPole", Vector3.new(0.3, poleHeight, 0.3), Vector3.new(x, poleHeight / 2, z), C.Metal, Enum.Material.Metal)
		local direction = x > 0 and -1 or 1
		part("StreetLampArm", Vector3.new(3.2, 0.25, 0.3), Vector3.new(x + direction * 1.5, poleHeight, z), C.Metal, Enum.Material.Metal, nil, false)
		light("StreetLampLens", Vector3.new(x + direction * 2.6, poleHeight - 0.2, z), 26, 0.9)
	end

	local function pine(x, z, height, variation)
		part("PineTrunk", Vector3.new(1.1, height * 0.62, 1.1), Vector3.new(x, height * 0.31, z), C.Trunk, Enum.Material.Wood)
		for tier = 0, 2 do
			local diameter = height * (0.42 - tier * 0.07)
			local crown = part("PineCrown", Vector3.new(diameter, height * 0.36, diameter),
				Vector3.new(x, height * (0.52 + tier * 0.17), z), variation or C.Pine, Enum.Material.Grass, nil, false)
			crown.Shape = Enum.PartType.Ball
		end
	end

	-- All route slabs have their own collision, including the area beyond Baseplate.
	part("ServiceRoadGround", Vector3.new(CONFIG.ShoulderWidth, 2, CONFIG.RouteLength + 12),
		Vector3.new(0, -1, CONFIG.RouteLength / 2), C.Snow, Enum.Material.Snow)
	part("ServiceRoad", Vector3.new(CONFIG.RoadWidth, 0.14, CONFIG.RouteLength + 2),
		Vector3.new(0, 0.07, CONFIG.RouteLength / 2), C.Road, Enum.Material.Asphalt)
	for _, x in ipairs({-CONFIG.RoadWidth / 2 + 0.8, CONFIG.RoadWidth / 2 - 0.8}) do
		part("RoadEdgeLine", Vector3.new(0.14, 0.025, CONFIG.RouteLength), Vector3.new(x, 0.155, CONFIG.RouteLength / 2),
			C.Text, Enum.Material.SmoothPlastic, nil, false)
	end
	for z = 18, CONFIG.RouteLength - 15, 28 do
		part("RoadCentreDash", Vector3.new(0.16, 0.025, 10), Vector3.new(0, 0.155, z), C.Yellow, Enum.Material.SmoothPlastic, nil, false)
	end
	for index = 0, 14 do
		local z = 22 + index * 42
		local side = index % 2 == 0 and -1 or 1
		pine(side * (30 + (index % 3) * 7), z, 20 + (index % 4) * 3)
		pine(-side * (42 + (index % 2) * 9), z + 17, 22 + (index % 3) * 4)
	end
	for index = 0, 6 do
		streetLamp(index % 2 == 0 and -15 or 15, 45 + index * 86, true)
	end
	for _, z in ipairs({84, 206, 442, 538}) do
		local x = z % 4 == 0 and -19 or 19
		part("RoadsideBoulder", Vector3.new(5, 2.2, 3), Vector3.new(x, 1.1, z), C.Concrete, Enum.Material.Rock,
			CFrame.Angles(0, math.rad(z % 60), math.rad(8)))
	end
	sign("RoadDirection", "RACCOON CITY\nBUTTERFLY CORPS  >", Vector3.new(-18, 6.5, 28), Vector3.new(9, 3.2, 0.18), C.Dark)
	part("RoadSignPost", Vector3.new(0.25, 6, 0.25), Vector3.new(-18, 3, 28.1), C.Metal, Enum.Material.Metal)

	-- The halfway hut is accessible from the shoulder without blocking the road.
	local hutX, hutZ = -28, 323
	part("RestHutWalk", Vector3.new(22, 0.12, 6), Vector3.new(-17, 0.07, 312), C.Pavement, Enum.Material.Pebble)
	part("RestHutFloor", Vector3.new(16, 0.4, 14), Vector3.new(hutX, 0.2, hutZ), C.Pavement)
	for _, x in ipairs({hutX - 8, hutX + 8}) do
		part("RestHutWall", Vector3.new(0.5, 8, 14), Vector3.new(x, 4.4, hutZ), C.Metal, Enum.Material.WoodPlanks)
	end
	part("RestHutBack", Vector3.new(16, 8, 0.5), Vector3.new(hutX, 4.4, hutZ + 7), C.Metal, Enum.Material.WoodPlanks)
	for _, x in ipairs({hutX - 5.5, hutX + 5.5}) do
		part("RestHutFront", Vector3.new(5, 8, 0.5), Vector3.new(x, 4.4, hutZ - 7), C.Metal, Enum.Material.WoodPlanks)
	end
	part("RestHutRoof", Vector3.new(18, 0.5, 17), Vector3.new(hutX, 8.6, hutZ), C.Dark, Enum.Material.Metal)
	part("RestHutSnow", Vector3.new(18, 0.15, 17), Vector3.new(hutX, 8.93, hutZ), C.Snow, Enum.Material.Snow, nil, false)
	part("RestHutBench", Vector3.new(9, 1.6, 2.5), Vector3.new(hutX, 1.2, hutZ + 4.2), C.Trunk, Enum.Material.Wood)
	part("RestHutMapBoard", Vector3.new(5, 3.5, 0.2), Vector3.new(hutX + 4.8, 5, hutZ + 6.65), C.PaleConcrete, Enum.Material.Wood)
	sign("RestHutMap", "SERVICE ROAD\nYOU ARE HALFWAY\nCITY AHEAD", Vector3.new(hutX + 4.8, 5, hutZ + 6.5), Vector3.new(4.7, 3.1, 0.08), C.PaleConcrete, nil, C.Dark)
	sign("RestHutSign", "NORTH RIDGE\nROADSIDE SHELTER", Vector3.new(hutX, 7.15, hutZ - 7.4), Vector3.new(9, 1.8, 0.12), C.Dark)
	light("RestHutLamp", Vector3.new(hutX, 7.9, hutZ - 4), 17, 1.1)
	marker("RoadCheckpoint", Vector3.new(0, 3.5, CONFIG.RouteLength / 2))
	marker("RestHutCheckpoint", Vector3.new(hutX, 3.5, hutZ))

	-- The city ground overlaps the service-road slab, so there is no fall seam.
	currentOrigin = cityOrigin
	part("CityGround", CONFIG.CityGroundSize, Vector3.new(0, -1, 100), C.Snow, Enum.Material.Snow)
	part("CityMainStreet", Vector3.new(CONFIG.RoadWidth, 0.14, 119), Vector3.new(0, 0.07, 29.5), C.Road, Enum.Material.Asphalt)
	part("CityCrossStreet", Vector3.new(280, 0.14, 20), Vector3.new(0, 0.075, 45), C.Road, Enum.Material.Asphalt)
	part("RearAccessStreet", Vector3.new(270, 0.14, 18), Vector3.new(0, 0.07, 218), C.Road, Enum.Material.Asphalt)
	for _, x in ipairs({-16, 16}) do
		part("CitySidewalk", Vector3.new(8, 0.35, 118), Vector3.new(x, 0.175, 29), C.Pavement)
		for _, z in ipairs({-12, 22, 68}) do streetLamp(x, z, false) end
	end
	for _, z in ipairs({33, 57}) do
		for _, x in ipairs({-78, 78}) do
			part("CrossStreetSidewalk", Vector3.new(116, 0.35, 4), Vector3.new(x, 0.175, z), C.Pavement)
		end
	end
	for z = 30, 35, 1.5 do
		part("PedestrianCrossing", Vector3.new(18, 0.025, 0.7), Vector3.new(0, 0.165, z), C.Text, Enum.Material.SmoothPlastic, nil, false)
	end
	for _, z in ipairs({-20, -4, 12, 64, 80}) do
		part("CityCentreLine", Vector3.new(0.16, 0.025, 8), Vector3.new(0, 0.16, z), C.Yellow, Enum.Material.SmoothPlastic, nil, false)
	end
	part("CityWelcomePost", Vector3.new(0.4, 10, 0.4), Vector3.new(-21, 5, -28), C.Metal, Enum.Material.Metal)
	sign("CityWelcome", "RACCOON CITY\nNORTH DISTRICT", Vector3.new(-21, 9, -28), Vector3.new(14, 4, 0.2), C.Dark)
	marker("CityArrival", Vector3.new(0, 3.5, -12), Vector3.new(16, 7, 8))

	local buildings = {
		{name = "RaccoonClinic", text = "RACCOON CLINIC", x = -48, z = 7, width = 27, depth = 30, height = 35, color = Color3.fromRGB(131, 142, 144)},
		{name = "MarigoldDiner", text = "MARIGOLD DINER", x = 49, z = 5, width = 30, depth = 27, height = 25, color = Color3.fromRGB(128, 98, 77)},
		{name = "CedarApartments", text = "CEDAR RESIDENCES", x = -68, z = 81, width = 38, depth = 36, height = 56, color = Color3.fromRGB(112, 105, 98)},
		{name = "CityArchive", text = "CITY ARCHIVE", x = 65, z = 80, width = 38, depth = 34, height = 42, color = Color3.fromRGB(125, 136, 139)},
		{name = "NorthBank", text = "NORTH DISTRICT BANK", x = -94, z = 157, width = 43, depth = 52, height = 73, color = Color3.fromRGB(99, 116, 127)},
		{name = "PoliceAnnex", text = "RACCOON POLICE ANNEX", x = 94, z = 161, width = 46, depth = 46, height = 61, color = Color3.fromRGB(96, 107, 116)},
		{name = "CentralExchange", text = "CENTRAL EXCHANGE", x = -54, z = 256, width = 34, depth = 40, height = 82, color = Color3.fromRGB(106, 123, 134)},
		{name = "GraysideWarehouse", text = "GRAY SIDE LOGISTICS", x = 56, z = 251, width = 38, depth = 37, height = 48, color = Color3.fromRGB(124, 112, 102)},
	}
	for index, data in ipairs(buildings) do
		local building = Instance.new("Model")
		building.Name = data.name
		building.Parent = city
		currentParent = building
		part("BuildingShell", Vector3.new(data.width, data.height, data.depth), Vector3.new(data.x, data.height / 2, data.z),
			data.color, index % 2 == 0 and Enum.Material.Brick or Enum.Material.Concrete)
		part("RoofCornice", Vector3.new(data.width + 1.4, 1.2, data.depth + 1.4), Vector3.new(data.x, data.height + 0.4, data.z), C.Metal)
		part("RoofSnow", Vector3.new(data.width, 0.15, data.depth), Vector3.new(data.x, data.height + 1.1, data.z), C.Snow, Enum.Material.Snow, nil, false)
		for y = 13, data.height - 5, 10 do
			for column = -1, 1 do
				local pane = part("FacadeWindow", Vector3.new(data.width / 5, 5.3, 0.15),
					Vector3.new(data.x + column * data.width / 3.8, y, data.z - data.depth / 2 - 0.1),
					C.Glass, Enum.Material.Glass, nil, false)
				pane.Reflectance = 0.12
			end
		end
		for _, side in ipairs({-1, 1}) do
			part("FacadePilaster", Vector3.new(0.65, data.height - 3, 0.6),
				Vector3.new(data.x + side * (data.width / 2 - 1.8), data.height / 2, data.z - data.depth / 2 - 0.2), C.PaleConcrete, nil, nil, false)
		end
		part("Shopfront", Vector3.new(data.width - 5, 5.8, 0.2), Vector3.new(data.x, 3.3, data.z - data.depth / 2 - 0.12), C.Dark, Enum.Material.Glass)
		sign("StorefrontSign", data.text, Vector3.new(data.x, 8.3, data.z - data.depth / 2 - 0.35),
			Vector3.new(data.width - 3, 2.3, 0.2), C.Dark)
		if index % 2 == 0 then
			part("RoofServiceRoom", Vector3.new(data.width * 0.45, 5, data.depth * 0.4),
				Vector3.new(data.x + 2, data.height + 3.5, data.z + 3), C.Metal)
		else
			part("Antenna", Vector3.new(0.22, 11, 0.22), Vector3.new(data.x, data.height + 6.5, data.z + 2), C.Metal, Enum.Material.Metal, nil, false)
		end
	end
	currentParent = city
	for _, x in ipairs({-21.5, 21.5}) do
		for _, z in ipairs({4, 72}) do
			part("Planter", Vector3.new(3.5, 1.6, 6), Vector3.new(x, 0.8, z), C.Concrete)
			part("PlanterSnow", Vector3.new(3.2, 0.25, 5.7), Vector3.new(x, 1.75, z), C.Snow, Enum.Material.Snow, nil, false)
		end
	end
	for _, x in ipairs({-114, 112}) do
		for index = 1, 3 do
			part("SideStreetRubble", Vector3.new(2 + index, 0.8 + index * 0.25, 2.7), Vector3.new(x + index * 2, 0.6, 44 + index),
				C.Concrete, Enum.Material.Slate, CFrame.Angles(0, index * 0.4, 0.2))
		end
	end

	-- Landmark tower: all opaque upper mass starts above the actual lobby ceiling.
	local headquarters = Instance.new("Model")
	headquarters.Name = "ButterflyCorpsHeadquarters"
	headquarters.Parent = city
	currentParent = headquarters
	local width, depth = CONFIG.HeadquartersWidth, CONFIG.HeadquartersDepth
	local front = CONFIG.HeadquartersFront
	local middle = front + depth / 2
	local lobbyTop = CONFIG.LobbyFloor + CONFIG.LobbyHeight
	part("HeadquartersPlaza", Vector3.new(83, 0.3, 27), Vector3.new(0, 0.15, 92), C.PaleConcrete, Enum.Material.Concrete)
	for step = 1, 3 do
		part("EntranceStep", Vector3.new(14, step * 0.4, 2), Vector3.new(0, step * 0.2, 98 + step * 2), C.PaleConcrete, Enum.Material.Marble)
	end
	part("LobbyFloor", Vector3.new(width, CONFIG.LobbyFloor, depth), Vector3.new(0, CONFIG.LobbyFloor / 2, middle),
		C.PaleConcrete, Enum.Material.Marble)
	part("HeadquartersTower", Vector3.new(width, CONFIG.HeadquartersHeight - lobbyTop, depth),
		Vector3.new(0, (CONFIG.HeadquartersHeight + lobbyTop) / 2, middle), C.Concrete, Enum.Material.Concrete)
	for _, x in ipairs({-width / 2, width / 2}) do
		part("LobbySideWall", Vector3.new(1.2, CONFIG.LobbyHeight, depth), Vector3.new(x, CONFIG.LobbyFloor + CONFIG.LobbyHeight / 2, middle), C.PaleConcrete)
	end
	part("LobbyBackWall", Vector3.new(width, CONFIG.LobbyHeight, 1.2), Vector3.new(0, CONFIG.LobbyFloor + CONFIG.LobbyHeight / 2, front + depth), C.PaleConcrete)
	local frontWingWidth = (width - CONFIG.EntranceWidth) / 2
	for _, side in ipairs({-1, 1}) do
		local panelX = side * (CONFIG.EntranceWidth + frontWingWidth) / 2
		local glass = part("LobbyFrontGlass", Vector3.new(frontWingWidth, CONFIG.LobbyHeight, 0.4),
			Vector3.new(panelX, CONFIG.LobbyFloor + CONFIG.LobbyHeight / 2, front), C.Glass, Enum.Material.Glass)
		glass.Transparency = 0.47
		for _, x in ipairs({side * 5.15, side * 18.5, side * 31.7}) do
			part("LobbyMullion", Vector3.new(0.3, CONFIG.LobbyHeight, 0.65), Vector3.new(x, CONFIG.LobbyFloor + CONFIG.LobbyHeight / 2, front), C.Metal, Enum.Material.Metal)
		end
	end
	part("EntranceLintel", Vector3.new(CONFIG.EntranceWidth, 4, 1.2), Vector3.new(0, lobbyTop - 2, front), C.Metal, Enum.Material.Metal)
	part("EntranceCanopy", Vector3.new(29, 0.65, 10), Vector3.new(0, 12.8, front - 3.2), C.Metal, Enum.Material.Metal)
	sign("ButterflyCorpsSign", "BUTTERFLY CORPS", Vector3.new(0, 22, front - 0.75), Vector3.new(53, 5.4, 0.35), C.Dark, nil, C.Text)
	sign("HeadquartersSubtitle", "RESEARCH  /  RESPONSE  /  RECOVERY", Vector3.new(0, 16.3, front - 0.8), Vector3.new(45, 1.5, 0.2), C.Metal)
	for _, x in ipairs({-26, -13, 13, 26}) do
		part("HeadquartersFacadeFin", Vector3.new(0.75, CONFIG.HeadquartersHeight - 29, 1.2),
			Vector3.new(x, (CONFIG.HeadquartersHeight + 29) / 2, front - 0.5), C.PaleConcrete, Enum.Material.Concrete, nil, false)
	end
	for y = 34, 84, 10 do
		for _, x in ipairs({-20, -7, 7, 20}) do
			local glass = part("HeadquartersWindow", Vector3.new(10, 5.8, 0.2), Vector3.new(x, y, front - 0.7), C.Glass, Enum.Material.Glass, nil, false)
			glass.Reflectance = 0.17
		end
		for _, x in ipairs({-32.65, 32.65}) do
			part("HeadquartersSideWindowBand", Vector3.new(0.2, 5.8, depth - 8), Vector3.new(x, y, middle), C.Glass, Enum.Material.Glass, nil, false)
		end
	end
	part("HeadquartersCrown", Vector3.new(width + 3, 2, depth + 3), Vector3.new(0, CONFIG.HeadquartersHeight + 0.5, middle), C.Metal)
	part("HeadquartersRoofSnow", Vector3.new(width + 2, 0.18, depth + 2), Vector3.new(0, CONFIG.HeadquartersHeight + 1.65, middle), C.Snow, Enum.Material.Snow, nil, false)
	part("HeadquartersRoofPlant", Vector3.new(24, 8, 25), Vector3.new(0, CONFIG.HeadquartersHeight + 5, middle + 15), C.Metal)
	part("CommunicationsMast", Vector3.new(0.5, 18, 0.5), Vector3.new(0, CONFIG.HeadquartersHeight + 17, middle + 15), C.Metal, Enum.Material.Metal, nil, false)

	-- Four tilted metal wings form a butterfly emblem, readable from the main road.
	local function butterflyLogo(name, centre, scale, color)
		for _, side in ipairs({-1, 1}) do
			part(name .. "UpperWing", Vector3.new(4.6 * scale, 5.9 * scale, 0.3),
				centre + Vector3.new(side * 2.7 * scale, 1.65 * scale, 0), color, Enum.Material.Metal,
				CFrame.Angles(0, 0, -side * math.rad(27)), false)
			part(name .. "LowerWing", Vector3.new(3.3 * scale, 3.6 * scale, 0.3),
				centre + Vector3.new(side * 2.1 * scale, -2.1 * scale, 0), color, Enum.Material.Metal,
				CFrame.Angles(0, 0, side * math.rad(32)), false)
		end
		part(name .. "Body", Vector3.new(0.8 * scale, 6.8 * scale, 0.38), centre, C.PaleConcrete, Enum.Material.Metal, nil, false)
	end
	butterflyLogo("TowerButterfly", Vector3.new(0, 73, front - 1), 1.5, C.Blue)
	part("LobbyReceptionDesk", Vector3.new(21, 3.5, 4.5), Vector3.new(0, CONFIG.LobbyFloor + 1.75, 132), C.Metal, Enum.Material.Metal)
	part("LobbyCountertop", Vector3.new(22, 0.25, 5), Vector3.new(0, CONFIG.LobbyFloor + 3.62, 132), C.PaleConcrete, Enum.Material.Marble)
	sign("LobbyDeskSign", "BUTTERFLY CORPS\nVISITOR RECEPTION", Vector3.new(0, CONFIG.LobbyFloor + 2, 129.68), Vector3.new(13, 1.8, 0.08), C.Metal)
	part("ReceptionFeatureWall", Vector3.new(30, 12, 0.5), Vector3.new(0, CONFIG.LobbyFloor + 6, 141), C.Dark, Enum.Material.Slate)
	butterflyLogo("LobbyButterfly", Vector3.new(0, 9, 140.65), 0.75, C.Blue)
	for _, x in ipairs({-23, 23}) do
		part("LobbyBench", Vector3.new(4, 1.5, 11), Vector3.new(x, CONFIG.LobbyFloor + 0.75, 119), C.Dark, Enum.Material.Fabric)
		part("LobbyBenchBack", Vector3.new(0.35, 3, 11), Vector3.new(x + (x > 0 and 1.85 or -1.85), CONFIG.LobbyFloor + 1.5, 119), C.Metal)
		part("LobbyPlanter", Vector3.new(3, 3, 3), Vector3.new(x, CONFIG.LobbyFloor + 1.5, 137), C.PaleConcrete)
		local foliage = part("LobbyFoliage", Vector3.new(3, 4, 3), Vector3.new(x, CONFIG.LobbyFloor + 4.8, 137), C.Pine, Enum.Material.Grass, nil, false)
		foliage.Shape = Enum.PartType.Ball
	end
	for _, z in ipairs({113, 126, 153, 175}) do light("LobbyCeilingLight", Vector3.new(0, lobbyTop - 0.4, z), 29, 1.6, C.Text) end
	for _, x in ipairs({-5, 5}) do light("CanopyLight", Vector3.new(x, 12.25, front - 4), 19, 1.1, C.Blue) end
	currentParent = city
	marker("ButterflyEntrance", Vector3.new(0, 4, 110), Vector3.new(8, 6, 6))
	marker("ButterflyReception", Vector3.new(0, 4.7, 125))
	city.Parent = workspace
	return city
end

return { Build = Build, Config = CONFIG }
