--!strict
-- The dojos: one per player, three along each long side of the plaza behind the throwing strip
-- (Logic/PlazaPlan has the layout), fenced in by invisible walls. There are six, which is the
-- server size the game is meant for; a seventh player is turned away. Positions are in
-- Hub-local coordinates (see World/Hub). The plaza itself, with its fountain, is World/Plaza's.
--
-- Each dojo is a building of up to three floors with ten pads on each (Logic/DojoPlan has the
-- layout, World/DojoHall builds the building). This module lays out the pads, with their
-- upgrade consoles and price tags, and hands the dojos out to players. A dojo stands with one
-- floor until Services/Dojo puts up more for its owner (setFloors).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Build = require(ReplicatedStorage.Shared.View.Build)
local Data = require("../Data")
local DojoHall = require("./DojoHall")
local DojoPlan = require(ReplicatedStorage.Shared.Logic.DojoPlan)
local Hub = require("./Hub")
local Net = require(ReplicatedStorage.Shared.Net)
local PlazaPlan = require(ReplicatedStorage.Shared.Logic.PlazaPlan)
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
	part: Part, -- the round seal on the pad, whose color shows the pad's state
	prompt: ProximityPrompt, -- place, take, swap, merge, or unlock the pad
	console: Part, -- the board between the pad and the aisle that the upgrade buttons sit on
	buttons: { one: Button, ten: Button, max: Button }, -- +1 level, +10, as many as affordable
	stand: CFrame, -- where a shinobi on the pad stands, facing the plaza
	tag: TextLabel, -- floats over a pad that is not open yet: its price, or the game pass
	tagGui: BillboardGui,
	figure: Model?,
}

export type Plot = {
	index: number,
	owner: Player?,
	folder: Folder,
	pads: { Pad },
	hall: DojoHall.Hall,
	sign: TextLabel, -- the name board on the roof
	banner: BillboardGui, -- the owner's name floating over the roof, seen from afar
	bannerLabel: TextLabel,
	spawn: CFrame, -- where the owner appears: on the street by the entrance, facing the lane
}

-- A pad: a square wooden mat with a round seal on it.
local MAT = 0.3 -- height of the mat
local MAT_MARGIN = 0.6 -- how far the mat reaches past the seal on each side
local SEAL = 0.25 -- thickness of the seal

-- The upgrade console: a board leaning back towards its pad, as wide as most of the pad.
local CONSOLE_SLOPE = math.rad(40) -- how far the board is tipped up from lying flat
local CONSOLE_GAP = MAT_MARGIN -- between the seal's edge and the board's top edge
local CONSOLE_WIDTH = 5.4
-- From its foot up the slope; it reaches DojoPlan.CONSOLE_DEPTH into the aisle.
local CONSOLE_LENGTH = (DojoPlan.CONSOLE_DEPTH - CONSOLE_GAP) / math.cos(CONSOLE_SLOPE)
local CONSOLE_MARGIN = 0.15 -- bare board around the buttons
local BUTTON_GAP = 0.1
local SMALL_BUTTON = 0.95 -- how far up the slope the two small buttons reach
local SLAB = 0.25 -- thickness of the board and of a button
local UP = Vector3.new(0, 1, 0)

local STONE = Color3.fromRGB(99, 95, 98)
local BOARD = Color3.fromRGB(62, 44, 36)
local BUTTON = Color3.fromRGB(105, 102, 98)
local FENCE = Color3.fromRGB(93, 64, 55)
local FENCE_HEIGHT = 4

