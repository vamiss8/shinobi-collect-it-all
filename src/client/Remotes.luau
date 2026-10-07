--!strict
-- The RemoteEvents created by the server, looked up once.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)

local folder = ReplicatedStorage:WaitForChild(Net.FOLDER)

local function event(name: string): RemoteEvent
	return folder:WaitForChild(name) :: RemoteEvent
end

return {
	State = event(Net.Events.State),
	Inventory = event(Net.Events.Inventory),
	Index = event(Net.Events.Index),
	Hold = event(Net.Events.Hold),
	ThrowChakra = event(Net.Events.ThrowChakra),
	KickStart = event(Net.Events.KickStart),
	KickPress = event(Net.Events.KickPress),
	KickResult = event(Net.Events.KickResult),
	Flight = event(Net.Events.Flight),
	Reveal = event(Net.Events.Reveal),
	RunStart = event(Net.Events.RunStart),
	RunEnd = event(Net.Events.RunEnd),
	Bubble = event(Net.Events.Bubble),
	BubblePop = event(Net.Events.BubblePop),
	Ring = event(Net.Events.Ring),
	RingPress = event(Net.Events.RingPress),
	RingResult = event(Net.Events.RingResult),
	Buy = event(Net.Events.Buy),
	Upgrade = event(Net.Events.Upgrade),
	Upgraded = event(Net.Events.Upgraded),
	Sell = event(Net.Events.Sell),
	Notify = event(Net.Events.Notify),
	Offline = event(Net.Events.Offline),
	Collect = event(Net.Events.Collect),
}
