--!strict
-- Footsteps by the ground underfoot, in place of Roblox's own (owner, 2026-10-18: "the walking
-- sounds are Roblox's stock ones, rather quiet and unclear, and do not depend on the surface;
-- make them cooler, a little louder and more noticeable"). Every character near the camera,
-- the player's own and everyone else's, is heard stepping on what lies under its feet (a ray
-- down from its root: grass, earth, sand, wood, stone, snow, water; Config/Sounds `steps`), a
-- step at a time and as fast as it runs; a jump and a landing are heard too. The steps play in
-- the "Effects" group, so the settings' slider turns them up and down with every other effect.
--
-- Roblox's own running, jumping and landing sounds, which its RbxCharacterSounds script puts
-- on every character's root on every client, are silenced, so that the two are not heard at
-- once; its other sounds (climbing, swimming, falling) are left as they are.

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)

local Audio = require("./Audio")

local Footsteps = {}

local STEPS = Sounds.steps

-- Roblox's own sounds that ours stand in for, by the names it gives them.
local SILENCED: { [string]: boolean } = { Running = true, Jumping = true, Landing = true }

-- Studs one step carries a runner: steps come speed / STRIDE times a second, about what the
-- default walk and run look like, but never fewer or more than these many a second (on the
-- lane a runner covers 80 studs a second, and the feet cannot be heard at that pace).
local STRIDE = 6
local SLOWEST = 1.8
local FASTEST = 7.5
-- Studs a second under which a character stands still.
local MOVING = 1.5
-- How far through a step a character is as it sets off, so that the first one comes at once.
local SET_OFF = 0.75
-- Steps grow louder with the pace: this share of their volume at a walk, all of it from
-- RUNNING studs a second on.
local WALKING_SHARE = 0.75
local RUNNING = 34
-- Nobody's steps are worked out farther than this from the camera, studs.
local HEARD = 110
-- How far a step carries: as loud as it is up to the first, nothing past the second, studs.
-- The camera is 10 to 15 studs from the player, so their own steps are heard in full.
local NEAR = 16
local FAR = 100
-- A jump is leaving the ground at least this fast upwards, studs a second; a landing is heard
-- after a fall at least this fast, and at its loudest from the second on.
local JUMP_SPEED = 12
local LANDING_SPEED = 18
local HARD_LANDING = 60
-- How far under the feet the ground may lie for a character to stand on it, studs: a step
-- down a stair is not a fall.
local REACH = 1.4
-- An R6 body's legs hang under its root with no HipHeight to say so, studs.
local R6_LEGS = 2

type Walker = {
	humanoid: Humanoid,
	root: BasePart,
	phase: number, -- how far through the next step, 0 to 1
	grounded: boolean,
	falling: number, -- the fastest it has gone down since it left the ground, studs a second
	sounds: { [number]: Sound }, -- by asset id, made the first time each is stepped
	last: { [string]: number }, -- the variant each surface stepped last
}

local walkers: { [Model]: Walker } = {}
local random = Random.new()

-- The ground is looked for under the feet, never on a character (they pass through one
-- another) and never on what is only for the eye.
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.RespectCanCollide = true

local function refilter()
	local bodies: { Instance } = {}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(bodies, player.Character)
		end
	end
	params.FilterDescendantsInstances = bodies
end

-- Turns one of Roblox's own sounds down for good, whichever audio API it was made with.
local function silence(instance: Instance)
	if not SILENCED[instance.Name] then
		return
	end
	if not (instance:IsA("Sound") or instance.ClassName == "AudioPlayer") then
		return
	end
	local quiet = instance :: any
	quiet.Volume = 0
	instance:GetPropertyChangedSignal("Volume"):Connect(function()
		if quiet.Volume ~= 0 then
			quiet.Volume = 0
		end
	end)
end

local function soundFor(walker: Walker, id: number): Sound
	local found = walker.sounds[id]
	if found and found.Parent then
		return found
	end
	local made = Instance.new("Sound")
	made.Name = "Footstep"
	made.SoundId = `rbxassetid://{id}`
	made.SoundGroup = Audio.group("Effects")
	made.RollOffMode = Enum.RollOffMode.InverseTapered
	made.RollOffMinDistance = NEAR
	made.RollOffMaxDistance = FAR
	made.Parent = walker.root
	walker.sounds[id] = made
	return made
end

