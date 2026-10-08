--!strict
-- Particle emitters described as plain data, so that an effect is a short list of layers and
-- not a page of properties. Used for the aura of a mutation (View/Aura), for what streams off
-- a flying kunai (View/KunaiEffects) and for what a speed stage shows on its runner
-- (server Services/SpeedLook).
--
-- Only textures that ship with Roblox are used, so there is nothing to upload.

local Particles = {}

Particles.SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
Particles.FIRE = "rbxasset://textures/particles/fire_main.dds"
Particles.SMOKE = "rbxasset://textures/particles/smoke_main.dds"

-- One emitter. An effect is one or more of them layered.
export type Layer = {
	texture: string,
	rate: number, -- particles a second
	life: { number }, -- seconds, shortest and longest
	speed: { number }, -- studs a second, slowest and fastest
	down: boolean?, -- particles set off downwards instead of upwards
	back: boolean?, -- or out of the back of the part, for something that flies nose first
	locked: boolean?, -- particles travel with the part instead of being left where they appeared
	spread: number, -- degrees off that direction; 180 is every way
	-- Where in its part a particle appears, when not anywhere in the part's box: within a ball
	-- as wide as the part, or on that ball's skin. From there it sets off away from the ball's
	-- middle, or towards it when `inward`.
	from: ("ball" | "shell")?,
	inward: boolean?,
	-- Studs across, when a particle appears and when it is gone; given three, when it appears,
	-- half way and when it is gone.
	size: { number },
	streak: number?, -- drawn stretched along its flight, this much (1 to 3): a spark is a dart
	flat: boolean?, -- drawn lying across its flight: one that rises is a disc seen from above
	drag: number?, -- how fast it slows down; not at all when left out
	lift: number, -- pull upwards, studs a second squared; negative sinks
	spin: number, -- degrees a second, either way
	-- 0 is paint, 1 is light. Light is added to what is behind it: it shows in the dark and
	-- against the dark and is all but lost against a sunlit pavement.
	glow: number,
	bright: number?, -- how many times brighter than its color it is drawn; 1 when left out
	lit: boolean?, -- takes the light of the place, as dust does, instead of showing its own color
	fade: number, -- how see-through a particle is at its clearest, 0..1
	color: string?, -- hex; the color of whatever wears the effect when left out
}

-- Builds the emitter of one layer; `own` is the color used when the layer names none.
function Particles.emitter(layer: Layer, own: Color3): ParticleEmitter
	local color = if layer.color then Color3.fromHex(layer.color) else own
	local clear = layer.fade
	local particles = Instance.new("ParticleEmitter")
	particles.Texture = layer.texture
	particles.Rate = layer.rate
	particles.Lifetime = NumberRange.new(layer.life[1], layer.life[2])
	particles.Speed = NumberRange.new(layer.speed[1], layer.speed[2])
	particles.EmissionDirection = if layer.back
		then Enum.NormalId.Back
		elseif layer.down then Enum.NormalId.Bottom
		else Enum.NormalId.Top
	particles.LockedToPart = layer.locked == true
	particles.SpreadAngle = Vector2.new(layer.spread, layer.spread)
	particles.Acceleration = Vector3.new(0, layer.lift, 0)
	if layer.streak then
		-- A dart points the way it flies: it is neither turned nor spun.
		particles.Orientation = Enum.ParticleOrientation.VelocityParallel
		particles.Squash = NumberSequence.new(layer.streak)
		particles.Rotation = NumberRange.new(0)
	else
		if layer.flat then
			particles.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
		end
		particles.Rotation = NumberRange.new(0, 360)
		particles.RotSpeed = NumberRange.new(-layer.spin, layer.spin)
	end
	if layer.from then
		particles.Shape = Enum.ParticleEmitterShape.Sphere
		particles.ShapeStyle = if layer.from == "shell"
			then Enum.ParticleEmitterShapeStyle.Surface
			else Enum.ParticleEmitterShapeStyle.Volume
		particles.ShapeInOut = if layer.inward
			then Enum.ParticleEmitterShapeInOut.Inward
			else Enum.ParticleEmitterShapeInOut.Outward
	end
	particles.Drag = layer.drag or 0
	local size = layer.size
	particles.Size = if #size >= 3
		then NumberSequence.new({
			NumberSequenceKeypoint.new(0, size[1]),
			NumberSequenceKeypoint.new(0.5, size[2]),
			NumberSequenceKeypoint.new(1, size[3]),
		})
		else NumberSequence.new(size[1], size[2])
	-- Each particle fades in, holds, and fades out again.
	particles.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.15, clear),
		NumberSequenceKeypoint.new(0.7, clear + (1 - clear) * 0.3),
		NumberSequenceKeypoint.new(1, 1),
	})
	particles.Color = ColorSequence.new(color, color:Lerp(Color3.new(1, 1, 1), 0.4))
	particles.LightEmission = layer.glow
	particles.LightInfluence = if layer.lit then 1 else 0
	particles.Brightness = layer.bright or 1
	return particles
end

return Particles
