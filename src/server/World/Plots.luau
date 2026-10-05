--!strict
-- The dojos: one per player, in two rows along the street behind the throwing strip, fenced in
-- by invisible walls. There are six, which is the server size the game is meant for; a seventh
-- player is turned away. Positions are in Hub-local coordinates (see World/Hub).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Build = require(ReplicatedStorage.Shared.View.Build)
local Data = require("../Data")
local Hub = require("./Hub")
local Net = require(ReplicatedStorage.Shared.Net)
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)
local Util = require("../Util")

local Plots = {}

-- One button of a pad's upgrade console: a slab to click or tap, with its text on its face.
export type Button = {
	part: Part,
	label: TextLabel,
	gui: SurfaceGui,
}

export type Pad = {
	index: number,
	part: Part,
	prompt: ProximityPrompt, -- place, take, swap, merge, or unlock the pad
	console: Part, -- the board at the foot of the pad that the upgrade buttons sit on
	buttons: { one: Button, ten: Button, max: Button }, -- +1 level, +10, as many as affordable
	figure: Model?,
}

export type Plot = {
	index: number,
	owner: Player?,
	folder: Folder,
	pads: { Pad },
	sign: TextLabel,
	spawn: CFrame, -- where the owner appears: on the street by the dojo, facing the lane
}

local DOJOS = 6
-- Each pair of facing dojos takes this much of the street's length; the rest is the gap
-- between one pair and the next.
local SLOT_PITCH = 72
local DOJO_DEPTH = 64 -- along the street
local DOJO_WIDTH = 50 -- away from the street
local PAD_SIZE = 7
local PAD_PITCH = 10
local PAD_COLUMNS = 6
local PAD_ROWS = 4

-- The upgrade console: a board leaning back towards its pad, as wide as most of the pad.
local CONSOLE_SLOPE = math.rad(40) -- how far the board is tipped up from lying flat
local CONSOLE_WIDTH = 5.4
local CONSOLE_LENGTH = 2.8 -- from its foot up the slope
local CONSOLE_MARGIN = 0.15 -- bare board around the buttons
local BUTTON_GAP = 0.1
local SMALL_BUTTON = 0.95 -- how far up the slope the two small buttons reach
local SLAB = 0.25 -- thickness of the board and of a button

local WOOD = Color3.fromRGB(121, 85, 61)
local STONE = Color3.fromRGB(99, 95, 98)
local COBBLE = Color3.fromRGB(140, 135, 130)
local FENCE = Color3.fromRGB(93, 64, 55)
local FENCE_HEIGHT = 4
local BOARD = Color3.fromRGB(62, 44, 36)
local BUTTON = Color3.fromRGB(105, 102, 98)

