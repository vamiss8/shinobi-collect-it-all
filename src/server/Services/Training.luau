--!strict
-- Training. Two tools sit at the front of the hotbar:
--   Meditate (slot 1) lifts the player into the air where they stand and earns Chakra on a
--     timer, so it works AFK.
--   Chakra Control (slot 2) is the active way: a ring closes in on a target and the player
--     presses as they meet. The closer the press, the more it pays.
-- Both are done standing still. Equipping a tool only asks to train: the training starts once
-- the character has come to rest, and walking, running or jumping off puts the tool away.
-- Neither works in the middle of a throw, from the power bar to the end of the run home.
-- While a training runs, bonus bubbles pop up now and then; popping one multiplies training
-- gains for a short while.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Animations = require(ReplicatedStorage.Shared.Config.Animations)
local Data = require("../Data")
local Economy = require(ReplicatedStorage.Shared.Logic.Economy)
local Focus = require(ReplicatedStorage.Shared.Logic.Focus)
local Kick = require(ReplicatedStorage.Shared.Logic.Kick)
local Kicking = require("./Kicking")
local Loadout = require("./Loadout")
local Net = require(ReplicatedStorage.Shared.Net)
local Remotes = require("../Remotes")
local Roll = require(ReplicatedStorage.Shared.Logic.Roll)
local Session = require("../Session")
local State = require("./State")
local Stats = require("./Stats")
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)

local Training = {}

local MEDITATE = "meditate"
local FOCUS = "focus"

-- A character drifting slower than this counts as standing still, studs per second.
local STILL_SPEED = 1
-- A training character moving faster than this has walked off, studs per second.
local MOVING_SPEED = 3
-- A character on the ring that is this far from where it started has moved, studs along the
-- ground. Speed alone misses a quick tap on a movement key: the tap is over before the next
-- check, but the step it took is still there.
local STEP = 0.5
-- How often players holding a training tool are checked, seconds.
local REST_CHECK = 0.1
-- Still checks in a row before a training starts. One is not enough: at the top of a jump a
-- character is motionless for an instant.
local STILL_CHECKS = 4
-- Right after a meditation begins the character rises to its height and settles there; it is
-- not checked for having moved off yet.
local SETTLE_SECONDS = 1.2

-- Someone holding a training tool: waiting to come to rest, then training with it from the
-- spot they stopped on.
type Trainee = {
	humanoid: Humanoid,
	mode: string,
	still: number,
	startedAt: number?,
	spot: Vector3?,
}

type Bubble = { id: number, multiplier: number, expires: number }
-- A chakra-control ring in progress: when the server started it, and its round.
type Ring = { startedAt: number, round: Focus.Round }

local rng = Random.new()
local bubbles: { [Player]: Bubble } = {}
local nextBubbleAt: { [Player]: number } = {}
local bubbleCount = 0
local rings: { [Player]: Ring } = {}
local trainees: { [Player]: Trainee } = {}

-- Chakra for one rep. A meditation tick pays a share of a rep, a ring press several at once.
local function repGain(player: Player, data: Data.Data): number
	return Economy.chakraPerRep(data.kunai) * Stats.multipliers(data).chakra * Session.boost(player)
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if root and root:IsA("BasePart") then root else nil
end

-- How fast the player's character is moving, or nil if they have none.
local function speedOf(player: Player): number?
	local root = rootOf(player)
	return if root then root.AssemblyLinearVelocity.Magnitude else nil
end

local function isStill(player: Player): boolean
	local speed = speedOf(player)
	return speed ~= nil and speed < STILL_SPEED
end

-- How far along the ground the character is from `spot`.
local function strayed(root: BasePart, spot: Vector3): number
	local offset = root.Position - spot
	return Vector3.new(offset.X, 0, offset.Z).Magnitude
end

-- Starts the first ring for the player: the server notes the time, the client draws it.
local function startRing(player: Player)
	local round = Focus.round(rng:NextNumber(), rng:NextNumber())
	rings[player] = { startedAt = os.clock(), round = round }
	Remotes.Ring:FireClient(player, round)
end

local function setMode(player: Player, mode: string?)
	-- Tools also fire Unequipped while a leaving player's character is torn down.
	if not Data.get(player) then
		return
	end
	Session.of(player).training = mode
	if mode == FOCUS then
		startRing(player)
	else
		rings[player] = nil
	end
	if not mode then
		-- Training stopped: a bubble still on offer is withdrawn, and the client takes it
		-- off the screen when it sees the new state.
		bubbles[player] = nil
		nextBubbleAt[player] = nil
	end
	State.push(player)
end

