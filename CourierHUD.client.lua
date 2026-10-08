-- CourierHUD (LocalScript, StarterPlayer > StarterPlayerScripts)
-- Health "condition" panel, first aid count, objective + arrow, pickup toasts,
-- damage / low-health vignette, death screen and delivery-complete card.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ContextActionService = game:GetService("ContextActionService")

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("CourierRemote")

local LOW_FRACTION = 0.30     -- DANGER below this (matches the server's limp threshold)
local CAUTION_FRACTION = 0.60 -- CAUTION below this

local COLORS = {
	fine = Color3.fromRGB(96, 214, 130),
	caution = Color3.fromRGB(236, 170, 52),
	danger = Color3.fromRGB(224, 56, 48),
	dead = Color3.fromRGB(120, 120, 120),
	text = Color3.fromRGB(226, 231, 236),
	dim = Color3.fromRGB(140, 148, 158),
	panel = Color3.fromRGB(10, 12, 16),
}

----------------------------------------------------------------------
-- UI helpers
----------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "CourierHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 5
gui.Parent = player:WaitForChild("PlayerGui")

local function panel(parent, name, size, position, anchor)
	local f = Instance.new("Frame")
	f.Name = name
	f.Size = size
	f.Position = position
	f.AnchorPoint = anchor or Vector2.new(0, 0)
	f.BackgroundColor3 = COLORS.panel
	f.BackgroundTransparency = 0.3
	f.BorderSizePixel = 0
	f.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = f
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(70, 76, 86)
	stroke.Transparency = 0.4
	stroke.Parent = f
	return f
end

local function label(parent, name, text, size, position, textSize, font, color, alignX)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.Size = size
	l.Position = position
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextSize = textSize
	l.Font = font or Enum.Font.GothamMedium
	l.TextColor3 = color or COLORS.text
	l.TextXAlignment = alignX or Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Center
	l.Parent = parent
	return l
end

----------------------------------------------------------------------
-- Damage / low-health vignette (four gradient edges)
----------------------------------------------------------------------
local vignette = Instance.new("Folder")
vignette.Name = "Vignette"
vignette.Parent = gui

local edges = {}
local function edge(name, size, position, anchor, rotation)
	local f = Instance.new("Frame")
	f.Name = name
	f.Size = size
	f.Position = position
	f.AnchorPoint = anchor
	f.BackgroundColor3 = Color3.fromRGB(170, 8, 8)
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	f.Active = false
	f.ZIndex = 2
	f.Parent = vignette
	local g = Instance.new("UIGradient")
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	g.Rotation = rotation
	g.Parent = f
	table.insert(edges, f)
end
edge("Top", UDim2.new(1, 0, 0.28, 0), UDim2.new(0, 0, 0, 0), Vector2.new(0, 0), 90)
edge("Bottom", UDim2.new(1, 0, 0.28, 0), UDim2.new(0, 0, 1, 0), Vector2.new(0, 1), 270)
edge("Left", UDim2.new(0.18, 0, 1, 0), UDim2.new(0, 0, 0, 0), Vector2.new(0, 0), 0)
edge("Right", UDim2.new(0.18, 0, 1, 0), UDim2.new(1, 0, 0, 0), Vector2.new(1, 0), 180)

----------------------------------------------------------------------
-- Condition panel (sits above the weapon HUD)
----------------------------------------------------------------------
local healthPanel = panel(gui, "Condition", UDim2.new(0, 310, 0, 70), UDim2.new(0, 24, 1, -166), Vector2.new(0, 1))
label(healthPanel, "Caption", "CONDITION", UDim2.new(0, 120, 0, 14), UDim2.new(0, 14, 0, 8), 11, Enum.Font.GothamMedium, COLORS.dim)
local stateLabel = label(healthPanel, "State", "FINE", UDim2.new(0, 160, 0, 28), UDim2.new(0, 14, 0, 22), 24, Enum.Font.GothamBlack, COLORS.fine)
local aidLabel = label(healthPanel, "Aid", "", UDim2.new(0, 140, 0, 28), UDim2.new(1, -154, 0, 22), 13, Enum.Font.GothamMedium, COLORS.dim, Enum.TextXAlignment.Right)

local barTrack = Instance.new("Frame")
barTrack.Name = "Track"
barTrack.Size = UDim2.new(1, -28, 0, 5)
barTrack.Position = UDim2.new(0, 14, 0, 56)
barTrack.BackgroundColor3 = Color3.fromRGB(40, 44, 50)
barTrack.BorderSizePixel = 0
barTrack.Parent = healthPanel

local barFill = Instance.new("Frame")
barFill.Name = "Fill"
barFill.Size = UDim2.new(1, 0, 1, 0)
barFill.BackgroundColor3 = COLORS.fine
barFill.BorderSizePixel = 0
barFill.Parent = barTrack

----------------------------------------------------------------------
-- Objective panel (top-left) with direction arrow
----------------------------------------------------------------------
local objPanel = panel(gui, "Objective", UDim2.new(0, 340, 0, 82), UDim2.new(0, 24, 0, 56))
label(objPanel, "Caption", "OBJECTIVE", UDim2.new(0, 120, 0, 14), UDim2.new(0, 14, 0, 8), 11, Enum.Font.GothamMedium, COLORS.dim)
local arrow = label(objPanel, "Arrow", "â–²", UDim2.new(0, 30, 0, 30), UDim2.new(0, 12, 0, 34), 24, Enum.Font.GothamBold, COLORS.caution, Enum.TextXAlignment.Center)
arrow.AnchorPoint = Vector2.new(0, 0)
local objText = label(objPanel, "Text", "", UDim2.new(1, -62, 0, 38), UDim2.new(0, 50, 0, 24), 14, Enum.Font.GothamMedium, COLORS.text)
objText.TextWrapped = true
objText.TextYAlignment = Enum.TextYAlignment.Top
local distLabel = label(objPanel, "Distance", "", UDim2.new(1, -62, 0, 14), UDim2.new(0, 50, 0, 62), 12, Enum.Font.GothamMedium, COLORS.dim)

----------------------------------------------------------------------
-- Toast
----------------------------------------------------------------------
local toastLabel = Instance.new("TextLabel")
toastLabel.Name = "Toast"
toastLabel.AnchorPoint = Vector2.new(0.5, 0.5)
toastLabel.Position = UDim2.new(0.5, 0, 0.78, 0)
toastLabel.Size = UDim2.new(0, 460, 0, 34)
toastLabel.BackgroundColor3 = COLORS.panel
toastLabel.BackgroundTransparency = 1
toastLabel.TextTransparency = 1
toastLabel.Font = Enum.Font.GothamBold
toastLabel.TextSize = 16
toastLabel.TextColor3 = COLORS.text
toastLabel.Text = ""
toastLabel.BorderSizePixel = 0
toastLabel.ZIndex = 5
toastLabel.Parent = gui
local toastCorner = Instance.new("UICorner")
toastCorner.CornerRadius = UDim.new(0, 6)
toastCorner.Parent = toastLabel

local toastToken = 0
local function toast(text, kind)
	toastToken = toastToken + 1
	local token = toastToken
	toastLabel.Text = text
	if kind == "item" then
		toastLabel.TextColor3 = COLORS.fine
	elseif kind == "warn" then
		toastLabel.TextColor3 = COLORS.caution
	else
		toastLabel.TextColor3 = COLORS.text
	end
	toastLabel.TextTransparency = 0
	toastLabel.BackgroundTransparency = 0.35
	task.delay(2.6, function()
		if token ~= toastToken then
			return
		end
		TweenService:Create(toastLabel, TweenInfo.new(0.5), { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
	end)
end

----------------------------------------------------------------------
-- Death overlay
----------------------------------------------------------------------
local deathOverlay = Instance.new("Frame")
deathOverlay.Name = "Death"
deathOverlay.Size = UDim2.new(1, 0, 1, 0)
deathOverlay.BackgroundColor3 = Color3.new(0, 0, 0)
deathOverlay.BackgroundTransparency = 1
deathOverlay.BorderSizePixel = 0
deathOverlay.ZIndex = 20
deathOverlay.Active = false
deathOverlay.Parent = gui

local deathTitle = label(deathOverlay, "Title", "YOU DIED", UDim2.new(1, 0, 0, 80), UDim2.new(0, 0, 0.42, 0), 64, Enum.Font.GothamBlack, Color3.fromRGB(190, 24, 24), Enum.TextXAlignment.Center)
deathTitle.TextTransparency = 1
deathTitle.ZIndex = 21
local deathSub = label(deathOverlay, "Sub", "Returning to the last checkpoint...", UDim2.new(1, 0, 0, 24), UDim2.new(0, 0, 0.42, 84), 16, Enum.Font.GothamMedium, COLORS.dim, Enum.TextXAlignment.Center)
deathSub.TextTransparency = 1
deathSub.ZIndex = 21

local function showDeath()
	TweenService:Create(deathOverlay, TweenInfo.new(1.2), { BackgroundTransparency = 0.1 }):Play()
	TweenService:Create(deathTitle, TweenInfo.new(1.2), { TextTransparency = 0 }):Play()
	TweenService:Create(deathSub, TweenInfo.new(1.6), { TextTransparency = 0 }):Play()
end

local function hideDeath()
	TweenService:Create(deathOverlay, TweenInfo.new(1.0), { BackgroundTransparency = 1 }):Play()
	TweenService:Create(deathTitle, TweenInfo.new(0.6), { TextTransparency = 1 }):Play()
	TweenService:Create(deathSub, TweenInfo.new(0.6), { TextTransparency = 1 }):Play()
end

----------------------------------------------------------------------
-- Delivery complete card
----------------------------------------------------------------------
local endCard = panel(gui, "Complete", UDim2.new(0, 420, 0, 250), UDim2.new(0.5, 0, 0.5, 0), Vector2.new(0.5, 0.5))
endCard.BackgroundTransparency = 0.1
endCard.Visible = false
endCard.ZIndex = 30
local endTitle = label(endCard, "Title", "DELIVERY COMPLETE", UDim2.new(1, 0, 0, 40), UDim2.new(0, 0, 0, 26), 28, Enum.Font.GothamBlack, COLORS.fine, Enum.TextXAlignment.Center)
endTitle.ZIndex = 31
local endStats = label(endCard, "Stats", "", UDim2.new(1, -40, 0, 80), UDim2.new(0, 20, 0, 84), 18, Enum.Font.GothamMedium, COLORS.text, Enum.TextXAlignment.Center)
endStats.ZIndex = 31

local continueButton = Instance.new("TextButton")
continueButton.Name = "Continue"
continueButton.Size = UDim2.new(0, 160, 0, 40)
continueButton.Position = UDim2.new(0.5, -80, 1, -64)
continueButton.BackgroundColor3 = Color3.fromRGB(40, 46, 54)
continueButton.BorderSizePixel = 0
continueButton.Text = "CONTINUE"
continueButton.TextColor3 = COLORS.text
continueButton.Font = Enum.Font.GothamBold
continueButton.TextSize = 16
continueButton.ZIndex = 31
continueButton.Parent = endCard
local buttonCorner = Instance.new("UICorner")
buttonCorner.CornerRadius = UDim.new(0, 6)
buttonCorner.Parent = continueButton
continueButton.Activated:Connect(function()
	endCard.Visible = false
end)

local function showComplete(seconds, deaths)
	local total = math.max(0, math.floor((seconds or 0) + 0.5))
	endStats.Text = string.format("Time   %d:%02d\nDeaths   %d", math.floor(total / 60), total % 60, deaths or 0)
	endCard.Visible = true
end

----------------------------------------------------------------------
-- Health tracking
----------------------------------------------------------------------
local currentHumanoid = nil
local lastHealth = 100
local flashAlpha = 0
local fraction = 1
local dead = false

local function refreshHealth()
	local humanoid = currentHumanoid
	if not humanoid or humanoid.Parent == nil then
		return
	end
	fraction = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
	barFill.Size = UDim2.new(fraction, 0, 1, 0)

	local color, text
	if humanoid.Health <= 0 then
		color, text = COLORS.dead, "DEAD"
	elseif fraction < LOW_FRACTION then
		color, text = COLORS.danger, "DANGER"
	elseif fraction < CAUTION_FRACTION then
		color, text = COLORS.caution, "CAUTION"
	else
		color, text = COLORS.fine, "FINE"
	end
	stateLabel.Text = text
	stateLabel.TextColor3 = color
	barFill.BackgroundColor3 = color
end

local function bindCharacter(character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then
		return
	end
	currentHumanoid = humanoid
	lastHealth = humanoid.Health
	dead = false
	refreshHealth()

	humanoid.HealthChanged:Connect(function(health)
		if health < lastHealth then
			local lost = lastHealth - health
			flashAlpha = math.clamp(0.45 + lost / 40, 0, 1)
		end
		lastHealth = health
		refreshHealth()
	end)

	humanoid.Died:Connect(function()
		dead = true
		refreshHealth()
		showDeath()
	end)
end

player.CharacterAdded:Connect(function(character)
	-- Let the server move the new character to the checkpoint before the screen clears.
	task.delay(0.8, hideDeath)
	bindCharacter(character)
end)
if player.Character then
	task.spawn(bindCharacter, player.Character)
end

----------------------------------------------------------------------
-- Attributes -> UI
----------------------------------------------------------------------
local function refreshAid()
	local count = player:GetAttribute("Medkits") or 0
	aidLabel.Text = string.format("FIRST AID x%d  [H]", count)
	aidLabel.TextColor3 = count > 0 and COLORS.text or COLORS.dim
end

local function refreshObjective()
	objText.Text = player:GetAttribute("Objective") or ""
end

player:GetAttributeChangedSignal("Medkits"):Connect(refreshAid)
player:GetAttributeChangedSignal("Objective"):Connect(refreshObjective)
refreshAid()
refreshObjective()

----------------------------------------------------------------------
-- Per-frame: arrow, distance, vignette
----------------------------------------------------------------------
RunService.RenderStepped:Connect(function(dt)
	-- Objective arrow + distance
	local target = player:GetAttribute("ObjectivePos")
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local camera = workspace.CurrentCamera
	if typeof(target) == "Vector3" and root and camera then
		local delta = target - root.Position
		local flat = Vector3.new(delta.X, 0, delta.Z)
		distLabel.Text = string.format("%d m", math.floor(flat.Magnitude * 0.28 + 0.5))
		local look = camera.CFrame.LookVector
		local right = camera.CFrame.RightVector
		look = Vector3.new(look.X, 0, look.Z)
		right = Vector3.new(right.X, 0, right.Z)
		if flat.Magnitude > 0.1 and look.Magnitude > 0.01 and right.Magnitude > 0.01 then
			local dir = flat.Unit
			arrow.Rotation = math.deg(math.atan2(dir:Dot(right.Unit), dir:Dot(look.Unit)))
		end
		arrow.Visible = true
	else
		distLabel.Text = ""
		arrow.Visible = false
	end

	-- Vignette: hit flash that decays, plus a heartbeat pulse when in danger
	flashAlpha = math.max(0, flashAlpha - dt * 1.6)
	local pulse = 0
	if not dead and currentHumanoid and fraction < LOW_FRACTION then
		local speed = 3 + 4 * (1 - fraction / LOW_FRACTION)
		pulse = 0.28 + 0.14 * math.sin(os.clock() * speed)
	end
	local alpha = math.max(flashAlpha * 0.85, pulse)
	for _, f in ipairs(edges) do
		f.BackgroundTransparency = 1 - alpha
	end
end)

----------------------------------------------------------------------
-- Input + server messages
----------------------------------------------------------------------
local function onUseMedkit(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		remote:FireServer("UseMedkit")
	end
	return Enum.ContextActionResult.Sink
end
ContextActionService:BindAction("UseMedkit", onUseMedkit, true, Enum.KeyCode.H, Enum.KeyCode.DPadUp)
ContextActionService:SetTitle("UseMedkit", "AID")

remote.OnClientEvent:Connect(function(action, a, b)
	if action == "Notice" then
		toast(tostring(a), b)
	elseif action == "Complete" then
		endTitle.Text = "DELIVERY COMPLETE"
		showComplete(a, b)
	elseif action == "ChapterComplete" then
		endTitle.Text = "HOUSE SECURED"
		showComplete(a, b)
	elseif action == "CityComplete" then
		endTitle.Text = "BUTTERFLY CORPS"
		showComplete(a, b)
	end
end)
