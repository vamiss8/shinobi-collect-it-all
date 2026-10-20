--!strict
-- What the game will want later, fetched a little at a time (owner, 2026-10-20: "the game must
-- start and play on any device; I fear the assets will load long on phones").
--
-- Every supplied model (some ninety, about 1.8 million triangles in all) and every piece of
-- music used to be asked for the moment the game started, all at once. Roblox fetches what is
-- asked for in turn, so on a slow phone the interface's own pictures and the world round the
-- player waited behind them. Now nothing is fetched for later until the game has loaded and
-- stood a few seconds; then a few things at a time, in the order they were queued (the zones'
-- models from the first zone on); and what a throw is about to show is fetched at the press,
-- beside the queue (client Cinematic: the roulette of its zone and its enemy; client Audio:
-- its enemy's track).

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)

local Preload = {}

-- Seconds after the game has loaded before anything is fetched for later; how many things are
-- fetched together; the pause between batches.
local SETTLE = 6
local BATCH = 3
local PAUSE = 0.3

local queue: { Instance } = {}
local asked: { [Instance]: boolean } = {}

-- Fetched in their turn, after what is queued already.
function Preload.later(items: { Instance })
	for _, item in items do
		if not asked[item] then
			table.insert(queue, item)
		end
	end
end

-- Fetched at once, beside the queue: what is about to be seen or heard.
function Preload.now(items: { Instance })
	local fresh: { Instance } = {}
	for _, item in items do
		if not asked[item] then
			asked[item] = true
			table.insert(fresh, item)
		end
	end
	if #fresh > 0 then
		task.spawn(function()
			pcall(function()
				ContentProvider:PreloadAsync(fresh)
			end)
		end)
	end
end

-- A model of the Models folder by name, whatever the capitals of its name (as View/Figure
-- finds them), or nothing.
function Preload.model(name: string): Instance?
	local folder = ReplicatedStorage:FindFirstChild(Net.MODELS_FOLDER)
	if not folder then
		return nil
	end
	local found = folder:FindFirstChild(name)
	if found then
		return found
	end
	local lower = string.lower(name)
	for _, child in folder:GetChildren() do
		if string.lower(child.Name) == lower then
			return child
		end
	end
	return nil
end

function Preload.start()
	task.spawn(function()
		if not game:IsLoaded() then
			game.Loaded:Wait()
		end
		task.wait(SETTLE)
		while true do
			local batch: { Instance } = {}
			while #batch < BATCH and #queue > 0 do
				local item = table.remove(queue, 1) :: Instance
				if not asked[item] then
					asked[item] = true
					table.insert(batch, item)
				end
			end
			if #batch > 0 then
				pcall(function()
					ContentProvider:PreloadAsync(batch)
				end)
				task.wait(PAUSE)
			else
				task.wait(1)
			end
		end
	end)
end

return Preload
