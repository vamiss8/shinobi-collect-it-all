--!strict
-- The scenery of the lane. Every zone has a module of its own here, named by the zone's id,
-- that builds what stands around its stretch of the lane out of plain parts, and a folder of
-- its own in Workspace.Zones. What a zone is colored in, and the surface of its lane, come from
-- Config/ZoneArt; its light and its weather are each client's business (client Mood, Weather).
--
-- Scenery is only looked at. It stands outside the lane's walls or hangs high over them, it is
-- never collided with or found by a ray, and it does not move the lane, its walls, the gate,
-- the throwing strip or the zone signs, which are the Hub's.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Kit = require(script.Kit)
local Looks = require(ReplicatedStorage.Shared.Config.ZoneArt)
local Net = require(ReplicatedStorage.Shared.Net)

local ZoneArt = {}

local BUILDERS: { [string]: (scene: Kit.Scene) -> () } = {
	academy = require(script.academy),
	land_of_waves = require(script.land_of_waves),
	forest_of_death = require(script.forest_of_death),
	chunin_exam_finals = require(script.chunin_exam_finals),
	valley_of_the_end = require(script.valley_of_the_end),
	hidden_sand = require(script.hidden_sand),
	akatsuki_lair = require(script.akatsuki_lair),
	hidden_rain = require(script.hidden_rain),
	kamui_dimension = require(script.kamui_dimension),
	great_ninja_war = require(script.great_ninja_war),
}

-- Call after Hub.start(): positions are in the Hub's coordinates, and the lane it built gets
-- each zone's surface here.
function ZoneArt.start()
	local root = Instance.new("Folder")
	root.Name = "Zones"
	local hub = Workspace:FindFirstChild(Net.HUB_FOLDER)

	local counts: { string } = {}
	local total = 0
	for index, zone in Catalog.zones do
		local art = Looks.zones[zone.id]
		if not art then
			continue
		end

		-- Only how the lane looks: its size and place are the Hub's and stay as they are.
		local lane = if hub then hub:FindFirstChild(`Lane_{zone.id}`) else nil
		if art.lane and lane and lane:IsA("BasePart") then
			lane.Color = Color3.fromHex(art.lane.color)
			lane.Material = Kit.material(art.lane.material)
		end

		local build = BUILDERS[zone.id]
		if build then
			local scene = Kit.scene(zone, index, art)
			-- A zone that fails to build must not take the server's start down with it.
			-- Typed loosely: pcall of a function that returns nothing is typed without the error.
			local ok, problem = (pcall :: any)(build, scene)
			if not ok then
				warn(`[Zones] {zone.id} was left unfinished: {problem}`)
			end
			scene.folder.Parent = root
			table.insert(counts, `{zone.id} {scene.parts}`)
			total += scene.parts
		end
	end

	root.Parent = Workspace
	print(`[Zones] parts: {table.concat(counts, ", ")}; {total} in all`)
end

return ZoneArt