-- Builds the upgrade console of the pad at hub-local (x, z), on the pad's street side. The
-- wide button on top buys one level; under it two small ones buy ten and as many as the Ryo
-- allows. They are plain parts marked with attributes: the client finds the one under the
-- pointer and reports a press (client/Consoles). A ClickDetector would do it without client
-- code, but it swaps the mouse cursor for a large hand while hovered. The buttons start out
-- hidden: Services/Dojo shows and labels them.
local function buildConsole(
	folder: Folder,
	padIndex: number,
	x: number,
	z: number,
	side: number
): (Part, { one: Button, ten: Button, max: Button })
	-- `up` runs up the board, away from the street; `out` is the way its face looks.
	local up = Vector3.new(0, math.sin(CONSOLE_SLOPE), side * math.cos(CONSOLE_SLOPE))
	local out = Vector3.new(0, math.cos(CONSOLE_SLOPE), -side * math.sin(CONSOLE_SLOPE))
	local reach = PAD_SIZE / 2 + 0.2 + CONSOLE_LENGTH * math.cos(CONSOLE_SLOPE)
	local foot = Hub.at(x, 0, z - side * reach)

	-- A slab lying on the board: `along` is how far up the slope its middle is, `across` how
	-- far to the side, `lift` how far its middle stands off the board's surface.
	local function slab(name: string, size: Vector2, along: number, across: number, lift: number)
		local center = foot + up * along + Vector3.new(across, 0, 0) + out * lift
		local part = Build.part(folder, name, Vector3.new(size.X, size.Y, SLAB), center, BUTTON)
		-- A part's front face looks where its CFrame looks, and text on it reads upright.
		part.CFrame = CFrame.lookAt(center, center + out)
		part.CanCollide = false
		part.Transparency = 1
		return part
	end

	local function button(kind: string, size: Vector2, along: number, across: number): Button
		local part = slab(`Upgrade_{kind}_{padIndex}`, size, along, across, SLAB / 2)
		part:SetAttribute(Net.UPGRADE_ATTRIBUTE, kind)
		part:SetAttribute(Net.ACTIVE_ATTRIBUTE, false)
		local label, gui = Build.faceLabel(part, Enum.NormalId.Front, "")
		gui.Enabled = false
		return { part = part, label = label, gui = gui }
	end

	local board = slab(
		`Console{padIndex}`,
		Vector2.new(CONSOLE_WIDTH, CONSOLE_LENGTH),
		CONSOLE_LENGTH / 2,
		0,
		-SLAB / 2
	)
	board.Color = BOARD
	board.Material = Enum.Material.Wood

	local inner = CONSOLE_WIDTH - 2 * CONSOLE_MARGIN
	local small = Vector2.new((inner - BUTTON_GAP) / 2, SMALL_BUTTON)
	local big = Vector2.new(inner, CONSOLE_LENGTH - 2 * CONSOLE_MARGIN - BUTTON_GAP - SMALL_BUTTON)
	local smallAlong = CONSOLE_MARGIN + small.Y / 2
	local bigAlong = CONSOLE_MARGIN + small.Y + BUTTON_GAP + big.Y / 2
	-- Seen from the street, +10 is on the left and MAX on the right in either row of dojos.
	local toLeft = side * (small.X + BUTTON_GAP) / 2
	return board,
		{
			one = button("one", big, bigAlong, 0),
			ten = button("ten", small, smallAlong, toLeft),
			max = button("max", small, smallAlong, -toLeft),
		}
end

local plots: { Plot } = {}
local byPlayer: { [Player]: Plot } = {}

local function build(index: number): Plot
	-- Odd dojos stand on the left of the street, even ones on the right, facing each other.
	local slot = math.ceil(index / 2)
	local side = if index % 2 == 1 then -1 else 1
	-- The first pair starts right at the lane, so their floors meet the throwing strip's line.
	local centerX = -DOJO_DEPTH / 2 - (slot - 1) * SLOT_PITCH
	local streetEdge = Hub.LANE_WIDTH / 2
	local centerZ = side * (streetEdge + DOJO_WIDTH / 2)

	local folder = Instance.new("Folder")
	folder.Name = `Dojo{index}`

	Build.part(
		folder,
		"Floor",
		Vector3.new(DOJO_DEPTH, 1, DOJO_WIDTH),
		Hub.at(centerX, -0.5, centerZ),
		WOOD,
		Enum.Material.WoodPlanks
	)

	local signAnchor =
		Build.part(folder, "SignAnchor", Vector3.one, Hub.at(centerX, 14, centerZ), WOOD)
	signAnchor.Transparency = 1
	signAnchor.CanCollide = false
	local sign = Build.label(signAnchor, "Empty Dojo", 0, Vector2.new(36, 6))

	-- Pads in rows parallel to the street, numbered from the street inwards, so the row a new
	-- player starts with is the one by the entrance.
	local pads: { Pad } = {}
	for row = 1, PAD_ROWS do
		for column = 1, PAD_COLUMNS do
			local padIndex = #pads + 1
			local x = centerX + (column - (PAD_COLUMNS + 1) / 2) * PAD_PITCH
			local z = side * (streetEdge + 9 + (row - 1) * PAD_PITCH)
			local part = Build.part(
				folder,
				`Pad{padIndex}`,
				Vector3.new(PAD_SIZE, 0.5, PAD_SIZE),
				Hub.at(x, 0.25, z),
				STONE
			)
			local prompt = Build.prompt(part, "Place", "Empty pad")
			prompt.MaxActivationDistance = 7
			prompt.Enabled = false

			local console, buttons = buildConsole(folder, padIndex, x, z, side)
			table.insert(pads, {
				index = padIndex,
				part = part,
				prompt = prompt,
				console = console,
				buttons = buttons,
			})
		end
	end
	assert(
		#pads >= Tuning.Dojo.startPads + Tuning.Dojo.buyablePads + Tuning.Dojo.gamePassPads,
		"the dojo has fewer pads than Tuning.Dojo allows a player to unlock"
	)

	folder.Parent = Workspace

	local spawnAt = Hub.at(centerX, 3, side * (streetEdge - 5))
	return {
		index = index,
		folder = folder,
		pads = pads,
		sign = sign,
		spawn = CFrame.lookAt(spawnAt, spawnAt + Vector3.new(10, 0, 0)),
	}
