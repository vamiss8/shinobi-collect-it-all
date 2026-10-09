--!strict
-- The throw and the run home.
--
-- Standing on the shared throwing strip starts the power bar. On a press the server grades it,
-- rolls the drop and freezes the thrower while their client stages the reveal: the kunai's
-- flight, a roulette of shinobi where it landed, and a look at the zone's enemy. The server then
-- teleports the player to the landing spot and has the enemy chase them. Reaching the street
-- keeps the shinobi; getting caught loses it.
--
-- The timeline (flight, roll, hold, intro) is fixed here and sent to the client, so both sides
-- follow the same schedule, the client simply one network hop later.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Chase = require(ReplicatedStorage.Shared.Logic.Chase)
local Data = require("../Data")
local Economy = require(ReplicatedStorage.Shared.Logic.Economy)
local Events = require("./Events")
local Figure = require(ReplicatedStorage.Shared.View.Figure)
local Hub = require("../World/Hub")
local Index = require(ReplicatedStorage.Shared.Logic.Index)
local Inventory = require("./Inventory")
local Kick = require(ReplicatedStorage.Shared.Logic.Kick)
local Net = require(ReplicatedStorage.Shared.Net)
local Plots = require("../World/Plots")
local Remotes = require("../Remotes")
local Roll = require(ReplicatedStorage.Shared.Logic.Roll)
local Session = require("../Session")
local State = require("./State")
local Stats = require("./Stats")
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)

local Kicking = {}

-- How often players are checked against the throwing strip, seconds.
local STRIP_CHECK = 0.1
-- A throw never lands closer than this beyond the strip, studs.
local MIN_LANDING = 8
-- How far short of the lane's end a kunai lands at the farthest, studs: room for the roulette
-- that stands past it, and for the shinobi it stops on, which leaps to more than its size.
local END_ROOM = 16

type Aim = { startedAt: number }

type Run = {
	character: Model,
	root: BasePart,
	humanoid: Humanoid,
	unit: Economy.Unit,
	zone: Catalog.Zone,
	carried: Model,
	enemy: Model,
	enemyAt: Vector3,
	enemySpeed: number, -- studs per second on the lane; set by how deep the kunai fell
	releaseAt: number, -- os.clock() time the player may start running
	released: boolean,
	chaseFrom: number, -- os.clock() time the enemy starts moving
}

local rng = Random.new()
local aims: { [Player]: Aim } = {} -- power bar running
local flights: { [Player]: {} } = {} -- between the press and the teleport
local runs: { [Player]: Run } = {} -- from the teleport until home or caught

local function roll(): number
	return rng:NextNumber()
end

local function bodyOf(player: Player): (Model?, BasePart?, Humanoid?)
	local character = player.Character
	if not character then
		return nil, nil, nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if root and root:IsA("BasePart") and humanoid and humanoid.Health > 0 then
		return character, root, humanoid
	end
	return nil, nil, nil
end

-- Stops the player from walking during the reveal, or gives them their run speed back: on the
-- lane, the speed everyone runs at there.
local function setFrozen(player: Player, humanoid: Humanoid, frozen: boolean, onLane: boolean?)
	local data = Data.get(player)
	local speed = if frozen or not data
		then 0
		else Economy.walkSpeed(Economy.runLevel(data.speedLevel, data.runAt))
	humanoid.WalkSpeed = if onLane then Chase.onLane(speed) else speed
end

local function cancelAim(player: Player)
	if aims[player] then
		aims[player] = nil
		Remotes.KickResult:FireClient(player, nil)
	end
end

-- Ends the run. Escaping adds the unit to the inventory; being caught sends the player back to
-- their dojo with a small consolation.
local function endRun(player: Player, escaped: boolean)
	local run = runs[player]
	if not run then
		return
	end
	runs[player] = nil
	run.enemy:Destroy()
	run.carried:Destroy()

	local data = Data.get(player)
	if not data then
		return
	end
	local alive = run.character.Parent ~= nil and run.humanoid.Health > 0
	if alive then
		setFrozen(player, run.humanoid, false)
		Hub.setRunner(run.character, false)
	end

	local unit = run.unit
	local isNew, reward = false, 0
	if escaped then
		-- The player arrives carrying their catch, ready to put it on a pad.
		Inventory.hold(player, Inventory.add(player, data, unit))
		isNew = Index.record(data.found, unit.character, unit.mutation)
		if isNew then
			reward = Index.discoveryReward(unit.character, unit.mutation)
			State.pushIndex(player)
		end
	else
		reward = math.floor(Economy.unitIncome(unit) * Tuning.Chase.consolationSeconds)
		local plot = Plots.of(player)
		if alive and plot then
			run.character:PivotTo(plot.spawn)
		end
	end
	data.ryo += reward

	local payload: Net.RunEnd = {
		escaped = escaped,
		character = unit.character,
		mutation = unit.mutation,
		zone = run.zone.id,
		isNew = isNew,
		reward = reward,
	}
	Remotes.RunEnd:FireClient(player, payload)
	State.push(player)
