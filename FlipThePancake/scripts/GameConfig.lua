-- GameConfig (ModuleScript in ReplicatedStorage)
-- All the numbers that control the game live here, so you can tweak them easily.
-- Shop items live in PanConfig, SizeConfig, PancakeConfig and ToppingConfig.

local GameConfig = {}

--------------------------------------------------------------------
-- RESTAURANTS (each one has a kitchen where one player cooks)
-- They line Main Street, facing the spawn plaza.
--------------------------------------------------------------------
GameConfig.Restaurants = {
	{ Name = "Flapjack Diner",  Wall = Color3.fromRGB(125, 205, 200), Accent = Color3.fromRGB(220, 50, 60),  Outside = Color3.fromRGB(245, 240, 230) },
	{ Name = "The Syrup Shack", Wall = Color3.fromRGB(240, 200, 150), Accent = Color3.fromRGB(150, 80, 30),  Outside = Color3.fromRGB(170, 105, 70) },
	{ Name = "Butter Barn",     Wall = Color3.fromRGB(255, 235, 150), Accent = Color3.fromRGB(200, 40, 40),  Outside = Color3.fromRGB(190, 50, 45) },
	{ Name = "Stack House",     Wall = Color3.fromRGB(190, 215, 255), Accent = Color3.fromRGB(40, 90, 180),  Outside = Color3.fromRGB(235, 240, 250) },
	{ Name = "Golden Griddle",  Wall = Color3.fromRGB(255, 225, 180), Accent = Color3.fromRGB(215, 160, 30), Outside = Color3.fromRGB(60, 55, 60) },
	{ Name = "Cosmic Cakes",    Wall = Color3.fromRGB(210, 190, 255), Accent = Color3.fromRGB(130, 60, 220), Outside = Color3.fromRGB(45, 35, 80) },
}
GameConfig.StationCount = #GameConfig.Restaurants
GameConfig.StationPosition = Vector3.new(0, 0, 0) -- ground level of the island

-- The island: a long path runs north (-Z) from the spawn to the market hub.
-- Restaurants sit on plots on both sides of the path, with their front doors facing it.
GameConfig.Island = {
	PathHalfWidth = 7,
	PlotRows = { 90, -30, -150 },  -- Z of each row of plots (south to north)
	RestaurantX = 57,              -- how far each kitchen is from the path
	Spawn = Vector3.new(0, 0, 190),
	Hub = Vector3.new(0, 0, -225),
	LandHalfWidth = 140,
	LandNorth = -265,
	LandSouth = 225,
}

-- Where the kitchen of restaurant number i is, and which way it faces.
-- A station's "front" (where you stand and where the door is) is its local +Z.
function GameConfig.GetStationCFrame(index)
	local island = GameConfig.Island
	local row = island.PlotRows[math.ceil(index / 2)]
	local left = (index % 2 == 1)
	local x = left and -island.RestaurantX or island.RestaurantX
	-- left-side restaurants face +X (toward the path), right-side ones face -X
	return CFrame.new(x, 0, row) * CFrame.Angles(0, math.rad(left and 90 or -90), 0)
end

-- Just outside each restaurant's front door, in the kitchen's own space
GameConfig.RestaurantDoor = Vector3.new(-14.5, 0, 36.5)

function GameConfig.GetStationOrigin(index)
	return GameConfig.GetStationCFrame(index).Position
end

-- Where the plate for stacking sits (on the service counter), relative to a station's origin
GameConfig.StackPlateOffset = Vector3.new(-11, 3.9, 2.5)

--------------------------------------------------------------------
-- STACKING
--------------------------------------------------------------------
-- Instead of serving, you can STACK finished pancakes on the plate. Each pancake in the stack adds
-- +10% to everything in it when you serve. But a sloppy or dropped flip can topple a tall stack!
GameConfig.StackBonusPerPancake = 0.10
GameConfig.MaxStack = 25
GameConfig.StackSafeHeight = 3          -- stacks this short never topple
GameConfig.ToppleChancePerPancake = 0.1 -- extra topple chance for each pancake above the safe height
GameConfig.MaxToppleChance = 0.85
GameConfig.StackPancakeSize = 1.9       -- how big pancakes look on the stack

