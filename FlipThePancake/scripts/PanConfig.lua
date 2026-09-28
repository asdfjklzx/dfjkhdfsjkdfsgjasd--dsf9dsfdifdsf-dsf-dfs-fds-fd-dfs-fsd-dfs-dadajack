-- PanConfig (ModuleScript in ReplicatedStorage)
-- Better pans cook faster, widen the PERFECT zone and multiply your Butter.
--   CookSpeed    = how much faster pancakes cook (2 = twice as fast)
--   PerfectBonus = how much wider the PERFECT zone gets on each side (0.01 = 1% of the meter)
--   Multiplier   = Butter multiplier
--   Particles    = optional effect on the pan: "Sparkle", "Shine", "Fire" or "Stars"
--   RimColor / RimMaterial / LipColor / LipMaterial = optional looks for the pan's wall and top edge

local PanConfig = {}

PanConfig.Items = {
	{ Id = "Rusty", Rarity = "Common", Name = "Rusty Pan", Price = 0, CookSpeed = 1.0, PerfectBonus = 0, Multiplier = 1,
		Color = Color3.fromRGB(125, 80, 55), Material = Enum.Material.CorrodedMetal,
		Description = "It works... mostly." },
	{ Id = "Nonstick", Rarity = "Common", Name = "Nonstick Pan", Price = 250, CookSpeed = 1.2, PerfectBonus = 0.01, Multiplier = 1.1,
		Color = Color3.fromRGB(45, 45, 52), Material = Enum.Material.SmoothPlastic,
		Description = "Nothing sticks!" },
	{ Id = "CastIron", Rarity = "Uncommon", Name = "Cast Iron Skillet", Price = 1500, CookSpeed = 1.4, PerfectBonus = 0.02, Multiplier = 1.25,
		Color = Color3.fromRGB(32, 32, 34), Material = Enum.Material.Slate,
		Description = "Heavy, hot and reliable." },
	{ Id = "Copper", Rarity = "Rare", Name = "Copper Pan", Price = 8000, CookSpeed = 1.6, PerfectBonus = 0.03, Multiplier = 1.5,
		Color = Color3.fromRGB(210, 120, 70), Material = Enum.Material.Metal,
		Description = "Fancy chef stuff." },
	{ Id = "Golden", Rarity = "Epic", Name = "Golden Pan", Price = 40000, CookSpeed = 1.9, PerfectBonus = 0.04, Multiplier = 2,
		Color = Color3.fromRGB(255, 205, 60), Material = Enum.Material.Metal, Reflectance = 0.2, Particles = "Sparkle",
		Description = "Solid gold. Sparkles!" },
	{ Id = "Diamond", Rarity = "Legendary", Name = "Diamond Pan", Price = 200000, CookSpeed = 2.2, PerfectBonus = 0.05, Multiplier = 3,
		Color = Color3.fromRGB(175, 235, 255), Material = Enum.Material.Glass, Reflectance = 0.3, Particles = "Shine",
		Description = "Shiny, see-through, unbreakable." },
	{ Id = "Lava", Rarity = "Legendary", Name = "Lava Pan", Price = 1000000, CookSpeed = 2.6, PerfectBonus = 0.06, Multiplier = 5,
		Color = Color3.fromRGB(70, 40, 30), Material = Enum.Material.CrackedLava, Particles = "Fire",
		RimColor = Color3.fromRGB(45, 30, 25), RimMaterial = Enum.Material.Basalt,
		LipColor = Color3.fromRGB(255, 110, 30), LipMaterial = Enum.Material.Neon,
		Description = "Forged in a volcano. HOT." },
	{ Id = "Galaxy", Rarity = "Mythic", Name = "Galaxy Pan", Price = 5000000, CookSpeed = 3.0, PerfectBonus = 0.07, Multiplier = 8,
		Color = Color3.fromRGB(18, 14, 45), Material = Enum.Material.SmoothPlastic, Reflectance = 0.1, Particles = "Stars",
		RimColor = Color3.fromRGB(28, 20, 60), RimMaterial = Enum.Material.SmoothPlastic,
		LipColor = Color3.fromRGB(170, 90, 255), LipMaterial = Enum.Material.Neon,
		-- The galaxy picture on the cooking surface (galaxy_pan_texture.png).
		-- After you upload it to Roblox, paste its image ID here, like "rbxassetid://1234567890".
		SurfaceImage = "rbxassetid://109977644133765", -- galaxy_pan_texture.png, uploaded Sep 28 2026
		-- Until then, Studio on this PC shows a local copy so you can preview it:
		StudioPreviewImage = "rbxasset://textures/FlipThePancake/galaxy_pan.png",
		Description = "Cooks with the power of the stars." },
}

PanConfig.ById = {}
for _, item in ipairs(PanConfig.Items) do
	PanConfig.ById[item.Id] = item
end

return PanConfig