end

-- Teleports the player to where the kunai landed, facing home, with the rolled unit over their
-- head and the zone's enemy behind them. They stay frozen while the client shows the enemy.
local function startRun(player: Player, drop: Roll.Drop, landing: Vector3, enemyAt: Vector3)
	local character, root, humanoid = bodyOf(player)
	local zone = Catalog.zoneById[drop.zone]
	if not Data.get(player) or not character or not root or not humanoid or not zone then
		if humanoid then
			setFrozen(player, humanoid, false)
		end
		return
	end

	humanoid:UnequipTools()
	humanoid.Sit = false
	Inventory.hold(player, nil)
	-- The zones are walled off; a runner may pass the gate behind the strip on the way home.
	Hub.setRunner(character, true)
	local home = landing - Vector3.new(10, 0, 0)
	character:PivotTo(CFrame.lookAt(landing + Vector3.new(0, 3, 0), home + Vector3.new(0, 3, 0)))

	local unit: Economy.Unit = { character = drop.character, mutation = drop.mutation, level = 1 }
	local carried = Figure.build(unit)
	Figure.attach(carried, character)

	local enemy = Figure.enemy(zone)
	enemy:PivotTo(CFrame.lookAt(enemyAt, landing))
	enemy.Parent = Workspace

	local releaseAt = os.clock() + Tuning.Chase.introSeconds
	runs[player] = {
		character = character,
		root = root,
		humanoid = humanoid,
		unit = unit,
		zone = zone,
		carried = carried,
		enemy = enemy,
		enemyAt = enemyAt,
		enemySpeed = Chase.onLane(Chase.enemySpeed(zone, Hub.toLocal(landing).X)),
		releaseAt = releaseAt,
		released = false,
		chaseFrom = releaseAt + Tuning.Chase.enemyDelay,
	}

	local payload: Net.RunStart = {
		character = drop.character,
		mutation = drop.mutation,
		zone = drop.zone,
	}
	Remotes.RunStart:FireClient(player, payload)
end

-- Releases frozen runners, moves every chasing enemy and decides who escaped and who got caught.
local function stepRuns(dt: number)
	local now = os.clock()
	for player, run in runs do
		if player.Character ~= run.character or run.humanoid.Health <= 0 or not run.root.Parent then
			endRun(player, false)
		elseif not run.released then
			if now >= run.releaseAt then
				run.released = true
				setFrozen(player, run.humanoid, false, true)
			end
		elseif Hub.toLocal(run.root.Position).X <= 0 then
			endRun(player, true)
		elseif now >= run.chaseFrom then
			local position = run.root.Position
			local target = Vector3.new(position.X, run.enemyAt.Y, position.Z)
			local offset = target - run.enemyAt
			local step = run.enemySpeed * dt
			if offset.Magnitude <= math.max(step, Tuning.Chase.catchRadius) then
				endRun(player, false)
			else
				run.enemyAt += offset.Unit * step
				run.enemy:PivotTo(CFrame.lookAt(run.enemyAt, target))
			end
		end
	end
end

-- Starts the power bar for players standing on the strip and cancels it when they step off.
local function checkStrip()
	for _, player in Players:GetPlayers() do
		local _, root = bodyOf(player)
		local inside = root ~= nil and Hub.onStrip(root.Position)
		if aims[player] then
			if not inside then
				cancelAim(player)
			end
		elseif inside and Data.get(player) and not flights[player] and not runs[player] then
			aims[player] = { startedAt = os.clock() }
			Remotes.KickStart:FireClient(player, Tuning.Kick.barPeriod)
		end
	end
end

