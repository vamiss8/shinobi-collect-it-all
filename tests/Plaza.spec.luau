--!strict
-- The plaza behind the lane's start, checked on the plaza itself: its builder is run outside
-- Roblox (tests/zones) and what it made is measured against the layout (Logic/PlazaPlan).

local DojoPlan = require("../src/shared/Logic/DojoPlan")
local PlazaPlan = require("../src/shared/Logic/PlazaPlan")
local T = require("./harness")
local Zones = require("./zones")

-- Anything lower than this is paving or a pattern laid into it: it is walked over, not round.
local FLAT = 0.2
-- How much room a player needs clear of anything solid, studs.
local ROOM = 4
-- What hangs over where players walk hangs above the tallest of them.
local HEADROOM = 7.5
local LANE_HALF = Zones.LANE_WIDTH / 2

local folder: any = nil
local function parts(): { any }
	if not folder then
		folder = Zones.plaza()
	end
	local list = {}
	for _, item in folder:GetDescendants() do
		if item:IsA("BasePart") then
			table.insert(list, item)
		end
	end
	return list
end

-- The six dojo halls, each with all three of its floors up: as tall and as wide as they get.
local halls: any = nil
local function hallParts(): { any }
	if not halls then
		halls = Zones.dojos({ 3, 3, 3, 3, 3, 3 })
	end
	local list = {}
	for _, item in halls:GetDescendants() do
		if item:IsA("BasePart") then
			table.insert(list, item)
		end
	end
	return list
end

-- Tenten's shop, which stands on the plaza but is built by a module of its own.
local shop: any = nil
local function shopParts(): { any }
	if not shop then
		shop = Zones.shop()
	end
	local list = {}
	for _, item in shop:GetDescendants() do
		if item:IsA("BasePart") then
			table.insert(list, item)
		end
	end
	return list
end

local function where(part: any): string
	local at = part.CFrame.Position
	return string.format("%s at %.0f, %.0f, %.0f", part.Name, at.X, at.Y, at.Z)
end

-- Whether a part stands up out of the paving inside the given rectangle of the ground.
local function standsIn(part: any, fromX: number, toX: number, fromZ: number, toZ: number): boolean
	local low, high = Zones.bounds(part)
	return high.Y > FLAT and high.X > fromX and low.X < toX and high.Z > fromZ and low.Z < toZ
end