function GameConfig.GetStackMultiplier(count)
	return 1 + GameConfig.StackBonusPerPancake * math.max(count - 1, 0)
end

function GameConfig.GetToppleChance(height, dropped)
	local chance = GameConfig.ToppleChancePerPancake * math.max(height - GameConfig.StackSafeHeight + 1, 0)
	if dropped then
		chance *= 1.5
	end
	return math.min(chance, GameConfig.MaxToppleChance)
end

--------------------------------------------------------------------
-- CUSTOMERS & ORDERS
--------------------------------------------------------------------
GameConfig.Orders = {
	RewardMultiplier = 3,     -- filling an order exactly pays 3x
	Patience = 90,            -- seconds a customer waits
	RushPatience = 60,
	NextCustomerDelay = 8,    -- seconds before the next customer walks up
	RushNextCustomerDelay = 2,
	MaxCount = 5,             -- the biggest stack a customer will ask for
	PerfectChance = 0.35,     -- how often they insist on a PERFECT cook
	ToppingChance = 0.6,      -- how often they want toppings (if you own some)
}

--------------------------------------------------------------------
-- RUSH HOUR
--------------------------------------------------------------------
GameConfig.RushHour = {
	Interval = 600,           -- seconds between rush hours (10 minutes)
	Duration = 120,           -- how long it lasts (2 minutes)
	ButterMultiplier = 2,
	StudioInterval = 90,      -- in Studio playtests it comes sooner so you can test it
	Music = "",               -- optional: a Creator Store music id like "rbxassetid://123"
}

--------------------------------------------------------------------
-- COOKING
--------------------------------------------------------------------
GameConfig.MinCookTime = 1  -- a side must cook at least this long before you can flip/serve

-- The PERFECT zone sits in the middle of the meter. Pans make it wider, fancy pancakes make it smaller.
GameConfig.PerfectCenter = 0.66
GameConfig.PerfectHalfWidth = 0.06

GameConfig.ZoneColors = {
	Raw = Color3.fromRGB(245, 232, 196),
	Golden = Color3.fromRGB(120, 205, 95),
	Perfect = Color3.fromRGB(255, 205, 40),
	Burnt = Color3.fromRGB(70, 35, 25),
}

GameConfig.CookMultipliers = {
	Raw = 0.3,
	Golden = 1.0,
	Perfect = 1.5,
	Burnt = 0.2,
}

-- Builds the cook meter zones. "End" is a fraction of the cook time.
function GameConfig.BuildCookZones(perfectAdjust)
	local half = math.clamp(GameConfig.PerfectHalfWidth + (perfectAdjust or 0), 0.02, 0.16)
	local perfectStart = GameConfig.PerfectCenter - half
	local perfectEnd = GameConfig.PerfectCenter + half
	local colors = GameConfig.ZoneColors
	return {
		{ Name = "Raw", End = math.max(perfectStart - 0.15, 0.2), Color = colors.Raw },
		{ Name = "Golden", End = perfectStart, Color = colors.Golden },
		{ Name = "Perfect", End = perfectEnd, Color = colors.Perfect },
		{ Name = "Golden", End = math.min(perfectEnd + 0.13, 0.95), Color = colors.Golden },
		{ Name = "Burnt", End = math.huge, Color = colors.Burnt },
	}
end

GameConfig.CookZones = GameConfig.BuildCookZones(0) -- the default zones

function GameConfig.GetCookZone(fraction, zones)
	for _, zone in ipairs(zones or GameConfig.CookZones) do
		if fraction < zone.End then
			return zone.Name
		end
	end
	return "Burnt"
end

-- The pancake's color as it cooks (0 = raw batter, 1 = charcoal)
local CHARCOAL = Color3.fromRGB(35, 25, 20)
local DARK_BROWN = Color3.fromRGB(60, 35, 20)

