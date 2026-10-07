-- New script created by Ropilot
-- Replace this with your code
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local package = ReplicatedStorage:WaitForChild("SurvivalWeapon")
local Config = require(package:WaitForChild("Config"))
local reloadAnimation = ReplicatedStorage:WaitForChild("Animations"):WaitForChild("PistolReloadFluid")
local remote = package:FindFirstChild("Action") or Instance.new("RemoteEvent")
remote.Name = "Action"
remote.Parent = package
local states = {}

local function publish(player, state)
	player:SetAttribute("WeaponMagazine", state.magazine)
	player:SetAttribute("WeaponReserve", state.reserve)
	player:SetAttribute("WeaponReloading", state.reloading)
	player:SetAttribute("WeaponReloadEnd", state.reloadEnd)
	player:SetAttribute("WeaponReloadUsesTrack", state.reloading and state.reloadTrack ~= nil)
	player:SetAttribute("WeaponArmed", state.armed)
end
local function alive(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and root and humanoid.Health > 0 then
		return character, humanoid, root
	end
end
local function cancelReload(player, state)
	state.token = state.token + 1
	state.reloading = false
	state.reloadEnd = 0
	if state.reloadTrack then
		state.reloadTrack:Stop(Config.ReloadBlendSeconds)
	end
	local humanoid = state.reloadHumanoid
	if humanoid and humanoid.Parent and humanoid.WalkSpeed == Config.ReloadWalkSpeed then
		humanoid.WalkSpeed = state.oldWalkSpeed
	end
	state.reloadHumanoid = nil
	publish(player, state)
end

-- Lightweight greybox pistol, welded to the character rather than supplied as a refillable Tool.
local function createWeapon(character, hand)
	local model = Instance.new("Model")
	model.Name = "SurvivalPistol"
	local function part(name, size, offset, color)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Color = color
		p.Material = Enum.Material.Metal
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.Massless = true
		p.CFrame = hand.CFrame * Config.Grip * offset
		p.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = hand
		weld.Part1 = p
		weld.Parent = p
		return p
	end
	local handle = part("Grip", Vector3.new(0.3,0.6,0.38), CFrame.new(),
		Color3.fromRGB(42,44,47))
	model.PrimaryPart = handle
	local magazine = part("Magazine", Vector3.new(0.25,0.35,0.32), CFrame.new(0,-0.4,0),
		Color3.fromRGB(75,79,84))
	magazine:FindFirstChildOfClass("WeldConstraint"):Destroy()
	local magazineJoint = Instance.new("Motor6D")
	magazineJoint.Name = "MagazineJoint"
	magazineJoint.Part0 = handle
	magazineJoint.Part1 = magazine
	magazineJoint.C0 = CFrame.new(0,-0.4,0)
	magazineJoint.Parent = handle
	local slide = part("Slide", Vector3.new(0.34,0.28,1.25), CFrame.new(0,0.35,-0.4),
		Color3.fromRGB(100,105,111))
	part("Barrel", Vector3.new(0.2,0.15,0.25), CFrame.new(0,0.32,-1.05),
		Color3.fromRGB(38,40,43))
	local muzzle = Instance.new("Attachment")
	muzzle.Name = "Muzzle"
	muzzle.Position = Vector3.new(0,-0.03,-0.8)
	muzzle.Parent = slide
	model.Parent = character
	return model
end

local function characterAdded(player, character)
	local state = states[player]
	if not state then return end
	cancelReload(player, state)
	if state.reloadTrack then
		state.reloadTrack:Destroy()
		state.reloadTrack = nil
	end
	state.armed = true
	publish(player, state)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid or player.Character ~= character then return end
	local handName = humanoid.RigType == Enum.HumanoidRigType.R15 and "RightHand" or "Right Arm"
	local hand = character:WaitForChild(handName, 10)
	if not hand or player.Character ~= character or not states[player] then return end
	createWeapon(character, hand)
	-- Server-created Animator and server playback replicate the track to every client.
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	if humanoid.RigType == Enum.HumanoidRigType.R15 then
		local ok, track = pcall(function()
			return animator:LoadAnimation(reloadAnimation)
		end)
		if ok then
			track.Priority = Enum.AnimationPriority.Action2
			track.Looped = false
			state.reloadTrack = track
		else
			warn("Could not load PistolReloadFluid: " .. tostring(track))
		end
	end
	humanoid.Died:Connect(function()
		if states[player] == state then
			state.armed = false
			cancelReload(player, state)
		end
	end)
end
local function addPlayer(player)
	if states[player] then return end
	local state = {
		magazine = Config.StartingMagazine, reserve = Config.StartingReserve,
		armed = true, reloading = false, reloadEnd = 0,
		token = 0, lastShot = -math.huge, credits = 12, lastRequest = os.clock(),
	}
	states[player] = state
	publish(player, state)
	player.CharacterAdded:Connect(function(character)
		characterAdded(player, character)
	end)
	if player.Character then task.spawn(characterAdded, player, player.Character) end
end
Players.PlayerAdded:Connect(addPlayer)
Players.PlayerRemoving:Connect(function(player)
	local state = states[player]
	if state and state.reloadTrack then state.reloadTrack:Destroy() end
	states[player] = nil
end)
for _, player in ipairs(Players:GetPlayers()) do addPlayer(player) end

local function finiteVector(value)
	return typeof(value) == "Vector3" and value.X == value.X and value.Y == value.Y
		and value.Z == value.Z and math.abs(value.X) < 1e6
		and math.abs(value.Y) < 1e6 and math.abs(value.Z) < 1e6
end
local function tell(player, message)
	remote:FireClient(player, "Notice", message)
end
remote.OnServerEvent:Connect(function(player, action, origin, direction)
	local state = states[player]
	if not state then return end
	local clock = os.clock()
	state.credits = math.min(12, state.credits + (clock - state.lastRequest) * 8)
	state.lastRequest = clock
	if state.credits < 1 then return end
	state.credits = state.credits - 1
	local character, humanoid, root = alive(player)
	if not character then return end

	if action == "Holster" then
		state.armed = not state.armed
		cancelReload(player, state)
		local model = character:FindFirstChild("SurvivalPistol")
		if model then
			for _, part in ipairs(model:GetDescendants()) do
				if part:IsA("BasePart") then part.Transparency = state.armed and 0 or 1 end
			end
		end
		return
	end
	if not state.armed then return end
	if action == "Reload" then
		if state.reloading then return end
		if state.magazine >= Config.MagazineSize then tell(player, "MAGAZINE FULL") return end
		if state.reserve <= 0 then tell(player, "NO SPARE AMMUNITION") return end
		state.reloading = true
		state.reloadEnd = workspace:GetServerTimeNow() + Config.ReloadSeconds
		state.token = state.token + 1
		local token = state.token
		state.oldWalkSpeed = humanoid.WalkSpeed
		state.reloadHumanoid = humanoid
		humanoid.WalkSpeed = math.min(humanoid.WalkSpeed, Config.ReloadWalkSpeed)
		if state.reloadTrack then
			local duration = state.reloadTrack.Length > 0 and state.reloadTrack.Length
				or Config.ReloadAnimationSeconds
			state.reloadTrack:Play(Config.ReloadBlendSeconds, 1, duration / Config.ReloadSeconds)
		end
		publish(player, state)
		task.delay(Config.ReloadSeconds, function()
			if states[player] ~= state or state.token ~= token then return end
			if player.Character ~= character or humanoid.Health <= 0 or not state.armed then
				cancelReload(player, state)
				return
			end
			local transfer = math.min(Config.MagazineSize - state.magazine, state.reserve)
			state.magazine = state.magazine + transfer
			state.reserve = state.reserve - transfer
			cancelReload(player, state)
		end)
		return
	end
	if action ~= "Fire" or state.reloading or clock - state.lastShot < Config.ShotInterval then return end
	if state.magazine <= 0 then
		tell(player, state.reserve > 0 and "EMPTY — RELOAD" or "OUT OF AMMUNITION")
		return
	end
	if not finiteVector(origin) or not finiteVector(direction) then return end
	if direction.Magnitude < 0.9 or direction.Magnitude > 1.1 then return end
	local head = character:FindFirstChild("Head")
	local model = character:FindFirstChild("SurvivalPistol")
	local muzzle = model and model:FindFirstChild("Muzzle", true)
	if not head or not muzzle or (origin - head.Position).Magnitude > 12 then return end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {character}
	-- Camera origins cannot be supplied through a wall.
	if workspace:Raycast(head.Position, origin - head.Position, params) then return end

	state.lastShot = clock
	state.magazine = state.magazine - 1
	publish(player, state)
	local velocity = root.AssemblyLinearVelocity
	local speed = Vector3.new(velocity.X,0,velocity.Z).Magnitude
	local now = workspace:GetServerTimeNow()
	local shotDirection = Config.ShotDirection(direction.Unit, now, speed)
	local aimHit = workspace:Raycast(origin, shotDirection * Config.Range, params)
	local target = aimHit and aimHit.Position or origin + shotDirection * Config.Range
	-- Start at the body and traverse the muzzle: this also blocks a barrel poking through cover.
	-- Pose joints are rendered locally; use a stable firing origin on the server.
	local muzzlePosition = head.Position + root.CFrame.RightVector * Config.MuzzleOffset.X
		+ Vector3.new(0,Config.MuzzleOffset.Y,0) + shotDirection * Config.MuzzleOffset.Z
	local obstruction = workspace:Raycast(head.Position, muzzlePosition - head.Position, params)
	local start = obstruction and head.Position or muzzlePosition
	local delta = target - start
	local hit = obstruction
	if not hit and delta.Magnitude > 0.01 then
		hit = workspace:Raycast(start, delta.Unit * math.min(delta.Magnitude, Config.Range), params)
	end
	local finish = hit and hit.Position or target
	local damaged = false
	if hit then
		local ancestor = hit.Instance.Parent
		local targetHumanoid
		local targetModel
		while ancestor and ancestor ~= workspace do
			if ancestor:IsA("Model") then
				targetHumanoid = ancestor:FindFirstChildOfClass("Humanoid")
				if targetHumanoid then targetModel = ancestor break end
			end
			ancestor = ancestor.Parent
		end
		if targetHumanoid and targetHumanoid ~= humanoid and targetHumanoid.Health > 0 then
			local targetPlayer = Players:GetPlayerFromCharacter(targetModel)
			if not targetPlayer or Config.DamagePlayers then
				-- Only the server's raycast against the rig's actual Head can kill an armored mutant.
				-- Scope this rule to NPCs so a character attribute cannot change PvP damage.
				local headshotOnly = not targetPlayer and targetModel:GetAttribute("HeadshotOnly") == true
				local isHeadshot = hit.Instance == targetModel:FindFirstChild("Head")
				if headshotOnly and not isHeadshot then
					tell(player, "ARMORED MUTANT - AIM FOR THE HEAD")
				else
					local healthBefore = targetHumanoid.Health
					local damage = headshotOnly and healthBefore
						or Config.Damage * (hit.Instance.Name == "Head" and Config.HeadshotMultiplier or 1)
					local previousHitUserId = targetModel:GetAttribute("LastHitUserId")
					-- Write attribution before TakeDamage: encounter Died listeners can read it immediately.
					targetModel:SetAttribute("LastHitUserId", player.UserId)
					targetModel:SetAttribute("HeadshotKilled", isHeadshot and damage >= healthBefore)
					targetHumanoid:TakeDamage(damage)
					damaged = targetHumanoid.Health < healthBefore
					if not damaged then
						targetModel:SetAttribute("LastHitUserId", previousHitUserId)
					end
					if targetHumanoid.Health > 0 then
						targetModel:SetAttribute("HeadshotKilled", false)
					elseif headshotOnly then
						tell(player, "HEADSHOT - MUTANT DOWN")
					end
				end
			end
		end
	end
	player:SetAttribute("WeaponLastShot", now)
	remote:FireAllClients("Shot", player, start, finish, damaged)
end)

-- Courier pickups add spare ammunition through this event (server-side): AddAmmo:Fire(player, amount)
local addAmmo = package:FindFirstChild("AddAmmo")
if not addAmmo then
	addAmmo = Instance.new("BindableEvent")
	addAmmo.Name = "AddAmmo"
	addAmmo.Parent = package
end
addAmmo.Event:Connect(function(player, amount)
	local state = states[player]
	if not state or type(amount) ~= "number" then return end
	state.reserve = math.min(state.reserve + amount, Config.MaxReserve or 24)
	publish(player, state)
end)
