local Lighting = game:GetService("Lighting")
local ServerScriptService = game:GetService("ServerScriptService")

local CONFIG = {
	Name = "HospitalFogGreybox",
	CellSize = 7,
	WallThickness = 1,
	WallHeight = 10,
	DoorWidth = 5,
	DoorHeight = 8,
	FloorThickness = 0.5,
	FogDistance = 40,
	SlabThickness = 1,   -- ceiling of floor 1 / floor of floor 2
	RoofThickness = 0.5,
	StairWidth = 6,
	StairTreads = 28,
	WindowWidth = 4.2,
	WindowHeight = 3.6,
	WindowSill = 3.5,
	TrimThickness = 0.13,
	PanelHeight = 2.7,
	AccentColor = Color3.fromRGB(56, 100, 101),
	TrimColor = Color3.fromRGB(54, 65, 69),
	WindowColor = Color3.fromRGB(108, 143, 151),
	EmergencyColor = Color3.fromRGB(172, 55, 45),
	FloorMaterial = Enum.Material.SmoothPlastic,
	FloorReflectance = 0.025,

	FloorColor = Color3.fromRGB(111, 123, 124),
	WallColor = Color3.fromRGB(165, 171, 158),
	FurnitureColor = Color3.fromRGB(65, 78, 80),
	BeddingColor = Color3.fromRGB(159, 178, 164),
}

local baseplate = workspace:WaitForChild("Baseplate")
assert(baseplate:IsA("BasePart"), "Baseplate must be a BasePart")
assert(
	baseplate.Size.X >= 70 and baseplate.Size.Z >= 70,
	"HospitalLayout needs a Baseplate at least 70 x 70 studs."
)

-- Prevent the previous weather script from restoring its longer fog range.
local oldLighting = ServerScriptService:FindFirstChild("SnowyMountain")
if oldLighting and oldLighting:IsA("Script") then
	oldLighting.Disabled = true
end

-- Atmosphere overrides legacy distance fog, so use distance fog alone.
for _, object in ipairs(Lighting:GetChildren()) do
	if object:IsA("Atmosphere") then
		object:Destroy()
	end
end

Lighting.FogColor = Color3.fromRGB(117, 131, 148)
Lighting.FogStart = 5
Lighting.FogEnd = CONFIG.FogDistance
Lighting.Ambient = Color3.fromRGB(10, 16, 35)
Lighting.OutdoorAmbient = Lighting.Ambient
Lighting.GlobalShadows = false
Lighting.Brightness = 0.7
Lighting.ClockTime = 18

-- Rebuild only this script's own generated layout.
local previous = workspace:FindFirstChild(CONFIG.Name)
if previous then
	assert(
		previous:GetAttribute("GeneratedHospitalLayout"),
		"An unrelated model already uses the layout name."
	)
	previous:Destroy()
end

local hospital = Instance.new("Model")
hospital.Name = CONFIG.Name
hospital:SetAttribute("GeneratedHospitalLayout", true)
hospital:SetAttribute("CorridorClearWidth", 6)
hospital:SetAttribute("FogDistance", CONFIG.FogDistance)
hospital:SetAttribute("ArchitectureVersion", 2)

-- Keep the building on the plate, near the spawn area.
local offsetX = math.clamp(
	90,
	-baseplate.Size.X / 2 + 4,
	baseplate.Size.X / 2 - 60
)
local offsetZ = math.clamp(
	24,
	-baseplate.Size.Z / 2 + 53,
	baseplate.Size.Z / 2 - 11
)

local origin = baseplate.CFrame * CFrame.new(
	offsetX,
	baseplate.Size.Y / 2,
	offsetZ
)

local function part(name, size, position, color, rotation)
	local object = Instance.new("Part")
	object.Name = name
	object.Size = size
	object.CFrame = origin
		* CFrame.new(position)
		* CFrame.Angles(0, rotation or 0, 0)
	object.Color = color or CONFIG.WallColor
	object.Material = Enum.Material.Concrete
	object.Anchored = true
	object.CanTouch = false
	object.TopSurface = Enum.SurfaceType.Smooth
	object.BottomSurface = Enum.SurfaceType.Smooth
	object.Parent = hospital
	return object
end

-- Small finishes are visual only, so they cannot snag the player or absorb shots.
local function detail(name, size, position, color, material, rotation)
	local object = part(name, size, position, color, rotation)
	object.Material = material or Enum.Material.Metal
	object.CanCollide, object.CanQuery, object.CanTouch = false, false, false
	return object
end

local function sign(name, text, position, rotation, width)
	local board = part(
		name,
		Vector3.new(width or 5, 1.3, 0.12),
		position,
		CONFIG.FurnitureColor,
		rotation
	)
	board.CanCollide, board.CanQuery, board.CanTouch = false, false, false
	board.Material = Enum.Material.Metal

	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 40
	surface.LightInfluence = 0
	surface.Parent = board

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(230, 236, 241)
	label.Parent = surface
	return board
