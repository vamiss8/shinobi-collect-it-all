--!strict
-- What players do, told to Roblox's analytics (owner, 2026-10-19: "analytics, do it"): the
-- charts are in Creator Hub > the game > Analytics, under Onboarding (the base tutorial, step
-- by step: where new players stop), Economy (where Ryo and Herbs come from and go) and Custom
-- events (throws, runs, rebirths, tips, achievements and the like, with breakdowns). Roblox
-- takes these events from the server of a published game only: in Studio nothing is sent.
--
-- Read from Roblox's docs on 2026-10-19 (creator-docs: AnalyticsService.yaml and
-- production/analytics): at most 5 currencies, 20 transaction types, 100 item SKUs and 10
-- funnels a game; 3 custom fields, string values, 8,000 combinations; 120 + 20 a player events
-- a minute in all. So the dojo's income, paid every second, is added up and sent once a minute
-- (and as the player leaves), and so are levels bought on the consoles; and custom events
-- keep to a few names with what varies in their fields.

local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Analytics = {}

-- Whether events go out at all: not from Studio, where Roblox does not take them.
local live = not RunService:IsStudio()

-- How often what is added up is sent, seconds.
local FLUSH_EVERY = 60

export type Currency = "Ryo" | "Herbs"

-- Sums waiting to be sent, by player, then by flow, currency, transaction and item.
type Pending = {
	[string]: {
		amount: number,
		flow: Enum.AnalyticsEconomyFlowType,
		currency: string,
		transaction: string,
		sku: string?,
	},
}
local pending: { [Player]: Pending } = {}
-- What each player's balance was last told to be, by currency, for a sum sent later.
local balances: { [Player]: { [string]: number } } = {}

-- The custom fields of an event, from up to three strings.
local function fields(a: string?, b: string?, c: string?): { [string]: string }?
	if not a then
		return nil
	end
	local keys = Enum.AnalyticsCustomFieldKeys
	local made: { [string]: string } = { [keys.CustomField01.Name] = a }
	if b then
		made[keys.CustomField02.Name] = b
	end
	if c then
		made[keys.CustomField03.Name] = c
	end
	return made
end

-- A custom event: a name of few kinds, and what varies in up to three fields.
function Analytics.event(
	player: Player,
	name: string,
	value: number?,
	a: string?,
	b: string?,
	c: string?
)
	if not live then
		return
	end
	pcall(function()
		AnalyticsService:LogCustomEvent(player, name, value or 1, fields(a, b, c))
	end)
end

local function sendEconomy(
	player: Player,
	flow: Enum.AnalyticsEconomyFlowType,
	currency: string,
	amount: number,
	balance: number,
	transaction: string,
	sku: string?
)
	if not live or amount <= 0 then
		return
	end
	pcall(function()
		AnalyticsService:LogEconomyEvent(
			player,
			flow,
			currency,
			amount,
			math.max(balance, 0),
			transaction,
			sku
		)
	end)
end

-- Ryo or Herbs coming in (`source`) or going out, with the balance after: `transaction` one of
-- Roblox's kinds (Gameplay, Shop, IAP, TimedReward, Onboarding), `sku` what it was for.
-- `often` adds it up and sends it with the next round instead, for what happens every second.
function Analytics.economy(
	player: Player,
	source: boolean,
	currency: Currency,
	amount: number,
	balance: number,
	transaction: Enum.AnalyticsEconomyTransactionType,
	sku: string?,
	often: boolean?
)
	if not live or amount <= 0 then
		return
	end
	local flow = if source
		then Enum.AnalyticsEconomyFlowType.Source
		else Enum.AnalyticsEconomyFlowType.Sink
	local kept = balances[player] or {}
	balances[player] = kept
	kept[currency] = balance
	if not often then
		sendEconomy(player, flow, currency, amount, balance, transaction.Name, sku)
		return
	end
	local waiting = pending[player] or {}
	pending[player] = waiting
	local key = `{flow.Name}|{currency}|{transaction.Name}|{sku or ""}`
	local sum = waiting[key]
	if sum then
		sum.amount += amount
	else
		waiting[key] = {
			amount = amount,
			flow = flow,
			currency = currency,
			transaction = transaction.Name,
			sku = sku,
		}
	end
end

-- A step of the base tutorial reached, for the Onboarding chart (1 is the first).
function Analytics.onboarding(player: Player, step: number, name: string)
	if not live then
		return
	end
	pcall(function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, step, name)
	end)
end

local function flush(player: Player)
	local waiting = pending[player]
	if not waiting then
		return
	end
	pending[player] = nil
	local kept = balances[player] or {}
	for _, sum in waiting do
		sendEconomy(
			player,
			sum.flow,
			sum.currency,
			sum.amount,
			kept[sum.currency] or 0,
			sum.transaction,
			sum.sku
		)
	end
end

function Analytics.start()
	Players.PlayerRemoving:Connect(function(player)
		flush(player)
		balances[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(FLUSH_EVERY)
			for player in pending do
				flush(player)
			end
		end
	end)
end

return Analytics
