-- ToppingConfig (ModuleScript in ReplicatedStorage)
-- Toppings are unlocked forever. Turn them on in your topping slots; each one adds a Butter bonus
-- and appears on your pancakes when you serve them.
--   Bonus = extra Butter (0.10 = +10%). Bonuses add together.

local ToppingConfig = {}

-- You get more topping slots as your all-time Butter grows
ToppingConfig.SlotThresholds = {
	{ TotalButter = 0, Slots = 1 },
	{ TotalButter = 5000, Slots = 2 },
	{ TotalButter = 100000, Slots = 3 },
	{ TotalButter = 2000000, Slots = 5 },
}

ToppingConfig.Items = {
	{ Id = "Syrup", Rarity = "Common", Name = "Maple Syrup", Price = 100, Bonus = 0.10, Description = "Sweet, sticky, classic." },
	{ Id = "Butter", Rarity = "Common", Name = "Butter Pat", Price = 400, Bonus = 0.15, Description = "A melty square of butter." },
	{ Id = "Cream", Rarity = "Uncommon", Name = "Whipped Cream", Price = 2000, Bonus = 0.25, Description = "A fluffy swirl on top." },
	{ Id = "Berries", Rarity = "Uncommon", Name = "Fresh Berries", Price = 10000, Bonus = 0.40, Description = "Strawberries and blueberries." },
	{ Id = "Chocolate", Rarity = "Rare", Name = "Chocolate Drizzle", Price = 35000, Bonus = 0.60, Description = "Rich chocolate zig-zags." },
	{ Id = "Sprinkles", Rarity = "Rare", Name = "Sprinkles", Price = 100000, Bonus = 0.80, Description = "A party on a pancake." },
	{ Id = "Banana", Rarity = "Epic", Name = "Caramelized Banana", Price = 400000, Bonus = 1.20, Description = "Golden banana slices." },
	{ Id = "GoldLeaf", Rarity = "Legendary", Name = "Gold Leaf", Price = 2000000, Bonus = 2.00, Description = "Real (pretend) gold flakes." },
	{ Id = "Cosmic", Rarity = "Mythic", Name = "Cosmic Syrup", Price = 20000000, Bonus = 4.00, Description = "Glowing syrup from space." },
}

ToppingConfig.ById = {}
for _, item in ipairs(ToppingConfig.Items) do
	ToppingConfig.ById[item.Id] = item
end

return ToppingConfig