end

local function ceilingLight(x, z, y)
	local fixture = part(
		"LightFixture",
		Vector3.new(1.5, 0.2, 2),
		Vector3.new(x, y or 9.8, z),
		Color3.fromRGB(193, 210, 226)
	)
	fixture.Material = Enum.Material.Neon
	fixture.CanCollide = false
	fixture.CanQuery = false
	detail("LightHousing", Vector3.new(1.9, 0.18, 2.4), Vector3.new(x, (y or 9.8) + 0.16, z), CONFIG.TrimColor)

	local light = Instance.new("PointLight")
	light.Color = fixture.Color
	light.Brightness = 1.2
	light.Range = 18
	light.Shadows = false
	light.Parent = fixture
end

-- One building, two floors.
--   Floor 1: lobby -> bent corridor -> maternity ward, plus a stairwell off the corridor.
--   Floor 2: reached by a ramp in the stairwell: landing -> upper hall -> isolation ward.
-- Grid coordinates increase northward; world Z decreases northward.
local S = CONFIG.CellSize
local T = CONFIG.WallThickness
local H = CONFIG.WallHeight
local SLAB = CONFIG.SlabThickness
local ROOF = CONFIG.RoofThickness
local floor1 = CONFIG.FloorThickness          -- floor 1 walking surface
local floor2 = floor1 + H + SLAB              -- floor 2 walking surface
local levelBase = {floor1, floor2}
hospital:SetAttribute("UpperFloorTop", floor2)

local cells = {}
local doors = {}

local function key(x, z, level)
	return x .. ":" .. z .. ":" .. level
end

local function edgeKey(a, b)
	if a > b then
		a, b = b, a
	end
	return a .. "|" .. b
end

local function cell(x, z, zone, level)
	cells[key(x, z, level)] = {x = x, z = z, zone = zone, level = level}
end

local function room(x1, x2, z1, z2, zone, level)
	for x = x1, x2 do
		for z = z1, z2 do
			cell(x, z, zone, level)
		end
	end
end

local function doorway(x1, z1, x2, z2, level)
	doors[edgeKey(key(x1, z1, level), key(x2, z2, level))] = true
end

---------------------------------------------------------------- Floor 1
room(0, 2, 0, 2, "Lobby", 1)                 -- Lobby: 21 x 21 studs.
cell(1, 3, "Corridor", 1)                    -- Bent corridor route.
for x = 1, 4 do
	cell(x, 4, "Corridor", 1)
end
for z = 5, 7 do
	cell(4, z, "Corridor", 1)
end
room(5, 8, 5, 7, "Maternity", 1)             -- Maternity ward: 28 x 21 studs.
for z = 5, 8 do
	cell(2, z, "Stair", 1)                   -- Stairwell shaft, 7 x 28 studs.
end

doorway(1, 2, 1, 3, 1) -- Lobby exit.
doorway(4, 6, 5, 6, 1) -- Maternity entrance.
doorway(2, 4, 2, 5, 1) -- Stairwell door (locked by CourierGame).

---------------------------------------------------------------- Floor 2
for z = 5, 8 do
	cell(2, z, "Stair", 2)                   -- Open to the shaft below (no floor).
end
for _, c in ipairs({{2, 9}, {3, 9}, {4, 9}, {4, 10}, {5, 10}, {6, 10}}) do
	cell(c[1], c[2], "UpperHall", 2)         -- Landing + bent upper hall.
end
room(5, 7, 7, 9, "Isolation", 2)             -- Isolation ward: 21 x 21 studs.

doorway(2, 8, 2, 9, 2)  -- Top of the stairs to the landing.
doorway(6, 10, 6, 9, 2) -- Upper hall to the isolation ward.