function GameConfig.GetCookColor(fraction, pancakeType)
	local raw = pancakeType and pancakeType.Raw or Color3.fromRGB(250, 238, 200)
	local cooked = pancakeType and pancakeType.Cooked or Color3.fromRGB(206, 136, 56)
	local keys = {
		{ 0.00, raw },
		{ 0.50, raw:Lerp(cooked, 0.75) },
		{ 0.66, cooked },
		{ 0.85, cooked:Lerp(DARK_BROWN, 0.55) },
		{ 1.00, CHARCOAL },
	}
	fraction = math.clamp(fraction, 0, 1)
	for i = 1, #keys - 1 do
		local a, b = keys[i], keys[i + 1]
		if fraction <= b[1] then
			return a[2]:Lerp(b[2], (fraction - a[1]) / (b[1] - a[1]))
		end
	end
	return CHARCOAL
end

--------------------------------------------------------------------
-- FLIPPING
--------------------------------------------------------------------
GameConfig.PowerChargeSpeed = 0.75 -- how fast the power needle moves (it bounces back and forth)

-- Power zones on the flip bar. Sweet = the perfect spot.
-- Perfect/Good/Sloppy = how far from Sweet still counts. Further than Sloppy = DROPPED.
-- HalfTurns must be odd so the pancake always lands on its other side.
GameConfig.FlipTricks = {
	{ Name = "Single",  Label = "FLIP!",                      ShortLabel = "x1",
	  Min = 0.12, Max = 0.40, Sweet = 0.26,  Perfect = 0.040, Good = 0.090, Sloppy = 0.140,
	  Multiplier = 1.0, HalfTurns = 1, Height = 5,  FlightTime = 0.8, SlowMo = false },
	{ Name = "Double",  Label = "DOUBLE FLIP!",               ShortLabel = "DOUBLE x1.5",
	  Min = 0.40, Max = 0.65, Sweet = 0.525, Perfect = 0.030, Good = 0.070, Sloppy = 0.100,
	  Multiplier = 1.5, HalfTurns = 3, Height = 8,  FlightTime = 1.1, SlowMo = false },
	{ Name = "Triple",  Label = "TRIPLE FLIP!!",              ShortLabel = "TRIPLE x2.5",
	  Min = 0.65, Max = 0.88, Sweet = 0.765, Perfect = 0.022, Good = 0.050, Sloppy = 0.080,
	  Multiplier = 2.5, HalfTurns = 5, Height = 11, FlightTime = 1.6, SlowMo = true },
	{ Name = "Tornado", Label = "🌪️ PANCAKE TORNADO!!! 🌪️", ShortLabel = "TORNADO x5",
	  Min = 0.88, Max = 1.00, Sweet = 0.94,  Perfect = 0.015, Good = 0.030, Sloppy = 0.045,
	  Multiplier = 5.0, HalfTurns = 9, Height = 14, FlightTime = 2.1, SlowMo = true },
}

GameConfig.FlipQualityMultipliers = {
	Perfect = 1.3,
	Good = 1.0,
	Sloppy = 0.8,
}

-- Which trick a power value lands in (nil = too weak, the pancake flops off)
function GameConfig.GetTrickIndex(power)
	local tricks = GameConfig.FlipTricks
	if power < tricks[1].Min then
		return nil
	end
	for index, trick in ipairs(tricks) do
		if power <= trick.Max then
			return index
		end
	end
	return #tricks
end

-- How well a power value lands for a given trick. tolerance < 1 makes it harder.
function GameConfig.GetFlipQuality(power, trickIndex, tolerance)
	local trick = GameConfig.FlipTricks[trickIndex]
	tolerance = tolerance or 1
	local miss = math.abs(power - trick.Sweet)
	if miss <= trick.Perfect * tolerance then
		return "Perfect"
	elseif miss <= trick.Good * tolerance then
		return "Good"
	elseif miss <= trick.Sloppy * tolerance then
		return "Sloppy"
	end
	return "Dropped"
end

-- Returns (trickIndex, quality) where quality is "Perfect", "Good", "Sloppy" or "Dropped"
function GameConfig.GetFlipResult(power, tolerance)
	local index = GameConfig.GetTrickIndex(power)
	if not index then
		return 1, "Dropped"
	end
	return index, GameConfig.GetFlipQuality(power, index, tolerance)
end

--------------------------------------------------------------------
-- EARNINGS
--------------------------------------------------------------------

