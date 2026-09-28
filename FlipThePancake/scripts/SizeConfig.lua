-- SizeConfig (ModuleScript in ReplicatedStorage)
-- Bigger pans cook several pancakes at once. They're all flipped together, but each one lands
-- (or drops!) on its own and is scored separately.
--   Diameter  = size of each pancake
--   Shape     = "Round" pan (uses PanRadius) or "Griddle" (a flat plate, uses PlateSize)
--   Offsets   = where each pancake sits on the pan
--   ValueMultiplier / FlipTolerance = the Giant pan's special rules (worth more, harder to flip)

local SizeConfig = {}

SizeConfig.Items = {
	{ Id = "Small", Rarity = "Common", Name = "Small Pan", Price = 0, Count = 1, Diameter = 3.4,
		Shape = "Round", PanRadius = 2.25,
		Offsets = { Vector3.new(0, 0, 0) },
		Description = "One pancake at a time." },
	{ Id = "Medium", Rarity = "Uncommon", Name = "Medium Pan", Price = 1000, Count = 2, Diameter = 3.0,
		Shape = "Griddle", PlateSize = Vector2.new(7, 3.8),
		Offsets = { Vector3.new(-1.6, 0, 0), Vector3.new(1.6, 0, 0) },
		Description = "Two at once!" },
	{ Id = "Large", Rarity = "Rare", Name = "Large Pan", Price = 12000, Count = 3, Diameter = 2.6,
		Shape = "Griddle", PlateSize = Vector2.new(6.6, 5.4),
		Offsets = { Vector3.new(-1.4, 0, 0.9), Vector3.new(1.4, 0, 0.9), Vector3.new(0, 0, -1.4) },
		Description = "Three pancakes per flip." },
	{ Id = "Griddle", Rarity = "Epic", Name = "Griddle", Price = 150000, Count = 5, Diameter = 2.2,
		Shape = "Griddle", PlateSize = Vector2.new(7.6, 5.2),
		Offsets = {
			Vector3.new(-2.4, 0, 1.2), Vector3.new(0, 0, 1.2), Vector3.new(2.4, 0, 1.2),
			Vector3.new(-1.2, 0, -1.2), Vector3.new(1.2, 0, -1.2),
		},
		Description = "A proper diner griddle." },
	{ Id = "Mega", Rarity = "Legendary", Name = "MEGA Griddle", Price = 2000000, Count = 8, Diameter = 1.85,
		Shape = "Griddle", PlateSize = Vector2.new(8, 4.4),
		Offsets = {
			Vector3.new(-2.85, 0, 1), Vector3.new(-0.95, 0, 1), Vector3.new(0.95, 0, 1), Vector3.new(2.85, 0, 1),
			Vector3.new(-2.85, 0, -1), Vector3.new(-0.95, 0, -1), Vector3.new(0.95, 0, -1), Vector3.new(2.85, 0, -1),
		},
		Description = "EIGHT pancakes. Pure chaos." },
	{ Id = "Giant", Rarity = "Mythic", Name = "Giant Pancake Pan", Price = 25000000, Count = 1, Diameter = 5.4,
		Shape = "Round", PanRadius = 3.3,
		Offsets = { Vector3.new(0, 0, 0) },
		ValueMultiplier = 20, FlipTolerance = 0.6,
		Description = "ONE huge pancake worth 20x. Very hard to flip!" },
}

SizeConfig.ById = {}
for _, item in ipairs(SizeConfig.Items) do
	SizeConfig.ById[item.Id] = item
end

return SizeConfig