---------------------------------------------------------------- Geometry
local function wall(x, z, dx, dz, hasDoor, level, height, exterior, zone)
	local horizontal = dz ~= 0
	local center = Vector3.new(
		x * S + dx * S / 2,
		levelBase[level] + height / 2,
		-z * S - dz * S / 2
	)

	local function section(name, length, h, along, vertical, color)
		local size = horizontal
			and Vector3.new(length, h, T)
			or Vector3.new(T, h, length)

		local shift = horizontal
			and Vector3.new(along, vertical, 0)
			or Vector3.new(0, vertical, along)

		return part(name, size, center + shift, color)
	end
	local function finish(length, along)
		local base = levelBase[level]
		local function band(name, tall, y, color, thickness)
			local size = horizontal and Vector3.new(length, tall, T + thickness)
				or Vector3.new(T + thickness, tall, length)
			local p = Vector3.new(center.X, y, center.Z)
			p += horizontal and Vector3.new(along, 0, 0) or Vector3.new(0, 0, along)
			detail(name, size, p, color, Enum.Material.SmoothPlastic)
		end
		band("HygienicWallPanel", CONFIG.PanelHeight, base + CONFIG.PanelHeight / 2, CONFIG.AccentColor, 0.035)
		band("WallBumperRail", 0.14, base + CONFIG.PanelHeight, CONFIG.TrimColor, 0.13)
		band("WallSkirting", 0.25, base + 0.125, CONFIG.TrimColor, 0.08)
		band("CeilingCornice", 0.18, base + height - 0.09, CONFIG.TrimColor, 0.07)
	end

	if not hasDoor then
		if exterior and zone ~= "Stair" then
			local w, h, sill = CONFIG.WindowWidth, CONFIG.WindowHeight, CONFIG.WindowSill
			local jamb = (S - w) / 2
			section("WindowPier", jamb, height, -(S + w) / 4, 0)
			section("WindowPier", jamb, height, (S + w) / 4, 0)
			section("WindowSillWall", w, sill, 0, (sill - height) / 2)
			local top = height - sill - h
			section("WindowHeaderWall", w, top, 0, (height - top) / 2)
			local glass = section("HospitalWindow", w, h, 0, sill + h / 2 - height / 2, CONFIG.WindowColor)
			glass.Size = horizontal and Vector3.new(w, h, 0.18) or Vector3.new(0.18, h, w)
			glass.Material, glass.Transparency, glass.Reflectance = Enum.Material.Glass, 0.38, 0.08
			local mid = levelBase[level] + sill + h / 2
			for _, side in ipairs({-1, 1}) do
				local framePosition = Vector3.new(center.X, mid, center.Z)
				framePosition += horizontal and Vector3.new(side * w / 2, 0, 0) or Vector3.new(0, 0, side * w / 2)
				detail("WindowFrame", horizontal and Vector3.new(0.15, h + 0.25, T + 0.18) or Vector3.new(T + 0.18, h + 0.25, 0.15), framePosition, CONFIG.TrimColor)
				detail("WindowFrame", horizontal and Vector3.new(w + 0.25, 0.15, T + 0.18) or Vector3.new(T + 0.18, 0.15, w + 0.25), Vector3.new(center.X, mid + side * h / 2, center.Z), CONFIG.TrimColor)
			end
			detail("WindowMullion", horizontal and Vector3.new(0.1, h, 0.24) or Vector3.new(0.24, h, 0.1), Vector3.new(center.X, mid, center.Z), CONFIG.TrimColor)
		else
			section("Wall", S, height, 0, 0)
		end
		finish(S, 0)
		return
	end

	local jamb = (S - CONFIG.DoorWidth) / 2
	local jambOffset = (S + CONFIG.DoorWidth) / 4
	section("DoorJamb", jamb, height, -jambOffset, 0)
	section("DoorJamb", jamb, height, jambOffset, 0)
	finish(jamb, -jambOffset)
	finish(jamb, jambOffset)
	section(
		"DoorLintel",
		CONFIG.DoorWidth,
		height - CONFIG.DoorHeight,
		0,
		CONFIG.DoorHeight / 2
	)
	local frameHeight = CONFIG.DoorHeight
	for _, side in ipairs({-1, 1}) do
		local p = Vector3.new(center.X, levelBase[level] + frameHeight / 2, center.Z)
		p += horizontal and Vector3.new(side * (CONFIG.DoorWidth / 2 + 0.12), 0, 0) or Vector3.new(0, 0, side * (CONFIG.DoorWidth / 2 + 0.12))
		detail("DoorCasing", horizontal and Vector3.new(0.24, frameHeight, T + 0.2) or Vector3.new(T + 0.2, frameHeight, 0.24), p, CONFIG.TrimColor)
	end
	detail("DoorCasingHeader", horizontal and Vector3.new(CONFIG.DoorWidth + 0.5, 0.25, T + 0.2) or Vector3.new(T + 0.2, 0.25, CONFIG.DoorWidth + 0.5), Vector3.new(center.X, levelBase[level] + frameHeight + 0.13, center.Z), CONFIG.TrimColor)
end

local directions = {
	{1, 0},
	{-1, 0},
	{0, 1},
	{0, -1},
}