-- Plays one of `ids` from the walker's feet: at random, never the same one twice running, a
-- little louder or softer and higher or lower each time, so that a run is not one sound over
-- and over.
local function step(walker: Walker, key: string, ids: { number }, volume: number, speed: number)
	local count = #ids
	if count == 0 then
		return
	end
	local pick = random:NextInteger(1, count)
	if count > 1 and pick == walker.last[key] then
		pick = pick % count + 1
	end
	walker.last[key] = pick
	local id = ids[pick]
	if id <= 0 then
		return
	end
	local sound = soundFor(walker, id)
	sound.Volume = volume * random:NextNumber(0.85, 1)
	sound.PlaybackSpeed = speed * random:NextNumber(0.92, 1.08)
	sound.TimePosition = 0
	sound:Play()
end

-- What lies under the walker's feet, if anything does within reach.
local function ground(walker: Walker): RaycastResult?
	local root, humanoid = walker.root, walker.humanoid
	local legs = if humanoid.RigType == Enum.HumanoidRigType.R6 then R6_LEGS else humanoid.HipHeight
	local down = root.Size.Y / 2 + legs + REACH
	return Workspace:Raycast(root.Position, Vector3.new(0, -down, 0), params)
end

local function update(walker: Walker, dt: number, eye: Vector3?)
	local root, humanoid = walker.root, walker.humanoid
	if
		humanoid.Health <= 0
		or humanoid.Sit
		or (eye and (root.Position - eye).Magnitude > HEARD)
	then
		walker.phase = SET_OFF
		walker.grounded = true
		walker.falling = 0
		return
	end
	local velocity = root.AssemblyLinearVelocity
	local hit = ground(walker)
	if not hit then
		if walker.grounded and velocity.Y > JUMP_SPEED and STEPS.jump.id > 0 then
			step(walker, "jump", { STEPS.jump.id }, STEPS.jump.volume, 1)
		end
		walker.grounded = false
		walker.falling = math.min(walker.falling, velocity.Y)
		walker.phase = SET_OFF
		return
	end

	local key = STEPS.materials[hit.Material.Name] or STEPS.fallback
	local surface = STEPS.surfaces[key]
	if not walker.grounded then
		-- Down again: a landing is the ground's own step, louder and lower, by how hard it was.
		walker.grounded = true
		local fall = -walker.falling
		walker.falling = 0
		if surface and fall >= LANDING_SPEED then
			local share = math.clamp(fall / HARD_LANDING, 0.55, 1)
			step(
				walker,
				key,
				surface.ids,
				surface.volume * STEPS.landing.volume * share,
				(surface.speed or 1) * STEPS.landing.speed
			)
		end
		return
	end

	local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	if speed < MOVING then
		walker.phase = SET_OFF
		return
	end
	walker.phase += dt * math.clamp(speed / STRIDE, SLOWEST, FASTEST)
	if walker.phase >= 1 then
		walker.phase %= 1
		if surface then
			local share = WALKING_SHARE + (1 - WALKING_SHARE) * math.clamp(speed / RUNNING, 0, 1)
			step(walker, key, surface.ids, surface.volume * share, surface.speed or 1)
		end
	end
end

local function track(character: Model)
	for _, item in character:GetDescendants() do
		silence(item)
	end
	character.DescendantAdded:Connect(silence)
	refilter()
	character.AncestryChanged:Connect(function()
		if not character:IsDescendantOf(game) then
			walkers[character] = nil
			refilter()
		end
	end)
	task.spawn(function()
		local humanoid = character:WaitForChild("Humanoid", 30)
		local root = character:WaitForChild("HumanoidRootPart", 30)
		if not (humanoid and humanoid:IsA("Humanoid") and root and root:IsA("BasePart")) then
			return
		end
		if not character:IsDescendantOf(game) then
			return
		end
		walkers[character] = {
			humanoid = humanoid,
			root = root,
			phase = SET_OFF,
			grounded = true,
			falling = 0,
			sounds = {},
			last = {},
		}
	end)
end

local function watch(player: Player)
	if player.Character then
		track(player.Character)
	end
	player.CharacterAdded:Connect(track)
end

function Footsteps.start()
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function()
		task.defer(refilter)
	end)

	RunService.Heartbeat:Connect(function(dt)
		local camera = Workspace.CurrentCamera
		local eye = if camera then camera.CFrame.Position else nil
		for _, walker in walkers do
			update(walker, dt, eye)
		end
	end)

	-- Every step is fetched ahead, in the background, so that the first ones are heard.
	task.spawn(function()
		local list: { any } = {}
		for _, surface in STEPS.surfaces do
			for _, id in surface.ids do
				if id > 0 then
					table.insert(list, `rbxassetid://{id}`)
				end
			end
		end
		if STEPS.jump.id > 0 then
			table.insert(list, `rbxassetid://{STEPS.jump.id}`)
		end
		pcall(function()
			ContentProvider:PreloadAsync(list)
		end)
	end)
end

return Footsteps
