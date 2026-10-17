--!strict
-- Exercise the server's real throw lifecycle with a deterministic clock and remotes.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local Animations = require("../src/shared/Config/Animations")
local Tuning = require("../src/shared/Config/Tuning")
local T = require("./harness")

local FLIGHT = 1.25
local REVEAL = FLIGHT + Tuning.Chase.rollSeconds + Tuning.Chase.holdSeconds
-- How long the arm swings before the kunai leaves it, and a hair past a moment: the server
-- adds its times up in an order of its own, and may come out a rounding away from ours.
local WINDUP = Animations.THROW_RELEASE * Animations.THROW_STRETCH
local PAST = 1e-6

local function signal(): any
	local listeners: { (...any) -> () } = {}
	return {
		Connect = function(_, callback: (...any) -> ())
			table.insert(listeners, callback)
		end,
		Fire = function(_, ...: any)
			for _, callback in listeners do
				callback(...)
			end
		end,
	}
end

local function fixture(): any
	local now = 0
	local delayed: { any } = {}
	local events: { any } = {}
	local heartbeat = signal()
	local leaving: (any) -> () = function(_: any) end
	local position = roblox.Vector3.new(0, 6, 3)
	local root = {
		Position = position,
		CFrame = { Position = position, LookVector = roblox.Vector3.zAxis },
		Parent = {},
		IsA = function(_, class: string): boolean
			return class == "BasePart"
		end,
	}
	local humanoid = { Health = 100, WalkSpeed = 16, Sit = false, UnequipTools = function() end }
	local character = {
		Parent = {},
		FindFirstChild = function(_, name: string): any
			return if name == "HumanoidRootPart" then root else nil
		end,
		FindFirstChildOfClass = function(_, class: string): any
			return if class == "Humanoid" then humanoid else nil
		end,
		PivotTo = function(_, frame: any)
			root.Position = frame.Position
		end,
	}
	local player = {
		UserId = 17,
		Character = character,
		GetNetworkPing = function(): number
			return 0
		end,
	}
	local data = {
		chakra = 10,
		streak = 0,
		spins = 0,
		herbs = 0,
		kunai = "wood",
		speedLevel = 0,
		runAt = 0,
	}
	local remotes: { [string]: any } = {}
	for _, name in
		{
			"KickStart",
			"KickResult",
			"Flight",
			"Reveal",
			"RunStart",
			"RunEnd",
			"KickPress",
			"ThrowChakra",
		}
	do
		remotes[name] = {
			OnServerEvent = signal(),
			FireClient = function(_, _, payload: any)
				table.insert(events, { name = name, payload = payload })
			end,
			FireAllClients = function(_, payload: any)
				table.insert(events, { name = name, payload = payload })
			end,
		}
	end
	local function model(): any
		return { Destroy = function() end, PivotTo = function() end }
	end
	local siblings = {
		["../Data"] = {
			get = function(): any
				return data
			end,
			onLeaving = function(callback: (any) -> ())
				leaving = callback
			end,
		},
		["./Events"] = {
			current = function(): any
				return nil
			end,
		},
		-- The enemy of a run is moved through this module; how it looks is not this test's.
		["./EnemyMoves"] = {
			new = function(): any
				return { step = function() end, finish = function() end, destroy = function() end }
			end,
		},
		["../World/Hub"] = {
			LANE_WIDTH = 60,
			onStrip = function(): boolean
				return true
			end,
			toLocal = function(at: any): any
				return at
			end,
			at = roblox.Vector3.new,
			setRunner = function() end,
		},
		["./Inventory"] = { tieHandsWhile = function() end, hold = function() end },
		["../World/Plots"] = {},
		["../Remotes"] = remotes,
		["../Session"] = {
			of = function(): any
				return { throwChakra = 0 }
			end,
		},
		["./State"] = {
			push = function()
				table.insert(events, { name = "State" })
			end,
		},
		["./Stats"] = {
			multipliers = function(): any
				return { luck = 1, mutationLuck = 1 }
			end,
		},
	}
	local zone = { id = "first" }
	local replicated = {
		Shared = {
			Config = {
				Animations = Animations,
				Catalog = { zoneById = { first = zone }, zoneOrder = { first = 1 } },
				Tuning = Tuning,
			},
			Logic = {
				Chase = {
					onLane = function(speed: number): number
						return speed
					end,
					enemySpeed = function(): number
						return 16
					end,
				},
				Economy = {
					runLevel = function(): number
						return 0
					end,
					twinPads = function(): { number }
						return {}
					end,
					walkSpeed = function(): number
						return 16
					end,
				},
				Index = {},
				Pouch = {
					earned = function(): number
						return 1
					end,
				},
				Kick = {
					reconcileElapsed = function(): number
						return 0
					end,
					barPosition = function(): number
						return 0.5
					end,
					resolve = function(): any
						return {
							distance = 40,
							streak = 1,
							grade = "perfect",
							share = 1,
							sage = false,
						}
					end,
					flight = function(): (number, number)
						return FLIGHT, 12
					end,
				},
				Roll = {
					spinLuck = function(): number
						return 1
					end,
					drop = function(): any
						return { character = "shinobi", mutation = "none", zone = "first" }
					end,
				},
			},
			Net = {},
			View = { Figure = { build = model, enemy = model, attach = function() end } },
		},
	}
	local services = {
		Players = {
			GetPlayers = function(): { any }
				return { player }
			end,
		},
		ReplicatedStorage = replicated,
		RunService = { Heartbeat = heartbeat },
		Workspace = {},
	}
	local scope = {
		game = {
			GetService = function(_, name: string): any
				return services[name]
			end,
		},
		require = function(module: any): any
			return if typeof(module) == "string" then siblings[module] else module
		end,
		Vector3 = roblox.Vector3,
		-- Only pose geometry matters here; this also avoids Lune's reversed lookAt.
		CFrame = {
			lookAt = function(at: any, target: any): any
				return { Position = at, LookVector = (target - at).Unit }
			end,
		},
		Random = {
			new = function(): any
				return {
					NextNumber = function(): number
						return 0.5
					end,
				}
			end,
		},
		os = {
			clock = function(): number
				return now
			end,
		},
		task = {
			delay = function(seconds: number, callback: () -> ())
				table.insert(delayed, { at = now + seconds, callback = callback })
			end,
		},
	}
	local chunk = luau.load(luau.compile(fs.readFile("src/server/Services/Kicking.luau")), {
		debugName = "Kicking",
		environment = scope,
	})
	local kicking = chunk()
	kicking.start()
	local h = {
		events = events,
		delayed = delayed,
		root = root,
		humanoid = humanoid,
		data = data,
		kicking = kicking,
	}
	function h.aim()
		heartbeat:Fire(0.1)
		table.clear(events)
	end
	function h.press()
		remotes.KickPress.OnServerEvent:Fire(player, 0)
	end
	function h.leave()
		leaving(player)
	end
	function h.advance(untilTime: number)
		while true do
			table.sort(delayed, function(a, b)
				return a.at < b.at
			end)
			local first = delayed[1]
			if not first or first.at > untilTime then
				break
			end
			table.remove(delayed, 1)
			now = first.at
			first.callback()
		end
		now = untilTime
	end
	return h