for id, data in pairs(cells) do
	local cx, cz = data.x * S, -data.z * S

	if data.level == 1 then
		local tile = part(
			data.zone .. "Floor",
			Vector3.new(S, floor1, S),
			Vector3.new(cx, floor1 / 2, cz),
			CONFIG.FloorColor
		)
		if not hospital.PrimaryPart then
			hospital.PrimaryPart = tile
		end
		tile.Material, tile.Reflectance = CONFIG.FloorMaterial, CONFIG.FloorReflectance

		-- Ceiling, unless this is the open shaft or a floor-2 slab already covers it.
		local above = cells[key(data.x, data.z, 2)]
		local covered = above ~= nil and above.zone ~= "Stair"
		if data.zone ~= "Stair" and not covered then
			part("Ceiling", Vector3.new(S, SLAB, S),
				Vector3.new(cx, floor1 + H + SLAB / 2, cz))
		end
	else
		if data.zone ~= "Stair" then
			local tile = part(
				data.zone .. "Floor",
				Vector3.new(S, SLAB, S),
				Vector3.new(cx, floor2 - SLAB / 2, cz),
				CONFIG.FloorColor
			)
			tile.Material, tile.Reflectance = CONFIG.FloorMaterial, CONFIG.FloorReflectance

			-- Floor-2 space with no room below: a solid block keeps it from floating.
			if not cells[key(data.x, data.z, 1)] then
				part("SupportBlock", Vector3.new(S, H, S),
					Vector3.new(cx, floor1 + H / 2, cz))
			end
		end

		part("Roof", Vector3.new(S, ROOF, S),
			Vector3.new(cx, floor2 + H + ROOF / 2, cz))
	end
	if data.zone ~= "Stair" then
		local y = levelBase[data.level] + 0.012
		for _, s in ipairs({-1, 1}) do
			detail("FloorGrout", Vector3.new(S - 0.03, 0.012, 0.035), Vector3.new(cx, y, cz + s * S / 2), CONFIG.TrimColor, Enum.Material.SmoothPlastic)
			detail("FloorGrout", Vector3.new(0.035, 0.012, S - 0.03), Vector3.new(cx + s * S / 2, y, cz), CONFIG.TrimColor, Enum.Material.SmoothPlastic)
		end
	end

	for _, direction in ipairs(directions) do
		local dx, dz = direction[1], direction[2]
		local neighborId = key(data.x + dx, data.z + dz, data.level)
		local neighbor = cells[neighborId]

		-- Process each shared edge once.
		if not neighbor or id < neighborId then
			if not neighbor or neighbor.zone ~= data.zone then
				local entrance = data.level == 1
					and data.x == 1
					and data.z == 0
					and dz == -1

				-- Shaft walls on floor 1 run up to the floor-2 level.
				local height = H
				if data.level == 1 and (data.zone == "Stair"
					or (neighbor and neighbor.zone == "Stair")) then
					height = H + SLAB
				end

				wall(
					data.x,
					data.z,
					dx,
					dz,
					entrance or doors[edgeKey(id, neighborId)],
					data.level,
					height,
					neighbor == nil,
					data.zone
				)
			end
		end
	end
end

-- Stair ramp: floor 1 corridor level up to the floor 2 landing (about 21 degrees).
do
	local rampStart = Vector3.new(2 * S, floor1, -(4 * S + S / 2))
	local rampEnd = Vector3.new(2 * S, floor2, -(8 * S + S / 2))
	local ramp = Instance.new("Part")
	ramp.Name = "StairRamp"
	ramp.Size = Vector3.new(CONFIG.StairWidth, 1, (rampEnd - rampStart).Magnitude)
	ramp.CFrame = origin
		* CFrame.lookAt((rampStart + rampEnd) / 2, rampEnd)
		* CFrame.new(0, -0.5, 0)
	ramp.Color = CONFIG.FloorColor
	ramp.Material = Enum.Material.SmoothPlastic
	ramp.Anchored = true
	ramp.TopSurface = Enum.SurfaceType.Smooth
	ramp.BottomSurface = Enum.SurfaceType.Smooth
	ramp.Parent = hospital
	-- Visible stair treads sit over the original smooth collision ramp.
	-- This preserves the climb while giving the shaft a proper staircase.
	local rise = (rampEnd.Y - rampStart.Y) / CONFIG.StairTreads
	local run = math.abs(rampEnd.Z - rampStart.Z) / CONFIG.StairTreads
	for index = 1, CONFIG.StairTreads do
		local y = rampStart.Y + rise * (index - 0.5)
		local z = rampStart.Z - run * (index - 0.5)
		detail("StairTread", Vector3.new(CONFIG.StairWidth, 0.08, run), Vector3.new(2 * S, y, z), CONFIG.FloorColor, Enum.Material.Metal)
		detail("StairRiser", Vector3.new(CONFIG.StairWidth, rise, 0.06), Vector3.new(2 * S, y - rise / 2, z + run / 2), CONFIG.TrimColor)
		detail("StairNosing", Vector3.new(CONFIG.StairWidth - 0.15, 0.035, 0.09), Vector3.new(2 * S, y + 0.06, z + run / 2 - 0.04), Color3.fromRGB(200, 169, 89))
	end
	for _, side in ipairs({-1, 1}) do
		local shift = Vector3.new(side * (CONFIG.StairWidth / 2 - 0.2), 3, 0)
		local a, b = rampStart + shift, rampEnd + shift
		local rail = detail("StairHandrail", Vector3.new(0.14, 0.14, (b - a).Magnitude), (a + b) / 2, CONFIG.TrimColor)
		rail.CFrame = origin * CFrame.lookAt((a + b) / 2, b)
		for index = 0, 7 do
			local foot = rampStart:Lerp(rampEnd, index / 7) + Vector3.new(shift.X, 0, 0)
			detail("StairBaluster", Vector3.new(0.1, 3, 0.1), foot + Vector3.new(0, 1.5, 0), CONFIG.TrimColor)
		end
	end