-- The client reports when the player pressed, as seconds it had watched the ring. The timing
-- is checked against the server's own clock the same way a throw is (see Kick.reconcileElapsed).
-- A ring exists only while the player stands still with the tool out (see watchTrainees), so a
-- press sent on the run finds none.
local function ringPress(player: Player, claimed: unknown)
	local data = Data.get(player)
	local ring = rings[player]
	if not data or not ring then
		return
	end
	-- Every press is graded and answered, even one that comes right after the ring started
	-- (a double click): the client holds its ring still until it hears back.
	local serverElapsed = os.clock() - ring.startedAt
	local claimedElapsed = if typeof(claimed) == "number" then claimed else math.huge
	local elapsed = Kick.reconcileElapsed(claimedElapsed, serverElapsed, player:GetNetworkPing())
	local hit = Focus.grade(Focus.phase(elapsed, ring.round.period), ring.round.target)
	local gain = repGain(player, data) * hit.reps
	data.chakra += gain

	-- The next ring is a fresh draw and starts now; the client starts drawing it when the
	-- result arrives.
	local nextRound = Focus.round(rng:NextNumber(), rng:NextNumber())
	local result: Net.RingResult = { grade = hit.grade, gain = gain, next = nextRound }
	Remotes.RingResult:FireClient(player, result)
	ring.round = nextRound
	ring.startedAt = os.clock()
	State.push(player)
end

