-- WorldBuilder (ModuleScript in ServerScriptService)
-- Builds the island the game takes place on, in a bright low-poly tycoon style:
--   * a grass island with a sand beach, surrounded by real (terrain) water
--   * blocky cliffs with trees and rocks around the edges
--   * a long path from the spawn (south) to the market hub (north), with a fountain plaza in the middle
--   * 6 plots (3 on each side of the path) with a restaurant on each, doors facing the path
--   * trees, bushes, flowers and pebbles scattered around
-- Everything is made from basic parts, so no uploads are needed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))

local WorldBuilder = {}

local ISLAND = GameConfig.Island
local FLAT = CFrame.Angles(0, 0, math.rad(90)) -- stands a cylinder upright
local WHITE = Color3.new(1, 1, 1)
local GRASS = Color3.fromRGB(110, 205, 70)
local PLOT_GRASS = Color3.fromRGB(150, 225, 105)
local SAND = Color3.fromRGB(240, 215, 150)
local PATH = Color3.fromRGB(230, 205, 165)
local PATH_EDGE = Color3.fromRGB(200, 170, 130)
local DIRT = Color3.fromRGB(185, 120, 80)
local ROCK = Color3.fromRGB(150, 150, 155)
local LEAF_GREENS = {
	Color3.fromRGB(120, 210, 70), Color3.fromRGB(95, 190, 60), Color3.fromRGB(150, 225, 80), Color3.fromRGB(70, 165, 60),
}
local FLOWER_COLORS = {
	Color3.fromRGB(255, 90, 110), Color3.fromRGB(255, 210, 60), Color3.fromRGB(250, 250, 250),
	Color3.fromRGB(190, 120, 255), Color3.fromRGB(255, 150, 60),
}