-- TESTING: in Studio playtests only, you start with at least this much Butter so you can try the shop.
-- Real players in the published game never get this. Set it to 0 to turn it off.
GameConfig.StudioTestButter = 100000000

--------------------------------------------------------------------
-- LOADOUT (what the player has equipped, combined into numbers the game uses)
--------------------------------------------------------------------
GameConfig.DefaultEquipped = { Pan = "Rusty", Size = "Small", Pancake = "Classic", Toppings = {} }

function GameConfig.GetLoadout(equipped)
	local folder = script.Parent
	local PanConfig = require(folder:WaitForChild("PanConfig"))
	local SizeConfig = require(folder:WaitForChild("SizeConfig"))
	local PancakeConfig = require(folder:WaitForChild("PancakeConfig"))
	local ToppingConfig = require(folder:WaitForChild("ToppingConfig"))

	equipped = equipped or GameConfig.DefaultEquipped
	local pan = PanConfig.ById[equipped.Pan] or PanConfig.Items[1]
	local size = SizeConfig.Items[1] -- pan sizes were removed: everyone cooks one pancake at a time
	local pancakeType = PancakeConfig.ById[equipped.Pancake] or PancakeConfig.Items[1]

	local toppings, bonus = {}, 0
	for _, id in ipairs(equipped.Toppings or {}) do
		local topping = ToppingConfig.ById[id]
		if topping then
			table.insert(toppings, topping)
			bonus += topping.Bonus
		end
	end

	return {
		Pan = pan,
		Size = size,
		Pancake = pancakeType,
		Toppings = toppings,
		CookTime = pancakeType.CookTime / pan.CookSpeed,
		Zones = GameConfig.BuildCookZones(pan.PerfectBonus - pancakeType.Difficulty),
		ToppingMultiplier = 1 + bonus,
		FlipTolerance = (size.FlipTolerance or 1) * (pancakeType.FlipTolerance or 1),
		ValueMultiplier = size.ValueMultiplier or 1,
	}
end

-- Rarity tiers for shop items (card colors, labels and effects)
GameConfig.Rarities = {
	Common    = { Order = 1, Color = Color3.fromRGB(165, 165, 170), Light = Color3.fromRGB(245, 245, 245) },
	Uncommon  = { Order = 2, Color = Color3.fromRGB(80, 190, 95),   Light = Color3.fromRGB(225, 250, 225) },
	Rare      = { Order = 3, Color = Color3.fromRGB(60, 140, 255),  Light = Color3.fromRGB(220, 235, 255) },
	Epic      = { Order = 4, Color = Color3.fromRGB(165, 85, 255),  Light = Color3.fromRGB(238, 222, 255) },
	Legendary = { Order = 5, Color = Color3.fromRGB(255, 175, 30),  Light = Color3.fromRGB(255, 240, 200), Shine = true },
	Mythic    = { Order = 6, Color = Color3.fromRGB(255, 70, 160),  Light = Color3.fromRGB(255, 225, 240), Shine = true, Rainbow = true },
}

function GameConfig.GetRarity(item)
	return GameConfig.Rarities[item.Rarity or "Common"] or GameConfig.Rarities.Common
end

function GameConfig.GetToppingSlots(totalButter)
	local ToppingConfig = require(script.Parent:WaitForChild("ToppingConfig"))
	local slots = 1
	for _, step in ipairs(ToppingConfig.SlotThresholds) do
		if totalButter >= step.TotalButter then
			slots = step.Slots
		end
	end
	return slots
end

--------------------------------------------------------------------
-- COMBO
--------------------------------------------------------------------
-- Every PERFECT flip in a row adds 1 to your combo. The Butter multiplier is the combo (max x10).
-- A sloppy flip, a drop, or serving a raw/burnt side resets it.
GameConfig.MaxCombo = 10

function GameConfig.GetComboMultiplier(combo)
	return math.clamp(combo, 1, GameConfig.MaxCombo)
end

--------------------------------------------------------------------
-- SAVING
--------------------------------------------------------------------
GameConfig.DataStoreName = "FlipThePancake_v1"
GameConfig.DataVersion = 2
GameConfig.AutoSaveInterval = 60 -- seconds