return {
	["the plaza builds, with a sensible number of parts and few lights"] = function()
		local count = #parts()
		T.ok(count >= 150 and count <= 700, `the plaza is {count} parts`)
		local lights = 0
		for _, item in folder:GetDescendants() do
			if item:IsA("PointLight") then
				lights += 1
			end
		end
		T.ok(lights <= 8, `the plaza has {lights} lights`)
	end,

	["everything of the plaza is anchored and stands inside the yard"] = function()
		for _, part in parts() do
			local low, high = Zones.bounds(part)
			T.ok(part.Anchored, `{where(part)} is not anchored`)
			T.ok(low.X >= -PlazaPlan.DEPTH - 0.01, `{where(part)} stands behind the yard`)
			T.ok(high.X <= 0.01, `{where(part)} stands on the lane`)
			T.ok(
				low.Z >= -PlazaPlan.YARD_HALF and high.Z <= PlazaPlan.YARD_HALF,
				`{where(part)} stands outside the yard`
			)
		end
	end,

	["the paving covers the whole plaza"] = function()
		local found = false
		for _, part in parts() do
			local low, high = Zones.bounds(part)
			if
				part.CanCollide
				and math.abs(high.Y) < 1e-6
				and low.X <= -PlazaPlan.DEPTH + 0.01
				and high.X >= -0.01
				and low.Z <= -PlazaPlan.HALF_WIDTH + 0.01
				and high.Z >= PlazaPlan.HALF_WIDTH - 0.01
			then
				found = true
			end
		end
		T.ok(found, "no solid floor from the lane's start to the back and from dojo to dojo")
	end,

	["nothing solid stands where an owner appears"] = function()
		for index = 1, PlazaPlan.DOJOS do
			local spawn = PlazaPlan.spawn(index)
			for _, part in parts() do
				local blocked = part.CanCollide
					and standsIn(
						part,
						spawn.along - ROOM,
						spawn.along + ROOM,
						spawn.side - ROOM,
						spawn.side + ROOM
					)
				T.ok(not blocked, `{where(part)} stands where the owner of dojo {index} appears`)
			end
		end
	end,

	["the stalls' places are left free"] = function()
		local reach = PlazaPlan.STALL_HALF + 1
		for id, spot in PlazaPlan.stalls do
			for _, part in parts() do
				local taken = standsIn(
					part,
					spot.along - reach,
					spot.along + reach,
					spot.side - reach,
					spot.side + reach
				)
				T.ok(not taken, `{where(part)} stands in the place of the {id} stall`)
			end
		end
	end,

	["Tenten's shop keeps to its place, and its place is kept free for it"] = function()
		local spot = PlazaPlan.SHOP
		local fromX, toX = spot.along - PlazaPlan.SHOP_FRONT, spot.along + PlazaPlan.SHOP_DEPTH
		local fromZ, toZ = spot.side - PlazaPlan.SHOP_HALF, spot.side + PlazaPlan.SHOP_HALF
		local pieces = shopParts()
		T.ok(#pieces >= 150, `the shop is only {#pieces} parts`)
		local counter = false
		for _, part in pieces do
			local low, high = Zones.bounds(part)
			T.ok(part.Anchored, `{where(part)} of the shop is not anchored`)
			T.ok(
				low.X >= fromX and high.X <= toX and low.Z >= fromZ and high.Z <= toZ,
				`{where(part)} of the shop stands outside its place`
			)
			T.ok(low.Y >= -0.01, `{where(part)} of the shop is under the paving`)
			if part.Name == "Counter" then
				counter = true
				T.ok(part.CanCollide, "the counter is not solid")
				-- The counter is behind the front line, and its prompt is used from before it.
				T.ok(low.X >= spot.along, "the counter stands out in front of the shop")
			end
		end
		T.ok(counter, "the shop has no counter")
		for _, part in parts() do
			local taken = standsIn(part, fromX, toX, fromZ, toZ)
			T.ok(not taken, `{where(part)} stands in the place of Tenten's shop`)
		end
	end,

	-- Two flat sides in one plane, one over the other, flicker as the camera moves. The shop is
	-- held to this where it shows; the crossed blades of a shuriken are let be.
	["nothing of Tenten's shop flickers where it is seen"] = function()
		for _, fight in Zones.fights(shopParts()) do
			T.ok(
				fight.area < 0.1,
				string.format(
					"%s and %s share a plane over %.2f square studs",
					where(fight.first),
					where(fight.second),
					fight.area
				)
			)
		end
	end,

	["the way from the plaza onto the lane is open"] = function()
		for _, part in parts() do
			local blocked = part.CanCollide
				and standsIn(part, -PlazaPlan.FRONT_GAP, 1, -LANE_HALF, LANE_HALF)
			T.ok(not blocked, `{where(part)} stands in the way onto the lane`)
		end
	end,

	["nothing of the plaza stands on a dojo's plot or at the foot of its stairs"] = function()
		for index = 1, PlazaPlan.DOJOS do
			local dojo = PlazaPlan.dojo(index)
			-- A dojo's stairs start at its end nearest the lane and are stepped onto from
			-- beside it: a few studs past that end have to stay clear as well.
			local fromX = dojo.along - DojoPlan.HALF_WIDTH
			local toX = dojo.along + DojoPlan.HALF_WIDTH + ROOM
			local near = PlazaPlan.HALF_WIDTH
			local far = PlazaPlan.HALF_WIDTH + DojoPlan.FRONT + ROOM
			for _, part in parts() do
				local onPlot = if dojo.side > 0
					then standsIn(part, fromX, toX, near, far)
					else standsIn(part, fromX, toX, -far, -near)
				T.ok(not onPlot, `{where(part)} stands on the plot of dojo {index}`)
			end
		end
	end,

	["the fountain's basin is walled all the way round, in the plaza's middle"] = function()
		local fountain = PlazaPlan.FOUNTAIN
		local rim = 0
		for _, part in parts() do
			if part.Name == "Rim" then
				rim += 1
				local at = part.CFrame.Position
				local out = math.sqrt((at.X - fountain.along) ^ 2 + (at.Z - fountain.side) ^ 2)
				T.ok(out < PlazaPlan.FOUNTAIN_RADIUS, `{where(part)} is outside the fountain`)
				T.ok(out > PlazaPlan.FOUNTAIN_RADIUS - 3, `{where(part)} is not at the rim`)
				T.ok(part.CanCollide, "the rim is solid")
			end
		end
		T.ok(rim >= 16, `the rim is only {rim} pieces`)
		-- Nothing else that is solid crowds the walk round it, out to where the stalls stand.
		local reach = PlazaPlan.FOUNTAIN_RADIUS
		local clear = PlazaPlan.STALL_RING - PlazaPlan.STALL_HALF
		for _, part in parts() do
			if part.CanCollide then
				local low, high = Zones.bounds(part)
				local at = part.CFrame.Position
				local out = math.sqrt((at.X - fountain.along) ^ 2 + (at.Z - fountain.side) ^ 2)
				local inWalk = high.Y > FLAT and out > reach + 1 and out < reach + 6
				T.ok(not inWalk, `{where(part)} crowds the walk round the fountain ({low.Y})`)
				T.ok(
					clear > reach + 6,
					"the walk round the fountain is narrower than it is checked"
				)
			end
		end
	end,

	["cherry trees stand on the plaza, clear of every dojo"] = function()
		local planters = 0
		local crowns = {}
		for _, part in parts() do
			if part.Name == "Planter" then
				planters += 1
				local low, high = Zones.bounds(part)
				T.ok(
					low.Z >= -PlazaPlan.HALF_WIDTH + ROOM + 3
						and high.Z <= PlazaPlan.HALF_WIDTH - ROOM - 3,
					`{where(part)} leaves no way past it along the dojos' fronts`
				)
			elseif part.Name == "CherryCrown" then
				table.insert(crowns, part)
			end
		end
		T.eq(planters, 2 * (PlazaPlan.PER_SIDE + 1), "a tree before every alley and at each end")
		-- No crown reaches into a dojo: not its walls, not its roof, not the small roofs round
		-- its upper floors. A crown is a ball; a piece of a dojo is taken by the box it fits in.
		local pieces = hallParts()
		T.ok(#pieces > 1000, "the dojo halls did not build")
		for _, crown in crowns do
			local middle = crown.CFrame.Position
			local radius = crown.Size.X / 2
			for _, piece in pieces do
				local low, high = Zones.bounds(piece)
				local dx = math.max(low.X - middle.X, 0, middle.X - high.X)
				local dy = math.max(low.Y - middle.Y, 0, middle.Y - high.Y)
				local dz = math.max(low.Z - middle.Z, 0, middle.Z - high.Z)
				local apart = math.sqrt(dx * dx + dy * dy + dz * dz)
				T.ok(
					apart >= radius + 1,
					`{where(crown)} runs into a dojo's {piece.Name} ({apart - radius} studs off)`
				)
			end
		end
	end,

	-- What is see-through is drawn farthest first, measured to each piece's middle: two such
	-- pieces one over the other change places as the camera moves, and one paints out the
	-- other. So the fountain's water is not see-through, and of what lies on it only foam is.
	["nothing see-through lies over anything else that is"] = function()
		local clear = {}
		local water = 0
		for _, part in parts() do
			if part.Name == "Water" or part.Name == "Shoal" or part.Name == "BowlWater" then
				water += 1
				T.eq(part.Transparency, 0, `{where(part)} is see-through`)
			end
			if part.Transparency > 0 and part.Transparency < 1 then
				table.insert(clear, part)
			end
		end
		T.eq(water, 4, "the pool, its shoal and the two bowls' water")
		for i, a in clear do
			local lowA, highA = Zones.bounds(a)
			for j = i + 1, #clear do
				local b = clear[j]
				local lowB, highB = Zones.bounds(b)
				-- Seen from anywhere above, two pieces cover one another only if one is over
				-- the other or they overlap on the ground.
				local apart = highA.X <= lowB.X
					or highB.X <= lowA.X
					or highA.Z <= lowB.Z
					or highB.Z <= lowA.Z
				T.ok(apart, `{where(a)} and {where(b)} are both see-through, one over the other`)
			end
		end
	end,

	["the fountain's water runs down in streams that stay over its pool"] = function()
		parts()
		local fountain = PlazaPlan.FOUNTAIN
		local streams = 0
		for _, item in folder:GetDescendants() do
			if item:IsA("Beam") then
				streams += 1
				local first, last = item.Attachment0, item.Attachment1
				T.ok(first ~= nil and last ~= nil, "a stream has lost an end")
				-- Its ends are given from the piece that holds them, at the fountain's foot.
				local hold = first.Parent.CFrame.Position
				T.near(hold.X, fountain.along, 1e-6, "the streams hang from the fountain's middle")
				T.near(hold.Z, fountain.side, 1e-6)
				local from, to = first.CFrame.Position, last.CFrame.Position
				T.ok(to.Y <= from.Y, `a stream ends higher ({to.Y}) than it starts ({from.Y})`)
				-- The curve it follows: it leaves along its first end's right hand and comes
				-- in along its last end's.
				local leave = from + first.CFrame.RightVector * item.CurveSize0
				local arrive = to - last.CFrame.RightVector * item.CurveSize1
				for step = 0, 10 do
					local t = step / 10
					local u = 1 - t
					local at = from * (u * u * u)
						+ leave * (3 * u * u * t)
						+ arrive * (3 * u * t * t)
						+ to * (t * t * t)
					local out = math.sqrt(at.X * at.X + at.Z * at.Z)
					T.ok(
						out <= PlazaPlan.FOUNTAIN_RADIUS - 1.8,
						`a stream leaves the basin, {out} out`
					)
					T.ok(at.Y >= 2, `a stream dips under the pool, to {at.Y}`)
				end
			end
		end
		T.ok(streams >= 30, `the fountain has only {streams} streams`)
	end,

	["benches are solid all over, back and all"] = function()
		local benches = 0
		for _, part in parts() do
			if string.sub(part.Name, 1, 5) == "Bench" then
				benches += 1
				T.ok(part.CanCollide, `{where(part)} cannot be stood on`)
			end
		end
		T.ok(benches >= 16, `only {benches} pieces of bench`)
	end,

	["every lantern hangs from the arm of its post"] = function()
		local lanterns = 0
		for _, lantern in parts() do
			if lantern.Name == "Lantern" then
				lanterns += 1
				local at = lantern.CFrame.Position
				local _, top = Zones.bounds(lantern)
				local hung = false
				for _, cord in parts() do
					local where_ = cord.CFrame.Position
					if
						cord.Name == "LanternCord"
						and math.abs(where_.X - at.X) < 0.05
						and math.abs(where_.Z - at.Z) < 0.05
					then
						local low, high = Zones.bounds(cord)
						-- The cord starts no more than a cap's thickness above the lantern,
						-- and an arm lies on top of it.
						T.ok(
							low.Y - top.Y <= 0.3,
							`{where(lantern)} hangs {low.Y - top.Y} under its cord`
						)
						for _, arm in parts() do
							if arm.Name == "LanternArm" then
								local armLow, armHigh = Zones.bounds(arm)
								if
									armLow.X <= where_.X
									and armHigh.X >= where_.X
									and armLow.Z <= where_.Z
									and armHigh.Z >= where_.Z
									and math.abs(armLow.Y - high.Y) <= 0.05
								then
									hung = true
								end
							end
						end
					end
				end
				T.ok(hung, `{where(lantern)} hangs in the air`)
			end
		end
		T.ok(lanterns >= 12, `only {lanterns} lanterns`)
	end,

	["a lantern on a post is solid and hangs over a tall player's head"] = function()
		local lanterns = 0
		for _, part in parts() do
			if part.Name == "Lantern" or part.Name == "LanternCap" or part.Name == "LanternArm" then
				lanterns += 1
				local low = Zones.bounds(part)
				T.ok(part.CanCollide, `{where(part)} cannot be touched`)
				T.ok(low.Y >= HEADROOM, `{where(part)} hangs only {low.Y} studs up`)
			end
		end
		T.ok(lanterns >= 48, `only {lanterns} pieces of lantern`)
	end,

	["the gate at the back is solid, its beams as well as its pillars"] = function()
		local pieces = 0
		for _, part in parts() do
			if string.sub(part.Name, 1, 4) == "Gate" then
				pieces += 1
				T.ok(part.CanCollide, `{where(part)} is passed through`)
			end
		end
		-- Two pillars on two feet, two beams and a cap.
		T.eq(pieces, 7)
	end,

	["a stone lantern is solid from its foot to its knob"] = function()
		local pieces = 0
		for _, part in parts() do
			if string.sub(part.Name, 1, 12) == "StoneLantern" then
				pieces += 1
				T.ok(part.CanCollide, `{where(part)} can be walked through`)
			end
		end
		T.ok(pieces >= 6 * 2 * PlazaPlan.DOJOS, `only {pieces} pieces of stone lantern`)
	end,

	["the notice board carries notices on both of its sides"] = function()
		local board: any = nil
		for _, part in parts() do
			if part.Name == "NoticeBoard" then
				board = part
			end
		end
		T.ok(board ~= nil, "there is no notice board")
		local middle = board.CFrame.Position
		local sides = { [1] = 0, [-1] = 0 }
		local said: { [string]: boolean } = {}
		for _, paper in parts() do
			if paper.Name == "Notice" then
				local at = paper.CFrame.Position
				local side = if at.Z > middle.Z then 1 else -1
				sides[side] += 1
				-- It lies on the board, inside its edges.
				local low, high = Zones.bounds(paper)
				local boardLow, boardHigh = Zones.bounds(board)
				T.ok(
					low.X >= boardLow.X and high.X <= boardHigh.X,
					`{where(paper)} hangs past the board's end`
				)
				T.ok(
					low.Y >= boardLow.Y and high.Y <= boardHigh.Y,
					`{where(paper)} hangs past the board's edge`
				)
				T.near(math.abs(at.Z - middle.Z), board.Size.Z / 2 + paper.Size.Z / 2, 0.02)
				-- Its writing is on the face that looks away from the board, and says something
				-- no other paper says.
				local gui = paper:FindFirstChildOfClass("SurfaceGui")
				T.ok(gui ~= nil, `{where(paper)} is blank`)
				T.eq(gui.Face.Name, if side == 1 then "Back" else "Front", "the face written on")
				local words = {}
				for _, item in gui:GetDescendants() do
					if item:IsA("TextLabel") and item.Text ~= "" then
						table.insert(words, item.Text)
						T.eq(item.Font.Name, "PermanentMarker", "the game's brush")
					end
				end
				T.ok(#words >= 2, `{where(paper)} says next to nothing`)
				local all = table.concat(words, " / ")
				T.ok(not said[all], `two notices say the same: {all}`)
				said[all] = true
			end
		end
		T.ok(sides[1] >= 6, `only {sides[1]} notices on the side that looks at the path`)
		T.ok(sides[-1] >= 6, `only {sides[-1]} notices on the side that looks at the dojos`)
	end,

	["no two notices overlap"] = function()
		local papers = {}
		for _, paper in parts() do
			if paper.Name == "Notice" then
				table.insert(papers, paper)
			end
		end
		for i, a in papers do
			local lowA, highA = Zones.bounds(a)
			for j = i + 1, #papers do
				local b = papers[j]
				local lowB, highB = Zones.bounds(b)
				local apart = highA.X <= lowB.X
					or highB.X <= lowA.X
					or highA.Y <= lowB.Y
					or highB.Y <= lowA.Y
					or highA.Z <= lowB.Z
					or highB.Z <= lowA.Z
				T.ok(apart, `{where(a)} lies over {where(b)}`)
			end
		end
	end,

	-- Two flat sides in one plane, one over the other, flicker as the camera moves.
	["no two sides that look unlike lie in one plane where both are seen"] = function()
		for _, fight in Zones.fights(parts()) do
			T.ok(
				false,
				string.format(
					"%s and %s share a plane over %.2f square studs",
					where(fight.first),
					where(fight.second),
					fight.area
				)
			)
		end
	end,

	["a pair of stone lanterns stands before every dojo"] = function()
		for index = 1, PlazaPlan.DOJOS do
			local dojo = PlazaPlan.dojo(index)
			local pair = 0
			for _, part in parts() do
				local at = part.CFrame.Position
				if
					part.Name == "StoneLantern"
					and math.abs(at.X - dojo.along) <= 16
					and at.Z * dojo.side > PlazaPlan.HALF_WIDTH - 12
					and at.Z * dojo.side < PlazaPlan.HALF_WIDTH
				then
					pair += 1
				end
			end
			T.eq(pair, 2, `stone lanterns before dojo {index}`)
		end
	end,
}