end

-- Short entry approach, flush with the hospital floor.
part(
	"EntryApproach",
	Vector3.new(6, floor1, 7),
	Vector3.new(7, floor1 / 2, 7),
	CONFIG.FloorColor
)

---------------------------------------------------------------- Furniture
-- Lobby furniture leaves the entrance-to-corridor route clear.
part("ReceptionDesk", Vector3.new(5, 3, 2.5),
	Vector3.new(13, floor1 + 1.5, -10),
	CONFIG.FurnitureColor)

for _, z in ipairs({-3, -11}) do
	part("WaitingBench", Vector3.new(3, 1.5, 5),
		Vector3.new(0, floor1 + 0.75, z),
		CONFIG.FurnitureColor)
end

-- Bed bays with bassinets. `side` picks which side the bassinet sits on.
local function bedBay(x, z, base, side)
	part("BedBase", Vector3.new(4, 1.4, 7),
		Vector3.new(x, base + 0.7, z),
		CONFIG.FurnitureColor)

	part("Mattress", Vector3.new(3.8, 0.6, 6.8),
		Vector3.new(x, base + 1.7, z),
		CONFIG.BeddingColor)

	part("Pillow", Vector3.new(3.2, 0.35, 1.2),
		Vector3.new(x, base + 2.175, z - 2.5),
		Color3.fromRGB(219, 223, 226))

	part("Headboard", Vector3.new(4, 2.5, 0.3),
		Vector3.new(x, base + 1.25, z - 3.35),
		CONFIG.FurnitureColor)

	local bx = x + side * 4.2
	part("BassinetStand", Vector3.new(0.5, 2, 0.5),
		Vector3.new(bx, base + 1, z),
		CONFIG.FurnitureColor)

	part("BassinetTray", Vector3.new(2, 0.3, 3),
		Vector3.new(bx, base + 2.15, z),
		CONFIG.BeddingColor)

	for _, s in ipairs({-1, 1}) do
		part("BassinetSide", Vector3.new(0.15, 0.65, 3),
			Vector3.new(bx + s * 0.925, base + 2.6, z),
			CONFIG.FurnitureColor)
	end
	for _, sx in ipairs({-1, 1}) do
		for _, sz in ipairs({-1, 1}) do
			detail("BedCaster", Vector3.new(0.28, 0.45, 0.45), Vector3.new(x + sx * 1.8, base + 0.23, z + sz * 2.8), CONFIG.TrimColor)
		end
		detail("BedSafetyRail", Vector3.new(0.1, 0.12, 4.1), Vector3.new(x + sx * 1.98, base + 2.35, z), Color3.fromRGB(132, 146, 143))
		for _, dz in ipairs({-1.7, 1.7}) do
			detail("BedRailSupport", Vector3.new(0.1, 0.8, 0.1), Vector3.new(x + sx * 1.98, base + 1.95, z + dz), CONFIG.TrimColor)
		end
	end
	detail("FoldedBlanket", Vector3.new(3.6, 0.12, 0.75), Vector3.new(x, base + 2.07, z + 2.75), Color3.fromRGB(92, 125, 121), Enum.Material.Fabric)
	local poleX, poleZ = x + side * 2.7, z - 2.4
	detail("IVPole", Vector3.new(0.09, 5.5, 0.09), Vector3.new(poleX, base + 2.75, poleZ), Color3.fromRGB(137, 151, 151))
	detail("IVPoleFeet", Vector3.new(1.4, 0.12, 0.12), Vector3.new(poleX, base + 0.15, poleZ), CONFIG.TrimColor)
	detail("IVPoleFeet", Vector3.new(0.12, 0.12, 1.4), Vector3.new(poleX, base + 0.15, poleZ), CONFIG.TrimColor)
	detail("IVHook", Vector3.new(0.9, 0.07, 0.07), Vector3.new(poleX, base + 5.45, poleZ), CONFIG.TrimColor)
	local bag = detail("IVBag", Vector3.new(0.5, 0.9, 0.2), Vector3.new(poleX + 0.3, base + 4.8, poleZ), Color3.fromRGB(164, 193, 187), Enum.Material.Glass)
	bag.Transparency = 0.3
	detail("IVTube", Vector3.new(0.025, 2.7, 0.025), Vector3.new(poleX + 0.3, base + 3.05, poleZ), Color3.fromRGB(121, 149, 139), Enum.Material.SmoothPlastic)