--------------------------------------------------------------------
-- SOUNDS
-- "rbxasset://" sounds are built into Roblox. "rbxassetid://" sounds are from the Creator Store
-- (the sizzles are by Pro Sound Effects, which Roblox licenses for use in any game).
-- Give a sound an Ids list instead of Id to pick a random one each time it plays.
--------------------------------------------------------------------
GameConfig.Sounds = {
	PourSizzle = {
		Ids = {
			"rbxassetid://9119165436", -- Sizzle Short And Explosive Sear 1
			"rbxassetid://9119166199", -- Sizzle Short And Explosive Sear 8
			"rbxassetid://9119166195", -- Sizzle Short And Explosive Sear 10
			"rbxassetid://9119165650", -- Sizzle Short And Explosive Sear 4
		},
		Volume = 0.8, Pitch = 1,
	},
	Sizzle = { Id = "rbxassetid://9114542867", Volume = 0.35, Pitch = 1 }, -- Fry Or Sizzle 1 (butter sizzling in a pan)
	Whoosh = { Id = "rbxasset://sounds/action_falling.ogg",        Volume = 0.5,  Pitch = 1.6 },
	Land   = { Id = "rbxasset://sounds/action_jump_land.mp3",      Volume = 0.9,  Pitch = 1.2 },
	Ding   = { Id = "rbxasset://sounds/volume_slider.ogg",         Volume = 1.0,  Pitch = 1.0 },
	Coin   = { Id = "rbxasset://sounds/volume_slider.ogg",         Volume = 0.6,  Pitch = 1.5 },
	Splat  = { Id = "rbxasset://sounds/impact_water.mp3",          Volume = 0.9,  Pitch = 0.8 },
	Sad    = { Id = "rbxasset://sounds/oof.ogg",                   Volume = 0.6,  Pitch = 0.8 },
	Boom   = { Id = "rbxasset://sounds/impact_explosion_03.mp3",   Volume = 0.35, Pitch = 1.3 },
}

-- Particle textures (built into Roblox)
GameConfig.Textures = {
	Sparkle = "rbxasset://textures/particles/sparkles_main.dds",
	Smoke   = "rbxasset://textures/particles/smoke_main.dds",
	Fire    = "rbxasset://textures/particles/fire_main.dds",
	Square  = "rbxasset://textures/particles/SquareParticle.png",
	Ring    = "rbxasset://textures/particles/explosion01_shockwave_main.dds",
}

--------------------------------------------------------------------
-- 3D MODELS FROM THE CREATOR STORE
-- Free models picked for looks. Install them once in Studio by pasting the line from
-- InstallAssets.txt into the Command Bar (View > Command Bar). They land in ReplicatedStorage > Assets.
-- If a model isn't installed, the game falls back to its built-in part version.
--------------------------------------------------------------------
GameConfig.Assets = {
	PancakeStack = 12549666717, -- tall stack with syrup, blueberries and butter (counter + shop displays)
	SyrupBottle = 5598700855,   -- maple-leaf syrup bottle
	WhippedCream = 1110204444,  -- whipped cream swirl (topping)
	Strawberry = 5404875453,    -- strawberry with leaves (topping)
	Blueberry = 5567879375,     -- blueberry (topping)
	Butter = 110529888654605,   -- butter stick (topping + counter)
	Spatula = 230504041,        -- spatula (counter decoration)
	ShopStall = 4901101728,     -- candy-striped sweet stand (the shop)
}
GameConfig.ShopStallTurn = 180 -- degrees; change to 0, 90 or 270 if the shop stall faces the wrong way

--------------------------------------------------------------------
-- HELPERS
--------------------------------------------------------------------
-- 1234 -> "1.2K", 5600000 -> "5.6M"
function GameConfig.FormatNumber(n)
	local suffixes = { "", "K", "M", "B", "T", "Qa", "Qi" }
	local i = 1
	while n >= 1000 and i < #suffixes do
		n /= 1000
		i += 1
	end
	if i == 1 then
		return tostring(math.floor(n))
	end
	local text = string.format("%.1f", n):gsub("%.0$", "")
	return text .. suffixes[i]
end

return GameConfig
