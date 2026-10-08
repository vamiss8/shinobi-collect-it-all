--!strict
-- Where a model stands: the point on the ground under it that the game puts on a pad, under a
-- tag, in the middle of a portrait.
--
-- It was the middle of the model's bounding box, which is the middle of the body only for a
-- model that holds nothing out to one side. Hidan's scythe reaches 2.6 studs past his right
-- hand, and he stood a stud off his place; Zabuza's sword did the same to him, and a fan, a
-- gourd, a tail or a cloak of chakra moved others by less. So a model stands where its feet
-- are: the middle of whatever of it touches the ground, each piece weighed by how much ground
-- it covers. Two sandals outweigh the foot of a scythe's shaft fifteen times over.
--
-- Measured on the files of all sixty figures and five shopkeepers (2026-10-08): every one was
-- made standing on its file's origin, and this rule finds that point to within 0.7% of the
-- model's height sideways, where the box's middle was up to 21% off.

local Footing = {}

-- A piece of a model as a box set square with the world: its middle and half its size.
export type Piece = {
	x: number,
	y: number,
	z: number,
	halfX: number,
	halfY: number,
	halfZ: number,
}

-- A piece stands on the ground when its underside is this near the model's lowest point, as a
-- share of the model's height.
Footing.NEAR = 0.03

-- Where on the ground the model made of `pieces` stands: x and z. Nil when nothing of it covers
-- any ground to speak of, and whoever asks falls back on the middle of the box.
function Footing.of(pieces: { Piece }): (number?, number?)
	local floor, top = math.huge, -math.huge
	for _, piece in pieces do
		floor = math.min(floor, piece.y - piece.halfY)
		top = math.max(top, piece.y + piece.halfY)
	end
	local near = (top - floor) * Footing.NEAR

	local weight, x, z = 0, 0, 0
	for _, piece in pieces do
		if piece.y - piece.halfY - floor <= near then
			local covers = 4 * piece.halfX * piece.halfZ
			weight += covers
			x += covers * piece.x
			z += covers * piece.z
		end
	end
	if weight <= 0 then
		return nil, nil
	end
	return x / weight, z / weight
end

return Footing