end

-- Floor 1: maternity ward, central aisle stays clear.
for _, x in ipairs({38.5, 52.5}) do
	for _, z in ipairs({-35.7, -48.3}) do
		bedBay(x, z, floor1, 1)
	end
end

part("NursesCounter", Vector3.new(5, 3, 1.5),
	Vector3.new(28, floor1 + 1.5, -50),
	CONFIG.FurnitureColor)

-- Floor 2: isolation ward with a specimen table in the middle.
bedBay(34.5, -57, floor2, 1)
bedBay(49.5, -57, floor2, -1)
part("SpecimenTable", Vector3.new(4, 3, 2.5),
	Vector3.new(42, floor2 + 1.5, -52),
	CONFIG.FurnitureColor)

---------------------------------------------------------------- Signs
-- Landmarks appear before the next turn disappears into fog.
sign("LobbySign", "HOSPITAL LOBBY",
	Vector3.new(7, 9.6, 3.6), math.pi, 10)

sign("FirstTurnSign", "MATERNITY >",
	Vector3.new(7, 7.5, -30.9), math.pi, 5)

sign("StairsSign", "STAIRS",
	Vector3.new(14, 9.5, -30.9), math.pi, 5)

sign("SecondTurnSign", "WARD A",
	Vector3.new(30.9, 7.5, -28), math.pi / 2, 5)

sign("MaternitySign", "MATERNITY",
	Vector3.new(30.9, 9.5, -42), math.pi / 2, 5)

sign("IsolationSign", "ISOLATION WARD",
	Vector3.new(42, floor2 + 9.5, -67.1), 0, 5)

---------------------------------------------------------------- Lights
for _, point in ipairs({
	{7, -7},
	{7, -21},
	{7, -28},
	{28, -28},
	{28, -42},
	{39, -42},
	{53, -42},
	{14, -36},   -- foot of the stairs
	}) do
	ceilingLight(point[1], point[2])
end

local upperY = floor2 + 9.3
for _, point in ipairs({
	{14, -40},   -- stair shaft
	{14, -52},
	{14, -63},   -- landing
	{28, -66},   -- upper hall
	{42, -70},
	{42, -56},   -- isolation ward
	}) do
	ceilingLight(point[1], point[2], upperY)
end

---------------------------------------------------------------- Exterior architecture
-- The forecourt stops before the courier's driving lane (local Z = 11 onward).
local canopyY = floor1 + CONFIG.DoorHeight + 0.8
part("EntranceCanopy", Vector3.new(18, 0.45, 6.5), Vector3.new(7, canopyY, 6.6), CONFIG.TrimColor).Material = Enum.Material.Metal
detail("CanopySnow", Vector3.new(18, 0.16, 6.5), Vector3.new(7, canopyY + 0.31, 6.6), Color3.fromRGB(201, 211, 209), Enum.Material.Snow)
for _, x in ipairs({-0.5, 14.5}) do
	part("EntranceColumn", Vector3.new(0.55, canopyY - floor1, 0.55), Vector3.new(x, floor1 + (canopyY - floor1) / 2, 8.8), CONFIG.TrimColor).Material = Enum.Material.Metal
	part("ColumnPlinth", Vector3.new(0.95, 0.5, 0.95), Vector3.new(x, floor1 + 0.25, 8.8), CONFIG.WallColor)
end
local fascia = sign("HospitalIdentity", "RACCOON CITY HOSPITAL", Vector3.new(7, canopyY - 0.2, 9.92), math.pi, 13.8)
fascia.Color = CONFIG.AccentColor
detail("CanopyFascia", Vector3.new(18, 1.55, 0.24), Vector3.new(7, canopyY - 0.18, 9.8), CONFIG.AccentColor)
detail("MedicalCrossVertical", Vector3.new(0.32, 1.2, 0.16), Vector3.new(-1.1, canopyY - 0.2, 9.99), Color3.fromRGB(225, 231, 217), Enum.Material.Neon)
detail("MedicalCrossHorizontal", Vector3.new(1.2, 0.32, 0.16), Vector3.new(-1.1, canopyY - 0.2, 10), Color3.fromRGB(225, 231, 217), Enum.Material.Neon)
sign("EntranceSubtitle", "EMERGENCY  /  RECEPTION", Vector3.new(7, 7.5, 4.08), math.pi, 5)
ceilingLight(7, 7, canopyY - 0.35)
for _, x in ipairs({-3.5, 3.5, 10.5, 17.5}) do
	detail("FacadePier", Vector3.new(0.44, H + SLAB, 0.35), Vector3.new(x, floor1 + (H + SLAB) / 2, 4.05), CONFIG.TrimColor)
