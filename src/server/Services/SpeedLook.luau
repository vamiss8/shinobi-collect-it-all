--!strict
-- Shows a player's speed stage (Config/SpeedStages) on their character, for everyone to see.
-- A stage names what it puts on the runner, and this module knows what each of those looks
-- like: cloth and iron strapped to the shins and wrists, dust at the feet, and with the Gates
-- open steam, lights, flame, sparks, ribbons and embers in the Gate's color.
--
-- NOTHING OF THE PLAYER'S OWN CHARACTER IS CHANGED: every piece is added, welded on or hung
-- from the body, and found by the names every avatar's body has, so it works whatever the
-- player wears. Nothing lights the character up either: a light on the body turned every face
-- the Gate's color.
--
-- Everything is added on the server, so it replicates to every client. It goes on each new
-- character and is redone when a purchase reaches a new stage.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Data = require("../Data")
local Loadout = require("./Loadout")
local Particles = require(ReplicatedStorage.Shared.View.Particles)
local SpeedStages = require(ReplicatedStorage.Shared.Config.SpeedStages)

local SpeedLook = {}

-- Attribute on everything this module adds, so it can be found and taken off again.
local MARK = "SpeedLook"
local IRON = Color3.fromRGB(66, 66, 70)
local WHITE = Color3.new(1, 1, 1)
-- The lower legs and forearms of an R15 body, and the legs and arms of an R6 one; the hands
-- of the first, which the second has none of.
local LEGS = { "LeftLowerLeg", "RightLowerLeg", "Left Leg", "Right Leg" }
local ARMS = { "LeftLowerArm", "RightLowerArm", "Left Arm", "Right Arm" }
local HANDS = { "LeftHand", "RightHand", "Left Arm", "Right Arm" }
-- Some of what a runner shows only shows while they move faster than this along the ground,
-- studs a second.
local RUNNING = 4
local CHECK_SECONDS = 0.15

-- What comes off a runner, as layers of particles (View/Particles). A layer without a color
-- takes its stage's.
local DUST: Particles.Layer = {
	texture = Particles.SMOKE,
	rate = 22,
	life = { 0.4, 0.8 },
	speed = { 1.5, 3 },
	spread = 70,
	size = { 0.5, 1.5 },
	lift = 1.5,
	spin = 60,
	glow = 0,
	fade = 0.45,
	color = "#BCAAA4",
}
local MOTES: Particles.Layer = {
	texture = Particles.SPARKLE,
	rate = 6,
	life = { 1, 1.6 },
	speed = { 1.5, 2.5 },
	locked = true,
	spread = 40,
	size = { 0.35, 0.1 },
	lift = 1,
	spin = 120,
	glow = 1,
	fade = 0.1,
}
local FLAME: Particles.Layer = {
	texture = Particles.FIRE,
	rate = 14,
	life = { 0.5, 0.9 },
	speed = { 3, 5 },
	locked = true,
	spread = 20,
	size = { 1.6, 0.3 },
	lift = 3,
	spin = 30,
	glow = 0.8,
	fade = 0.3,
}
local SPARKS: Particles.Layer = {
	texture = Particles.SPARKLE,
	rate = 16,
	life = { 0.15, 0.35 },
	speed = { 8, 14 },
	locked = true,
	spread = 180,
	size = { 0.5, 0.1 },
	lift = 0,
	spin = 300,
	glow = 1,
	fade = 0,
}
local FAN: Particles.Layer = {
	texture = Particles.SPARKLE,
	rate = 30,
	life = { 0.3, 0.6 },
	speed = { 10, 16 },
	back = true,
	spread = 55,
	size = { 0.7, 0.15 },
	lift = 2,
	spin = 200,
	glow = 1,
	fade = 0.1,
}
local BURST: Particles.Layer = {
	texture = Particles.SMOKE,
	rate = 26,
	life = { 0.35, 0.7 },
	speed = { 6, 10 },
	spread = 85,
	size = { 0.8, 2.6 },
	lift = 1,
	spin = 60,
	glow = 0.4,
	fade = 0.5,
}
local EMBERS: Particles.Layer = {
	texture = Particles.SPARKLE,
	rate = 9,
	life = { 1.4, 2.2 },
	speed = { 3, 5 },
	spread = 30,
	size = { 0.45, 0.1 },
	lift = 2.5,
	spin = 160,
	glow = 1,
	fade = 0.05,
	color = "#FFD180",
}