-- Builds the upgrade console of the pad whose seal's top is centered on `top`, on the side
-- `facing` (a level unit vector, towards the aisle). The wide button on top buys one level; under it
-- two small ones buy ten and as many as the Ryo allows. They are plain parts marked with
-- attributes: the client finds the one under the pointer and reports a press
-- (client/Consoles). A ClickDetector would do it without client code, but it swaps the mouse
-- cursor for a large hand while hovered. The buttons start out hidden: Services/Dojo shows and
-- labels them.
local function buildConsole(
	folder: Folder,
	padIndex: number,
	top: Vector3,
	facing: Vector3
): (Part, { one: Button, ten: Button, max: Button })
	-- `up` runs up the board, towards the pad; `out` is the way its face looks; `right` is the
	-- right hand of a player who stands in the aisle and reads it.
	local up = UP * math.sin(CONSOLE_SLOPE) - facing * math.cos(CONSOLE_SLOPE)
	local out = UP * math.cos(CONSOLE_SLOPE) + facing * math.sin(CONSOLE_SLOPE)
	local right = UP:Cross(facing)
	local floor = Vector3.new(top.X, top.Y - MAT - SEAL, top.Z)
	local foot = floor + facing * (DojoPlan.PAD_SIZE / 2 + DojoPlan.CONSOLE_DEPTH)

	-- A slab lying on the board: `along` is how far up the slope its middle is, `across` how
	-- far to the reader's right, `lift` how far its middle stands off the board's surface.
	local function slab(name: string, size: Vector2, along: number, across: number, lift: number)
		local center = foot + up * along + right * across + out * lift
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
	-- +10 on the reader's left, MAX on the right.
	local offset = (small.X + BUTTON_GAP) / 2
	return board,
		{
			one = button("one", big, bigAlong, 0),
			ten = button("ten", small, smallAlong, -offset),
			max = button("max", small, smallAlong, offset),
		}
end

-- One pad of a dojo: the mat, the seal with its prompt, the console and the price tag.
local function buildPad(folder: Folder, frame: DojoHall.Frame, padIndex: number): Pad
	local spot = DojoPlan.pad(padIndex)
	local floor = frame.at(spot.x, spot.y, spot.z)
	local matSize = DojoPlan.PAD_SIZE + 2 * MAT_MARGIN
	Build.part(
		folder,
		`PadMat{padIndex}`,
		Vector3.new(matSize, MAT, matSize),
		floor + Vector3.new(0, MAT / 2, 0),
		BOARD,
		Enum.Material.Wood
	)

	-- A cylinder lies along its X axis; this lays the seal flat.
	local center = floor + Vector3.new(0, MAT + SEAL / 2, 0)
	local seal = Build.part(
		folder,
		`Pad{padIndex}`,
		Vector3.new(SEAL, DojoPlan.PAD_SIZE, DojoPlan.PAD_SIZE),
		center,
		STONE
	)
	seal.Shape = Enum.PartType.Cylinder
	seal.CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90))
	seal.Transparency = 0.6 -- locked, as Services/Dojo draws it until someone owns the dojo

	local prompt = Build.prompt(seal, "Place", "Empty pad")
	prompt.MaxActivationDistance = 7
	prompt.Enabled = false

	local facing = frame.inward * spot.facing
	local top = floor + Vector3.new(0, MAT + SEAL, 0)
	local console, buttons = buildConsole(folder, padIndex, top, facing)

	local tag, tagGui = Build.label(seal, "", 4.5, Vector2.new(9, 3.6))
	tagGui.MaxDistance = 150
	tagGui.Enabled = false

	return {
		index = padIndex,
		part = seal,
		prompt = prompt,
		console = console,
		buttons = buttons,
		-- Every shinobi looks out of the dojo, at the plaza, whichever row it stands in. (Each
		-- used to face the aisle: the front row, the one a new player fills first, stood with
		-- its back to the plaza and its face to the back wall.)
		stand = CFrame.lookAt(top, top - frame.inward),
		tag = tag,
		tagGui = tagGui,
	}
end

local plots: { Plot } = {}
local byPlayer: { [Player]: Plot } = {}