end
detail("LobbyRoofCap", Vector3.new(22, 0.26, 22), Vector3.new(7, floor1 + H + SLAB + 0.13, -7), CONFIG.TrimColor)
for _, side in ipairs({-1, 1}) do
	detail("LobbyParapet", Vector3.new(0.3, 0.9, 22), Vector3.new(7 + side * 10.85, 12.1, -7), CONFIG.WallColor, Enum.Material.Concrete)
	detail("LobbyParapet", Vector3.new(22, 0.9, 0.3), Vector3.new(7, 12.1, -7 + side * 10.85), CONFIG.WallColor, Enum.Material.Concrete)
end
-- Upper roof edging follows the original footprint instead of covering the open shaft.
for _, data in pairs(cells) do
	if data.level == 2 then
		for _, direction in ipairs(directions) do
			local dx, dz = direction[1], direction[2]
			if not cells[key(data.x + dx, data.z + dz, 2)] then
				local size = dz ~= 0 and Vector3.new(S, 0.65, 0.32) or Vector3.new(0.32, 0.65, S)
				detail("UpperRoofParapet", size, Vector3.new(data.x * S + dx * S / 2, floor2 + H + ROOF + 0.3, -data.z * S - dz * S / 2), CONFIG.TrimColor)
			end
		end
	end
end
local function airUnit(x, roofY, z)
	detail("AirHandlingUnit", Vector3.new(4.8, 1.8, 3.2), Vector3.new(x, roofY + 0.9, z), Color3.fromRGB(100, 112, 111))
	for index = -3, 3 do
		detail("VentLouvre", Vector3.new(3.8, 0.08, 0.08), Vector3.new(x, roofY + 0.9 + index * 0.19, z + 1.65), CONFIG.TrimColor)
	end
	detail("VentDuct", Vector3.new(1.2, 0.75, 3), Vector3.new(x + 1.2, roofY + 0.4, z - 2.8), Color3.fromRGB(113, 125, 122))
end
airUnit(0, 11.8, -9)
airUnit(55, 11.5, -37)
airUnit(47, 22, -56)
for _, x in ipairs({-3.95, 17.95}) do
	detail("RainwaterDownpipe", Vector3.new(0.16, 10.7, 0.16), Vector3.new(x, 5.7, -15), CONFIG.TrimColor)
end
for _, x in ipairs({1, 13}) do
	local bollard = part("EntryBollard", Vector3.new(0.35, 2.6, 0.35), Vector3.new(x, 1.3, 10.4), CONFIG.TrimColor)
	bollard.Material = Enum.Material.Metal
	detail("BollardReflector", Vector3.new(0.38, 0.22, 0.38), Vector3.new(x, 2.0, 10.4), Color3.fromRGB(204, 177, 96), Enum.Material.Neon)
end
for index = 0, 4 do
	detail("ApproachStripe", Vector3.new(5.2, 0.015, 0.3), Vector3.new(7, floor1 + 0.02, 6 + index * 0.8), Color3.fromRGB(207, 209, 178), Enum.Material.SmoothPlastic)
end

---------------------------------------------------------------- Clinical interior details
local function monitor(x, y, z, yaw)
	local screen = detail("ClinicalMonitor", Vector3.new(1.9, 1.25, 0.2), Vector3.new(x, y, z), Color3.fromRGB(17, 28, 29), Enum.Material.Metal, yaw)
	local surface = Instance.new("SurfaceGui")
	surface.Name, surface.Face, surface.LightInfluence = "MonitorDisplay", Enum.NormalId.Front, 0
	surface.CanvasSize = Vector2.new(190, 125)
	surface.Parent = screen
	local heading = Instance.new("TextLabel")
	heading.Size = UDim2.fromScale(1, 0.25)
	heading.BackgroundTransparency = 1
	heading.Font, heading.TextSize = Enum.Font.Code, 12
	heading.Text, heading.TextColor3 = "PATIENT MONITOR", Color3.fromRGB(130, 176, 162)
	heading.Parent = surface
	local points = {Vector2.new(8,72),Vector2.new(49,72),Vector2.new(60,64),Vector2.new(68,84),Vector2.new(77,43),Vector2.new(86,90),Vector2.new(95,72),Vector2.new(141,72),Vector2.new(155,64),Vector2.new(163,72),Vector2.new(182,72)}
	for index = 1, #points - 1 do
		local a, b = points[index], points[index + 1]
		local delta = b - a
		local line = Instance.new("Frame")
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		line.Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2)
		line.Size, line.Rotation = UDim2.fromOffset(delta.Magnitude, 2), math.deg(math.atan2(delta.Y, delta.X))
		line.BackgroundColor3, line.BorderSizePixel = Color3.fromRGB(107, 194, 153), 0
		line.Parent = surface
	end
	return screen