-- A MEDITATING CHARACTER HOVERS, AND IS NOT SEATED (owner, 2026-10-12: "the rise is not at
-- once, and not enough: the legs touch the ground"; then, of two attempts to raise it: "are
-- you sure you made the rise? It feels as if it is not applied, and was not before either").
-- It was not, and could not be while the player was seated. A seated Humanoid holds nothing
-- up: the character lies on its own body, with its root wherever that leaves it. So raising
-- the body over its root (the animation's own stud, then a joint moved by the server, by 1.3
-- studs and by 4) only let the whole character sink until the body lay on the ground again,
-- the root now under it. What does hold a character over the ground is a standing Humanoid's
-- HipHeight. So meditation no longer sits the player down: they stand, the Humanoid is told
-- to hold them higher, and the lotus is the animation's alone. The root rises too, and with
-- it whatever goes by the root: the rank's orbs, a runner's effects, a carried shinobi, the
-- camera. The server sets it and it is every client's to see.
--
-- The body is raised over as long as the animation takes to fold the legs
-- (Animations.MEDITATE_RISE), eased at both ends as the animation is: raised in one step it
-- jumped two studs and then floated the animation's last stud (owner, 2026-10-15: "it rises
-- in pieces"). It comes down at once, since the player is walking off.
local hipRest: { [Humanoid]: number } = setmetatable({}, { __mode = "k" }) :: any
local hipRise: { [Humanoid]: Tween } = setmetatable({}, { __mode = "k" }) :: any

local function hover(humanoid: Humanoid, up: boolean)
	local rest = hipRest[humanoid]
	local rising = hipRise[humanoid]
	if rising then
		hipRise[humanoid] = nil
		rising:Cancel()
	end
	if up then
		local from = rest or humanoid.HipHeight
		hipRest[humanoid] = from
		local rise = TweenService:Create(
			humanoid,
			TweenInfo.new(
				Animations.MEDITATE_RISE,
				Enum.EasingStyle.Sine,
				Enum.EasingDirection.InOut
			),
			{ HipHeight = from + Tuning.Training.meditateLift }
		)
		hipRise[humanoid] = rise
		rise:Play()
	elseif rest then
		hipRest[humanoid] = nil
		humanoid.HipHeight = rest
	end
end

local function makeTool(name: string, tip: string): Tool
	local tool = Instance.new("Tool")
	tool.Name = name
	tool.ToolTip = tip
	tool.RequiresHandle = false
	tool.CanBeDropped = false
	return tool
end

-- The tool for `mode` was put away. When one tool is swapped for the other, the new one may
-- already have registered, so only this tool's own traces are cleared.
local function putAway(player: Player, mode: string)
	local trainee = trainees[player]
	if trainee and trainee.mode == mode then
		trainees[player] = nil
	end
	if Data.get(player) and Session.of(player).training == mode then
		setMode(player, nil)
	end
end

local function giveTools(player: Player, _character: Model, backpack: Instance, humanoid: Humanoid)
	-- Equipping a tool only asks to train; watchTrainees starts the training once the player
	-- is at rest.
	local function takeOut(mode: string)
		if Data.get(player) then
			trainees[player] = { humanoid = humanoid, mode = mode, still = 0 }
		end
	end

	local meditate = makeTool("Meditate", "Stand still to gather Chakra")
	meditate.Equipped:Connect(function()
		takeOut(MEDITATE)
	end)
	meditate.Unequipped:Connect(function()
		hover(humanoid, false)
		putAway(player, MEDITATE)
	end)
	meditate.Parent = backpack

	local focus = makeTool("Chakra Control", "Stand still and press as the rings meet")
	focus.Equipped:Connect(function()
		takeOut(FOCUS)
	end)
	focus.Unequipped:Connect(function()
		putAway(player, FOCUS)
	end)
	focus.Parent = backpack
end

-- Starts the training of players who hold a tool once they have come to rest, and puts the
-- tool away for those who moved off again: no gathering Chakra on the run.
local function watchTrainees()
	local now = os.clock()
	for player, trainee in trainees do
		local root = rootOf(player)
		if not root then
			continue
		end
		local speed = root.AssemblyLinearVelocity.Magnitude
		-- Not in the middle of a throw. At the power bar a click belongs to the throw, and
		-- through the flight and the reveal the player stands still only because they are
		-- held in place.
		if Kicking.throwing(player) then
			trainee.humanoid:UnequipTools()
			continue
		end
		if not trainee.startedAt then
			trainee.still = if speed < STILL_SPEED then trainee.still + 1 else 0
			if trainee.still >= STILL_CHECKS then
				trainee.startedAt = now
				trainee.spot = root.Position
				if trainee.mode == MEDITATE then
					hover(trainee.humanoid, true)
				end
				setMode(player, trainee.mode)
			end
		elseif trainee.mode == MEDITATE then
			-- A meditating player hovers where they stopped, and comes down by walking off
			-- or jumping.
			local settled = now - trainee.startedAt > SETTLE_SECONDS
			if settled and speed > MOVING_SPEED then
				-- Fires the tool's Unequipped, which clears the trainee and ends the training.
				trainee.humanoid:UnequipTools()
			end
		elseif speed > MOVING_SPEED or strayed(root, trainee.spot or root.Position) > STEP then
			-- On the ring any movement at all ends the training: a step off the spot, however
			-- short, or a jump.
			trainee.humanoid:UnequipTools()
		end
	end
end

-- Offers a bubble when one is due. Bubbles only come while a training tool is equipped.
local function tickBubble(player: Player, now: number)
	if not Session.of(player).training then
		nextBubbleAt[player] = nil
		return
	end
	local t = Tuning.Training
	local due = nextBubbleAt[player]
	if not due then
		nextBubbleAt[player] = now + rng:NextNumber(t.bubbleEveryMin, t.bubbleEveryMax)
	elseif now >= due then
		bubbleCount += 1
		local bubble: Bubble = {
			id = bubbleCount,
			multiplier = Roll.bubble(rng:NextNumber()),
			expires = now + t.bubbleSeconds + 1, -- a second of grace for latency
		}
		bubbles[player] = bubble
		nextBubbleAt[player] = now
			+ t.bubbleSeconds
			+ rng:NextNumber(t.bubbleEveryMin, t.bubbleEveryMax)

		local payload: Net.Bubble = {
			id = bubble.id,
			multiplier = bubble.multiplier,
			seconds = t.bubbleSeconds,
		}
		Remotes.Bubble:FireClient(player, payload)
	end
end

local function popBubble(player: Player, id: unknown)
	local bubble = bubbles[player]
	local now = os.clock()
	if not bubble or bubble.id ~= id or now > bubble.expires then
		return
	end
	bubbles[player] = nil

	-- A weaker bubble never replaces a stronger boost that is still running.
	local session = Session.of(player)
	if bubble.multiplier >= Session.boost(player) then
		session.boost = bubble.multiplier
		session.boostUntil = now + Tuning.Training.boostSeconds
	end
	State.push(player)
end

function Training.start()
	Remotes.BubblePop.OnServerEvent:Connect(popBubble)
	Remotes.RingPress.OnServerEvent:Connect(ringPress)
	Loadout.register(giveTools)

	Data.onLeaving(function(player)
		bubbles[player] = nil
		nextBubbleAt[player] = nil
		rings[player] = nil
		trainees[player] = nil
		Session.clear(player)
	end)

	task.spawn(function()
		while true do
			task.wait(REST_CHECK)
			watchTrainees()
		end
	end)

	task.spawn(function()
		while true do
			task.wait(Tuning.Training.meditateInterval)
			local now = os.clock()
			for _, player in Players:GetPlayers() do
				local data = Data.get(player)
				if data then
					if Session.of(player).training == MEDITATE and isStill(player) then
						data.chakra += repGain(player, data) * Tuning.Training.meditateReps
						State.push(player)
					end
					tickBubble(player, now)
				end
			end
		end
	end)
end

return Training
