-- Visibility opens gradually on the long city road; the hospital keeps its fog.
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local CFG = {
	RoadFog = 210, CityFog = 410, BlendRate = 1.5, CityRevealDistance = 260,
	RoadAtmosphere = {Density = 0.32, Haze = 1.8, Offset = 0},
	CityAtmosphere = {Density = 0.14, Haze = 0.65, Offset = 0.12},
}
local originalStart, originalEnd
local atmosphereOriginals = {}
local elapsed = 0
local function lerp(a, b, alpha) return a + (b - a) * alpha end
local connection = RunService.Heartbeat:Connect(function(dt)
	elapsed += dt
	if elapsed < 0.1 then return end
	local step = elapsed
	elapsed = 0
	local city = workspace:FindFirstChild("RaccoonCity")
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local roadOrigin = city and city:GetAttribute("RoadOrigin")
	local cityOrigin = city and city:GetAttribute("CityOrigin")
	local ready = root and typeof(roadOrigin) == "CFrame" and typeof(cityOrigin) == "CFrame"
	if not originalEnd then
		if not ready then return end
		originalStart, originalEnd = Lighting.FogStart, Lighting.FogEnd
	end
	local roadBlend, cityBlend = 0, 0
	if ready then
		local roadDistance = roadOrigin:PointToObjectSpace(root.Position).Z
		local distance = (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(cityOrigin.X, 0, cityOrigin.Z)).Magnitude
		roadBlend = math.clamp(roadDistance / 90, 0, 1)
		cityBlend = (1 - math.clamp(distance / CFG.CityRevealDistance, 0, 1)) * roadBlend
	end
	local target = lerp(lerp(originalEnd, CFG.RoadFog, roadBlend), CFG.CityFog, cityBlend)
	local blend = 1 - math.exp(-CFG.BlendRate * step)
	Lighting.FogEnd += (target - Lighting.FogEnd) * blend
	Lighting.FogStart += (originalStart + 15 * roadBlend - Lighting.FogStart) * blend
	-- If another weather system adds Atmosphere, it overrides distance fog.
	-- Cache each instance before changing it; never create an atmosphere here.
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		local original = atmosphereOriginals[atmosphere]
		if not original then
			original = {Density = atmosphere.Density, Haze = atmosphere.Haze, Offset = atmosphere.Offset}
			atmosphereOriginals[atmosphere] = original
		end
		for _, property in ipairs({"Density", "Haze", "Offset"}) do
			local desired = lerp(lerp(original[property], CFG.RoadAtmosphere[property], roadBlend), CFG.CityAtmosphere[property], cityBlend)
			atmosphere[property] = lerp(atmosphere[property], desired, blend)
		end
	end
end)
script.Destroying:Connect(function()
	connection:Disconnect()
	if originalEnd then Lighting.FogStart, Lighting.FogEnd = originalStart, originalEnd end
	for atmosphere, original in pairs(atmosphereOriginals) do
		if atmosphere.Parent then
			for property, value in pairs(original) do atmosphere[property] = value end
		end
	end
end)
