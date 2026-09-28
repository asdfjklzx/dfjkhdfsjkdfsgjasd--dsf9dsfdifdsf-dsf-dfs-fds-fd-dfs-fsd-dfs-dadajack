-- PancakeConfig (ModuleScript in ReplicatedStorage)
-- Fancier pancakes are worth more but take longer to cook and have a smaller PERFECT zone.
--   BaseValue  = Butter per pancake (before multipliers)
--   CookTime   = seconds for the meter to go from raw to burnt (before the pan's speed)
--   Difficulty = how much smaller the PERFECT zone gets on each side
--   Raw/Cooked = batter color and golden-brown color
--   Bits       = little pieces mixed into the batter (berries, chips...)
--   Special    = "Rainbow", "Galaxy" or "Golden" for extra visuals

local PancakeConfig = {}

PancakeConfig.Items = {
	{ Id = "Classic", Rarity = "Common", Name = "Classic Buttermilk", Price = 0, BaseValue = 5, CookTime = 7, Difficulty = 0,
		Raw = Color3.fromRGB(250, 238, 200), Cooked = Color3.fromRGB(206, 136, 56),
		Description = "Fluffy and simple." },
	{ Id = "Blueberry", Rarity = "Common", Name = "Blueberry", Price = 500, BaseValue = 12, CookTime = 7, Difficulty = 0.005,
		Raw = Color3.fromRGB(245, 235, 212), Cooked = Color3.fromRGB(200, 140, 70),
		Bits = { Colors = { Color3.fromRGB(60, 70, 170), Color3.fromRGB(85, 60, 150) }, Count = 7, Size = 0.28, Shape = "Ball" },
		Description = "Bursting with berries." },
	{ Id = "ChocolateChip", Rarity = "Uncommon", Name = "Chocolate Chip", Price = 3000, BaseValue = 25, CookTime = 7.5, Difficulty = 0.01,
		Raw = Color3.fromRGB(245, 230, 195), Cooked = Color3.fromRGB(195, 130, 60),
		Bits = { Colors = { Color3.fromRGB(70, 40, 25) }, Count = 9, Size = 0.2, Shape = "Block" },
		Description = "Melty chocolate in every bite." },
	{ Id = "Strawberry", Rarity = "Uncommon", Name = "Strawberry", Price = 15000, BaseValue = 50, CookTime = 7.5, Difficulty = 0.012,
		Raw = Color3.fromRGB(255, 205, 215), Cooked = Color3.fromRGB(230, 140, 125),
		Bits = { Colors = { Color3.fromRGB(220, 40, 60) }, Count = 6, Size = 0.3, Shape = "Block" },
		Description = "Pretty in pink." },
	{ Id = "BananaNut", Rarity = "Rare", Name = "Banana Nut", Price = 50000, BaseValue = 90, CookTime = 8, Difficulty = 0.015,
		Raw = Color3.fromRGB(250, 240, 190), Cooked = Color3.fromRGB(205, 150, 70),
		Bits = { Colors = { Color3.fromRGB(150, 100, 55), Color3.fromRGB(245, 225, 150) }, Count = 8, Size = 0.22, Shape = "Block" },
		Description = "Nutty, crunchy, banana-y." },
	{ Id = "RedVelvet", Rarity = "Rare", Name = "Red Velvet", Price = 180000, BaseValue = 175, CookTime = 8, Difficulty = 0.018,
		Raw = Color3.fromRGB(200, 45, 60), Cooked = Color3.fromRGB(140, 25, 35),
		Bits = { Colors = { Color3.fromRGB(255, 250, 245) }, Count = 5, Size = 0.2, Shape = "Ball" },
		Description = "Deep red with cream cheese bits." },
	{ Id = "Matcha", Rarity = "Epic", Name = "Matcha", Price = 600000, BaseValue = 350, CookTime = 8.5, Difficulty = 0.02,
		Raw = Color3.fromRGB(195, 230, 150), Cooked = Color3.fromRGB(120, 160, 70),
		Description = "Green tea power." },
	{ Id = "Rainbow", Rarity = "Legendary", Name = "Rainbow", Price = 2500000, BaseValue = 800, CookTime = 8.5, Difficulty = 0.022,
		Raw = Color3.fromRGB(255, 250, 245), Cooked = Color3.fromRGB(235, 200, 160), Special = "Rainbow",
		Bits = { Colors = {
			Color3.fromRGB(255, 80, 80), Color3.fromRGB(255, 180, 50), Color3.fromRGB(255, 240, 80),
			Color3.fromRGB(90, 220, 110), Color3.fromRGB(80, 160, 255), Color3.fromRGB(190, 100, 255),
		}, Count = 14, Size = 0.18, Shape = "Block" },
		Description = "Every color at once!" },
	{ Id = "Galaxy", Rarity = "Mythic", Name = "Galaxy", Price = 10000000, BaseValue = 2000, CookTime = 9, Difficulty = 0.025,
		Raw = Color3.fromRGB(80, 55, 160), Cooked = Color3.fromRGB(40, 22, 95), Special = "Galaxy",
		Bits = { Colors = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(180, 220, 255) }, Count = 12, Size = 0.12, Shape = "Ball", Neon = true },
		Description = "Made of actual stars. Glows!" },
	{ Id = "Golden", Rarity = "Mythic", Name = "Golden Pancake", Price = 50000000, BaseValue = 5000, CookTime = 9, Difficulty = 0.03,
		Raw = Color3.fromRGB(255, 230, 130), Cooked = Color3.fromRGB(235, 180, 40), Special = "Golden",
		FaceMaterial = Enum.Material.Metal, FlipTolerance = 0.8,
		Description = "The legendary pancake. Hard to flip!" },
}

PancakeConfig.ById = {}
for _, item in ipairs(PancakeConfig.Items) do
	PancakeConfig.ById[item.Id] = item
end

return PancakeConfig
