--!strict
-- Where a model stands (Logic/Footing): on its feet, whatever it holds out to one side.
local Footing = require("../src/shared/Logic/Footing")
local T = require("./harness")

-- A piece from the two corners of its box: x, y and z of the lowest, then of the highest.
local function piece(box: { number }): Footing.Piece
	return {
		x = (box[1] + box[4]) / 2,
		y = (box[2] + box[5]) / 2,
		z = (box[3] + box[6]) / 2,
		halfX = (box[4] - box[1]) / 2,
		halfY = (box[5] - box[2]) / 2,
		halfZ = (box[6] - box[3]) / 2,
	}
end

local function model(boxes: { { number } }): { Footing.Piece }
	local pieces = {}
	for _, box in boxes do
		table.insert(pieces, piece(box))
	end
	return pieces
end

-- The middle of the box round all of the pieces, sideways, and the model's height.
local function boxOf(boxes: { { number } }): (number, number)
	local left, right, floor, top = math.huge, -math.huge, math.huge, -math.huge
	for _, box in boxes do
		left, right = math.min(left, box[1]), math.max(right, box[4])
		floor, top = math.min(floor, box[2]), math.max(top, box[5])
	end
	return (left + right) / 2, top - floor
end

-- Hidan as his file has him (hidan.gltf, the bounds of its twenty-two meshes): he was made
-- standing on the file's origin, and holds a scythe of three blades out past his right hand.
local HIDAN = {
	{ -1.25, 4.04, -0.79, 1.25, 6.11, 1.01 }, -- head
	{ -0.29, 3.84, -0.13, 0.29, 4.36, 0.40 }, -- neck
	{ -0.77, 0.45, -0.21, -0.06, 2.38, 0.55 }, -- left leg
	{ -0.76, 0.00, -0.48, -0.11, 0.46, 0.48 }, -- left sandal
	{ 0.06, 0.45, -0.26, 0.99, 2.38, 0.58 }, -- right leg
	{ 0.11, 0.00, -0.48, 0.76, 0.46, 0.48 }, -- right sandal
	{ -1.64, 2.23, -0.28, -0.58, 3.89, 0.61 }, -- left arm
	{ -1.61, 2.04, -0.11, -1.05, 2.52, 0.37 }, -- left hand
	{ 0.58, 2.23, -0.28, 1.64, 3.89, 0.61 }, -- right arm
	{ 1.05, 2.04, -0.11, 1.61, 2.52, 0.37 }, -- right hand
	{ -0.83, 2.39, -0.34, 0.83, 3.91, 0.61 }, -- torso
	{ -1.04, 1.12, -0.46, 1.04, 3.91, 0.73 }, -- cloak
	{ -0.56, 1.11, -0.49, 0.56, 3.92, -0.18 }, -- cloak lining
	{ -1.53, 1.25, -0.47, 1.53, 3.65, 0.75 }, -- cloud emblems
	{ -0.82, 2.36, -0.36, 0.82, 2.65, 0.63 }, -- waist band
	{ -0.40, 4.01, -0.26, 0.40, 4.28, 0.46 }, -- neck protector
	{ -0.39, 2.87, -0.44, 0.39, 4.09, -0.18 }, -- necklace
	{ -1.15, 4.54, -0.71, 1.15, 6.39, 1.24 }, -- hair
	{ 1.45, 0.11, 0.20, 1.64, 5.99, 0.41 }, -- the scythe's shaft, its foot all but on the ground
	{ 1.54, 3.26, 0.25, 4.26, 5.80, 0.36 }, -- its three blades
	{ 1.54, 3.25, 0.22, 4.27, 5.82, 0.26 }, -- their edges
	{ 1.54, 0.32, 0.28, 2.00, 1.68, 0.69 }, -- its cord
}

return {
	["Hidan stands on his feet, not in the middle of himself and his scythe"] = function()
		local middle, height = boxOf(HIDAN)
		T.ok(middle > height * 0.2, "the scythe does not push his box off: the test is not a test")
		local x, z = Footing.of(model(HIDAN))
		T.ok(x ~= nil and z ~= nil, "he stands nowhere")
		T.ok(math.abs(x :: number) < height * 0.01, `he stands {x} off his feet, sideways`)
		T.ok(math.abs(z :: number) < height * 0.01, `he stands {z} off his feet, front to back`)
	end,

	["a figure that holds nothing stands in its own middle"] = function()
		local x, z = Footing.of(model({
			{ -0.8, 0, -0.5, -0.1, 0.5, 0.5 },
			{ 0.1, 0, -0.5, 0.8, 0.5, 0.5 },
			{ -1, 0.5, -0.6, 1, 3, 0.6 },
			{ -1.3, 3, -1, 1.3, 5, 1 },
		}))
		T.near(x :: number, 0, 1e-9)
		T.near(z :: number, 0, 1e-9)
	end,

	["what is carried on the back does not move the feet"] = function()
		-- A gourd behind the shoulders: the box's middle goes back with it, the feet do not.
		local x, z = Footing.of(model({
			{ -0.8, 0, -0.5, -0.1, 0.5, 0.5 },
			{ 0.1, 0, -0.5, 0.8, 0.5, 0.5 },
			{ -1, 0.5, -0.6, 1, 5, 0.6 },
			{ -0.9, 1.5, 0.6, 0.9, 4.5, 2.4 },
		}))
		T.near(x :: number, 0, 1e-9)
		T.near(z :: number, 0, 1e-9)
	end,

	["it does not matter where the model is, or how large"] = function()
		local moved = {}
		for _, box in HIDAN do
			table.insert(moved, {
				box[1] * 3 + 40,
				box[2] * 3 - 7,
				box[3] * 3 + 12,
				box[4] * 3 + 40,
				box[5] * 3 - 7,
				box[6] * 3 + 12,
			})
		end
		local x, z = Footing.of(model(HIDAN))
		local farX, farZ = Footing.of(model(moved))
		T.near(farX :: number, (x :: number) * 3 + 40, 1e-6)
		T.near(farZ :: number, (z :: number) * 3 + 12, 1e-6)
	end,

	["four feet share the weight"] = function()
		local x, z = Footing.of(model({
			{ -1, 0, -2, -0.5, 0.4, -1.5 },
			{ 0.5, 0, -2, 1, 0.4, -1.5 },
			{ -1, 0, 1.5, -0.5, 0.4, 2 },
			{ 0.5, 0, 1.5, 1, 0.4, 2 },
			{ -1.2, 0.4, -2.2, 1.2, 1.4, 2.6 },
		}))
		T.near(x :: number, 0, 1e-9)
		T.near(z :: number, 0, 1e-9)
	end,

	["a model of nothing, or of what covers no ground, stands nowhere"] = function()
		T.eq(Footing.of({}), nil)
		T.eq(Footing.of(model({ { 0, 0, 0, 0, 5, 0 } })), nil)
	end,
}