-- Emitters that only run while their runner does, with the body whose speed says so.
local whileRunning: { [ParticleEmitter]: BasePart } = {}

local function mark<T>(instance: T): T
	((instance :: any) :: Instance):SetAttribute(MARK, true)
	return instance
end

-- Takes off whatever look the character has.
local function clear(character: Model)
	for _, item in character:GetDescendants() do
		if item:GetAttribute(MARK) then
			item:Destroy()
		end
	end
end

-- A band round the lower part of a limb, welded to it. `from` and `to` say where it runs, as
-- shares of the limb's height down from its middle; `swell` is how far it stands out.
local function band(
	limb: BasePart,
	name: string,
	from: number,
	to: number,
	swell: number,
	color: Color3,
	material: Enum.Material
)
	local part = mark(Instance.new("Part"))
	part.Name = name
	part.Size = Vector3.new(limb.Size.X + swell, limb.Size.Y * (to - from), limb.Size.Z + swell)
	part.CFrame = limb.CFrame * CFrame.new(0, -limb.Size.Y * (from + to) / 2, 0)
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = limb
	weld.Part1 = part
	weld.Parent = part
	part.Parent = limb
end

-- The body's parts of the given names that this character has.
local function limbs(character: Model, names: { string }): { BasePart }
	local found = {}
	for _, name in names do
		local limb = character:FindFirstChild(name)
		if limb and limb:IsA("BasePart") then
			table.insert(found, limb)
		end
	end
	return found
end

-- A point on the ground under the runner, where what is kicked up comes from.
local function atFeet(root: BasePart, humanoid: Humanoid): Attachment
	local drop = if humanoid.RigType == Enum.HumanoidRigType.R6
		then root.Size.Y / 2 + 2
		else root.Size.Y / 2 + humanoid.HipHeight
	local feet = mark(Instance.new("Attachment"))
	feet.Name = "SpeedLookFeet"
	feet.Position = Vector3.new(0, -drop, 0)
	feet.Parent = root
	return feet
end

-- Hangs a layer of particles on `from`. One that is only for the run stays off until the
-- loop in start() sees its runner running.
local function emit(
	from: Instance,
	root: BasePart,
	name: string,
	layer: Particles.Layer,
	color: Color3,
	running: boolean?
): ParticleEmitter
	local particles = mark(Particles.emitter(layer, color))
	particles.Name = name
	if running then
		particles.Enabled = false
		whileRunning[particles] = root
	end
	particles.Parent = from
	return particles
end

-- Steam rising off the whole body, thicker with every Gate. It moves with the body, so it stays
-- round the runner at full speed instead of being strewn along the road; the trail is the streak.
local function steam(root: BasePart, color: Color3, gate: number)
	emit(root, root, "SpeedLookSteam", {
		texture = Particles.SMOKE,
		rate = 3 + gate * 2.5,
		life = { 0.8, 1.4 },
		speed = { 2, 3.5 },
		locked = true,
		spread = 25,
		size = { 1 + gate * 0.08, 2.4 + gate * 0.15 },
		lift = 2,
		spin = 40,
		glow = if gate >= SpeedStages.GATES then 0.8 else 0.5,
		fade = 0.45,
	}, color)
end

-- A ribbon of the Gate's color between two points of `part`, streaming behind it. A trail only
-- draws while its ends move, so it shows on the run and is gone when standing.
local function ribbon(
	part: BasePart,
	name: string,
	high: Vector3,
	low: Vector3,
	color: Color3,
	seconds: number
)
	local top = mark(Instance.new("Attachment"))
	top.Name = name .. "Top"
	top.Position = high
	top.Parent = part
	local bottom = mark(Instance.new("Attachment"))
	bottom.Name = name .. "Bottom"
	bottom.Position = low
	bottom.Parent = part

	local trail = mark(Instance.new("Trail"))
	trail.Name = name
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Color = ColorSequence.new(color, color:Lerp(WHITE, 0.35))
	trail.Transparency = NumberSequence.new(0.3, 1)
	trail.WidthScale = NumberSequence.new(1, 0.2)
	trail.Lifetime = seconds
	trail.MinLength = 0.1
	trail.LightEmission = 0.7
	trail.LightInfluence = 0
	trail.FaceCamera = true
	trail.Parent = part