local function build(index: number): Plot
	-- Odd dojos stand on the left of the plaza, even ones on the right, facing each other.
	local place = PlazaPlan.dojo(index)
	local side = place.side
	-- Dojo-local x runs away from the lane (see Logic/DojoPlan), so the foot of the staircase
	-- is at the end of the dojo nearest the throwing strip on both sides of the plaza.
	local frame: DojoHall.Frame = {
		at = function(x: number, y: number, z: number): Vector3
			return Hub.at(place.along - x, y, side * (PlazaPlan.HALF_WIDTH + z))
		end,
		inward = Vector3.new(0, 0, side),
	}

	local folder = Instance.new("Folder")
	folder.Name = `Dojo{index}`
	local hall = DojoHall.build(folder, frame)

	-- Each pad goes up and comes down with its floor.
	local pads: { Pad } = {}
	for padIndex = 1, DojoPlan.PAD_COUNT do
		local storey = hall.storeys[DojoPlan.pad(padIndex).floor]
		table.insert(pads, buildPad(storey, frame, padIndex))
	end
	local d = Tuning.Dojo
	assert(
		#pads >= d.startPads + d.buyablePads + d.gamePassPads,
		"the dojo has fewer pads than Tuning.Dojo allows a player to unlock"
	)

	-- Over the roof, which it rises with.
	local bannerAt =
		frame.at(0, DojoPlan.level(hall.floors + 1) + 22, (DojoPlan.FRONT + DojoPlan.BACK) / 2)
	local bannerAnchor = Build.part(hall.roof, "BannerAnchor", Vector3.one, bannerAt, BOARD)
	bannerAnchor.Transparency = 1
	bannerAnchor.CanCollide = false
	bannerAnchor.CanQuery = false
	local banner, bannerGui = Build.label(bannerAnchor, "", 0, Vector2.new(36, 6))
	bannerGui.Enabled = false

	folder.Parent = Workspace

	-- On the plaza in front of the entrance under the first landing.
	local spawn = PlazaPlan.spawn(index)
	local spawnAt = Hub.at(spawn.along, 3, spawn.side)
	return {
		index = index,
		folder = folder,
		pads = pads,
		hall = hall,
		sign = hall.sign,
		banner = bannerGui,
		bannerLabel = banner,
		spawn = CFrame.lookAt(spawnAt, spawnAt + Vector3.new(10, 0, 0)),
	}
end

-- What closes the yard the dojos and the plaza stand in: a low fence all round it, and behind
-- the fence an invisible wall too tall to jump. Together with the lane's own walls and the gate
-- behind the strip (World/Hub) the walls close the playable area.
local function buildYard()
	local folder = Instance.new("Folder")
	folder.Name = "Yard"

	local height = Hub.WALL_HEIGHT
	local thick = Hub.WALL_THICKNESS
	local depth = PlazaPlan.DEPTH
	-- From the center line to a dojo's far edge.
	local halfWidth = PlazaPlan.YARD_HALF
	-- From the lane's side wall out to the yard's: the yard is wider than the lane.
	local shoulder = halfWidth - Hub.LANE_WIDTH / 2

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
		-- From the yard's corner to the lane's side wall, in line with the throwing strip.
		table.insert(runs, {
			center = Vector3.new(
				thick / 2,
				0,
				side * (Hub.LANE_WIDTH / 2 + (shoulder + thick) / 2)
			),
			size = Vector3.new(thick, 0, shoulder + thick),
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

-- Puts up the dojo's first `count` floors and takes down the rest. Returns how many floors
-- stood before.
function Plots.setFloors(plot: Plot, count: number): number
	local before = plot.hall.floors
	DojoHall.setFloors(plot.hall, count)
	return before
end

-- Runs `fn` for every dojo. Services use it, after Plots.start(), to hook up the pads' prompts.
function Plots.forEach(fn: (plot: Plot) -> ())
	for _, plot in plots do
		fn(plot)
	end
end

local function setOwner(plot: Plot, player: Player?)
	plot.owner = player
	local name = if player then `{player.DisplayName}'s Dojo` else "Empty Dojo"
	plot.sign.Text = name
	plot.bannerLabel.Text = name
	plot.banner.Enabled = player ~= nil
end

-- Gives the player the first free dojo, or nothing if all are taken.
local function assign(player: Player): Plot?
	for _, plot in plots do
		if not plot.owner then
			setOwner(plot, player)
			byPlayer[player] = plot
			return plot
		end
	end
	return nil
end

function Plots.start()
	for index = 1, PlazaPlan.DOJOS do
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
			setOwner(plot, nil)
			Plots.setFloors(plot, 1)
			byPlayer[player] = nil
		end
	end)
end

return Plots
