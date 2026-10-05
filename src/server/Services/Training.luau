--!strict
-- Training. Two tools sit at the front of the hotbar:
--   Meditate (slot 1) sits the player down and earns Chakra on a timer, so it works AFK.
--   Chakra Control (slot 2) is the active way: a ring closes in on a target and the player
--     presses as they meet. The closer the press, the more it pays.
-- Both are done standing still. Equipping a tool only asks to train: the training starts once
-- the character has come to rest, and walking, running or jumping off puts the tool away.
-- Neither works in the middle of a throw, from the power bar to the end of the run home.
-- While a training runs, bonus bubbles pop up now and then; popping one multiplies training
-- gains for a short while.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
-- How often players holding a training tool are checked, seconds.
local REST_CHECK = 0.2
-- Still checks in a row before a training starts. One is not enough: at the top of a jump a
-- character is motionless for an instant, and a sit ordered in mid-air does not take.
local STILL_CHECKS = 2
-- Right after a training starts the character still settles; it is not checked for walking
-- off yet.
local SETTLE_SECONDS = 0.6

-- Someone holding a training tool: waiting to come to rest, then training with it.
type Trainee = { humanoid: Humanoid, mode: string, still: number, startedAt: number? }

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

-- How fast the player's character is moving, or nil if they have none.
local function speedOf(player: Player): number?
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if root and root:IsA("BasePart") then root.AssemblyLinearVelocity.Magnitude else nil
end

local function isStill(player: Player): boolean
	local speed = speedOf(player)
	return speed ~= nil and speed < STILL_SPEED
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
		humanoid.Sit = false
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
		local speed = speedOf(player)
		if not speed then
			continue
		end
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
				if trainee.mode == MEDITATE then
					trainee.humanoid.Sit = true
				end
				setMode(player, trainee.mode)
			end
		elseif now - trainee.startedAt > SETTLE_SECONDS then
			-- A meditating player gets up by jumping, which also ends the sit.
			local gotUp = trainee.mode == MEDITATE and not trainee.humanoid.Sit
			if gotUp or speed > MOVING_SPEED then
				-- Fires the tool's Unequipped, which clears the trainee and ends the training.
				trainee.humanoid:UnequipTools()
			end
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
