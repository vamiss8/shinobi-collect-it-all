--!strict
-- Footsteps by the ground underfoot, in place of Roblox's own (owner, 2026-10-18: "the walking
-- sounds are Roblox's stock ones, rather quiet and unclear, and do not depend on the surface;
-- make them cooler, a little louder and more noticeable"). Every character near the camera,
-- the player's own and everyone else's, is heard stepping on what lies under its feet (a ray
-- down from its root: grass, earth, sand, wood, stone, snow, water; Config/Sounds `steps`), a
-- step at a time and as fast as it runs; a jump and a landing are heard too. The steps play in
-- the "Effects" group, so the settings' slider turns them up and down with every other effect.
--
-- AT A RUN'S SPEED NOTHING MAY STUTTER (owner, the same day: "running home from the last zones
-- you go at a huge speed and the sounds glitch a little, though they are not bad in
-- themselves"). What could, by my reading of the code, not heard: a step's sound started over
-- while it still rang (four sounds at seven steps a second come round every half second, and
-- a sound cut off clicks), the tails of the last few steps piling up, the ray under the feet
-- missing the ground for a frame over a joint of the lane (a landing and a stride begun anew
-- each time), and the player's own steps riding a source that moves at 80 studs a second. So
-- every sound has two players used in turn, a step is faded out after a moment, the ground
-- must be gone for a tenth of a second before the feet are in the air, the pace is held to at
-- most six and a half steps a second and grows softer past a run, and the player's own steps
-- are not placed in the world at all (they are heard as from the camera, where they would be
-- in full anyway).
--
-- Roblox's own running, jumping and landing sounds, which its RbxCharacterSounds script puts
-- on every character's root on every client, are silenced, so that the two are not heard at
-- once; its other sounds (climbing, swimming, falling) are left as they are.

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
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
local FASTEST = 6.5
-- Studs a second under which a character stands still.
local MOVING = 1.5
-- How far through a step a character is as it sets off, so that the first one comes at once.
local SET_OFF = 0.75
-- Steps grow louder with the pace: this share of their volume at a walk, all of it at RUNNING
-- studs a second, and softer again past it, down to RACING_SHARE at RACING, so that six steps
-- a second on the lane do not drum.
local WALKING_SHARE = 0.75
local RUNNING = 34
local RACING = 80
local RACING_SHARE = 0.7
-- How long a step rings before it is faded out, seconds, and how fast it fades: the tails of
-- the sounds are long, and at a run they would pile up.
local STEP_TAIL = 0.3
local LANDING_TAIL = 0.5
local JUMP_TAIL = 0.4
local TAIL_FADE = 0.08
-- Nobody's steps are worked out farther than this from the camera, studs.
local HEARD = 110
-- How far a step carries: as loud as it is up to the first, nothing past the second, studs.
local NEAR = 16
local FAR = 100
-- A jump is leaving the ground at least this fast upwards, studs a second (a jump leaves at
-- about 50; running up a ramp at the lane's speed can reach 12). A jump within JUMP_REST
-- seconds of the last is heard at JUMP_AGAIN of the volume, so that jumping over and over is
-- a soft patter and not a sound repeated at full strength.
local JUMP_SPEED = 20
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
-- How long the ground must be gone from under the feet before they are in the air, seconds:
-- a frame's miss over a joint is not a fall.
local AIR_GRACE = 0.1
-- An R6 body's legs hang under its root with no HipHeight to say so, studs.
local R6_LEGS = 2

type Walker = {
	humanoid: Humanoid,
	root: BasePart,
	own: boolean, -- the player's own character, whose steps are not placed in the world
	phase: number, -- how far through the next step, 0 to 1
	grounded: boolean,
	airFor: number, -- seconds the ground has been gone from under the feet
	falling: number, -- the fastest it has gone down since it left the ground, studs a second
	sounds: { [number]: { Sound } }, -- two players a sound, by asset id, made when first stepped
	turn: { [number]: number }, -- which of the two played that sound last
	last: { [string]: number }, -- the variant each surface stepped last
	jumpedAt: number, -- os.clock() of the last jump heard
}

local walkers: { [Model]: Walker } = {}
local random = Random.new()
-- How many times each sound has been started, so that a fade meant for one step does not
-- touch the next, and the fade under way on each.
local plays: { [Sound]: number } = setmetatable({}, { __mode = "k" }) :: any
local tails: { [Sound]: Tween } = setmetatable({}, { __mode = "k" }) :: any

-- The player's own steps are heard from here, not from their feet.
local OWN_FOLDER = "Footsteps"

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

local function ownFolder(): Instance
	local found = SoundService:FindFirstChild(OWN_FOLDER)
	if found then
		return found
	end
	local made = Instance.new("Folder")
	made.Name = OWN_FOLDER
	made.Parent = SoundService
	return made
end

local function makeSound(walker: Walker, id: number): Sound
	local made = Instance.new("Sound")
	made.Name = "Footstep"
	made.SoundId = `rbxassetid://{id}`
	made.SoundGroup = Audio.group("Effects")
	made.RollOffMode = Enum.RollOffMode.InverseTapered
	made.RollOffMinDistance = NEAR
	made.RollOffMaxDistance = FAR
	made.Parent = if walker.own then ownFolder() else walker.root
	return made
end

-- The one of a sound's two players that played it longer ago.
local function soundFor(walker: Walker, id: number): Sound
	local pool = walker.sounds[id]
	if not pool or not pool[1].Parent or not pool[2].Parent then
		pool = { makeSound(walker, id), makeSound(walker, id) }
		walker.sounds[id] = pool
	end
	local turn = 3 - (walker.turn[id] or 2)
	walker.turn[id] = turn
	return pool[turn]
end

-- Fades a step out once it has rung for `tail` seconds, unless it has been started again.
local function fadeAfter(sound: Sound, tail: number)
	local token = plays[sound]
	task.delay(tail, function()
		if plays[sound] ~= token or not sound.IsPlaying then
			return
		end
		local tween = TweenService:Create(sound, TweenInfo.new(TAIL_FADE), { Volume = 0 })
		tails[sound] = tween
		tween.Completed:Once(function()
			if plays[sound] == token then
				sound:Stop()
			end
		end)
		tween:Play()
	end)
end

-- Plays one of `ids` from the walker's feet: at random, never the same one twice running, a
-- little louder or softer and higher or lower each time, so that a run is not one sound over
-- and over.
local function step(
	walker: Walker,
	key: string,
	ids: { number },
	volume: number,
	speed: number,
	tail: number
)
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
	local fading = tails[sound]
	if fading then
		fading:Cancel()
		tails[sound] = nil
	end
	plays[sound] = (plays[sound] or 0) + 1
	sound.Volume = volume * random:NextNumber(0.85, 1)
	sound.PlaybackSpeed = speed * random:NextNumber(0.92, 1.08)
	sound.TimePosition = 0
	sound:Play()
	fadeAfter(sound, tail)
end

-- What lies under the walker's feet, if anything does within reach.
local function ground(walker: Walker): RaycastResult?
	local root, humanoid = walker.root, walker.humanoid
	local legs = if humanoid.RigType == Enum.HumanoidRigType.R6 then R6_LEGS else humanoid.HipHeight
	local down = root.Size.Y / 2 + legs + REACH
	return Workspace:Raycast(root.Position, Vector3.new(0, -down, 0), params)
end

-- How loud a step is at a pace, as a share of the surface's volume.
local function paceShare(speed: number): number
	if speed <= RUNNING then
		return WALKING_SHARE + (1 - WALKING_SHARE) * math.clamp(speed / RUNNING, 0, 1)
	end
	return 1 + (RACING_SHARE - 1) * math.clamp((speed - RUNNING) / (RACING - RUNNING), 0, 1)
end

local function update(walker: Walker, dt: number, eye: Vector3?)
	local root, humanoid = walker.root, walker.humanoid
	if
		humanoid.Health <= 0
		or humanoid.Sit
		or (not walker.own and eye and (root.Position - eye).Magnitude > HEARD)
	then
		walker.phase = SET_OFF
		walker.grounded = true
		walker.airFor = 0
		walker.falling = 0
		return
	end
	local velocity = root.AssemblyLinearVelocity
	local hit = ground(walker)
	if not hit then
		walker.airFor += dt
		walker.falling = math.min(walker.falling, velocity.Y)
		local jumped = walker.grounded and velocity.Y > JUMP_SPEED
		if jumped then
			local now = os.clock()
			local again = now - walker.jumpedAt < JUMP_REST
			walker.jumpedAt = now
			local volume = STEPS.jump.volume * (if again then JUMP_AGAIN else 1)
			step(walker, "jump", STEPS.jump.ids, volume, 1, JUMP_TAIL)
		end
		if jumped or walker.airFor > AIR_GRACE then
			walker.grounded = false
			walker.phase = SET_OFF
		end
		return
	end
	walker.airFor = 0

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
				(surface.speed or 1) * (1 + (STEPS.landing.speed - 1) * hard),
				LANDING_TAIL
			)
		end
		return
	end
	walker.falling = 0

	local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	if speed < MOVING then
		walker.phase = SET_OFF
		return
	end
	walker.phase += dt * math.clamp(speed / STRIDE, SLOWEST, FASTEST)
	if walker.phase >= 1 then
		walker.phase %= 1
		if surface then
			local volume = surface.volume * paceShare(speed)
			step(walker, key, surface.ids, volume, surface.speed or 1, STEP_TAIL)
		end
	end
end

-- Lets a walker go: the sounds of the player's own, which are not on their character, with it.
local function forget(character: Model)
	local walker = walkers[character]
	walkers[character] = nil
	if walker and walker.own then
		for _, pool in walker.sounds do
			for _, sound in pool do
				sound:Destroy()
			end
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
			forget(character)
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
			phase = SET_OFF,
			grounded = true,
			airFor = 0,
			falling = 0,
			sounds = {},
			turn = {},
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
	task.spawn(function()
		local list: { any } = {}
		for _, surface in STEPS.surfaces do
			for _, id in surface.ids do
				if id > 0 then
					table.insert(list, `rbxassetid://{id}`)
				end
			end
		end
		for _, id in STEPS.jump.ids do
			if id > 0 then
				table.insert(list, `rbxassetid://{id}`)
			end
		end
		pcall(function()
			ContentProvider:PreloadAsync(list)
		end)
	end)
end

return Footsteps