local function press(player: Player, claimed: unknown)
	local aim = aims[player]
	local data = Data.get(player)
	local _, root, humanoid = bodyOf(player)
	if not aim or not data or not root or not humanoid then
		return
	end
	aims[player] = nil

	-- A malformed claim is treated as one that is far off, which falls back to the server's clock.
	local claimedElapsed = if typeof(claimed) == "number" then claimed else math.huge
	local serverElapsed = os.clock() - aim.startedAt
	local elapsed = Kick.reconcileElapsed(claimedElapsed, serverElapsed, player:GetNetworkPing())
	-- A player may throw with less Chakra than they have, to reach a zone they have outgrown.
	local chakra = data.chakra
	local chosen = Session.of(player).throwChakra
	if chosen > 0 then
		chakra = math.min(chakra, chosen)
	end
	local result = Kick.resolve(chakra, Kick.barPosition(elapsed), data.streak)
	local distance = result.distance

	data.streak = result.streak
	data.spins += 1

	local multipliers = Stats.multipliers(data)
	local spinLuck = Roll.spinLuck(data.spins)
	-- A catch made while an event runs has a chance of the event's own mutation.
	local drop = Roll.drop(
		distance,
		multipliers.luck * spinLuck,
		multipliers.mutationLuck,
		Events.current(),
		roll
	)

	-- The kunai flies straight down the lane from where the thrower stands.
	local chase = Tuning.Chase
	local margin = Hub.LANE_WIDTH / 2 - 4
	local side = math.clamp(Hub.toLocal(root.Position).Z, -margin, margin)
	-- It comes down short of the lane's very end, which the strongest throws reach to within
	-- half a stud: the roulette stands a few steps past the kunai, and stood in the wall.
	local along = math.clamp(
		distance,
		Tuning.Kick.stripDepth + MIN_LANDING,
		Tuning.Kick.trackLength - END_ROOM
	)
	local landing = Hub.at(along, 0, side)
	local enemyAt = landing + Vector3.new(chase.enemyGap, 0, 0)
	local duration, height = Kick.flight(distance)

	local token = {}
	flights[player] = token
	setFrozen(player, humanoid, true)

	local flight: Net.Flight = {
		thrower = player.UserId,
		kunai = data.kunai,
		from = root.Position + Vector3.new(0, 2, 0),
		to = landing + Vector3.new(0, 0.5, 0),
		duration = duration,
		height = height,
		linger = chase.rollSeconds + chase.holdSeconds,
	}
	Remotes.Flight:FireAllClients(flight)

	local reveal: Net.Reveal = {
		character = drop.character,
		mutation = drop.mutation,
		zone = drop.zone,
		at = landing,
		enemyAt = enemyAt,
		flight = duration,
		roll = chase.rollSeconds,
		hold = chase.holdSeconds,
		intro = chase.introSeconds,
	}
	Remotes.Reveal:FireClient(player, reveal)

	local payload: Net.KickResult = {
		grade = result.grade,
		power = result.share,
		distance = distance,
		sage = result.sage,
		zone = drop.zone,
		luck = spinLuck,
	}
	Remotes.KickResult:FireClient(player, payload)
	State.push(player)

	-- The token goes stale if the player leaves before the reveal is over.
	task.delay(duration + chase.rollSeconds + chase.holdSeconds, function()
		if flights[player] == token then
			flights[player] = nil
			startRun(player, drop, landing, enemyAt)
		end
	end)
end

-- The client picks how much Chakra to throw with; 0 means all of it.
local function setThrowChakra(player: Player, amount: unknown)
	-- `amount == amount` is false only for NaN.
	if Data.get(player) and typeof(amount) == "number" and amount == amount and amount >= 0 then
		Session.of(player).throwChakra = math.floor(amount)
		State.push(player)
	end
end

-- Whether the player is in the middle of a throw: at the power bar, watching the kunai and the
-- reveal, or running home. Training is off for all of it (see Services/Training).
function Kicking.throwing(player: Player): boolean
	return aims[player] ~= nil or flights[player] ~= nil or runs[player] ~= nil
end

-- Whether the player is away on a throw: watching the kunai and the reveal, or running home
-- with the catch. Their hands are not free for another shinobi until they are back.
function Kicking.away(player: Player): boolean
	return flights[player] ~= nil or runs[player] ~= nil
end

function Kicking.start()
	Inventory.tieHandsWhile(Kicking.away)
	Remotes.KickPress.OnServerEvent:Connect(press)
	Remotes.ThrowChakra.OnServerEvent:Connect(setThrowChakra)

	local sinceCheck = 0
	RunService.Heartbeat:Connect(function(dt)
		stepRuns(dt)
		sinceCheck += dt
		if sinceCheck >= STRIP_CHECK then
			sinceCheck = 0
			checkStrip()
		end
	end)

	Data.onLeaving(function(player)
		aims[player] = nil
		flights[player] = nil
		local run = runs[player]
		if run then
			runs[player] = nil
			run.enemy:Destroy()
			run.carried:Destroy()
		end
	end)
end

return Kicking