end

local function withThrow(id: string, check: (any) -> ())
	local saved = Animations.player.Throw
	Animations.player.Throw = id
	local ok, err = pcall(function()
		check(fixture())
	end)
	Animations.player.Throw = saved
	if not ok then
		error(err, 0)
	end
end

local function eventNames(h: any): string
	local names = {}
	for _, event in h.events do
		table.insert(names, event.name)
	end
	return table.concat(names, ",")
end

return {
	["empty throw preserves synchronous launch and event order"] = function()
		withThrow("", function(h)
			h.aim()
			h.press()
			T.eq(eventNames(h), "Flight,Reveal,KickResult,State")
			T.eq(#h.delayed, 1, "only the reveal completion is deferred")
			T.eq(h.humanoid.WalkSpeed, 0)
			T.eq(h.data.spins, 1)
			T.eq(
				h.root.CFrame.LookVector,
				roblox.Vector3.zAxis,
				"default throw does not turn the player"
			)
			h.advance(REVEAL - 0.01)
			T.eq(eventNames(h), "Flight,Reveal,KickResult,State")
			h.advance(REVEAL)
			T.eq(eventNames(h), "Flight,Reveal,KickResult,State,RunStart")
		end)
	end,

	["configured throw launches after windup and keeps the whole reveal"] = function()
		withThrow("123", function(h)
			h.aim()
			h.press()
			T.eq(eventNames(h), "KickResult,State", "result starts the pose immediately")
			T.eq(
				h.root.CFrame.Position,
				roblox.Vector3.new(0, 6, 3),
				"windup keeps root on the strip"
			)
			T.near(h.root.CFrame.LookVector.Y, 0, 0.000001, "turn stays horizontal")
			T.near(h.root.CFrame.LookVector.X, 1, 0.000001, "turn faces the lane")
			h.advance(WINDUP - 0.01)
			T.eq(eventNames(h), "KickResult,State")
			h.advance(WINDUP + PAST)
			T.eq(eventNames(h), "KickResult,State,Flight,Reveal")
			T.eq(h.events[3].payload.from, roblox.Vector3.new(0, 8, 3))
			h.advance(REVEAL)
			T.eq(
				eventNames(h),
				"KickResult,State,Flight,Reveal",
				"windup cannot shorten the reveal"
			)
			h.advance(WINDUP + REVEAL + PAST)
			T.eq(eventNames(h), "KickResult,State,Flight,Reveal,RunStart")
		end)
	end,

	["leaving cancels both scheduled launch and run start"] = function()
		withThrow("123", function(h)
			h.aim()
			h.press()
			h.leave()
			h.advance(WINDUP + REVEAL + PAST)
			T.eq(eventNames(h), "KickResult,State")
		end)
	end,

	["stale callbacks cannot launch or finish a replacement flight"] = function()
		withThrow("123", function(h)
			h.aim()
			h.press()
			h.advance(0.2)
			h.leave()
			h.aim()
			h.press()
			h.advance(WINDUP + PAST)
			T.eq(eventNames(h), "KickResult,State", "old launch cannot consume the current token")
			h.advance(0.2 + WINDUP + PAST)
			T.eq(eventNames(h), "KickResult,State,Flight,Reveal")
			h.advance(WINDUP + REVEAL + PAST)
			T.eq(
				eventNames(h),
				"KickResult,State,Flight,Reveal",
				"old reveal cannot start the current run"
			)
			h.advance(0.2 + WINDUP + REVEAL + PAST)
			T.eq(eventNames(h), "KickResult,State,Flight,Reveal,RunStart")
		end)
	end,
}