end

-- What surrounds the dojos: the street between the two rows, a low fence around the whole
-- yard, and behind the fence an invisible wall too tall to jump. Together with the lane's own
-- walls and the gate behind the strip (World/Hub) the walls close the playable area.
local function buildYard()
	local folder = Instance.new("Folder")
	folder.Name = "Yard"

	local height = Hub.WALL_HEIGHT
	local thick = Hub.WALL_THICKNESS
	-- How far back the yard goes: to the far edge of the last pair of dojos.
	local depth = (math.ceil(DOJOS / 2) - 1) * SLOT_PITCH + DOJO_DEPTH
	local halfWidth = Hub.LANE_WIDTH / 2 + DOJO_WIDTH -- from the center line to a dojo's far edge

	Build.part(
		folder,
		"Street",
		Vector3.new(depth, 1, Hub.LANE_WIDTH),
		Hub.at(-depth / 2, -0.5, 0),
		COBBLE,
		Enum.Material.Cobblestone
	)

	-- Each run of the boundary as a center and a size on the ground; a fence and a wall are
	-- raised on every one of them.
	local runs: { { center: Vector3, size: Vector3 } } = {
		{
			center = Vector3.new(-depth - thick / 2, 0, 0),
			size = Vector3.new(thick, 0, halfWidth * 2 + thick * 2),
		},
	}
	for _, side in { -1, 1 } do
		table.insert(runs, {
			center = Vector3.new(-depth / 2, 0, side * (halfWidth + thick / 2)),
			size = Vector3.new(depth, 0, thick),
		})
		-- From a front dojo's corner to the lane's side wall, in line with the throwing strip.
		table.insert(runs, {
			center = Vector3.new(
				thick / 2,
				0,
				side * (Hub.LANE_WIDTH / 2 + (DOJO_WIDTH + thick) / 2)
			),
			size = Vector3.new(thick, 0, DOJO_WIDTH + thick),
		})
	end

	for _, run in runs do
		Build.wall(
			folder,
			"Wall",
			Vector3.new(run.size.X, height, run.size.Z),
			Hub.at(run.center.X, height / 2, run.center.Z)
		)
		Build.part(
			folder,
			"Fence",
			Vector3.new(run.size.X, FENCE_HEIGHT, run.size.Z),
			Hub.at(run.center.X, FENCE_HEIGHT / 2, run.center.Z),
			FENCE,
			Enum.Material.Wood
		)
	end

	folder.Parent = Workspace
end

function Plots.of(player: Player): Plot?
	return byPlayer[player]
end

-- Runs `fn` for every dojo. Services use it, after Plots.start(), to hook up the pads' prompts.
function Plots.forEach(fn: (plot: Plot) -> ())
	for _, plot in plots do
		fn(plot)
	end
end

-- Gives the player the first free dojo, or nothing if all are taken.
local function assign(player: Player): Plot?
	for _, plot in plots do
		if not plot.owner then
			plot.owner = player
			plot.sign.Text = `{player.DisplayName}'s Dojo`
			byPlayer[player] = plot
			return plot
		end
	end
	return nil
end

function Plots.start()
	for index = 1, DOJOS do
		plots[index] = build(index)
	end
	buildYard()

	Data.onLoaded(function(player)
		local plot = assign(player)
		if not plot then
			-- Only happens if the place's Max Players is set above the number of dojos.
			player:Kick("This server is full. Please join another one.")
			return
		end
		Util.onCharacter(player, function(character)
			if not character:WaitForChild("HumanoidRootPart", 10) then
				return
			end
			-- Let the engine finish placing the fresh character, or it overrides the move.
			RunService.Heartbeat:Wait()
			if byPlayer[player] == plot and character.Parent then
				character:PivotTo(plot.spawn)
			end
		end)
	end)

	Data.onLeaving(function(player)
		local plot = byPlayer[player]
		if plot then
			plot.owner = nil
			plot.sign.Text = "Empty Dojo"
			byPlayer[player] = nil
		end
	end)
end

return Plots