end

-- Dresses the character for speed `level`, taking off the look of any earlier stage.
function SpeedLook.apply(character: Model, level: number)
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not root:IsA("BasePart") or not humanoid then
		return
	end
	clear(character)

	local stage = SpeedStages.at(level)
	local color = Color3.fromHex(stage.color)
	local gate = stage.gate
	local function wears(wear: SpeedStages.Wear): boolean
		return SpeedStages.wears(stage, wear)
	end

	-- Strapped on: cloth and iron on the shins, and on the forearms once the weights are heavy.
	for _, leg in limbs(character, LEGS) do
		if wears("warmers") then
			band(leg, "SpeedLookWarmer", 0, 0.46, 0.14, color, Enum.Material.Fabric)
		end
		if wears("weights") then
			band(leg, "SpeedLookWeight", 0.18, 0.32, 0.34, IRON, Enum.Material.Metal)
		end
		if wears("heavy") then
			band(leg, "SpeedLookWeight", 0.34, 0.44, 0.34, IRON, Enum.Material.Metal)
		end
	end
	if wears("wrists") then
		for _, arm in limbs(character, ARMS) do
			band(arm, "SpeedLookCuff", 0.04, 0.46, 0.12, color, Enum.Material.Fabric)
			band(arm, "SpeedLookWrist", 0.18, 0.36, 0.3, IRON, Enum.Material.Metal)
		end
	end

	-- Off the body: all the time.
	if wears("steam") then
		steam(root, color, gate)
	end
	if wears("motes") then
		emit(root, root, "SpeedLookMotes", MOTES, color)
	end
	if wears("sparks") then
		emit(root, root, "SpeedLookSparks", SPARKS, color)
	end
	if wears("embers") then
		emit(root, root, "SpeedLookEmbers", EMBERS, color)
	end

	-- At the feet.
	if wears("dust") or wears("flame") or wears("burst") then
		local feet = atFeet(root, humanoid)
		if wears("dust") then
			-- Heavier weights kick up more of it.
			local dust = emit(feet, root, "SpeedLookDust", DUST, color, true)
			if wears("heavy") then
				dust.Rate *= 1.6
			end
		end
		if wears("flame") then
			emit(feet, root, "SpeedLookFlame", FLAME, color)
		end
		if wears("burst") then
			emit(feet, root, "SpeedLookBurst", BURST, color, true)
		end
	end

	-- Behind the runner: only on the run.
	if wears("trail") then
		local seconds = 0.2 + gate * 0.04
		ribbon(
			root,
			"SpeedLookTrail",
			Vector3.new(0, 1.2, 0),
			Vector3.new(0, -1.2, 0),
			color,
			seconds
		)
	end
	if wears("streaks") then
		for _, hand in limbs(character, HANDS) do
			-- An R6 body has no hands: the ribbon comes off the end of the arm.
			local reach = if hand.Size.Y > 1.5 then -hand.Size.Y / 2 else 0
			ribbon(
				hand,
				"SpeedLookStreak",
				Vector3.new(0, reach + 0.25, 0),
				Vector3.new(0, reach - 0.25, 0),
				color,
				0.28
			)
		end
	end
	if wears("fan") then
		emit(root, root, "SpeedLookFan", FAN, color, true)
	end
end

function SpeedLook.start()
	-- Every fresh character gets the look of the stage reached. An R15 body's limbs can arrive a
	-- moment after the rest of it.
	Loadout.register(function(player, character, _backpack, humanoid)
		local data = Data.get(player)
		if not data then
			return
		end
		local level = data.speedLevel
		task.spawn(function()
			if humanoid.RigType == Enum.HumanoidRigType.R15 then
				character:WaitForChild("RightLowerLeg", 5)
				character:WaitForChild("RightHand", 5)
			end
			if character.Parent then
				SpeedLook.apply(character, level)
			end
		end)
	end)

	-- What is only for the run shows only while running on the ground.
	task.spawn(function()
		while true do
			task.wait(CHECK_SECONDS)
			for particles, root in whileRunning do
				if not particles.Parent or not root.Parent then
					whileRunning[particles] = nil
				else
					local velocity = root.AssemblyLinearVelocity
					local along = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
					particles.Enabled = along > RUNNING and math.abs(velocity.Y) < 3
				end
			end
		end
	end)
end

return SpeedLook