end
-- Keep the desktop pickup at (12.2, -9.6) unobscured.
monitor(14.7, 4.25, -10.6, math.pi)
detail("ReceptionKeyboard", Vector3.new(1.6, 0.07, 0.65), Vector3.new(14.6, 3.54, -9.7), CONFIG.TrimColor, Enum.Material.SmoothPlastic)
sign("ReceptionDeskLabel", "RECEPTION", Vector3.new(13, 2.3, -8.7), math.pi, 4.5)
detail("ReceptionToeKick", Vector3.new(4.9, 0.25, 0.08), Vector3.new(13, 0.85, -8.73), CONFIG.TrimColor)
-- Keycard is at the east end of this counter; equipment stays at the west end.
monitor(26.7, 4.3, -50.2, math.pi)
sign("NurseDeskLabel", "NURSES' STATION", Vector3.new(28, 2.25, -49.22), math.pi, 4.5)
for _, z in ipairs({-3, -11}) do
	-- The first-aid pickup remains on the centre of the first bench.
	detail("WaitingBackrest", Vector3.new(0.3, 1.5, 4.8), Vector3.new(-1.3, 2.2, z), CONFIG.AccentColor, Enum.Material.Fabric)
	for _, endZ in ipairs({-2.25, 2.25}) do
		detail("BenchArmrest", Vector3.new(2.7, 0.12, 0.12), Vector3.new(0, 2.5, z + endZ), CONFIG.TrimColor)
	end
end
sign("LobbyDirectory", "01  RECEPTION / MATERNITY\n02  ISOLATION / SPECIMENS", Vector3.new(16.91, 6, -5), math.pi / 2, 6)
sign("StaffNotice", "STAFF ACCESS ONLY\nKEYCARD REQUIRED", Vector3.new(19.9, 5.7, -30.92), math.pi, 3.8)
sign("IsolationWarning", "ISOLATION  /  BIOHAZARD", Vector3.new(42, floor2 + 7.4, -66.9), 0, 5)
sign("UpperLevelNumber", "02  /  CLINICAL WING", Vector3.new(14, floor2 + 7.2, -65.91), math.pi, 5)
sign("LobbyExitSign", "EXIT", Vector3.new(7, 8.7, 2.91), 0, 3)

for _, bed in ipairs({
	{38.5, -35.7, floor1, "A-01"}, {52.5, -35.7, floor1, "A-02"},
	{38.5, -48.3, floor1, "A-03"}, {52.5, -48.3, floor1, "A-04"},
	{34.5, -57, floor2, "I-01"}, {49.5, -57, floor2, "I-02"},
}) do
	monitor(bed[1], bed[3] + 3.4, bed[2] - 3.55, math.pi)
	sign("BedNumber", bed[4], Vector3.new(bed[1], bed[3] + 1.1, bed[2] + 3.53), math.pi, 1.4)
end
for _, z in ipairs({-35.7, -48.3}) do
	detail("PrivacyTrack", Vector3.new(0.1, 0.1, 6.1), Vector3.new(45.5, 9.9, z), CONFIG.TrimColor)
	-- Partly drawn curtains divide beds but leave the six-stud central ward aisle open.
	for index = 0, 5 do
		detail("PrivacyCurtain", Vector3.new(0.11, 5.6, 0.4), Vector3.new(45.5 + (index % 2) * 0.08, 6.7, z - 1.8 + index * 0.36), Color3.fromRGB(116, 145, 137), Enum.Material.Fabric)
	end
end
for _, level in ipairs({{0.5, 56.5, -51.7}, {11.5, 33.1, -48.4}}) do
	local y, x, z = level[1], level[2], level[3]
	detail("MedicalCabinet", Vector3.new(2.2, 5.8, 0.9), Vector3.new(x, y + 2.9, z), CONFIG.AccentColor, Enum.Material.Metal)
	for _, side in ipairs({-1, 1}) do
		detail("CabinetDoor", Vector3.new(1.05, 5.3, 0.09), Vector3.new(x + side * 0.55, y + 2.95, z + 0.51), CONFIG.WallColor)
		detail("CabinetHandle", Vector3.new(0.07, 0.6, 0.12), Vector3.new(x + side * 0.14, y + 3.05, z + 0.61), CONFIG.TrimColor)
	end
end
-- Recessed floor lines mark turns without changing the collision surface.
for _, route in ipairs({
	{Vector3.new(0.14, 0.012, 13), Vector3.new(9.5, floor1 + 0.022, -20)},
	{Vector3.new(16, 0.012, 0.14), Vector3.new(19, floor1 + 0.022, -26)},
	{Vector3.new(0.14, 0.012, 18), Vector3.new(26, floor1 + 0.022, -39)},
	{Vector3.new(12, 0.012, 0.14), Vector3.new(20, floor2 + 0.022, -61)},
}) do
	detail("WardRouteStripe", route[1], route[2], Color3.fromRGB(139, 175, 166), Enum.Material.SmoothPlastic)
end
hospital.Parent = workspace
print("Built enhanced two-floor hospital: framed windows, entrance canopy, stairs, clinical wards, and preserved mission route.")
