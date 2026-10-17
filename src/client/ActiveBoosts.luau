--!strict
-- The potions running for this player, on the screen (owner, 2026-10-17: "show the active
-- effects on the screen too, somewhere nice, not only in the shop"). A small scroll for each in
-- the upper left corner, under the event's timer while one runs (client EventShow): the
-- potion's picture on a seal of its effect's color, its name, what it does and how long it has
-- left. A potion drunk unrolls its scroll and pushes the others down; one run out rolls up and
-- the others close the gap. The last half minute is told by the outline turning red.
-- The seconds left come in the snapshot (Net.Snapshot `potions`, as they were when it was
-- sent) and are counted down here, so a scroll goes at its time without waiting for the next.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local EventShow = require("./EventShow")
local Icons = require("./Icons")
local Net = require(ReplicatedStorage.Shared.Net)
local Store = require("./Store")
local Strings = require("./Strings")
local ThrowPower = require("./ThrowPower")
local Ui = require("./Ui")

local ActiveBoosts = {}

local SIZE = Vector2.new(300, 58)
local SEAL = 44
-- Where the words begin: past the seal, which the scroll puts 28 in from its left end.
local TEXT_LEFT = 28 + SEAL + 12
-- Room between two scrolls, and between the event's timer and the first: a scroll's rollers
-- stand 11 past its sheet above and below.
local GAP = 26
-- Where the first scroll stands when there is no event's timer to go by.
local CORNER = Vector2.new(28, 18)
local SLIDE = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
-- The last seconds of a potion, when its outline turns red.
local ENDING = 30
local TICK = 0.25

-- An effect's color, for the seal and the outline (the words are ink); and what it is called.
local COLORS: { [string]: Color3 } = {
	chakra = Ui.BLUE,
	ryo = Ui.GOLD,
	luck = Ui.GREEN,
	mutationLuck = Color3.fromRGB(149, 117, 205),
}
local WORDS: { [string]: string } = {
	chakra = "BoostChakra",
	ryo = "BoostRyo",
	luck = "BoostLuck",
	mutationLuck = "BoostMutationLuck",
}

type Card = {
	potion: Catalog.Potion,
	paper: Ui.Parchment,
	detail: TextLabel,
	color: Color3,
	endsAt: number, -- os.clock() time it runs out; 0 when it is not running
	open: boolean, -- whether it is meant to be on the screen
	placed: boolean, -- whether it stood in its place when the scrolls were last laid out
}

-- 4:05 for 245 seconds, 1:02:05 for an hour and more.
local function clock(seconds: number): string
	local whole = math.max(math.ceil(seconds), 0)
	if whole >= 3600 then
		return string.format("%d:%02d:%02d", whole // 3600, whole // 60 % 60, whole % 60)
	end
	return string.format("%d:%02d", whole // 60, whole % 60)
end

-- The developer product that sells a potion: its key names the potion and its picture.
local function productOf(potionId: string): Catalog.Product?
	for _, product in Catalog.products do
		if product.kind == "potion" and product.potion == potionId then
			return product
		end
	end
	return nil
end

function ActiveBoosts.start()
	local layer = Ui.screen("Boosts", 12)
	local timer = EventShow.timer

	-- One scroll a potion, made at once and hidden, in the order of Config/Potions: a potion
	-- keeps its place in the column whatever was drunk first.
	local cards: { Card } = {}
	for _, potion in Catalog.potions do
		local product = productOf(potion.id)
		local color = COLORS[potion.effect] or Ui.SEAL
		local paper = Ui.parchment(layer, {
			Position = UDim2.fromOffset(CORNER.X, CORNER.Y),
			Size = UDim2.fromOffset(SIZE.X, SIZE.Y),
			Visible = false,
		}, SEAL)
		paper.edge.Color = color
		paper.seal.BackgroundColor3 = color
		local picture = Ui.make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.86, 0.86),
			BackgroundTransparency = 1,
		}, paper.seal)
		if product then
			Icons.goods(picture, product.key)
		end
		local name = Ui.text(paper.page, {
			Position = UDim2.fromOffset(TEXT_LEFT, 5),
			Size = UDim2.new(1, -(TEXT_LEFT + 24), 0, 26),
			TextScaled = true,
			TextColor3 = Ui.INK,
			Text = if product then Strings.get("Goods_" .. product.key) else potion.name,
		})
		Ui.make("UITextSizeConstraint", { MaxTextSize = 22 }, name)
		local detail = Ui.text(paper.page, {
			Position = UDim2.fromOffset(TEXT_LEFT, 30),
			Size = UDim2.new(1, -(TEXT_LEFT + 24), 0, 23),
			TextScaled = true,
			TextColor3 = Ui.INK,
			TextTransparency = 0.15,
		})
		Ui.make("UITextSizeConstraint", { MaxTextSize = 20 }, detail)
		table.insert(cards, {
			potion = potion,
			paper = paper,
			detail = detail,
			color = color,
			endsAt = 0,
			open = false,
			placed = false,
		})
	end

	-- Stands the scrolls on the screen one under another, from where the event's timer is, or
	-- under it while it is up. A scroll already in its place slides to its new one; one that
	-- has just come up is put there at once.
	local function lay()
		local x, y = CORNER.X, CORNER.Y
		if timer then
			x, y = timer.Position.X.Offset, timer.Position.Y.Offset
			if timer.Visible then
				y += timer.Size.Y.Offset + GAP
			end
		end
		for _, card in cards do
			local frame = card.paper.frame
			if frame.Visible then
				local goal = UDim2.fromOffset(x, y)
				if card.placed then
					TweenService:Create(frame, SLIDE, { Position = goal }):Play()
				else
					frame.Position = goal
				end
				card.placed = true
				y += SIZE.Y + GAP
			else
				card.placed = false
			end
		end
	end
	for _, card in cards do
		-- A scroll rolled up is hidden only once it has rolled: the others close up then.
		card.paper.frame:GetPropertyChangedSignal("Visible"):Connect(lay)
	end
	if timer then
		timer:GetPropertyChangedSignal("Visible"):Connect(lay)
	end

	local function refresh()
		local now = os.clock()
		for _, card in cards do
			local left = card.endsAt - now
			if left > 0 then
				local potion = card.potion
				local does = Strings.get(WORDS[potion.effect] or "BoostChakra", potion.multiplier)
				card.detail.Text = Strings.get("BoostLeft", does, clock(left))
				card.paper.edge.Color = if left <= ENDING then Ui.SEAL else card.color
				if not card.open then
					card.open = true
					Ui.unroll(card.paper)
					lay()
				end
			elseif card.open then
				card.open = false
				Ui.rollUp(card.paper)
			end
		end
		-- On a touch screen the throw power slider opens under the readouts, where these are.
		layer.Visible = not (Ui.touch() and ThrowPower.isOpen())
	end

	Store.onChange(function(state: Net.Snapshot)
		local now = os.clock()
		for _, card in cards do
			local left = state.potions[card.potion.id]
			card.endsAt = if left and left > 0 then now + left else 0
		end
		refresh()
	end)
	task.spawn(function()
		while true do
			task.wait(TICK)
			refresh()
		end
	end)
end

return ActiveBoosts
