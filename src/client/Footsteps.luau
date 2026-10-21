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
--
-- THIS IS THE FIRST VERSION AGAIN (owner, the same day, after a round that held the pace,
-- faded every step, heard the player's own steps from the camera and so on: "better bring
-- back the old sound; with the camera drawn back it used to grow quieter, which was cool, now
-- it does not; and other players' jumps and stomping cannot be heard, make them heard"), a
-- fifth softer (Config/Sounds `steps`), with two things of its own: other players' steps
-- carry farther, and their pace is measured from how their characters move on this screen.

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
local HEARD = 150
-- How far a step carries: as loud as it is up to the first, nothing past the second, studs.
-- The camera is 10 to 15 studs from the player, so their own steps are heard in full and grow
-- quieter as the camera is drawn back. Another player is seldom that close, so theirs carry
-- farther.
local NEAR = 16
local FAR = 100
local NEAR_OTHER = 24
local FAR_OTHER = 150
-- Another player's pace is what this client sees their character do (the physics' velocity of
-- a body another computer moves is not to be relied on), smoothed at this rate a second; a
-- move faster than TELEPORT studs a second is a teleport, not a step.
local SMOOTHING = 15
local TELEPORT = 400
-- A jump is leaving the ground at least this fast upwards, studs a second. A jump within
-- JUMP_REST seconds of the last is heard at JUMP_AGAIN of the volume, so that jumping over and
-- over is a soft patter and not a sound repeated at full strength.
local JUMP_SPEED = 12
local JUMP_REST = 1.5
local JUMP_AGAIN = 0.35
-- A landing is heard after a fall at least LANDING_SPEED studs a second. Up to PLAIN_FALL (a
-- plain jump on flat ground comes down at about 53) it is an ordinary step; faster, it grows
-- to Config/Sounds `landing` at HARD_LANDING.
local LANDING_SPEED = 18
local PLAIN_FALL = 58
local HARD_LANDING = 110
-- How far under the feet the ground may lie for a character to stand on it, studs: a step
-- down a stair is not a fall.
local REACH = 1.4
-- An R6 body's legs hang under its root with no HipHeight to say so, studs.
local R6_LEGS = 2

type Walker = {
	humanoid: Humanoid,
	root: BasePart,
	own: boolean, -- the player's own character
	lastAt: Vector3?, -- where another player's root stood a frame ago
	moved: Vector3, -- another player's velocity as seen here, smoothed
	phase: number, -- how far through the next step, 0 to 1
	grounded: boolean,
	falling: number, -- the fastest it has gone down since it left the ground, studs a second
	sounds: { [number]: Sound }, -- by asset id, made the first time each is stepped
	last: { [string]: number }, -- the variant each surface stepped last
	jumpedAt: number, -- os.clock() of the last jump heard
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
	made.RollOffMinDistance = if walker.own then NEAR else NEAR_OTHER
	made.RollOffMaxDistance = if walker.own then FAR else FAR_OTHER
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

-- How fast another player's character is going, by where it has been on this screen.
local function measured(walker: Walker, dt: number): Vector3
	local now = walker.root.Position
	local was = walker.lastAt
	walker.lastAt = now
	if not was or dt <= 0 then
		return walker.moved
	end
	local seen = (now - was) / dt
	if seen.Magnitude > TELEPORT then
		walker.moved = Vector3.zero
	else
		walker.moved = walker.moved:Lerp(seen, math.min(dt * SMOOTHING, 1))
	end
	return walker.moved
end

local function update(walker: Walker, dt: number, eye: Vector3?)
	local root, humanoid = walker.root, walker.humanoid
	local velocity = if walker.own then root.AssemblyLinearVelocity else measured(walker, dt)
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
	local hit = ground(walker)
	if not hit then
		if walker.grounded and velocity.Y > JUMP_SPEED then
			local now = os.clock()
			local again = now - walker.jumpedAt < JUMP_REST
			walker.jumpedAt = now
			local volume = STEPS.jump.volume * (if again then JUMP_AGAIN else 1)
			step(walker, "jump", STEPS.jump.ids, volume, 1)
		end
		walker.grounded = false
		walker.falling = math.min(walker.falling, velocity.Y)
		walker.phase = SET_OFF
		return
	end

	local key = STEPS.materials[hit.Material.Name] or STEPS.fallback
	local surface = STEPS.surfaces[key]
	if not walker.grounded then
		-- Down again: a landing is the ground's own step, louder and lower by how hard it was.
		walker.grounded = true
		local fall = -walker.falling
		walker.falling = 0
		if surface and fall >= LANDING_SPEED then
			local hard = math.clamp((fall - PLAIN_FALL) / (HARD_LANDING - PLAIN_FALL), 0, 1)
			local plain = math.clamp(fall / PLAIN_FALL, 0.6, 1)
			step(
				walker,
				key,
				surface.ids,
				surface.volume * plain * (1 + (STEPS.landing.volume - 1) * hard),
				(surface.speed or 1) * (1 + (STEPS.landing.speed - 1) * hard)
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

local function track(character: Model, own: boolean)
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
			own = own,
			lastAt = nil,
			moved = Vector3.zero,
			phase = SET_OFF,
			grounded = true,
			falling = 0,
			sounds = {},
			last = {},
			jumpedAt = -math.huge,
		}
	end)
end

local function watch(player: Player)
	local own = player == Players.LocalPlayer
	if player.Character then
		track(player.Character, own)
	end
	player.CharacterAdded:Connect(function(character)
		track(character, own)
	end)
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
	-- Fetched ahead as Sounds: a bare "rbxassetid://" string is fetched as a picture, and a
	-- sound's id then fails with "Asset type does not match requested type" (34 of them in the
	-- owner's log, 2026-10-21) and is not fetched at all.
	task.spawn(function()
		local list: { Instance } = {}
		local function add(id: number)
			if id > 0 then
				local sound = Instance.new("Sound")
				sound.SoundId = `rbxassetid://{id}`
				table.insert(list, sound)
			end
		end
		for _, surface in STEPS.surfaces do
			for _, id in surface.ids do
				add(id)
			end
		end
		for _, id in STEPS.jump.ids do
			add(id)
		end
		pcall(function()
			ContentProvider:PreloadAsync(list)
		end)
		for _, sound in list do
			sound:Destroy()
		end
	end)
end

return Footsteps