local function newPart(parent, props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = Enum.Material.SmoothPlastic
	if props.Shape then
		part.Shape = props.Shape
	end
	for key, value in pairs(props) do
		if key ~= "Shape" then
			part[key] = value
		end
	end
	part.Parent = parent
	return part
end

-- A flat slab from (x1, z1) to (x2, z2) with its top at height top
local function slab(parent, name, x1, z1, x2, z2, top, thickness, color, material)
	return newPart(parent, {
		Name = name,
		Size = Vector3.new(math.abs(x2 - x1), thickness, math.abs(z2 - z1)),
		CFrame = CFrame.new((x1 + x2) / 2, top - thickness / 2, (z1 + z2) / 2),
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
	})
end

local function signText(part, face, text, color)
	local surface = Instance.new("SurfaceGui")
	surface.Face = face
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud -- keeps text from stretching on wide signs
	surface.PixelsPerStud = 40
	surface.LightInfluence = 0
	surface.Parent = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color or WHITE
	label.TextStrokeTransparency = 0
	label.Text = text
	label.Parent = surface
end

--------------------------------------------------------------------
-- NATURE (low-poly trees, bushes, rocks, flowers)
--------------------------------------------------------------------
local function roundTree(parent, position, rng, scale)
	scale = scale or 1
	local model = Instance.new("Model")
	model.Name = "Tree"
	local height = (5 + rng:NextNumber() * 3) * scale
	newPart(model, { Name = "Trunk", Size = Vector3.new(1.1, height, 1.1) * Vector3.new(scale, 1, scale),
		CFrame = CFrame.new(position + Vector3.new(0, height / 2, 0)), Color = Color3.fromRGB(140, 95, 60) })
	local green = LEAF_GREENS[rng:NextInteger(1, #LEAF_GREENS)]
	for i = 1, 3 do
		local size = (3.5 + rng:NextNumber() * 2.5) * scale
		newPart(model, { Name = "Leaves", Size = Vector3.new(size, size * 0.85, size),
			CFrame = CFrame.new(position + Vector3.new(rng:NextNumber(-1.3, 1.3) * scale, height + rng:NextNumber(-0.5, 1.8) * scale, rng:NextNumber(-1.3, 1.3) * scale))
				* CFrame.Angles(0, rng:NextNumber() * math.pi, rng:NextNumber(-0.2, 0.2)),
			Color = green:Lerp(Color3.fromRGB(60, 140, 50), (i - 1) * 0.12) })
	end
	model.Parent = parent
end

local function pineTree(parent, position, rng, scale)
	scale = scale or 1
	local model = Instance.new("Model")
	model.Name = "Pine"
	newPart(model, { Name = "Trunk", Size = Vector3.new(0.9, 3, 0.9) * scale, CFrame = CFrame.new(position + Vector3.new(0, 1.5 * scale, 0)),
		Color = Color3.fromRGB(120, 80, 50) })
	local green = Color3.fromRGB(50, 150 + rng:NextInteger(0, 30), 70)
	local spin = rng:NextNumber() * math.pi
	for i = 1, 3 do
		local width = (5.5 - i * 1.4) * scale
		newPart(model, { Name = "Needles", Size = Vector3.new(width, 2.8 * scale, width),
			CFrame = CFrame.new(position + Vector3.new(0, (2 + i * 2.2) * scale, 0)) * CFrame.Angles(0, spin + i * 0.4, 0),
			Color = green:Lerp(Color3.fromRGB(110, 200, 90), i * 0.12) })
	end
	model.Parent = parent
end

local function tree(parent, position, rng, scale)
	if rng:NextNumber() < 0.4 then
		pineTree(parent, position, rng, scale)
	else
		roundTree(parent, position, rng, scale)
	end
end

local function bush(parent, position, rng)
	local green = LEAF_GREENS[rng:NextInteger(1, #LEAF_GREENS)]
	for _ = 1, 2 do
		local size = 2 + rng:NextNumber() * 1.5
		newPart(parent, { Name = "Bush", Size = Vector3.new(size, size * 0.8, size),
			CFrame = CFrame.new(position + Vector3.new(rng:NextNumber(-0.8, 0.8), size * 0.35, rng:NextNumber(-0.8, 0.8)))
				* CFrame.Angles(0, rng:NextNumber() * math.pi, 0), Color = green })
	end
end

local function rock(parent, position, rng, scale)
	scale = scale or 1
	local size = Vector3.new(rng:NextNumber(2, 4), rng:NextNumber(1.5, 3), rng:NextNumber(2, 4)) * scale
	newPart(parent, { Name = "Rock", Size = size,
		CFrame = CFrame.new(position + Vector3.new(0, size.Y * 0.35, 0)) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber() * math.pi, rng:NextNumber(-0.3, 0.3)),
		Color = ROCK:Lerp(Color3.fromRGB(120, 125, 130), rng:NextNumber()), Material = Enum.Material.Slate })
end

local function flower(parent, position, rng)
	newPart(parent, { Name = "Stem", Size = Vector3.new(0.15, 0.7, 0.15), CFrame = CFrame.new(position + Vector3.new(0, 0.35, 0)),
		Color = Color3.fromRGB(70, 150, 60), CanCollide = false })
	newPart(parent, { Name = "Flower", Size = Vector3.new(0.5, 0.25, 0.5), CFrame = CFrame.new(position + Vector3.new(0, 0.75, 0)) * CFrame.Angles(0, rng:NextNumber() * math.pi, 0),
		Color = FLOWER_COLORS[rng:NextInteger(1, #FLOWER_COLORS)], CanCollide = false })
end

local function pebble(parent, position, rng)
	newPart(parent, { Name = "Pebble", Size = Vector3.new(rng:NextNumber(0.5, 1.2), 0.25, rng:NextNumber(0.5, 1.2)),
		CFrame = CFrame.new(position + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, rng:NextNumber() * math.pi, 0),
		Color = ROCK:Lerp(WHITE, rng:NextNumber() * 0.3), CanCollide = false })
end

-- A raised block of land at the island's edge with trees and rocks on top
local function cliff(parent, position, rng)
	local model = Instance.new("Model")
	model.Name = "Cliff"
	local pieces = rng:NextInteger(1, 3)
	for i = 1, pieces do
		local width = rng:NextNumber(12, 22)
		local depth = rng:NextNumber(12, 22)
		local height = rng:NextNumber(4, 12) + (i - 1) * 3
		local offset = Vector3.new(rng:NextNumber(-7, 7), 0, rng:NextNumber(-7, 7))
		local center = position + offset
		local spin = CFrame.Angles(0, rng:NextNumber(-0.3, 0.3), 0)
		newPart(model, { Name = "Dirt", Size = Vector3.new(width, height, depth), CFrame = CFrame.new(center + Vector3.new(0, height / 2 - 0.5, 0)) * spin,
			Color = DIRT:Lerp(Color3.fromRGB(160, 100, 65), rng:NextNumber()) })
		newPart(model, { Name = "GrassTop", Size = Vector3.new(width + 0.4, 1.2, depth + 0.4), CFrame = CFrame.new(center + Vector3.new(0, height - 0.4, 0)) * spin,
			Color = GRASS })
		local top = center + Vector3.new(0, height, 0)
		for _ = 1, rng:NextInteger(1, 3) do
			tree(model, top + Vector3.new(rng:NextNumber(-width / 3, width / 3), 0, rng:NextNumber(-depth / 3, depth / 3)), rng)
		end
		if rng:NextNumber() < 0.5 then
			rock(model, top + Vector3.new(rng:NextNumber(-width / 3, width / 3), 0, rng:NextNumber(-depth / 3, depth / 3)), rng, 1.3)
		end
	end
	model.Parent = parent
end

--------------------------------------------------------------------
-- LANDMARKS
--------------------------------------------------------------------
local function bench(parent, cframe)
	local model = Instance.new("Model")
	model.Name = "Bench"
	local wood = Color3.fromRGB(165, 105, 60)
	newPart(model, { Name = "Seat", Size = Vector3.new(5, 0.35, 1.4), CFrame = cframe * CFrame.new(0, 1.5, 0), Color = wood, Material = Enum.Material.Wood })
	newPart(model, { Name = "Back", Size = Vector3.new(5, 1.3, 0.3), CFrame = cframe * CFrame.new(0, 2.3, 0.6), Color = wood, Material = Enum.Material.Wood })
	for _, x in ipairs({ -2.1, 2.1 }) do
		newPart(model, { Name = "Leg", Size = Vector3.new(0.3, 1.5, 1.3), CFrame = cframe * CFrame.new(x, 0.75, 0.1), Color = Color3.fromRGB(90, 60, 40) })
	end
	model.Parent = parent
end

local function flowerBed(parent, center, width, depth, rng)
	newPart(parent, { Name = "FlowerBed", Size = Vector3.new(width, 0.8, depth), CFrame = CFrame.new(center + Vector3.new(0, 0.4, 0)),
		Color = Color3.fromRGB(185, 115, 70) })
	newPart(parent, { Name = "Soil", Size = Vector3.new(width - 0.8, 0.2, depth - 0.8), CFrame = CFrame.new(center + Vector3.new(0, 0.85, 0)),
		Color = Color3.fromRGB(110, 75, 50) })
	for _ = 1, math.floor(width * depth / 3) do
		flower(parent, center + Vector3.new(rng:NextNumber(-width / 2 + 0.8, width / 2 - 0.8), 0.9, rng:NextNumber(-depth / 2 + 0.8, depth / 2 - 0.8)), rng)
	end
end

local function fountain(parent, position)
	local model = Instance.new("Model")
	model.Name = "Fountain"
	local stone = Color3.fromRGB(235, 230, 220)
	local water = Color3.fromRGB(80, 200, 235)
	newPart(model, { Name = "Basin", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.4, 14, 14),
		CFrame = CFrame.new(position + Vector3.new(0, 0.7, 0)) * FLAT, Color = stone })
	newPart(model, { Name = "Water", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 12.6, 12.6),
		CFrame = CFrame.new(position + Vector3.new(0, 1.35, 0)) * FLAT, Color = water, Material = Enum.Material.Glass, Transparency = 0.2, CanCollide = false })
	newPart(model, { Name = "Pillar", Shape = Enum.PartType.Cylinder, Size = Vector3.new(4, 1.6, 1.6),
		CFrame = CFrame.new(position + Vector3.new(0, 3, 0)) * FLAT, Color = stone })
	newPart(model, { Name = "Bowl", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.8, 5, 5),
		CFrame = CFrame.new(position + Vector3.new(0, 5, 0)) * FLAT, Color = stone })
	newPart(model, { Name = "BowlWater", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.15, 4.4, 4.4),
		CFrame = CFrame.new(position + Vector3.new(0, 5.4, 0)) * FLAT, Color = water, Material = Enum.Material.Glass, Transparency = 0.2, CanCollide = false })
	for i = 1, 3 do -- a golden pancake statue on top
		newPart(model, { Name = "StatuePancake", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, 3 - i * 0.2, 3 - i * 0.2),
			CFrame = CFrame.new(position + Vector3.new(0, 5.8 + i * 0.52, 0)) * FLAT, Color = Color3.fromRGB(240, 190, 60), Material = Enum.Material.Metal })
	end
	newPart(model, { Name = "StatueButter", Size = Vector3.new(0.9, 0.5, 0.9), CFrame = CFrame.new(position + Vector3.new(0, 7.6, 0)),
		Color = Color3.fromRGB(255, 225, 90) })
	local spray = Instance.new("ParticleEmitter")
	spray.Texture = GameConfig.Textures.Sparkle
	spray.Color = ColorSequence.new(Color3.fromRGB(200, 240, 255))
	spray.Size = NumberSequence.new(0.5, 0.1)
	spray.Transparency = NumberSequence.new(0.3, 1)
	spray.Lifetime = NumberRange.new(0.8, 1.2)
	spray.Rate = 25
	spray.Speed = NumberRange.new(6, 9)
	spray.SpreadAngle = Vector2.new(25, 25)
	spray.Acceleration = Vector3.new(0, -18, 0)
	spray.EmissionDirection = Enum.NormalId.Right -- the cylinder is rotated, so "Right" points up
	spray.Parent = model:FindFirstChild("Pillar")
	model.Parent = parent
end

local function gazebo(parent, position)
	local model = Instance.new("Model")
	model.Name = "Gazebo"
	newPart(model, { Name = "Floor", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 20, 20),
		CFrame = CFrame.new(position + Vector3.new(0, 0.5, 0)) * FLAT, Color = WHITE })
	for i = 1, 8 do
		local angle = i / 8 * math.pi * 2
		newPart(model, { Name = "Pillar", Size = Vector3.new(0.8, 9, 0.8),
			CFrame = CFrame.new(position + Vector3.new(math.cos(angle) * 8.8, 5.5, math.sin(angle) * 8.8)), Color = WHITE })
	end
	for i = 1, 4 do -- a stepped round roof
		newPart(model, { Name = "Roof", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 22 - i * 5, 22 - i * 5),
			CFrame = CFrame.new(position + Vector3.new(0, 9.5 + i, 0)) * FLAT, Color = (i % 2 == 1) and Color3.fromRGB(230, 90, 90) or WHITE })
	end
	newPart(model, { Name = "Top", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.6, CFrame = CFrame.new(position + Vector3.new(0, 14.6, 0)),
		Color = Color3.fromRGB(255, 210, 60) })
	model.Parent = parent
end

local STALL_GOODS = {
	{ "🍯 SYRUP", Color3.fromRGB(200, 120, 40) },
	{ "🍓 BERRIES", Color3.fromRGB(220, 60, 80) },
	{ "🧈 BUTTER", Color3.fromRGB(240, 200, 60) },
	{ "🥛 MILK", Color3.fromRGB(90, 160, 230) },
}

local function stall(parent, cframe, goods, rng)
	local model = Instance.new("Model")
	model.Name = "Stall"
	local color = goods[2]
	newPart(model, { Name = "Counter", Size = Vector3.new(8, 3.2, 3), CFrame = cframe * CFrame.new(0, 1.6, 0), Color = Color3.fromRGB(190, 130, 80), Material = Enum.Material.WoodPlanks })
	for _, x in ipairs({ -3.8, 3.8 }) do
		newPart(model, { Name = "Post", Size = Vector3.new(0.4, 8, 0.4), CFrame = cframe * CFrame.new(x, 4, -1.3), Color = Color3.fromRGB(150, 100, 60) })
	end
	for i = 0, 3 do
		newPart(model, { Name = "Awning", Size = Vector3.new(2.02, 0.2, 4.2),
			CFrame = cframe * CFrame.new(-3 + i * 2, 8.1, 0.2) * CFrame.Angles(math.rad(18), 0, 0), Color = (i % 2 == 0) and color or WHITE })
	end
	local sign = newPart(model, { Name = "Sign", Size = Vector3.new(6, 1.4, 0.3), CFrame = cframe * CFrame.new(0, 9.3, -1.2), Color = color })
	signText(sign, Enum.NormalId.Back, goods[1], WHITE)
	for _ = 1, 5 do -- goods on the counter
		newPart(model, { Name = "Goods", Shape = Enum.PartType.Ball, Size = Vector3.one * rng:NextNumber(0.6, 1),
			CFrame = cframe * CFrame.new(rng:NextNumber(-3, 3), 3.6, rng:NextNumber(-0.8, 0.8)), Color = color:Lerp(WHITE, rng:NextNumber() * 0.3) })
	end
	model.Parent = parent
end

--------------------------------------------------------------------
-- RESTAURANT BUILDINGS (a shell around each kitchen)
--------------------------------------------------------------------
-- cframe = the kitchen's ground CFrame (the stove is at its origin; local +Z = toward the front door).
-- Layout (local, looking down):
--   back  (z -6)  : kitchen with the stove, a fridge, a sink and shelves
--   left  (x -11) : the SERVICE COUNTER where customers order (with the stacking plate on it)
--   z 14          : a half wall between the kitchen and the dining room, with a gap to walk through
--   front (z 34)  : dining room with tables, then the front door (at x -14.5) and a big window
-- Any sign text named "RestaurantName" gets the owner's name.
WorldBuilder.RESTAURANT_DOOR = GameConfig.RestaurantDoor -- just outside the front door (local)

function WorldBuilder.BuildRestaurant(parent, cframe, theme)
	local model = Instance.new("Model")
	model.Name = "Building"
	local H = 22        -- tall ceiling so big flips don't hit it
	local HALF = 22     -- inside walls at x = +-22
	local BACK = -6.25
	local FRONT = 34
	local DEPTH = FRONT - BACK
	local MID = (FRONT + BACK) / 2
	local DOOR_X = -14.5
	local WOOD = Color3.fromRGB(165, 110, 65)
	local METAL = Color3.fromRGB(200, 200, 208)
	local function at(x, y, z)
		return cframe * CFrame.new(x, y, z)
	end
	local function block(name, width, height, depth, x, y, z, color, material)
		return newPart(model, { Name = name, Size = Vector3.new(width, height, depth), CFrame = at(x, y, z),
			Color = color, Material = material or Enum.Material.SmoothPlastic })
	end
	local function cylinder(name, height, diameter, x, y, z, color, material)
		return newPart(model, { Name = name, Shape = Enum.PartType.Cylinder, Size = Vector3.new(height, diameter, diameter),
			CFrame = at(x, y, z) * FLAT, Color = color, Material = material or Enum.Material.SmoothPlastic })
	end

	------------------------------------------------------------------ shell
	block("Floor", HALF * 2, 0.18, DEPTH, 0, 0.09, MID, Color3.fromRGB(200, 155, 105), Enum.Material.WoodPlanks)
	block("KitchenFloor", 31.5, 0.19, 20, 6.25, 0.095, 3.75, Color3.fromRGB(225, 225, 230)) -- x -9.5..22, z -6.25..13.75
	block("BackWall", HALF * 2 + 1, H, 1, 0, H / 2, BACK - 0.5, theme.Wall)
	for _, side in ipairs({ -1, 1 }) do
		block("SideWall", 1, H, DEPTH + 1, side * (HALF + 0.5), H / 2, MID, theme.Wall)
		block("OutsideSkin", 0.2, H, DEPTH + 1.2, side * (HALF + 1.1), H / 2, MID, theme.Outside)
	end
	block("Roof", HALF * 2 + 2.5, 1, DEPTH + 2.5, 0, H + 0.5, MID, theme.Outside:Lerp(Color3.new(0, 0, 0), 0.15))
	block("RoofTrim", HALF * 2 + 2.5, 1.2, 0.8, 0, H + 1.1, FRONT + 0.6, theme.Accent)

	------------------------------------------------------------------ front: door, window, awning, sign
	local outside = theme.Outside
	block("Front", 4.5, H, 1, -19.75, H / 2, FRONT, outside)                 -- x -22..-17.5
	block("Front", 6, H - 9, 1, DOOR_X, 9 + (H - 9) / 2, FRONT, outside)      -- above the door
	block("Front", 3.5, H, 1, -9.75, H / 2, FRONT, outside)                  -- x -11.5..-8
	block("Front", 26, 3, 1, 5, 1.5, FRONT, outside)                         -- under the window
	block("Front", 26, H - 11, 1, 5, 11 + (H - 11) / 2, FRONT, outside)      -- above the window
	block("Front", 4, H, 1, 20, H / 2, FRONT, outside)                       -- x 18..22
	newPart(model, { Name = "Window", Size = Vector3.new(26, 8, 0.3), CFrame = at(5, 7, FRONT),
		Color = Color3.fromRGB(170, 225, 245), Material = Enum.Material.Glass, Transparency = 0.5 })
	for _, x in ipairs({ -1.5, 5, 11.5 }) do
		block("Mullion", 0.3, 8, 0.5, x, 7, FRONT + 0.1, theme.Accent)
	end
	block("DoorFrame", 0.5, 9, 1.2, DOOR_X - 3, 4.5, FRONT, theme.Accent)
	block("DoorFrame", 0.5, 9, 1.2, DOOR_X + 3, 4.5, FRONT, theme.Accent)
	block("DoorFrame", 6.5, 0.5, 1.2, DOOR_X, 9, FRONT, theme.Accent)
	block("WelcomeMat", 5, 0.1, 2.5, DOOR_X, 0.2, FRONT + 2, theme.Accent, Enum.Material.Fabric)
	for i = 0, 12 do
		newPart(model, { Name = "Awning", Size = Vector3.new(2.02, 0.2, 3.6),
			CFrame = at(-7 + i * 2, 12.3, FRONT + 1.6) * CFrame.Angles(math.rad(25), 0, 0),
			Color = (i % 2 == 0) and theme.Accent or WHITE, Material = Enum.Material.Fabric })
	end
	local sign = newPart(model, { Name = "Sign", Size = Vector3.new(28, 4.5, 0.6), CFrame = at(2, 17, FRONT + 0.8), Color = theme.Accent })
	signText(sign, Enum.NormalId.Back, "🥞 " .. theme.Name, WHITE, "RestaurantName")
	block("SignTrim", 28.6, 0.4, 0.8, 2, 14.6, FRONT + 0.8, WHITE)
	block("SignTrim", 28.6, 0.4, 0.8, 2, 19.4, FRONT + 0.8, WHITE)

	-- a giant pancake stack on the roof
	for i = 1, 3 do
		cylinder("RoofPancake", 1.4, 10 - i * 0.5, 12, H + 1 + i * 1.45, 20, Color3.fromRGB(225, 165, 75))
	end
	block("RoofButter", 2.6, 1.2, 2.6, 12, H + 6.6, 20, Color3.fromRGB(255, 225, 90))
	cylinder("RoofSyrup", 0.2, 7.5, 12, H + 5.75, 20, Color3.fromRGB(160, 85, 25))

	------------------------------------------------------------------ service counter (customers order here)
	block("ServiceCounter", 3, 3.6, 17, -11, 1.8, 5.5, theme.Accent)          -- z -3..14
	block("ServiceCounterPanel", 0.2, 2.2, 15.5, -12.6, 1.8, 5.5, WHITE)      -- stripe on the customer side
	block("ServiceCounterTop", 3.6, 0.3, 17.6, -11, 3.75, 5.5, WOOD, Enum.Material.Wood)
	-- cash register
	block("Register", 1.4, 0.9, 1.2, -11, 4.35, 10.5, Color3.fromRGB(60, 60, 70))
	block("RegisterScreen", 0.1, 0.6, 0.9, -11.75, 4.9, 10.5, Color3.fromRGB(120, 230, 160))
	-- a glass pastry case with little pancakes inside
	newPart(model, { Name = "PastryCase", Size = Vector3.new(2.4, 1.6, 3), CFrame = at(-11, 4.7, -1.2),
		Color = Color3.fromRGB(200, 235, 250), Material = Enum.Material.Glass, Transparency = 0.6 })
	for i = 0, 2 do
		cylinder("DisplayPancake", 0.25, 1.1, -11, 4.05 + i * 0.27, -1.2, Color3.fromRGB(220, 155, 70))
	end
	cylinder("TipJar", 0.9, 0.6, -11, 4.35, 12.8, Color3.fromRGB(200, 235, 250), Enum.Material.Glass).Transparency = 0.4
	-- "ORDER HERE" sign hanging over the counter, facing the customers
	local orderSign = newPart(model, { Name = "OrderSign", Size = Vector3.new(0.3, 1.8, 6), CFrame = at(-11, 9.5, 5.5), Color = WHITE })
	signText(orderSign, Enum.NormalId.Left, "📋 ORDER HERE", theme.Accent, "OrderHere")
	for _, z in ipairs({ 3, 8 }) do
		block("SignChain", 0.1, 12.5 - 10.4, 0.1, -11, 10.4 + (H - 10.4) / 2, z, Color3.fromRGB(90, 90, 95), Enum.Material.Metal)
	end

	------------------------------------------------------------------ half wall between kitchen and dining room
	block("HalfWall", 19.5, 4, 0.6, 0.25, 2, 14, theme.Wall)     -- x -9.5..10
	block("HalfWall", 7, 4, 0.6, 18.5, 2, 14, theme.Wall)        -- x 15..22 (gap at x 10..15 to walk in)
	block("HalfWallTop", 19.9, 0.3, 1, 0.25, 4.15, 14, WOOD, Enum.Material.Wood)
	block("HalfWallTop", 7.4, 0.3, 1, 18.5, 4.15, 14, WOOD, Enum.Material.Wood)
	local staffSign = newPart(model, { Name = "StaffSign", Size = Vector3.new(4.6, 1.2, 0.2), CFrame = at(12.5, 8.5, 14.2), Color = theme.Accent })
	signText(staffSign, Enum.NormalId.Back, "👨‍🍳 KITCHEN", WHITE, "KitchenSign")

	------------------------------------------------------------------ kitchen appliances along the back
	-- fridge
	block("Fridge", 4, 8.5, 3.4, 19.4, 4.25, -4.2, METAL, Enum.Material.Metal)
	block("FridgeDoorLine", 4.05, 0.1, 0.1, 19.4, 5.8, -2.45, Color3.fromRGB(150, 150, 158))
	block("FridgeHandle", 0.25, 2.2, 0.3, 17.8, 6.9, -2.35, Color3.fromRGB(120, 120, 128), Enum.Material.Metal)
	block("FridgeHandle", 0.25, 2.2, 0.3, 17.8, 3.6, -2.35, Color3.fromRGB(120, 120, 128), Enum.Material.Metal)
	-- sink counter
	block("SinkCounter", 6, 3.5, 3, 13, 1.75, -4.4, WHITE)
	block("SinkTop", 6.2, 0.3, 3.2, 13, 3.65, -4.4, Color3.fromRGB(60, 60, 65), Enum.Material.Granite)
	block("Sink", 2.6, 0.2, 1.8, 13, 3.72, -4.2, METAL, Enum.Material.Metal)
	block("Faucet", 0.25, 1.4, 0.25, 13, 4.5, -5.3, METAL, Enum.Material.Metal)
	block("FaucetSpout", 0.25, 0.25, 0.9, 13, 5.1, -4.95, METAL, Enum.Material.Metal)
	-- wall oven
	block("Oven", 3.5, 7, 3, -16.5, 3.5, -4.5, Color3.fromRGB(50, 50, 55), Enum.Material.Metal)
	block("OvenWindow", 2.6, 1.8, 0.1, -16.5, 2.3, -2.95, Color3.fromRGB(255, 150, 60))
	block("OvenWindow", 2.6, 1.8, 0.1, -16.5, 5.2, -2.95, Color3.fromRGB(255, 150, 60))
	-- shelves on the kitchen's side wall
	for _, y in ipairs({ 6.5, 9 }) do
		block("KitchenShelf", 1.2, 0.2, 9, 21.4, y, 4, WOOD, Enum.Material.Wood)
		for i = 0, 3 do
			cylinder("Jar", 1, 0.7, 21.4, y + 0.6, 0.8 + i * 2.1, (i % 2 == 0) and Color3.fromRGB(255, 190, 60) or Color3.fromRGB(245, 240, 225))
		end
	end
	-- hanging pots and pans rail over the stove area
	block("PotRail", 12, 0.2, 0.2, 0, 13, -2, METAL, Enum.Material.Metal)
	for i = 0, 3 do
		cylinder("HangingPan", 0.2, 1.6, -4.5 + i * 3, 12, -2, Color3.fromRGB(45, 45, 50), Enum.Material.Metal)
	end

	------------------------------------------------------------------ dining room (keeps the lane from the door to the counter clear)
	for _, spot in ipairs({ Vector3.new(0, 0, 21), Vector3.new(9, 0, 21), Vector3.new(0, 0, 28.5), Vector3.new(9, 0, 28.5) }) do
		cylinder("TableTop", 0.3, 3.6, spot.X, 3, spot.Z, WHITE, Enum.Material.Marble)
		cylinder("TableLeg", 3, 0.4, spot.X, 1.5, spot.Z, Color3.fromRGB(60, 60, 65), Enum.Material.Metal)
		for _, dx in ipairs({ -2.7, 2.7 }) do
			cylinder("Stool", 0.4, 1.8, spot.X + dx, 2, spot.Z, theme.Accent)
			cylinder("StoolLeg", 2, 0.3, spot.X + dx, 1, spot.Z, Color3.fromRGB(60, 60, 65), Enum.Material.Metal)
		end
		cylinder("LampShade", 1.2, 2.4, spot.X, 15, spot.Z, theme.Accent)
		block("LampCord", 0.1, H - 15.6, 0.1, spot.X, 15.6 + (H - 15.6) / 2, spot.Z, Color3.fromRGB(40, 40, 45))
	end
	-- a booth along the right wall
	block("BoothSeat", 3, 1.8, 12, 19.5, 0.9, 25, theme.Accent, Enum.Material.Fabric)
	block("BoothBack", 1, 4, 12, 21.4, 2, 25, theme.Accent, Enum.Material.Fabric)
	block("BoothTable", 3, 0.3, 10, 16.3, 3, 25, WHITE, Enum.Material.Marble)
	block("BoothTableLeg", 0.6, 2.8, 0.6, 16.3, 1.5, 25, Color3.fromRGB(60, 60, 65), Enum.Material.Metal)
	-- plants in the front corners
	for _, x in ipairs({ -20, 20 }) do
		cylinder("PlantPot", 2, 2.4, x, 1, 32, Color3.fromRGB(190, 110, 70))
		for i = 1, 3 do
			newPart(model, { Name = "PlantLeaves", Size = Vector3.one * (2.2 - i * 0.3), CFrame = at(x + (i - 2) * 0.5, 2.3 + i * 0.9, 32) * CFrame.Angles(0, i, 0.2),
				Color = LEAF_GREENS[i] })
		end
	end
	-- menu board on the left wall, facing the room
	local menu = newPart(model, { Name = "MenuBoard", Size = Vector3.new(0.3, 5, 9), CFrame = at(-21.8, 11, 22), Color = Color3.fromRGB(40, 40, 45) })
	signText(menu, Enum.NormalId.Right, "MENU\n🥞 Pancakes\n🧈 Butter\n🍓 Toppings", WHITE, "Menu")

	model.Parent = parent
	return model
end

--------------------------------------------------------------------
-- THE ISLAND
--------------------------------------------------------------------
-- Rectangles (x1, z1, x2, z2) where nothing random should be placed
local function isClear(blocked, x, z, margin)
	for _, r in ipairs(blocked) do
		if x > r[1] - margin and x < r[3] + margin and z > r[2] - margin and z < r[4] + margin then
			return false
		end
	end
	return true
end

function WorldBuilder.Build()
	local world = Instance.new("Model")
	world.Name = "Island"
	local rng = Random.new(2026)
	local W, NORTH, SOUTH = ISLAND.LandHalfWidth, ISLAND.LandNorth, ISLAND.LandSouth
	local P = ISLAND.PathHalfWidth
	local spawn, hub = ISLAND.Spawn, ISLAND.Hub

	-- no more baseplate: the island sits in the sea
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate then
		baseplate:Destroy()
	end

	-- the sea (real terrain water, with a sandy sea floor)
	local terrain = workspace.Terrain
	terrain.WaterColor = Color3.fromRGB(35, 190, 225)
	terrain.WaterTransparency = 0.55
	terrain.WaterReflectance = 0.4
	terrain.WaterWaveSize = 0.12
	terrain.WaterWaveSpeed = 8
	terrain:FillBlock(CFrame.new(0, -18, 0), Vector3.new(1400, 6, 1400), Enum.Material.Sand)
	terrain:FillBlock(CFrame.new(0, -8.5, 0), Vector3.new(1400, 13, 1400), Enum.Material.Water)

	local ground = Instance.new("Folder")
	ground.Name = "Ground"
	ground.Parent = world

	-- land and beach
	slab(ground, "Beach", -W - 14, NORTH - 14, W + 14, SOUTH + 14, -0.4, 14, SAND, Enum.Material.Sand)
	slab(ground, "Grass", -W, NORTH, W, SOUTH, 0, 14, GRASS)

	-- the main path and its edges
	slab(ground, "Path", -P, hub.Z + 20, P, spawn.Z - 20, 0.15, 0.3, PATH)
	for _, side in ipairs({ -1, 1 }) do
		slab(ground, "PathEdge", side * P - 0.6, hub.Z + 20, side * P + 0.6, spawn.Z - 20, 0.2, 0.3, PATH_EDGE)
	end

	-- the plots, a path to each door, and the restaurant lawns
	local blocked = {
		{ -P - 3, hub.Z - 30, P + 3, spawn.Z + 30 }, -- main path
	}
	local plotsFolder = Instance.new("Folder")
	plotsFolder.Name = "Plots"
	plotsFolder.Parent = world
	for index = 1, GameConfig.StationCount do
		local cframe = GameConfig.GetStationCFrame(index)
		local origin = cframe.Position
		local side = (origin.X < 0) and -1 or 1
		local x1, x2 = side * 12, side * (W - 8)
		slab(plotsFolder, "Plot", math.min(x1, x2), origin.Z - 34, math.max(x1, x2), origin.Z + 34, 0.12, 0.3, PLOT_GRASS)
		table.insert(blocked, { math.min(x1, x2), origin.Z - 34, math.max(x1, x2), origin.Z + 34 })
		-- path from the main path to the front door
		local door = (cframe * CFrame.new(WorldBuilder.RESTAURANT_DOOR)).Position
		slab(plotsFolder, "DoorPath", math.min(side * P, door.X), door.Z - 3.5, math.max(side * P, door.X), door.Z + 3.5, 0.17, 0.3, PATH)
		-- pebbles and flowers scattered over the plot (away from the building)
		for _ = 1, 40 do
			local x = side * rng:NextNumber(14, W - 12)
			local z = origin.Z + rng:NextNumber(-32, 32)
			local localPoint = cframe:PointToObjectSpace(Vector3.new(x, 0, z))
			local onBuilding = math.abs(localPoint.X) < 25 and localPoint.Z > -9 and localPoint.Z < 39
			if not onBuilding then
				if rng:NextNumber() < 0.6 then
					pebble(plotsFolder, Vector3.new(x, 0.27, z), rng)
				else
					flower(plotsFolder, Vector3.new(x, 0.27, z), rng)
				end
			end
		end
		-- a couple of trees in the back yard
		for _ = 1, 3 do
			local back = cframe * CFrame.new(rng:NextNumber(-22, 22), 0, rng:NextNumber(-30, -13))
			if math.abs(back.Position.X) < W - 10 then
				tree(plotsFolder, back.Position + Vector3.new(0, 0.27, 0), rng)
			end
		end
	end

	local landmarks = Instance.new("Folder")
	landmarks.Name = "Landmarks"
	landmarks.Parent = world

	-- SPAWN PLAZA with a welcome arch
	slab(ground, "SpawnPlaza", -32, spawn.Z - 22, 32, spawn.Z + 25, 0.18, 0.3, PATH)
	table.insert(blocked, { -34, spawn.Z - 24, 34, spawn.Z + 27 })
	for _, x in ipairs({ -9, 9 }) do
		newPart(landmarks, { Name = "ArchPillar", Size = Vector3.new(2.5, 16, 2.5), CFrame = CFrame.new(x, 8, spawn.Z - 22),
			Color = Color3.fromRGB(255, 190, 70) })
	end
	local arch = newPart(landmarks, { Name = "ArchSign", Size = Vector3.new(24, 4.5, 1.5), CFrame = CFrame.new(0, 17, spawn.Z - 22),
		Color = Color3.fromRGB(230, 90, 60) })
	signText(arch, Enum.NormalId.Front, "🥞 FLIP THE PANCAKE! 🥞", WHITE)
	signText(arch, Enum.NormalId.Back, "🥞 WELCOME! 🥞", WHITE)
	for _, x in ipairs({ -26, 26 }) do
		flowerBed(landmarks, Vector3.new(x, 0.18, spawn.Z), 6, 14, rng)
	end
	for _, x in ipairs({ -18, 18 }) do
		bench(landmarks, CFrame.new(x, 0.18, spawn.Z + 18) * CFrame.Angles(0, math.pi, 0))
	end

	-- CENTER PLAZA with the fountain (between the middle plots)
	local center = Vector3.new(0, 0, ISLAND.PlotRows[2])
	slab(ground, "CenterPlaza", -20, center.Z - 20, 20, center.Z + 20, 0.2, 0.3, PATH)
	slab(ground, "CenterPlazaEdge", -21, center.Z - 21, 21, center.Z + 21, 0.1, 0.3, Color3.fromRGB(190, 120, 80))
	fountain(landmarks, center + Vector3.new(0, 0.2, 0))
	for _, corner in ipairs({ Vector3.new(-14, 0, -14), Vector3.new(14, 0, -14), Vector3.new(-14, 0, 14), Vector3.new(14, 0, 14) }) do
		flowerBed(landmarks, center + corner + Vector3.new(0, 0.2, 0), 7, 7, rng)
	end
	for _, dz in ipairs({ -9, 9 }) do
		bench(landmarks, CFrame.new(-10, 0.2, center.Z + dz) * CFrame.Angles(0, math.rad(90), 0))
		bench(landmarks, CFrame.new(10, 0.2, center.Z + dz) * CFrame.Angles(0, math.rad(-90), 0))
	end

	-- MARKET HUB at the north end: a gazebo and stalls
	slab(ground, "HubPlaza", -40, hub.Z - 28, 40, hub.Z + 22, 0.2, 0.3, PATH)
	table.insert(blocked, { -42, hub.Z - 30, 42, hub.Z + 24 })
	gazebo(landmarks, hub + Vector3.new(0, 0.2, -4))
	for i, goods in ipairs(STALL_GOODS) do
		local x = (i <= 2) and -28 or 28
		local z = hub.Z + ((i % 2 == 1) and -14 or 8)
		local facing = (x < 0) and math.rad(90) or math.rad(-90)
		stall(landmarks, CFrame.new(x, 0.2, z) * CFrame.Angles(0, facing, 0), goods, rng)
	end

	-- the restaurant buildings' footprints are handled by the plots above;
	-- CLIFFS around the edges (leaving the path ends open)
	local cliffs = Instance.new("Folder")
	cliffs.Name = "Cliffs"
	cliffs.Parent = world
	for z = NORTH + 20, SOUTH - 20, 34 do
		for _, side in ipairs({ -1, 1 }) do
			if rng:NextNumber() < 0.8 then
				cliff(cliffs, Vector3.new(side * (W - rng:NextNumber(2, 10)), 0, z + rng:NextNumber(-8, 8)), rng)
			end
		end
	end
	for x = -W + 20, W - 20, 30 do
		if math.abs(x) > 48 then
			cliff(cliffs, Vector3.new(x + rng:NextNumber(-6, 6), 0, NORTH + rng:NextNumber(2, 10)), rng)
			cliff(cliffs, Vector3.new(x + rng:NextNumber(-6, 6), 0, SOUTH - rng:NextNumber(2, 10)), rng)
		end
	end

	-- trees, bushes and rocks on the open grass
	local nature = Instance.new("Folder")
	nature.Name = "Nature"
	nature.Parent = world
	local placed = 0
	for _ = 1, 400 do
		if placed >= 70 then break end
		local x = rng:NextNumber(-W + 20, W - 20)
		local z = rng:NextNumber(NORTH + 20, SOUTH - 20)
		if isClear(blocked, x, z, 4) and math.abs(z - center.Z) > 26 then
			local roll = rng:NextNumber()
			if roll < 0.55 then
				tree(nature, Vector3.new(x, 0, z), rng)
			elseif roll < 0.85 then
				bush(nature, Vector3.new(x, 0, z), rng)
			else
				rock(nature, Vector3.new(x, 0, z), rng)
			end
			placed += 1
		end
	end
	-- a row of little trees along the path
	local function awayFromDoors(z)
		for _, row in ipairs(ISLAND.PlotRows) do
			if math.abs(z - row) < 14 then
				return false
			end
		end
		return math.abs(z - center.Z) > 26
	end
	for z = hub.Z + 30, spawn.Z - 30, 26 do
		if awayFromDoors(z) then
			tree(nature, Vector3.new(-P - 4, 0, z), rng, 0.6)
		end
		if awayFromDoors(z + 13) then
			tree(nature, Vector3.new(P + 4, 0, z + 13), rng, 0.6)
		end
	end

	world.Parent = workspace
	return world
end

return WorldBuilder
