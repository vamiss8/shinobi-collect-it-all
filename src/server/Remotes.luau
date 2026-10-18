--!strict
-- Creates the RemoteEvents described in Shared/Net. Requiring this module is what makes them exist.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)

local folder = Instance.new("Folder")
folder.Name = Net.FOLDER

local function event(name: string): RemoteEvent
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = folder
	return remote
end

local Remotes = {
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
	BuyPotion = event(Net.Events.BuyPotion),
	Drink = event(Net.Events.Drink),
	RunAt = event(Net.Events.RunAt),
	Rebirth = event(Net.Events.Rebirth),
	Upgrade = event(Net.Events.Upgrade),
	Upgraded = event(Net.Events.Upgraded),
	GroupGift = event(Net.Events.GroupGift),
	Achievement = event(Net.Events.Achievement),
	ClaimAchievement = event(Net.Events.ClaimAchievement),
	Placed = event(Net.Events.Placed),
	Sell = event(Net.Events.Sell),
	Notify = event(Net.Events.Notify),
	Offline = event(Net.Events.Offline),
	Collect = event(Net.Events.Collect),
	Dev = event(Net.Events.Dev),
	Announce = event(Net.Events.Announce),
	Settings = event(Net.Events.Settings),
	Rejoin = event(Net.Events.Rejoin),
}

folder.Parent = ReplicatedStorage

return Remotes
