--!strict
-- Brings a zone's enemy to life during a run (Services/Kicking): it stands and breathes while
-- the camera shows it, runs while it chases, and lunges when it catches the player.
--
-- With animations of its own (Config/Animations) and a rigged model they are played. Without,
-- its whole body is moved by code (Logic/EnemyMotion): every enemy has a motion of its own, a
-- runner's bounce, a snake's winding, a giant's heavy waddle. Kicking says where the enemy
-- stands and whether it moves; this module decides how it looks doing it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Animations = require(ReplicatedStorage.Shared.Config.Animations)
local EnemyMotion = require(ReplicatedStorage.Shared.Logic.EnemyMotion)
local Figure = require(ReplicatedStorage.Shared.View.Figure)
local Moves = require(ReplicatedStorage.Shared.View.Moves)

local EnemyMoves = {}

export type Mover = {
	-- Stands the enemy at `base` (its feet, facing where it heads) for this frame. `moving`
	-- says whether it chases or stands.
	step: (self: Mover, dt: number, base: CFrame, moving: boolean) -> (),
	-- The catch: lunges, then the enemy is gone. Takes the place of destroying it.
	finish: (self: Mover) -> (),
	-- Gone at once, as on an escape.
	destroy: (self: Mover) -> (),
}

-- Turns a pose into an offset from the feet.
local function offset(pose: EnemyMotion.Pose): CFrame
	-- A body's front is -Z: leaning forward tips its top that way.
	return CFrame.new(pose.side, pose.lift, -pose.forward)
		* CFrame.Angles(0, pose.yaw, 0)
		* CFrame.Angles(-pose.pitch, 0, -pose.roll)
end

-- Makes the mover for an enemy built by Figure.enemy for that zone.
function EnemyMoves.new(enemy: Model, zoneId: string): Mover
	local spec = Animations.enemies[zoneId]
	local motion: EnemyMotion.Motion = if spec then spec.motion else "walker"
	local height = Figure.ENEMY_HEIGHT

	-- Real animations only for an enemy that has them; then its limbs must be free to move.
	local animator: Animator? = nil
	if spec and (Animations.asset(spec.run) or Animations.asset(spec.idle)) then
		Moves.freeLimbs(enemy)
		animator = Moves.animator(enemy)
	end

	local travelled = 0
	local clock = 0
	local base = enemy:GetPivot()
	local wasMoving: boolean? = nil
	local gone = false

	-- The animation for a state, if there is one, started when the state changes.
	local function switch(moving: boolean): boolean
		if not animator or not spec then
			return false
		end
		local id = if moving then spec.run else spec.idle
		if wasMoving ~= moving then
			Moves.stop(animator, if moving then spec.idle else spec.run)
			Moves.play(animator, id, Enum.AnimationPriority.Movement, true)
		end
		return Animations.asset(id) ~= nil
	end

	local mover = {} :: Mover

	function mover.step(_self: Mover, dt: number, at: CFrame, moving: boolean)
		if gone then
			return
		end
		clock += dt
		if moving then
			-- No faster than it can step, however fast the lane has it going.
			travelled += EnemyMotion.paced(motion, (at.Position - base.Position).Magnitude, dt)
		end
		base = at
		local animated = switch(moving)
		wasMoving = moving
		if animated then
			enemy:PivotTo(at)
		else
			enemy:PivotTo(at * offset(EnemyMotion.pose(motion, travelled, clock, moving, height)))
		end
	end

	function mover.destroy(_self: Mover)
		gone = true
		enemy:Destroy()
	end

	function mover.finish(_self: Mover)
		if gone then
			return
		end
		gone = true
		local track = if animator and spec
			then Moves.play(animator, spec.catch, Enum.AnimationPriority.Action, false, 0.05)
			else nil
		task.spawn(function()
			local since = 0
			while since < EnemyMotion.CATCH_SECONDS and enemy.Parent do
				since += RunService.Heartbeat:Wait()
				if not track then
					enemy:PivotTo(base * offset(EnemyMotion.lunge(since, height)))
				end
			end
			enemy:Destroy()
		end)
	end

	return mover
end

return EnemyMoves
