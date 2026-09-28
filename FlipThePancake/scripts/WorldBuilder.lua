-- WorldBuilder (ModuleScript in ServerScriptService)
-- Builds the island the game takes place on, in a bright low-poly tycoon style:
--   * a grass island with a sand beach, surrounded by real (terrain) water
--   * blocky cliffs with trees and rocks around the edges
--   * a long path from the spawn (south) to the market hub (north), with a fountain plaza in the middle
--   * 6 plots (3 on each side of the path) with a restaurant on each, doors facing the path
--   * trees, bushes, flowers and pebbles scattered around
-- Everything is made from basic parts, so no uploads are needed.
-- Every surface uses a real Roblox material (grass, cobblestone, brick, plaster, planks, shingles...)
-- and small trim pieces (curbs, sills, moldings, lamps, fences) add detail without blocking anyone.

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
local IRON = Color3.fromRGB(45, 48, 55)
local STONE = Color3.fromRGB(215, 205, 190)
local LAMP_GLOW = Color3.fromRGB(255, 225, 160)

-- Material by name, so a material Roblox doesn't know yet falls back to plastic instead of erroring
local function M(name)
	local ok, material = pcall(function()
		return Enum.Material[name]
	end)
	return ok and material or Enum.Material.SmoothPlastic
end
local MAT = {
	Grass = M("Grass"), Leafy = M("LeafyGrass"), Ground = M("Ground"), Rock = M("Rock"), Sand = M("Sand"),
	Cobble = M("Cobblestone"), Pavement = M("Pavement"), Brick = M("Brick"), Plaster = M("Plaster"),
	Planks = M("WoodPlanks"), Wood = M("Wood"), Shingles = M("RoofShingles"), ClayTiles = M("ClayRoofTiles"),
	Tiles = M("CeramicTiles"), Marble = M("Marble"), Granite = M("Granite"), Metal = M("Metal"),
	Iron = M("DiamondPlate"), Fabric = M("Fabric"), Glass = M("Glass"), Leather = M("Leather"),
	Concrete = M("Concrete"), Slate = M("Slate"), Sandstone = M("Sandstone"), Limestone = M("Limestone"),
	Carpet = M("Carpet"), Neon = M("Neon"), Foil = M("Foil"),
}
WorldBuilder.Material = M
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

local function signText(part, face, text, color, name)
	local surface = Instance.new("SurfaceGui")
	surface.Face = face
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud -- keeps text from stretching on wide signs
	surface.PixelsPerStud = 40
	surface.LightInfluence = 0
	surface.Parent = part
	local label = Instance.new("TextLabel")
	label.Name = name or "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color or WHITE
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.fromRGB(60, 35, 20)
	label.Text = text
	label.Parent = surface
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0.12, 0)
	padding.PaddingBottom = UDim.new(0.12, 0)
	padding.PaddingLeft = UDim.new(0.04, 0)
	padding.PaddingRight = UDim.new(0.04, 0)
	padding.Parent = label
	return label
end

-- Small decorative piece: never blocks walking, never casts a messy shadow
local function trim(parent, props)
	props.CanCollide = false
	props.CastShadow = props.CastShadow or false
	return newPart(parent, props)
end

-- A lantern on a pole with a warm light (glass box, iron cap and base)
local function lampPost(parent, position, height)
	height = height or 9
	local model = Instance.new("Model")
	model.Name = "LampPost"
	newPart(model, { Name = "Base", Size = Vector3.new(1.4, 0.8, 1.4), CFrame = CFrame.new(position + Vector3.new(0, 0.4, 0)), Color = IRON, Material = MAT.Metal })
	newPart(model, { Name = "Pole", Shape = Enum.PartType.Cylinder, Size = Vector3.new(height, 0.45, 0.45),
		CFrame = CFrame.new(position + Vector3.new(0, height / 2 + 0.6, 0)) * FLAT, Color = IRON, Material = MAT.Metal })
	for _, y in ipairs({ 1.4, height - 0.2 }) do
		trim(model, { Name = "Collar", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.25, 0.7, 0.7),
			CFrame = CFrame.new(position + Vector3.new(0, y, 0)) * FLAT, Color = IRON, Material = MAT.Metal })
	end
	local top = position + Vector3.new(0, height + 0.6, 0)
	trim(model, { Name = "LanternBase", Size = Vector3.new(1.3, 0.2, 1.3), CFrame = CFrame.new(top + Vector3.new(0, 0.1, 0)), Color = IRON, Material = MAT.Metal })
	local glass = trim(model, { Name = "Lantern", Size = Vector3.new(1, 1.4, 1), CFrame = CFrame.new(top + Vector3.new(0, 0.9, 0)),
		Color = LAMP_GLOW, Material = MAT.Glass, Transparency = 0.25 })
	for _, corner in ipairs({ Vector3.new(-0.5, 0, -0.5), Vector3.new(0.5, 0, -0.5), Vector3.new(-0.5, 0, 0.5), Vector3.new(0.5, 0, 0.5) }) do
		trim(model, { Name = "LanternFrame", Size = Vector3.new(0.12, 1.4, 0.12), CFrame = CFrame.new(top + Vector3.new(0, 0.9, 0) + corner),
			Color = IRON, Material = MAT.Metal })
	end
	trim(model, { Name = "LanternCap", Size = Vector3.new(1.4, 0.25, 1.4), CFrame = CFrame.new(top + Vector3.new(0, 1.7, 0)), Color = IRON, Material = MAT.Metal })
	trim(model, { Name = "LanternRoof", Size = Vector3.new(0.9, 0.3, 0.9), CFrame = CFrame.new(top + Vector3.new(0, 1.95, 0)) * CFrame.Angles(0, math.rad(45), 0),
		Color = IRON, Material = MAT.Metal })
	trim(model, { Name = "Finial", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.35, CFrame = CFrame.new(top + Vector3.new(0, 2.2, 0)), Color = IRON, Material = MAT.Metal })
	local light = Instance.new("PointLight")
	light.Color = LAMP_GLOW
	light.Range = 16
	light.Brightness = 0.8
	light.Shadows = false
	light.Parent = glass
	model.Parent = parent
	return model
end

-- A white picket fence from a to b (both on the ground), with posts and two rails
local function fence(parent, a, b, color)
	color = color or Color3.fromRGB(250, 248, 240)
	local length = (b - a).Magnitude
	if length < 1 then return end
	local model = Instance.new("Model")
	model.Name = "Fence"
	local along = CFrame.lookAt(a, b) -- -Z points from a to b
	for _, y in ipairs({ 0.9, 2 }) do
		trim(model, { Name = "Rail", Size = Vector3.new(0.15, 0.3, length), CFrame = along * CFrame.new(0, y, -length / 2), Color = color, Material = MAT.Wood })
	end
	local count = math.floor(length / 1.1)
	for i = 0, count do
		local z = -i * length / count
		local post = (i % 5 == 0)
		newPart(model, { Name = post and "Post" or "Picket", Size = post and Vector3.new(0.45, 3, 0.45) or Vector3.new(0.3, 2.6, 0.5),
			CFrame = along * CFrame.new(0, post and 1.5 or 1.3, z), Color = color, Material = MAT.Wood, CastShadow = false })
		trim(model, { Name = "PicketTip", Size = Vector3.new(0.3, 0.35, 0.35), CFrame = along * CFrame.new(0, (post and 3 or 2.6) + 0.05, z) * CFrame.Angles(math.rad(45), 0, 0),
			Color = color, Material = MAT.Wood })
	end
	model.Parent = parent
	return model
end

--------------------------------------------------------------------
-- NATURE (low-poly trees, bushes, rocks, flowers)
--------------------------------------------------------------------
local BARK = Color3.fromRGB(125, 85, 55)

local function roundTree(parent, position, rng, scale)
	scale = scale or 1
	local model = Instance.new("Model")
	model.Name = "Tree"
	local height = (5 + rng:NextNumber() * 3) * scale
	newPart(model, { Name = "Trunk", Size = Vector3.new(1.1, height, 1.1) * Vector3.new(scale, 1, scale),
		CFrame = CFrame.new(position + Vector3.new(0, height / 2, 0)), Color = BARK, Material = MAT.Wood })
	-- root flare: a wider, twisted block at the foot of the trunk
	trim(model, { Name = "Roots", Size = Vector3.new(1.8, 0.8, 1.8) * scale,
		CFrame = CFrame.new(position + Vector3.new(0, 0.4 * scale, 0)) * CFrame.Angles(0, math.rad(45), 0), Color = BARK:Lerp(Color3.new(0, 0, 0), 0.1), Material = MAT.Wood })
	-- a side branch
	local branchAngle = rng:NextNumber() * math.pi * 2
	trim(model, { Name = "Branch", Size = Vector3.new(0.45, 2.4, 0.45) * scale,
		CFrame = CFrame.new(position + Vector3.new(0, height * 0.7, 0)) * CFrame.Angles(0, branchAngle, 0) * CFrame.Angles(0, 0, math.rad(-50)) * CFrame.new(0, 1 * scale, 0),
		Color = BARK, Material = MAT.Wood })
	local green = LEAF_GREENS[rng:NextInteger(1, #LEAF_GREENS)]
	for i = 1, 4 do
		local size = (3.2 + rng:NextNumber() * 2.5) * scale
		newPart(model, { Name = "Leaves", Size = Vector3.new(size, size * 0.85, size),
			CFrame = CFrame.new(position + Vector3.new(rng:NextNumber(-1.4, 1.4) * scale, height + rng:NextNumber(-0.5, 1.8) * scale, rng:NextNumber(-1.4, 1.4) * scale))
				* CFrame.Angles(rng:NextNumber(-0.25, 0.25), rng:NextNumber() * math.pi, rng:NextNumber(-0.25, 0.25)),
			Color = green:Lerp(Color3.fromRGB(60, 140, 50), (i - 1) * 0.1), Material = MAT.Leafy })
	end
	-- a lighter clump on top where the sun hits
	local capSize = 2.6 * scale
	trim(model, { Name = "LeavesTop", Size = Vector3.new(capSize, capSize * 0.8, capSize),
		CFrame = CFrame.new(position + Vector3.new(0, height + 2.4 * scale, 0)) * CFrame.Angles(0, rng:NextNumber() * math.pi, 0),
		Color = green:Lerp(Color3.fromRGB(200, 240, 120), 0.25), Material = MAT.Leafy, CastShadow = true })
	if rng:NextNumber() < 0.35 then -- some trees have fruit
		local fruit = (rng:NextNumber() < 0.5) and Color3.fromRGB(230, 60, 60) or Color3.fromRGB(255, 170, 50)
		for _ = 1, 4 do
			trim(model, { Name = "Fruit", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.55 * scale,
				CFrame = CFrame.new(position + Vector3.new(rng:NextNumber(-2, 2) * scale, height + rng:NextNumber(-1, 0.5) * scale, rng:NextNumber(-2, 2) * scale)),
				Color = fruit })
		end
	end
	model.Parent = parent
end

local function pineTree(parent, position, rng, scale)
	scale = scale or 1
	local model = Instance.new("Model")
	model.Name = "Pine"
	newPart(model, { Name = "Trunk", Size = Vector3.new(0.9, 3, 0.9) * scale, CFrame = CFrame.new(position + Vector3.new(0, 1.5 * scale, 0)),
		Color = Color3.fromRGB(110, 72, 45), Material = MAT.Wood })
	local green = Color3.fromRGB(50, 150 + rng:NextInteger(0, 30), 70)
	local spin = rng:NextNumber() * math.pi
	for i = 1, 4 do
		local width = (5.8 - i * 1.15) * scale
		newPart(model, { Name = "Needles", Size = Vector3.new(width, 2.4 * scale, width),
			CFrame = CFrame.new(position + Vector3.new(0, (1.8 + i * 1.9) * scale, 0)) * CFrame.Angles(0, spin + i * 0.4, 0),
			Color = green:Lerp(Color3.fromRGB(110, 200, 90), i * 0.1), Material = MAT.Leafy })
		-- a second layer turned 45 degrees makes each tier look like a star, not a box
		trim(model, { Name = "Needles", Size = Vector3.new(width * 0.8, 2.2 * scale, width * 0.8),
			CFrame = CFrame.new(position + Vector3.new(0, (1.8 + i * 1.9) * scale, 0)) * CFrame.Angles(0, spin + i * 0.4 + math.rad(45), 0),
			Color = green:Lerp(Color3.fromRGB(40, 110, 60), 0.15), Material = MAT.Leafy, CastShadow = true })
	end
	trim(model, { Name = "Tip", Size = Vector3.new(0.9, 1.3, 0.9) * scale, CFrame = CFrame.new(position + Vector3.new(0, 10 * scale, 0)) * CFrame.Angles(0, spin, 0),
		Color = green:Lerp(Color3.fromRGB(140, 220, 100), 0.4), Material = MAT.Leafy })
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
	for i = 1, 3 do
		local size = (2 + rng:NextNumber() * 1.5) * (i == 3 and 0.7 or 1)
		newPart(parent, { Name = "Bush", Size = Vector3.new(size, size * 0.8, size),
			CFrame = CFrame.new(position + Vector3.new(rng:NextNumber(-0.9, 0.9), size * 0.35 + (i == 3 and 0.6 or 0), rng:NextNumber(-0.9, 0.9)))
				* CFrame.Angles(rng:NextNumber(-0.2, 0.2), rng:NextNumber() * math.pi, rng:NextNumber(-0.2, 0.2)),
			Color = green:Lerp(Color3.fromRGB(190, 235, 110), (i - 1) * 0.12), Material = MAT.Leafy })
	end
	if rng:NextNumber() < 0.5 then -- berries or blossoms
		local dot = FLOWER_COLORS[rng:NextInteger(1, #FLOWER_COLORS)]
		for _ = 1, 5 do
			local angle = rng:NextNumber() * math.pi * 2
			trim(parent, { Name = "Blossom", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.4,
				CFrame = CFrame.new(position + Vector3.new(math.cos(angle) * 1.2, rng:NextNumber(0.8, 1.8), math.sin(angle) * 1.2)), Color = dot })
		end
	end
end

local function rock(parent, position, rng, scale)
	scale = scale or 1
	local size = Vector3.new(rng:NextNumber(2, 4), rng:NextNumber(1.5, 3), rng:NextNumber(2, 4)) * scale
	local color = ROCK:Lerp(Color3.fromRGB(120, 125, 130), rng:NextNumber())
	newPart(parent, { Name = "Rock", Size = size,
		CFrame = CFrame.new(position + Vector3.new(0, size.Y * 0.35, 0)) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber() * math.pi, rng:NextNumber(-0.3, 0.3)),
		Color = color, Material = MAT.Rock })
	-- a smaller chunk leaning on it, and a bit of moss on top
	trim(parent, { Name = "RockChip", Size = size * 0.45,
		CFrame = CFrame.new(position + Vector3.new(size.X * 0.45, size.Y * 0.18, size.Z * 0.2)) * CFrame.Angles(rng:NextNumber(-0.5, 0.5), rng:NextNumber() * math.pi, 0.4),
		Color = color:Lerp(WHITE, 0.08), Material = MAT.Rock })
	trim(parent, { Name = "Moss", Size = Vector3.new(size.X * 0.6, 0.2, size.Z * 0.6),
		CFrame = CFrame.new(position + Vector3.new(0, size.Y * 0.82, 0)) * CFrame.Angles(0, rng:NextNumber() * math.pi, 0),
		Color = Color3.fromRGB(100, 165, 70), Material = MAT.Grass })
end

local function flower(parent, position, rng)
	local color = FLOWER_COLORS[rng:NextInteger(1, #FLOWER_COLORS)]
	local spin = rng:NextNumber() * math.pi
	trim(parent, { Name = "Stem", Size = Vector3.new(0.12, 0.8, 0.12), CFrame = CFrame.new(position + Vector3.new(0, 0.4, 0)),
		Color = Color3.fromRGB(70, 150, 60), Material = MAT.Leafy })
	trim(parent, { Name = "Leaf", Size = Vector3.new(0.45, 0.06, 0.2), CFrame = CFrame.new(position + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, spin, math.rad(20)) * CFrame.new(0.2, 0, 0),
		Color = Color3.fromRGB(90, 175, 70), Material = MAT.Leafy })
	for i = 0, 3 do -- four petals around a yellow center
		trim(parent, { Name = "Petal", Size = Vector3.new(0.32, 0.08, 0.22),
			CFrame = CFrame.new(position + Vector3.new(0, 0.82, 0)) * CFrame.Angles(0, spin + i * math.pi / 2, 0) * CFrame.new(0.2, 0, 0) * CFrame.Angles(0, 0, math.rad(12)),
			Color = color })
	end
	trim(parent, { Name = "FlowerCenter", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.2, CFrame = CFrame.new(position + Vector3.new(0, 0.86, 0)),
		Color = (color == Color3.fromRGB(255, 210, 60)) and Color3.fromRGB(200, 110, 40) or Color3.fromRGB(255, 215, 70) })
end

local function pebble(parent, position, rng)
	trim(parent, { Name = "Pebble", Size = Vector3.new(rng:NextNumber(0.5, 1.2), 0.25, rng:NextNumber(0.5, 1.2)),
		CFrame = CFrame.new(position + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, rng:NextNumber() * math.pi, rng:NextNumber(-0.1, 0.1)),
		Color = ROCK:Lerp(WHITE, rng:NextNumber() * 0.3), Material = MAT.Rock })
end

-- A tuft of grass blades
local function grassTuft(parent, position, rng)
	local green = Color3.fromRGB(95, 185, 60):Lerp(Color3.fromRGB(150, 220, 90), rng:NextNumber())
	for i = 0, 2 do
		trim(parent, { Name = "GrassBlade", Size = Vector3.new(0.1, 0.7 + rng:NextNumber() * 0.4, 0.3),
			CFrame = CFrame.new(position + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, i * 2.1 + rng:NextNumber(), math.rad(rng:NextNumber(-25, 25))),
			Color = green, Material = MAT.Leafy })
	end
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
		local dirt = DIRT:Lerp(Color3.fromRGB(160, 100, 65), rng:NextNumber())
		newPart(model, { Name = "Dirt", Size = Vector3.new(width, height, depth), CFrame = CFrame.new(center + Vector3.new(0, height / 2 - 0.5, 0)) * spin,
			Color = dirt, Material = MAT.Ground })
		-- darker rock strata bands around the sides
		for band = 1, math.floor(height / 3.5) do
			trim(model, { Name = "Strata", Size = Vector3.new(width + 0.3, 0.6, depth + 0.3),
				CFrame = CFrame.new(center + Vector3.new(0, band * 3.2 - 1.2, 0)) * spin,
				Color = dirt:Lerp(Color3.fromRGB(110, 70, 50), 0.35 + (band % 2) * 0.15), Material = MAT.Sandstone })
		end
		newPart(model, { Name = "GrassTop", Size = Vector3.new(width + 0.4, 1.2, depth + 0.4), CFrame = CFrame.new(center + Vector3.new(0, height - 0.4, 0)) * spin,
			Color = GRASS, Material = MAT.Grass })
		-- grass drips over the edge
		for _ = 1, 4 do
			local side = rng:NextInteger(0, 3)
			local along = rng:NextNumber(-0.4, 0.4)
			local dx = (side == 0 and width / 2) or (side == 1 and -width / 2) or along * width
			local dz = (side == 2 and depth / 2) or (side == 3 and -depth / 2) or along * depth
			trim(model, { Name = "GrassDrip", Size = Vector3.new(side < 2 and 0.5 or 3, rng:NextNumber(1, 2.2), side < 2 and 3 or 0.5),
				CFrame = CFrame.new(center + Vector3.new(0, height - 1.2, 0)) * spin * CFrame.new(dx, 0, dz), Color = GRASS, Material = MAT.Grass })
		end
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
	-- seat and back are made of separate slats with gaps between them
	for i = 0, 3 do
		newPart(model, { Name = "Seat", Size = Vector3.new(5, 0.22, 0.3), CFrame = cframe * CFrame.new(0, 1.5, -0.55 + i * 0.36),
			Color = wood:Lerp(Color3.fromRGB(130, 80, 45), (i % 2) * 0.2), Material = MAT.Wood })
	end
	for i = 0, 2 do
		trim(model, { Name = "Back", Size = Vector3.new(5, 0.3, 0.14), CFrame = cframe * CFrame.new(0, 2.05 + i * 0.42, 0.72) * CFrame.Angles(math.rad(-8), 0, 0),
			Color = wood:Lerp(Color3.fromRGB(130, 80, 45), (i % 2) * 0.2), Material = MAT.Wood })
	end
	for _, x in ipairs({ -2.2, 2.2 }) do -- cast iron side frames with armrests
		newPart(model, { Name = "Leg", Size = Vector3.new(0.25, 1.5, 1.4), CFrame = cframe * CFrame.new(x, 0.75, 0.05), Color = IRON, Material = MAT.Metal })
		trim(model, { Name = "BackSupport", Size = Vector3.new(0.2, 1.5, 0.2), CFrame = cframe * CFrame.new(x, 2.35, 0.8) * CFrame.Angles(math.rad(-8), 0, 0),
			Color = IRON, Material = MAT.Metal })
		trim(model, { Name = "Armrest", Size = Vector3.new(0.3, 0.2, 1.5), CFrame = cframe * CFrame.new(x, 2.25, 0.05), Color = IRON, Material = MAT.Metal })
		trim(model, { Name = "Foot", Size = Vector3.new(0.4, 0.15, 1.6), CFrame = cframe * CFrame.new(x, 0.08, 0.05), Color = IRON, Material = MAT.Metal })
	end
	model.Parent = parent
end

local function flowerBed(parent, center, width, depth, rng)
	-- a brick planter with a stone cap, dark soil, flowers and grass tufts
	newPart(parent, { Name = "FlowerBed", Size = Vector3.new(width, 0.8, depth), CFrame = CFrame.new(center + Vector3.new(0, 0.4, 0)),
		Color = Color3.fromRGB(185, 105, 70), Material = MAT.Brick })
	for _, side in ipairs({ -1, 1 }) do
		trim(parent, { Name = "PlanterCap", Size = Vector3.new(width + 0.3, 0.2, 0.55), CFrame = CFrame.new(center + Vector3.new(0, 0.9, side * (depth / 2 - 0.2))),
			Color = STONE, Material = MAT.Limestone })
		trim(parent, { Name = "PlanterCap", Size = Vector3.new(0.55, 0.2, depth - 0.2), CFrame = CFrame.new(center + Vector3.new(side * (width / 2 - 0.2), 0.9, 0)),
			Color = STONE, Material = MAT.Limestone })
	end
	newPart(parent, { Name = "Soil", Size = Vector3.new(width - 0.8, 0.2, depth - 0.8), CFrame = CFrame.new(center + Vector3.new(0, 0.85, 0)),
		Color = Color3.fromRGB(95, 65, 45), Material = MAT.Ground })
	for _ = 1, math.floor(width * depth / 3) do
		local spot = center + Vector3.new(rng:NextNumber(-width / 2 + 0.8, width / 2 - 0.8), 0.9, rng:NextNumber(-depth / 2 + 0.8, depth / 2 - 0.8))
		if rng:NextNumber() < 0.75 then
			flower(parent, spot, rng)
		else
			grassTuft(parent, spot, rng)
		end
	end
end

local function fountain(parent, position)
	local model = Instance.new("Model")
	model.Name = "Fountain"
	local stone = Color3.fromRGB(235, 230, 220)
	local darkStone = Color3.fromRGB(200, 192, 180)
	local water = Color3.fromRGB(80, 200, 235)
	-- a round stone step around the basin
	newPart(model, { Name = "Step", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 16.5, 16.5),
		CFrame = CFrame.new(position + Vector3.new(0, 0.2, 0)) * FLAT, Color = darkStone, Material = MAT.Cobble })
	newPart(model, { Name = "Basin", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.4, 14, 14),
		CFrame = CFrame.new(position + Vector3.new(0, 0.9, 0)) * FLAT, Color = stone, Material = MAT.Limestone })
	-- carved blocks around the rim of the basin
	for i = 1, 16 do
		local angle = i / 16 * math.pi * 2
		trim(model, { Name = "RimStone", Size = Vector3.new(0.9, 0.35, 2.6),
			CFrame = CFrame.new(position + Vector3.new(math.cos(angle) * 6.7, 1.75, math.sin(angle) * 6.7)) * CFrame.Angles(0, -angle, 0),
			Color = (i % 2 == 0) and stone or darkStone, Material = MAT.Limestone })
	end
	newPart(model, { Name = "Water", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 12.6, 12.6),
		CFrame = CFrame.new(position + Vector3.new(0, 1.55, 0)) * FLAT, Color = water, Material = MAT.Glass, Transparency = 0.2, Reflectance = 0.15, CanCollide = false })
	trim(model, { Name = "PoolFloor", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, 12.4, 12.4),
		CFrame = CFrame.new(position + Vector3.new(0, 1.2, 0)) * FLAT, Color = Color3.fromRGB(60, 150, 190), Material = MAT.Tiles })
	for i = 1, 5 do -- coins at the bottom
		local angle = i * 1.9
		trim(model, { Name = "Coin", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.06, 0.4, 0.4),
			CFrame = CFrame.new(position + Vector3.new(math.cos(angle) * (2.5 + i * 0.5), 1.28, math.sin(angle) * (2.5 + i * 0.5))) * FLAT,
			Color = Color3.fromRGB(245, 195, 70), Material = MAT.Foil })
	end
	newPart(model, { Name = "Pillar", Shape = Enum.PartType.Cylinder, Size = Vector3.new(4, 1.6, 1.6),
		CFrame = CFrame.new(position + Vector3.new(0, 3.2, 0)) * FLAT, Color = stone, Material = MAT.Marble })
	for _, y in ipairs({ 1.6, 4.9 }) do
		trim(model, { Name = "PillarRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 2.1, 2.1),
			CFrame = CFrame.new(position + Vector3.new(0, y, 0)) * FLAT, Color = darkStone, Material = MAT.Marble })
	end
	newPart(model, { Name = "Bowl", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.8, 5, 5),
		CFrame = CFrame.new(position + Vector3.new(0, 5.2, 0)) * FLAT, Color = stone, Material = MAT.Marble })
	trim(model, { Name = "BowlUnder", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, 3.6, 3.6),
		CFrame = CFrame.new(position + Vector3.new(0, 4.6, 0)) * FLAT, Color = darkStone, Material = MAT.Marble })
	trim(model, { Name = "BowlWater", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.15, 4.4, 4.4),
		CFrame = CFrame.new(position + Vector3.new(0, 5.6, 0)) * FLAT, Color = water, Material = MAT.Glass, Transparency = 0.2 })
	-- water falling from the bowl
	for i = 1, 8 do
		local angle = i / 8 * math.pi * 2
		trim(model, { Name = "Waterfall", Size = Vector3.new(0.15, 3.6, 0.7),
			CFrame = CFrame.new(position + Vector3.new(math.cos(angle) * 2.55, 3.5, math.sin(angle) * 2.55)) * CFrame.Angles(0, -angle, 0),
			Color = Color3.fromRGB(170, 230, 250), Material = MAT.Glass, Transparency = 0.45 })
	end
	for i = 1, 3 do -- a golden pancake statue on top
		newPart(model, { Name = "StatuePancake", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, 3 - i * 0.2, 3 - i * 0.2),
			CFrame = CFrame.new(position + Vector3.new(0, 6 + i * 0.52, 0)) * FLAT, Color = Color3.fromRGB(240, 190, 60), Material = MAT.Metal, Reflectance = 0.15 })
	end
	trim(model, { Name = "StatueSyrup", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, 2.2, 2.2),
		CFrame = CFrame.new(position + Vector3.new(0, 7.8, 0)) * FLAT, Color = Color3.fromRGB(200, 120, 30), Material = MAT.Metal, Reflectance = 0.2 })
	newPart(model, { Name = "StatueButter", Size = Vector3.new(0.9, 0.5, 0.9), CFrame = CFrame.new(position + Vector3.new(0, 8.1, 0)),
		Color = Color3.fromRGB(255, 225, 90), Material = MAT.Metal, Reflectance = 0.2 })
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
	local red = Color3.fromRGB(230, 90, 90)
	newPart(model, { Name = "Floor", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 20, 20),
		CFrame = CFrame.new(position + Vector3.new(0, 0.5, 0)) * FLAT, Color = Color3.fromRGB(215, 175, 130), Material = MAT.Planks })
	trim(model, { Name = "FloorEdge", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 20.6, 20.6),
		CFrame = CFrame.new(position + Vector3.new(0, 0.2, 0)) * FLAT, Color = WHITE, Material = MAT.Wood })
	for i = 1, 8 do
		local angle = i / 8 * math.pi * 2
		local spot = position + Vector3.new(math.cos(angle) * 8.8, 0, math.sin(angle) * 8.8)
		newPart(model, { Name = "Pillar", Size = Vector3.new(0.8, 9, 0.8), CFrame = CFrame.new(spot + Vector3.new(0, 5.5, 0)), Color = WHITE, Material = MAT.Wood })
		trim(model, { Name = "PillarFoot", Size = Vector3.new(1.2, 0.6, 1.2), CFrame = CFrame.new(spot + Vector3.new(0, 1.3, 0)), Color = WHITE, Material = MAT.Wood })
		trim(model, { Name = "PillarHead", Size = Vector3.new(1.2, 0.5, 1.2), CFrame = CFrame.new(spot + Vector3.new(0, 9.75, 0)), Color = WHITE, Material = MAT.Wood })
		-- a railing between pillars, except at the two entrances (north and south)
		local nextAngle = (i + 1) / 8 * math.pi * 2
		local mid = (angle + nextAngle) / 2
		local isEntrance = math.abs(math.sin(mid)) > 0.9
		if not isEntrance then
			local a = position + Vector3.new(math.cos(angle) * 8.8, 0, math.sin(angle) * 8.8)
			local b = position + Vector3.new(math.cos(nextAngle) * 8.8, 0, math.sin(nextAngle) * 8.8)
			local along = CFrame.lookAt((a + b) / 2, b)
			local length = (b - a).Magnitude - 0.8
			newPart(model, { Name = "Rail", Size = Vector3.new(0.3, 0.25, length), CFrame = along + Vector3.new(0, 3.6, 0), Color = WHITE, Material = MAT.Wood })
			for j = -3, 3 do
				trim(model, { Name = "Baluster", Size = Vector3.new(0.18, 2.5, 0.18), CFrame = (along + Vector3.new(0, 2.3, 0)) * CFrame.new(0, 0, j * length / 7.5),
					Color = WHITE, Material = MAT.Wood })
			end
		end
		-- scalloped bunting under the roof edge
		trim(model, { Name = "Bunting", Size = Vector3.new(0.1, 0.9, 1.1),
			CFrame = CFrame.new(position + Vector3.new(math.cos(mid) * 9.6, 9.6, math.sin(mid) * 9.6)) * CFrame.Angles(0, -mid, 0) * CFrame.Angles(math.rad(45), 0, 0),
			Color = (i % 2 == 0) and red or Color3.fromRGB(255, 210, 60), Material = MAT.Fabric })
	end
	for i = 1, 4 do -- a stepped round roof
		newPart(model, { Name = "Roof", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 22 - i * 5, 22 - i * 5),
			CFrame = CFrame.new(position + Vector3.new(0, 9.5 + i, 0)) * FLAT, Color = (i % 2 == 1) and red or WHITE,
			Material = (i % 2 == 1) and MAT.Shingles or MAT.Wood })
	end
	newPart(model, { Name = "Top", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.6, CFrame = CFrame.new(position + Vector3.new(0, 14.6, 0)),
		Color = Color3.fromRGB(255, 210, 60), Material = MAT.Metal, Reflectance = 0.2 })
	trim(model, { Name = "Spire", Size = Vector3.new(0.2, 2, 0.2), CFrame = CFrame.new(position + Vector3.new(0, 16, 0)), Color = Color3.fromRGB(255, 210, 60), Material = MAT.Metal })
	-- a hanging lantern in the middle
	local lantern = trim(model, { Name = "Lantern", Size = Vector3.new(1.2, 1.5, 1.2), CFrame = CFrame.new(position + Vector3.new(0, 8.2, 0)),
		Color = LAMP_GLOW, Material = MAT.Glass, Transparency = 0.2 })
	trim(model, { Name = "LanternChain", Size = Vector3.new(0.1, 1.6, 0.1), CFrame = CFrame.new(position + Vector3.new(0, 9.7, 0)), Color = IRON, Material = MAT.Metal })
	local light = Instance.new("PointLight")
	light.Color = LAMP_GLOW
	light.Range = 18
	light.Brightness = 0.9
	light.Parent = lantern
	model.Parent = parent
end

local STALL_GOODS = {
	{ "🍯 SYRUP", Color3.fromRGB(200, 120, 40) },
	{ "🍓 BERRIES", Color3.fromRGB(220, 60, 80) },
	{ "🧈 BUTTER", Color3.fromRGB(240, 200, 60) },
	{ "🥛 MILK", Color3.fromRGB(90, 160, 230) },
}

local function crate(parent, cframe, color)
	local wood = Color3.fromRGB(190, 140, 90)
	newPart(parent, { Name = "Crate", Size = Vector3.new(2, 1.4, 1.6), CFrame = cframe * CFrame.new(0, 0.7, 0), Color = wood, Material = MAT.Planks })
	for _, y in ipairs({ 0.15, 1.25 }) do
		trim(parent, { Name = "CrateBand", Size = Vector3.new(2.06, 0.2, 1.66), CFrame = cframe * CFrame.new(0, y, 0), Color = wood:Lerp(Color3.new(0, 0, 0), 0.25), Material = MAT.Wood })
	end
	for i = 0, 5 do -- produce heaped inside
		trim(parent, { Name = "Produce", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.55,
			CFrame = cframe * CFrame.new(-0.6 + (i % 3) * 0.6, 1.45 + math.floor(i / 3) * 0.12, -0.3 + math.floor(i / 3) * 0.6), Color = color:Lerp(WHITE, (i % 2) * 0.15) })
	end
end

local function stall(parent, cframe, goods, rng)
	local model = Instance.new("Model")
	model.Name = "Stall"
	local color = goods[2]
	local wood = Color3.fromRGB(190, 130, 80)
	newPart(model, { Name = "Counter", Size = Vector3.new(8, 3.2, 3), CFrame = cframe * CFrame.new(0, 1.6, 0), Color = wood, Material = MAT.Planks })
	trim(model, { Name = "CounterTop", Size = Vector3.new(8.4, 0.25, 3.4), CFrame = cframe * CFrame.new(0, 3.3, 0), Color = Color3.fromRGB(150, 100, 60), Material = MAT.Wood })
	trim(model, { Name = "Skirt", Size = Vector3.new(8.05, 1, 0.1), CFrame = cframe * CFrame.new(0, 2.5, 1.53), Color = color, Material = MAT.Fabric })
	for _, x in ipairs({ -3.8, 3.8 }) do
		newPart(model, { Name = "Post", Size = Vector3.new(0.4, 8, 0.4), CFrame = cframe * CFrame.new(x, 4, -1.3), Color = Color3.fromRGB(150, 100, 60), Material = MAT.Wood })
		newPart(model, { Name = "FrontPost", Size = Vector3.new(0.3, 5, 0.3), CFrame = cframe * CFrame.new(x, 5.8, 1.35), Color = Color3.fromRGB(150, 100, 60), Material = MAT.Wood })
	end
	for i = 0, 3 do
		newPart(model, { Name = "Awning", Size = Vector3.new(2.02, 0.2, 4.2),
			CFrame = cframe * CFrame.new(-3 + i * 2, 8.1, 0.2) * CFrame.Angles(math.rad(18), 0, 0), Color = (i % 2 == 0) and color or WHITE, Material = MAT.Fabric })
		trim(model, { Name = "Valance", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, 1.9, 1.9),
			CFrame = cframe * CFrame.new(-3 + i * 2, 7.45, 2.2) * CFrame.Angles(0, math.rad(90), 0), Color = (i % 2 == 0) and color or WHITE, Material = MAT.Fabric })
	end
	local sign = newPart(model, { Name = "Sign", Size = Vector3.new(6, 1.4, 0.3), CFrame = cframe * CFrame.new(0, 9.3, -1.2), Color = color, Material = MAT.Wood })
	trim(model, { Name = "SignFrame", Size = Vector3.new(6.4, 1.8, 0.2), CFrame = cframe * CFrame.new(0, 9.3, -1.3), Color = Color3.fromRGB(120, 80, 45), Material = MAT.Wood })
	signText(sign, Enum.NormalId.Back, goods[1], WHITE)
	for _ = 1, 5 do -- goods on the counter, in little baskets
		local spot = cframe * CFrame.new(rng:NextNumber(-3, 3), 3.5, rng:NextNumber(-0.8, 0.8))
		trim(model, { Name = "Basket", Size = Vector3.new(1.1, 0.35, 0.9), CFrame = spot, Color = Color3.fromRGB(200, 160, 100), Material = MAT.Fabric })
		newPart(model, { Name = "Goods", Shape = Enum.PartType.Ball, Size = Vector3.one * rng:NextNumber(0.6, 0.9),
			CFrame = spot * CFrame.new(0, 0.35, 0), Color = color:Lerp(WHITE, rng:NextNumber() * 0.3) })
	end
	-- crates and a barrel beside the stall
	crate(model, cframe * CFrame.new(5.6, 0, 0.6) * CFrame.Angles(0, 0.2, 0), color)
	crate(model, cframe * CFrame.new(-5.4, 0, 0.9) * CFrame.Angles(0, -0.15, 0), color)
	newPart(model, { Name = "Barrel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.4, 1.8, 1.8), CFrame = cframe * CFrame.new(5.4, 1.2, -1.6) * FLAT,
		Color = Color3.fromRGB(160, 105, 60), Material = MAT.Wood })
	for _, y in ipairs({ 0.45, 1.95 }) do
		trim(model, { Name = "BarrelHoop", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 1.9, 1.9), CFrame = cframe * CFrame.new(5.4, y, -1.6) * FLAT,
			Color = IRON, Material = MAT.Metal })
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
	local DARK_WOOD = Color3.fromRGB(110, 70, 42)
	local METAL = Color3.fromRGB(200, 200, 208)
	local CHROME = Color3.fromRGB(225, 228, 235)
	local outsideMaterial = M(theme.OutsideMaterial or "Plaster")
	local roofMaterial = M(theme.RoofMaterial or "RoofShingles")
	local outsideTrim = theme.Outside:Lerp(WHITE, 0.55)
	local function at(x, y, z)
		return cframe * CFrame.new(x, y, z)
	end
	local function block(name, width, height, depth, x, y, z, color, material)
		return newPart(model, { Name = name, Size = Vector3.new(width, height, depth), CFrame = at(x, y, z),
			Color = color, Material = material or Enum.Material.SmoothPlastic })
	end
	-- decoration only: no collision, no shadow
	local function detail(name, width, height, depth, x, y, z, color, material)
		return trim(model, { Name = name, Size = Vector3.new(width, height, depth), CFrame = at(x, y, z),
			Color = color, Material = material or Enum.Material.SmoothPlastic })
	end
	local function cylinder(name, height, diameter, x, y, z, color, material)
		return newPart(model, { Name = name, Shape = Enum.PartType.Cylinder, Size = Vector3.new(height, diameter, diameter),
			CFrame = at(x, y, z) * FLAT, Color = color, Material = material or Enum.Material.SmoothPlastic })
	end
	local function detailCylinder(name, height, diameter, x, y, z, color, material)
		return trim(model, { Name = name, Shape = Enum.PartType.Cylinder, Size = Vector3.new(height, diameter, diameter),
			CFrame = at(x, y, z) * FLAT, Color = color, Material = material or Enum.Material.SmoothPlastic })
	end
	local function glow(part, range, brightness, color)
		local light = Instance.new("PointLight")
		light.Range = range
		light.Brightness = brightness
		light.Color = color or LAMP_GLOW
		light.Shadows = false
		light.Parent = part
		return light
	end

	------------------------------------------------------------------ shell
	block("Floor", HALF * 2, 0.18, DEPTH, 0, 0.09, MID, Color3.fromRGB(200, 155, 105), MAT.Planks)
	block("KitchenFloor", 31.5, 0.19, 20, 6.25, 0.095, 3.75, Color3.fromRGB(225, 225, 230), MAT.Tiles) -- x -9.5..22, z -6.25..13.75
	block("BackWall", HALF * 2 + 1, H, 1, 0, H / 2, BACK - 0.5, theme.Wall, MAT.Plaster)
	for _, side in ipairs({ -1, 1 }) do
		block("SideWall", 1, H, DEPTH + 1, side * (HALF + 0.5), H / 2, MID, theme.Wall, MAT.Plaster)
		block("OutsideSkin", 0.2, H, DEPTH + 1.2, side * (HALF + 1.1), H / 2, MID, theme.Outside, outsideMaterial)
	end
	block("BackSkin", HALF * 2 + 2.4, H, 0.2, 0, H / 2, BACK - 1.1, theme.Outside, outsideMaterial)
	block("Roof", HALF * 2 + 2.5, 1, DEPTH + 2.5, 0, H + 0.5, MID, theme.Outside:Lerp(Color3.new(0, 0, 0), 0.15), MAT.Concrete)
	block("RoofTrim", HALF * 2 + 2.5, 1.2, 0.8, 0, H + 1.1, FRONT + 0.6, theme.Accent, roofMaterial)

	-- inside: wood wainscoting with a chair rail, baseboards and crown molding on the walls
	local wainscot = theme.Wall:Lerp(DARK_WOOD, 0.55)
	for _, side in ipairs({ -1, 1 }) do
		detail("Wainscot", 0.2, 3.6, DEPTH - 0.4, side * (HALF - 0.1), 1.8 + 0.18, MID, wainscot, MAT.Planks)
		detail("ChairRail", 0.35, 0.3, DEPTH - 0.4, side * (HALF - 0.17), 3.75, MID, DARK_WOOD, MAT.Wood)
		detail("Baseboard", 0.3, 0.6, DEPTH - 0.4, side * (HALF - 0.15), 0.48, MID, DARK_WOOD, MAT.Wood)
		detail("CrownMolding", 0.6, 0.6, DEPTH, side * (HALF - 0.3), H - 0.3, MID, WHITE, MAT.Wood)
	end
	detail("Wainscot", HALF * 2, 3.6, 0.2, 0, 1.98, BACK + 0.1, wainscot, MAT.Planks)
	detail("ChairRail", HALF * 2, 0.3, 0.35, 0, 3.75, BACK + 0.17, DARK_WOOD, MAT.Wood)
	detail("CrownMolding", HALF * 2, 0.6, 0.6, 0, H - 0.3, BACK + 0.3, WHITE, MAT.Wood)
	detail("CrownMolding", HALF * 2, 0.6, 0.6, 0, H - 0.3, FRONT - 0.8, WHITE, MAT.Wood)
	-- ceiling beams
	for _, z in ipairs({ -1, 7, 15, 23, 31 }) do
		detail("CeilingBeam", HALF * 2, 0.9, 0.9, 0, H - 0.45, z, DARK_WOOD, MAT.Wood)
	end

	-- outside: a stone base, corner posts and a cornice at the top of the walls
	local plinth = Color3.fromRGB(150, 145, 140)
	for _, side in ipairs({ -1, 1 }) do
		detail("Plinth", 0.5, 1.6, DEPTH + 2.2, side * (HALF + 1.4), 0.8, MID, plinth, MAT.Cobble)
		detail("Cornice", 0.9, 0.9, DEPTH + 2.6, side * (HALF + 1.4), H - 0.45, MID, outsideTrim, MAT.Wood)
		for _, z in ipairs({ BACK - 1.2, FRONT + 0.6 }) do
			block("CornerPost", 1.4, H, 1.4, side * (HALF + 1.2), H / 2, z, outsideTrim, MAT.Wood)
		end
	end
	detail("Plinth", HALF * 2 + 2.4, 1.6, 0.5, 0, 0.8, BACK - 1.4, plinth, MAT.Cobble)
	detail("Cornice", HALF * 2 + 2.6, 0.9, 0.9, 0, H - 0.45, BACK - 1.4, outsideTrim, MAT.Wood)
	-- a low wall around the roof, plus a vent and a chimney
	for _, side in ipairs({ -1, 1 }) do
		detail("Parapet", 0.6, 1.4, DEPTH + 2.5, side * (HALF + 1), H + 1.7, MID, theme.Accent, roofMaterial)
	end
	detail("Parapet", HALF * 2 + 2.5, 1.4, 0.6, 0, H + 1.7, BACK - 1.2, theme.Accent, roofMaterial)
	block("RoofVent", 5, 2.2, 4, -12, H + 2.1, 0, METAL, MAT.Iron)
	for i = 0, 3 do
		detail("VentSlat", 4.6, 0.12, 0.1, -12, H + 1.5 + i * 0.4, 2.05, Color3.fromRGB(120, 120, 128), MAT.Metal)
	end
	block("Chimney", 2.4, 5, 2.4, 16, H + 3, -2, Color3.fromRGB(170, 85, 60), MAT.Brick)
	detail("ChimneyCap", 3, 0.4, 3, 16, H + 5.7, -2, Color3.fromRGB(90, 90, 95), MAT.Concrete)
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = GameConfig.Textures.Smoke
	smoke.Color = ColorSequence.new(Color3.fromRGB(240, 240, 240))
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 4) })
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) })
	smoke.Lifetime = NumberRange.new(3, 4.5)
	smoke.Rate = 3
	smoke.Speed = NumberRange.new(2, 3)
	smoke.SpreadAngle = Vector2.new(10, 10)
	smoke.Acceleration = Vector3.new(1.5, 0.5, 0)
	smoke.EmissionDirection = Enum.NormalId.Top
	smoke.Parent = model:FindFirstChild("Chimney")

	------------------------------------------------------------------ front: door, window, awning, sign
	local outside = theme.Outside
	block("Front", 4.5, H, 1, -19.75, H / 2, FRONT, outside, outsideMaterial)                 -- x -22..-17.5
	block("Front", 6, H - 9, 1, DOOR_X, 9 + (H - 9) / 2, FRONT, outside, outsideMaterial)      -- above the door
	block("Front", 3.5, H, 1, -9.75, H / 2, FRONT, outside, outsideMaterial)                  -- x -11.5..-8
	block("Front", 26, 3, 1, 5, 1.5, FRONT, outside, outsideMaterial)                         -- under the window
	block("Front", 26, H - 11, 1, 5, 11 + (H - 11) / 2, FRONT, outside, outsideMaterial)      -- above the window
	block("Front", 4, H, 1, 20, H / 2, FRONT, outside, outsideMaterial)                       -- x 18..22
	detail("Plinth", 4.5, 1.6, 0.5, -19.75, 0.8, FRONT + 0.7, plinth, MAT.Cobble)
	detail("Plinth", 3.5, 1.6, 0.5, -9.75, 0.8, FRONT + 0.7, plinth, MAT.Cobble)
	detail("Plinth", 30, 1.6, 0.5, 7, 0.8, FRONT + 0.7, plinth, MAT.Cobble)
	detail("Cornice", HALF * 2 + 2.6, 0.9, 0.9, 0, H - 0.45, FRONT + 0.8, outsideTrim, MAT.Wood)

	-- the big front window: glass, frame, mullions, a sill and a flower box
	newPart(model, { Name = "Window", Size = Vector3.new(26, 8, 0.3), CFrame = at(5, 7, FRONT),
		Color = Color3.fromRGB(170, 225, 245), Material = MAT.Glass, Transparency = 0.5, Reflectance = 0.15 })
	for _, x in ipairs({ -1.5, 5, 11.5 }) do
		block("Mullion", 0.3, 8, 0.5, x, 7, FRONT + 0.1, theme.Accent, MAT.Wood)
	end
	detail("Transom", 26, 0.3, 0.5, 5, 9.2, FRONT + 0.1, theme.Accent, MAT.Wood)
	for _, x in ipairs({ -8.1, 18.1 }) do
		detail("WindowFrame", 0.5, 8.6, 0.8, x, 7, FRONT + 0.1, outsideTrim, MAT.Wood)
	end
	detail("WindowFrame", 26.8, 0.5, 0.8, 5, 11.05, FRONT + 0.1, outsideTrim, MAT.Wood)
	detail("WindowSill", 27.4, 0.35, 1.2, 5, 2.85, FRONT + 0.4, outsideTrim, MAT.Wood)
	detail("InsideSill", 26, 0.3, 0.9, 5, 2.95, FRONT - 0.8, DARK_WOOD, MAT.Wood)
	detail("FlowerBox", 24, 0.9, 1, 5, 2.1, FRONT + 1.1, DARK_WOOD, MAT.Planks)
	detail("FlowerSoil", 23.6, 0.1, 0.8, 5, 2.55, FRONT + 1.1, Color3.fromRGB(95, 65, 45), MAT.Ground)
	local boxRng = Random.new(math.floor(cframe.Position.X * 7 + cframe.Position.Z))
	for i = 0, 22 do
		local x = -6 + i
		local spot = at(x + boxRng:NextNumber(-0.3, 0.3), 2.55, FRONT + 1.1 + boxRng:NextNumber(-0.2, 0.2)).Position
		if i % 3 == 0 then
			grassTuft(model, spot, boxRng)
		else
			flower(model, spot, boxRng)
		end
	end

	-- the door: frame, a step, a welcome mat, a little window above it and lamps on each side
	block("DoorFrame", 0.5, 9, 1.2, DOOR_X - 3, 4.5, FRONT, theme.Accent, MAT.Wood)
	block("DoorFrame", 0.5, 9, 1.2, DOOR_X + 3, 4.5, FRONT, theme.Accent, MAT.Wood)
	block("DoorFrame", 6.5, 0.5, 1.2, DOOR_X, 9, FRONT, theme.Accent, MAT.Wood)
	detail("DoorCasing", 7.6, 0.4, 1.4, DOOR_X, 9.5, FRONT + 0.1, outsideTrim, MAT.Wood)
	detail("DoorStep", 7, 0.25, 1.6, DOOR_X, 0.12, FRONT + 1.1, Color3.fromRGB(180, 175, 170), MAT.Concrete)
	block("WelcomeMat", 5, 0.1, 2.5, DOOR_X, 0.2, FRONT + 2, theme.Accent, MAT.Carpet)
	detail("MatBorder", 5.3, 0.08, 2.8, DOOR_X, 0.17, FRONT + 2, DARK_WOOD, MAT.Carpet)
	local doorWindow = detail("DoorTransom", 4.5, 1.6, 0.3, DOOR_X, 10.8, FRONT + 0.1, Color3.fromRGB(170, 225, 245), MAT.Glass)
	doorWindow.Transparency = 0.4
	-- the two doors, propped open against the inside of the front wall
	for _, side in ipairs({ -1, 1 }) do
		detail("Door", 2.9, 8.6, 0.3, DOOR_X + side * 4.55, 4.5, FRONT - 0.7, theme.Accent:Lerp(Color3.new(0, 0, 0), 0.15), MAT.Wood)
		local pane = detail("DoorGlass", 1.9, 4.6, 0.32, DOOR_X + side * 4.55, 5.8, FRONT - 0.7, Color3.fromRGB(170, 225, 245), MAT.Glass)
		pane.Transparency = 0.35
		detail("DoorPush", 0.2, 1.4, 0.15, DOOR_X + side * 3.4, 4.5, FRONT - 0.9, CHROME, MAT.Metal)
	end
	for _, dx in ipairs({ -4.1, 4.1 }) do
		detail("SconcePlate", 0.8, 1.2, 0.2, DOOR_X + dx, 7.6, FRONT + 0.6, Color3.fromRGB(60, 60, 65), MAT.Metal)
		local bulb = detail("Sconce", 0.8, 1, 0.8, DOOR_X + dx, 7.9, FRONT + 1, LAMP_GLOW, MAT.Glass)
		bulb.Transparency = 0.2
		detail("SconceCap", 1, 0.2, 1, DOOR_X + dx, 8.5, FRONT + 1, Color3.fromRGB(60, 60, 65), MAT.Metal)
		glow(bulb, 12, 0.7)
	end
	-- an OPEN sign hanging on the door frame
	local openSign = detail("OpenPlaque", 3, 1, 0.15, DOOR_X, 8.1, FRONT + 0.7, WHITE, MAT.Wood)
	signText(openSign, Enum.NormalId.Back, "OPEN", theme.Accent)

	-- striped fabric awning with scalloped edges
	for i = 0, 12 do
		local color = (i % 2 == 0) and theme.Accent or WHITE
		newPart(model, { Name = "Awning", Size = Vector3.new(2.02, 0.2, 3.6),
			CFrame = at(-7 + i * 2, 12.3, FRONT + 1.6) * CFrame.Angles(math.rad(25), 0, 0),
			Color = color, Material = MAT.Fabric })
		trim(model, { Name = "AwningScallop", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12, 2, 2),
			CFrame = at(-7 + i * 2, 11.55, FRONT + 3.2) * CFrame.Angles(0, math.rad(90), 0), Color = color, Material = MAT.Fabric })
	end
	for _, x in ipairs({ -8, 18 }) do
		detail("AwningArm", 0.2, 0.2, 3.6, x, 11.7, FRONT + 1.8, Color3.fromRGB(60, 60, 65), MAT.Metal).CFrame =
			at(x, 11.75, FRONT + 1.6) * CFrame.Angles(math.rad(25), 0, 0) * CFrame.new(0, -0.2, 0)
	end

	-- the name sign: a wooden frame, a row of marquee bulbs top and bottom
	local sign = newPart(model, { Name = "Sign", Size = Vector3.new(28, 4.5, 0.6), CFrame = at(2, 17, FRONT + 0.8), Color = theme.Accent, Material = MAT.Wood })
	signText(sign, Enum.NormalId.Back, "🥞 " .. theme.Name, WHITE, "RestaurantName")
	detail("SignBacker", 29.4, 5.9, 0.3, 2, 17, FRONT + 0.55, DARK_WOOD, MAT.Wood)
	block("SignTrim", 28.6, 0.4, 0.8, 2, 14.6, FRONT + 0.8, WHITE, MAT.Wood)
	block("SignTrim", 28.6, 0.4, 0.8, 2, 19.4, FRONT + 0.8, WHITE, MAT.Wood)
	for i = 0, 13 do
		for _, y in ipairs({ 14.6, 19.4 }) do
			local bulb = trim(model, { Name = "MarqueeBulb", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.35,
				CFrame = at(-11 + i * 2, y, FRONT + 1.25), Color = LAMP_GLOW, Material = MAT.Glass })
			bulb.Transparency = 0.1
		end
	end
	for _, x in ipairs({ -10, 14 }) do -- brackets holding the sign
		detail("SignBracket", 0.3, 0.3, 1.2, x, 20.1, FRONT + 0.5, Color3.fromRGB(60, 60, 65), MAT.Metal)
	end

	-- a giant pancake stack on the roof
	for i = 1, 3 do
		cylinder("RoofPancake", 1.4, 10 - i * 0.5, 12, H + 1 + i * 1.45, 20, Color3.fromRGB(225, 165, 75), MAT.Sand)
		detailCylinder("RoofPancakeEdge", 1.1, 10.15 - i * 0.5, 12, H + 1 + i * 1.45, 20, Color3.fromRGB(195, 125, 55), MAT.Sand)
	end
	block("RoofButter", 2.6, 1.2, 2.6, 12, H + 6.75, 20, Color3.fromRGB(255, 225, 90), MAT.Plaster)
	cylinder("RoofSyrup", 0.2, 7.5, 12, H + 6.1, 20, Color3.fromRGB(160, 85, 25), MAT.Glass)
	for i = 1, 6 do -- syrup dripping down the sides
		local angle = i / 6 * math.pi * 2
		detail("RoofSyrupDrip", 0.8, 1.4 + (i % 3) * 0.5, 0.3, 12 + math.cos(angle) * 4.3, H + 5.2 - (i % 3) * 0.25, 20 + math.sin(angle) * 4.3,
			Color3.fromRGB(160, 85, 25), MAT.Glass).CFrame = at(12 + math.cos(angle) * 4.35, H + 5.6 - (i % 3) * 0.25, 20 + math.sin(angle) * 4.35) * CFrame.Angles(0, -angle + math.pi / 2, 0)
	end
	detail("RoofPlate", 10, 0.3, 10, 12, H + 1.15, 20, WHITE, MAT.Marble)

	------------------------------------------------------------------ service counter (customers order here)
	block("ServiceCounter", 3, 3.6, 17, -11, 1.8, 5.5, theme.Accent, MAT.Planks)           -- z -3..14
	block("ServiceCounterPanel", 0.2, 2.2, 15.5, -12.6, 1.8, 5.5, WHITE, MAT.Wood)          -- stripe on the customer side
	for z = -1.5, 12.5, 3.5 do -- raised panels on the customer side
		detail("CounterPanelInset", 0.1, 1.6, 2.6, -12.72, 1.8, z + 0.25, theme.Accent:Lerp(WHITE, 0.2), MAT.Wood)
	end
	detail("CounterKick", 0.2, 0.5, 17, -12.6, 0.43, 5.5, CHROME, MAT.Metal)
	block("ServiceCounterTop", 3.6, 0.3, 17.6, -11, 3.75, 5.5, WOOD, MAT.Wood)
	detail("CounterTopEdge", 0.2, 0.2, 17.8, -12.85, 3.62, 5.5, CHROME, MAT.Metal)
	-- cash register
	block("Register", 1.4, 0.9, 1.2, -11, 4.35, 10.5, Color3.fromRGB(60, 60, 70), MAT.Metal)
	block("RegisterScreen", 0.1, 0.6, 0.9, -11.75, 4.9, 10.5, Color3.fromRGB(120, 230, 160))
	detail("RegisterKeys", 0.5, 0.1, 1, -11.45, 4.85, 10.5, Color3.fromRGB(200, 200, 205), MAT.Metal)
	detail("RegisterDrawer", 1.5, 0.3, 1.25, -11, 3.95, 10.5, Color3.fromRGB(45, 45, 52), MAT.Metal)
	-- a glass pastry case with little pancakes inside
	newPart(model, { Name = "PastryCase", Size = Vector3.new(2.4, 1.6, 3), CFrame = at(-11, 4.7, -1.2),
		Color = Color3.fromRGB(200, 235, 250), Material = MAT.Glass, Transparency = 0.6 })
	detail("PastryCaseBase", 2.5, 0.2, 3.1, -11, 3.95, -1.2, CHROME, MAT.Metal)
	detail("PastryCaseLid", 2.5, 0.1, 3.1, -11, 5.55, -1.2, CHROME, MAT.Metal)
	for i = 0, 2 do
		cylinder("DisplayPancake", 0.25, 1.1, -11, 4.05 + i * 0.27, -1.2, Color3.fromRGB(220, 155, 70))
	end
	detail("DisplayButter", 0.3, 0.15, 0.3, -11, 4.9, -1.2, Color3.fromRGB(255, 225, 90))
	cylinder("TipJar", 0.9, 0.6, -11, 4.35, 12.8, Color3.fromRGB(200, 235, 250), MAT.Glass).Transparency = 0.4
	detailCylinder("TipJarCoins", 0.3, 0.5, -11, 4.05, 12.8, Color3.fromRGB(245, 195, 70), MAT.Foil)
	detail("NapkinBox", 0.6, 0.5, 0.9, -11, 4.15, 7.5, WHITE)
	-- "ORDER HERE" sign hanging over the counter, facing the customers
	local orderSign = newPart(model, { Name = "OrderSign", Size = Vector3.new(0.3, 1.8, 6), CFrame = at(-11, 9.5, 5.5), Color = WHITE, Material = MAT.Wood })
	detail("OrderSignFrame", 0.2, 2.2, 6.4, -10.95, 9.5, 5.5, theme.Accent, MAT.Wood)
	signText(orderSign, Enum.NormalId.Left, "📋 ORDER HERE", theme.Accent, "OrderHere")
	for _, z in ipairs({ 3, 8 }) do
		block("SignChain", 0.1, 12.5 - 10.4, 0.1, -11, 10.4 + (H - 10.4) / 2, z, Color3.fromRGB(90, 90, 95), MAT.Metal)
	end

	------------------------------------------------------------------ half wall between kitchen and dining room
	block("HalfWall", 19.5, 4, 0.6, 0.25, 2, 14, theme.Wall, MAT.Plaster)     -- x -9.5..10
	block("HalfWall", 7, 4, 0.6, 18.5, 2, 14, theme.Wall, MAT.Plaster)        -- x 15..22 (gap at x 10..15 to walk in)
	detail("HalfWallTile", 19.5, 2.4, 0.64, 0.25, 1.4, 14, Color3.fromRGB(245, 245, 240), MAT.Tiles)
	detail("HalfWallTile", 7, 2.4, 0.64, 18.5, 1.4, 14, Color3.fromRGB(245, 245, 240), MAT.Tiles)
	block("HalfWallTop", 19.9, 0.3, 1, 0.25, 4.15, 14, WOOD, MAT.Wood)
	block("HalfWallTop", 7.4, 0.3, 1, 18.5, 4.15, 14, WOOD, MAT.Wood)
	for _, x in ipairs({ -3, 4 }) do -- little potted herbs on the half wall
		detailCylinder("HerbPot", 0.6, 0.7, x, 4.6, 14, Color3.fromRGB(190, 110, 70), MAT.Concrete)
		trim(model, { Name = "Herb", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.9, CFrame = at(x, 5.2, 14), Color = LEAF_GREENS[2], Material = MAT.Leafy })
	end
	local staffSign = newPart(model, { Name = "StaffSign", Size = Vector3.new(4.6, 1.2, 0.2), CFrame = at(12.5, 8.5, 14.2), Color = theme.Accent, Material = MAT.Wood })
	signText(staffSign, Enum.NormalId.Back, "👨‍🍳 KITCHEN", WHITE, "KitchenSign")

	------------------------------------------------------------------ kitchen appliances along the back
	-- tiled backsplash behind the kitchen
	detail("KitchenBacksplash", 31, 4, 0.12, 6.25, 5.6, BACK + 0.25, Color3.fromRGB(250, 250, 245), MAT.Tiles)
	-- fridge
	block("Fridge", 4, 8.5, 3.4, 19.4, 4.25, -4.2, METAL, MAT.Metal)
	block("FridgeDoorLine", 4.05, 0.1, 0.1, 19.4, 5.8, -2.45, Color3.fromRGB(150, 150, 158))
	block("FridgeHandle", 0.25, 2.2, 0.3, 17.8, 6.9, -2.35, Color3.fromRGB(120, 120, 128), MAT.Metal)
	block("FridgeHandle", 0.25, 2.2, 0.3, 17.8, 3.6, -2.35, Color3.fromRGB(120, 120, 128), MAT.Metal)
	detail("FridgeKick", 3.8, 0.4, 0.1, 19.4, 0.4, -2.47, Color3.fromRGB(60, 60, 65), MAT.Metal)
	for i, color in ipairs({ Color3.fromRGB(255, 90, 110), Color3.fromRGB(90, 170, 255), Color3.fromRGB(255, 210, 60) }) do
		detail("FridgeMagnet", 0.4, 0.4, 0.08, 19 + i * 0.6, 7 - (i % 2) * 0.5, -2.47, color)
	end
	detail("FridgeNote", 0.8, 1, 0.05, 20.5, 6.4, -2.48, Color3.fromRGB(255, 250, 200))
	-- sink counter
	block("SinkCounter", 6, 3.5, 3, 13, 1.75, -4.4, WHITE, MAT.Wood)
	for _, x in ipairs({ 11.5, 14.5 }) do
		detail("SinkCabinetDoor", 2.6, 2.4, 0.08, x, 1.8, -2.87, Color3.fromRGB(235, 235, 235), MAT.Wood)
		detail("SinkCabinetKnob", 0.2, 0.2, 0.15, x + ((x < 13) and 1 or -1), 2.4, -2.8, CHROME, MAT.Metal)
	end
	block("SinkTop", 6.2, 0.3, 3.2, 13, 3.65, -4.4, Color3.fromRGB(60, 60, 65), MAT.Granite)
	block("Sink", 2.6, 0.2, 1.8, 13, 3.72, -4.2, METAL, MAT.Metal)
	block("Faucet", 0.25, 1.4, 0.25, 13, 4.5, -5.3, METAL, MAT.Metal)
	block("FaucetSpout", 0.25, 0.25, 0.9, 13, 5.1, -4.95, METAL, MAT.Metal)
	for _, x in ipairs({ 12.5, 13.5 }) do
		detail("FaucetTap", 0.3, 0.2, 0.3, x, 4.3, -5.3, CHROME, MAT.Metal)
	end
	detail("DishSoap", 0.4, 0.8, 0.4, 15.2, 4.2, -5.3, Color3.fromRGB(90, 200, 120), MAT.Glass)
	for i = 0, 3 do -- a stack of plates next to the sink
		detailCylinder("CleanPlate", 0.08, 1.2, 10.9, 3.85 + i * 0.1, -4.4, WHITE, MAT.Marble)
	end
	-- wall oven
	block("Oven", 3.5, 7, 3, -16.5, 3.5, -4.5, Color3.fromRGB(50, 50, 55), MAT.Metal)
	block("OvenWindow", 2.6, 1.8, 0.1, -16.5, 2.3, -2.95, Color3.fromRGB(255, 150, 60))
	block("OvenWindow", 2.6, 1.8, 0.1, -16.5, 5.2, -2.95, Color3.fromRGB(255, 150, 60))
	for _, y in ipairs({ 3.5, 6.4 }) do
		detail("OvenHandle", 2.6, 0.18, 0.2, -16.5, y, -2.85, CHROME, MAT.Metal)
	end
	detail("OvenPanel", 3.3, 0.4, 0.08, -16.5, 6.85, -2.96, Color3.fromRGB(30, 30, 35), MAT.Metal)
	-- shelves on the kitchen's side wall, on brackets
	for _, y in ipairs({ 6.5, 9 }) do
		block("KitchenShelf", 1.2, 0.2, 9, 21.4, y, 4, WOOD, MAT.Wood)
		for _, z in ipairs({ 0.2, 7.8 }) do
			detail("ShelfBracket", 0.8, 0.5, 0.15, 21.6, y - 0.35, z, Color3.fromRGB(60, 60, 65), MAT.Metal)
		end
		for i = 0, 3 do
			local jarColor = (i % 2 == 0) and Color3.fromRGB(255, 190, 60) or Color3.fromRGB(245, 240, 225)
			cylinder("Jar", 1, 0.7, 21.4, y + 0.6, 0.8 + i * 2.1, jarColor, MAT.Glass).Transparency = 0.15
			detailCylinder("JarLid", 0.15, 0.75, 21.4, y + 1.17, 0.8 + i * 2.1, (i % 2 == 0) and Color3.fromRGB(200, 60, 60) or Color3.fromRGB(90, 140, 200), MAT.Metal)
			detail("JarLabel", 0.05, 0.4, 0.4, 21.04, y + 0.55, 0.8 + i * 2.1, WHITE)
		end
	end
	-- hanging pots and pans rail over the stove area
	block("PotRail", 12, 0.2, 0.2, 0, 13, -2, METAL, MAT.Metal)
	for _, x in ipairs({ -6, 6 }) do
		detail("PotRailRod", 0.15, H - 13, 0.15, x, 13 + (H - 13) / 2, -2, METAL, MAT.Metal)
	end
	for i = 0, 3 do
		cylinder("HangingPan", 0.2, 1.6, -4.5 + i * 3, 12, -2, Color3.fromRGB(45, 45, 50), MAT.Metal)
		detail("HangingPanHook", 0.1, 0.9, 0.1, -4.5 + i * 3, 12.55, -2, METAL, MAT.Metal)
	end
	-- kitchen ceiling lights
	for _, x in ipairs({ -4, 12 }) do
		detail("CeilingLight", 5, 0.3, 1.4, x, H - 1.05, 5, CHROME, MAT.Metal)
		local panel = detail("CeilingLightPanel", 4.6, 0.1, 1.1, x, H - 1.25, 5, Color3.fromRGB(255, 250, 235), MAT.Glass)
		glow(panel, 22, 0.6, Color3.fromRGB(255, 245, 225))
	end

	------------------------------------------------------------------ dining room (keeps the lane from the door to the counter clear)
	for _, spot in ipairs({ Vector3.new(0, 0, 21), Vector3.new(9, 0, 21), Vector3.new(0, 0, 28.5), Vector3.new(9, 0, 28.5) }) do
		cylinder("TableTop", 0.3, 3.6, spot.X, 3, spot.Z, WHITE, MAT.Marble)
		detailCylinder("TableEdge", 0.2, 3.75, spot.X, 2.95, spot.Z, CHROME, MAT.Metal)
		cylinder("TableLeg", 3, 0.4, spot.X, 1.5, spot.Z, Color3.fromRGB(60, 60, 65), MAT.Metal)
		detailCylinder("TableFoot", 0.2, 1.8, spot.X, 0.28, spot.Z, Color3.fromRGB(60, 60, 65), MAT.Metal)
		-- syrup, salt and a napkin holder on every table
		detailCylinder("TableSyrup", 0.7, 0.35, spot.X - 0.5, 3.5, spot.Z - 0.3, Color3.fromRGB(150, 80, 25), MAT.Glass)
		detailCylinder("TableSyrupCap", 0.15, 0.25, spot.X - 0.5, 3.92, spot.Z - 0.3, Color3.fromRGB(210, 50, 50))
		detailCylinder("TableSalt", 0.45, 0.25, spot.X - 0.1, 3.38, spot.Z - 0.5, WHITE, MAT.Glass)
		detail("NapkinHolder", 0.6, 0.45, 0.3, spot.X + 0.4, 3.38, spot.Z - 0.3, CHROME, MAT.Metal)
		detail("Napkins", 0.5, 0.4, 0.15, spot.X + 0.4, 3.45, spot.Z - 0.3, WHITE, MAT.Fabric)
		for _, dx in ipairs({ -2.7, 2.7 }) do
			cylinder("Stool", 0.4, 1.8, spot.X + dx, 2, spot.Z, theme.Accent, MAT.Leather)
			detailCylinder("StoolRing", 0.25, 1.9, spot.X + dx, 1.78, spot.Z, CHROME, MAT.Metal)
			cylinder("StoolLeg", 2, 0.3, spot.X + dx, 1, spot.Z, Color3.fromRGB(60, 60, 65), MAT.Metal)
			detailCylinder("StoolFootRing", 0.12, 1.1, spot.X + dx, 0.9, spot.Z, CHROME, MAT.Metal)
		end
		cylinder("LampShade", 1.2, 2.4, spot.X, 15, spot.Z, theme.Accent, MAT.Metal)
		local bulb = trim(model, { Name = "LampBulb", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.8, CFrame = at(spot.X, 14.3, spot.Z),
			Color = LAMP_GLOW, Material = MAT.Glass })
		glow(bulb, 14, 0.8)
		block("LampCord", 0.1, H - 15.6, 0.1, spot.X, 15.6 + (H - 15.6) / 2, spot.Z, Color3.fromRGB(40, 40, 45))
	end
	-- a booth along the right wall, with tufted cushions
	block("BoothSeat", 3, 1.8, 12, 19.5, 0.9, 25, theme.Accent, MAT.Leather)
	block("BoothBack", 1, 4, 12, 21.4, 2, 25, theme.Accent, MAT.Leather)
	for z = 20, 30, 2.5 do
		detail("BoothTuft", 0.25, 2.2, 0.15, 20.88, 2.8, z, theme.Accent:Lerp(Color3.new(0, 0, 0), 0.25), MAT.Leather)
	end
	detail("BoothPiping", 1.2, 0.2, 12.1, 21.4, 4.05, 25, CHROME, MAT.Metal)
	block("BoothTable", 3, 0.3, 10, 16.3, 3, 25, WHITE, MAT.Marble)
	detail("BoothTableEdge", 3.1, 0.2, 10.1, 16.3, 2.95, 25, CHROME, MAT.Metal)
	block("BoothTableLeg", 0.6, 2.8, 0.6, 16.3, 1.5, 25, Color3.fromRGB(60, 60, 65), MAT.Metal)
	-- framed pictures of pancakes above the booth
	for i, picture in ipairs({ "🥞", "🧈", "🍓" }) do
		local z = 20 + (i - 1) * 5
		detail("PictureFrame", 0.2, 3.2, 3.2, 21.85, 9.5, z, (i == 2) and DARK_WOOD or theme.Accent, MAT.Wood)
		local canvas = detail("Picture", 0.25, 2.6, 2.6, 21.85, 9.5, z, Color3.fromRGB(255, 248, 230), MAT.Fabric)
		signText(canvas, Enum.NormalId.Left, picture, WHITE)
	end
	-- plants in the front corners
	for _, x in ipairs({ -20, 20 }) do
		cylinder("PlantPot", 2, 2.4, x, 1, 32, Color3.fromRGB(190, 110, 70), MAT.Concrete)
		detailCylinder("PlantPotRim", 0.4, 2.7, x, 2, 32, Color3.fromRGB(170, 95, 60), MAT.Concrete)
		for i = 1, 4 do
			newPart(model, { Name = "PlantLeaves", Size = Vector3.one * (2.3 - i * 0.3), CFrame = at(x + (i - 2) * 0.45, 2.3 + i * 0.85, 32 + (i % 2) * 0.3) * CFrame.Angles(0, i, 0.2),
				Color = LEAF_GREENS[(i - 1) % #LEAF_GREENS + 1], Material = MAT.Leafy })
		end
	end
	-- a runner rug from the front door to the counter
	detail("Rug", 4.4, 0.05, 15, DOOR_X, 0.2, 24.5, theme.Accent, MAT.Carpet)
	detail("RugBorder", 5, 0.04, 15.6, DOOR_X, 0.19, 24.5, Color3.fromRGB(245, 235, 210), MAT.Carpet)
	-- menu board on the left wall, facing the room
	local menu = newPart(model, { Name = "MenuBoard", Size = Vector3.new(0.3, 5, 9), CFrame = at(-21.8, 11, 22), Color = Color3.fromRGB(40, 40, 45), Material = MAT.Slate })
	detail("MenuFrame", 0.2, 5.6, 9.6, -21.9, 11, 22, DARK_WOOD, MAT.Wood)
	detail("ChalkTray", 0.6, 0.2, 9, -21.6, 8.4, 22, DARK_WOOD, MAT.Wood)
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
	slab(ground, "Grass", -W, NORTH, W, SOUTH, 0, 14, GRASS, MAT.Grass)
	-- a rocky shoreline between the grass and the sand
	for _, side in ipairs({ -1, 1 }) do
		slab(ground, "Shore", side * W - 1.5, NORTH - 1.5, side * W + 1.5, SOUTH + 1.5, -0.1, 3, Color3.fromRGB(175, 165, 145), MAT.Rock)
	end
	for _, z in ipairs({ NORTH, SOUTH }) do
		slab(ground, "Shore", -W - 1.5, z - 1.5, W + 1.5, z + 1.5, -0.1, 3, Color3.fromRGB(175, 165, 145), MAT.Rock)
	end

	-- the main path: cobblestone with brick curbs and a paler center stripe
	slab(ground, "Path", -P, hub.Z + 20, P, spawn.Z - 20, 0.15, 0.3, PATH, MAT.Cobble)
	slab(ground, "PathStripe", -1.5, hub.Z + 20, 1.5, spawn.Z - 20, 0.16, 0.3, PATH:Lerp(WHITE, 0.35), MAT.Pavement)
	for _, side in ipairs({ -1, 1 }) do
		slab(ground, "PathEdge", side * P - 0.6, hub.Z + 20, side * P + 0.6, spawn.Z - 20, 0.25, 0.4, PATH_EDGE, MAT.Brick)
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
		slab(plotsFolder, "Plot", math.min(x1, x2), origin.Z - 34, math.max(x1, x2), origin.Z + 34, 0.12, 0.3, PLOT_GRASS, MAT.Grass)
		table.insert(blocked, { math.min(x1, x2), origin.Z - 34, math.max(x1, x2), origin.Z + 34 })
		-- path from the main path to the front door
		local door = (cframe * CFrame.new(WorldBuilder.RESTAURANT_DOOR)).Position
		slab(plotsFolder, "DoorPath", math.min(side * P, door.X), door.Z - 3.5, math.max(side * P, door.X), door.Z + 3.5, 0.17, 0.3, PATH, MAT.Cobble)
		for _, dz in ipairs({ -3.7, 3.7 }) do -- stone edging along the door path
			slab(plotsFolder, "DoorPathEdge", math.min(side * (P + 0.6), door.X), door.Z + dz - 0.3, math.max(side * (P + 0.6), door.X), door.Z + dz + 0.3, 0.3, 0.3, PATH_EDGE, MAT.Brick)
		end
		-- lamps on both sides of the door path, near the main path, and a mailbox
		for _, dz in ipairs({ -5, 5 }) do
			lampPost(plotsFolder, Vector3.new(side * (P + 4), 0.27, door.Z + dz), 8)
		end
		local mailbox = CFrame.new(side * (P + 7), 0.27, door.Z - 5.5) * CFrame.Angles(0, side * math.rad(-90), 0)
		newPart(plotsFolder, { Name = "MailboxPost", Size = Vector3.new(0.4, 3.4, 0.4), CFrame = mailbox * CFrame.new(0, 1.7, 0), Color = Color3.fromRGB(150, 100, 60), Material = MAT.Wood })
		trim(plotsFolder, { Name = "Mailbox", Size = Vector3.new(0.9, 0.9, 1.6), CFrame = mailbox * CFrame.new(0, 3.6, 0), Color = GameConfig.Restaurants[index].Accent, Material = MAT.Metal })
		trim(plotsFolder, { Name = "MailboxTop", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.6, 0.9, 0.9), CFrame = mailbox * CFrame.new(0, 4.05, 0) * CFrame.Angles(0, math.rad(90), 0),
			Color = GameConfig.Restaurants[index].Accent, Material = MAT.Metal })
		trim(plotsFolder, { Name = "MailboxFlag", Size = Vector3.new(0.08, 0.8, 0.35), CFrame = mailbox * CFrame.new(0.5, 4.2, 0.3), Color = Color3.fromRGB(230, 50, 50), Material = MAT.Metal })
		-- a white picket fence around the back and sides of the plot (the path side stays open)
		local near, far = side * 14, side * (W - 9)
		fence(plotsFolder, Vector3.new(far, 0.27, origin.Z - 33), Vector3.new(far, 0.27, origin.Z + 33))
		fence(plotsFolder, Vector3.new(near, 0.27, origin.Z - 33), Vector3.new(far, 0.27, origin.Z - 33))
		fence(plotsFolder, Vector3.new(near, 0.27, origin.Z + 33), Vector3.new(far, 0.27, origin.Z + 33))
		-- pebbles and flowers scattered over the plot (away from the building)
		for _ = 1, 60 do
			local x = side * rng:NextNumber(14, W - 12)
			local z = origin.Z + rng:NextNumber(-32, 32)
			local localPoint = cframe:PointToObjectSpace(Vector3.new(x, 0, z))
			local onBuilding = math.abs(localPoint.X) < 25 and localPoint.Z > -9 and localPoint.Z < 39
			if not onBuilding then
				local roll = rng:NextNumber()
				if roll < 0.35 then
					pebble(plotsFolder, Vector3.new(x, 0.27, z), rng)
				elseif roll < 0.6 then
					grassTuft(plotsFolder, Vector3.new(x, 0.27, z), rng)
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
	slab(ground, "SpawnPlazaEdge", -33, spawn.Z - 23, 33, spawn.Z + 26, 0.1, 0.3, PATH_EDGE, MAT.Brick)
	slab(ground, "SpawnPlaza", -32, spawn.Z - 22, 32, spawn.Z + 25, 0.18, 0.3, PATH, MAT.Cobble)
	-- a compass-rose inlay in the plaza, between the arch and the spawn point
	local inlay = CFrame.new(0, 0, spawn.Z - 10)
	newPart(ground, { Name = "PlazaInlay", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 14, 14),
		CFrame = inlay * CFrame.new(0, 0.19, 0) * FLAT, Color = Color3.fromRGB(215, 175, 130), Material = MAT.Sandstone })
	newPart(ground, { Name = "PlazaInlay", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 10, 10),
		CFrame = inlay * CFrame.new(0, 0.2, 0) * FLAT, Color = Color3.fromRGB(235, 215, 180), Material = MAT.Marble })
	for i = 0, 3 do
		trim(ground, { Name = "InlayStar", Size = Vector3.new(1.4, 0.32, 9), CFrame = inlay * CFrame.new(0, 0.21, 0) * CFrame.Angles(0, i * math.pi / 4, 0),
			Color = (i % 2 == 0) and Color3.fromRGB(230, 90, 60) or Color3.fromRGB(255, 190, 70), Material = MAT.Marble })
	end
	table.insert(blocked, { -34, spawn.Z - 24, 34, spawn.Z + 27 })
	for _, x in ipairs({ -9, 9 }) do
		newPart(landmarks, { Name = "ArchPillar", Size = Vector3.new(2.5, 16, 2.5), CFrame = CFrame.new(x, 8, spawn.Z - 22),
			Color = Color3.fromRGB(255, 190, 70), Material = MAT.Sandstone })
		trim(landmarks, { Name = "ArchPlinth", Size = Vector3.new(3.4, 2, 3.4), CFrame = CFrame.new(x, 1, spawn.Z - 22), Color = STONE, Material = MAT.Limestone })
		trim(landmarks, { Name = "ArchCapital", Size = Vector3.new(3.2, 0.8, 3.2), CFrame = CFrame.new(x, 14.4, spawn.Z - 22), Color = STONE, Material = MAT.Limestone })
		for _, y in ipairs({ 4, 8, 12 }) do
			trim(landmarks, { Name = "ArchBand", Size = Vector3.new(2.7, 0.35, 2.7), CFrame = CFrame.new(x, y, spawn.Z - 22), Color = Color3.fromRGB(230, 90, 60), Material = MAT.Sandstone })
		end
		-- a pancake stack on top of each pillar
		for i = 0, 2 do
			trim(landmarks, { Name = "ArchPancake", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.7, 3.2 - i * 0.2, 3.2 - i * 0.2),
				CFrame = CFrame.new(x, 19.7 + i * 0.72, spawn.Z - 22) * FLAT, Color = Color3.fromRGB(225, 165, 75), Material = MAT.Sand, CastShadow = true })
		end
		trim(landmarks, { Name = "ArchButter", Size = Vector3.new(0.9, 0.5, 0.9), CFrame = CFrame.new(x, 21.6, spawn.Z - 22), Color = Color3.fromRGB(255, 225, 90) })
		lampPost(landmarks, Vector3.new(x * 1.6, 0.18, spawn.Z - 19), 8)
	end
	local arch = newPart(landmarks, { Name = "ArchSign", Size = Vector3.new(24, 4.5, 1.5), CFrame = CFrame.new(0, 17, spawn.Z - 22),
		Color = Color3.fromRGB(230, 90, 60), Material = MAT.Wood })
	trim(landmarks, { Name = "ArchSignFrame", Size = Vector3.new(25, 5.5, 1.2), CFrame = CFrame.new(0, 17, spawn.Z - 22), Color = Color3.fromRGB(120, 70, 40), Material = MAT.Wood })
	for _, face in ipairs({ -1, 1 }) do
		for i = 0, 11 do
			for _, y in ipairs({ 14.95, 19.05 }) do
				trim(landmarks, { Name = "ArchBulb", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.4,
					CFrame = CFrame.new(-11 + i * 2, y, spawn.Z - 22 + face * 0.8), Color = LAMP_GLOW, Material = MAT.Glass })
			end
		end
	end
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
	slab(ground, "CenterPlaza", -20, center.Z - 20, 20, center.Z + 20, 0.2, 0.3, PATH, MAT.Cobble)
	slab(ground, "CenterPlazaEdge", -21, center.Z - 21, 21, center.Z + 21, 0.1, 0.3, Color3.fromRGB(190, 120, 80), MAT.Brick)
	for _, corner in ipairs({ Vector3.new(-19, 0, -19), Vector3.new(19, 0, -19), Vector3.new(-19, 0, 19), Vector3.new(19, 0, 19) }) do
		lampPost(landmarks, center + corner + Vector3.new(0, 0.2, 0), 9)
	end
	fountain(landmarks, center + Vector3.new(0, 0.2, 0))
	for _, corner in ipairs({ Vector3.new(-14, 0, -14), Vector3.new(14, 0, -14), Vector3.new(-14, 0, 14), Vector3.new(14, 0, 14) }) do
		flowerBed(landmarks, center + corner + Vector3.new(0, 0.2, 0), 7, 7, rng)
	end
	for _, dz in ipairs({ -9, 9 }) do
		bench(landmarks, CFrame.new(-10, 0.2, center.Z + dz) * CFrame.Angles(0, math.rad(90), 0))
		bench(landmarks, CFrame.new(10, 0.2, center.Z + dz) * CFrame.Angles(0, math.rad(-90), 0))
	end

	-- MARKET HUB at the north end: a gazebo and stalls
	slab(ground, "HubPlazaEdge", -41, hub.Z - 29, 41, hub.Z + 23, 0.1, 0.3, PATH_EDGE, MAT.Brick)
	slab(ground, "HubPlaza", -40, hub.Z - 28, 40, hub.Z + 22, 0.2, 0.3, PATH, MAT.Cobble)
	for _, x in ipairs({ -38, 38 }) do
		for _, z in ipairs({ hub.Z - 26, hub.Z + 20 }) do
			lampPost(landmarks, Vector3.new(x, 0.2, z), 9)
		end
	end
	-- strings of colored bulbs from the gazebo out to the stalls
	for _, x in ipairs({ -1, 1 }) do
		for _, dz in ipairs({ -14, 8 }) do
			local a = hub + Vector3.new(x * 9, 10.2, -4)
			local b = Vector3.new(x * 26, 8.6, hub.Z + dz)
			local length = (b - a).Magnitude
			local count = math.floor(length / 2.2)
			trim(landmarks, { Name = "LightString", Size = Vector3.new(0.08, 0.08, length), CFrame = CFrame.lookAt((a + b) / 2, b), Color = IRON })
			for i = 1, count do
				local t = i / (count + 1)
				trim(landmarks, { Name = "StringBulb", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.4,
					CFrame = CFrame.new(a:Lerp(b, t) - Vector3.new(0, 0.2, 0)), Color = FLOWER_COLORS[(i % #FLOWER_COLORS) + 1], Material = MAT.Glass })
			end
		end
	end
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
			lampPost(nature, Vector3.new(P + 2.5, 0, z), 9)
		end
		if awayFromDoors(z + 13) then
			tree(nature, Vector3.new(P + 4, 0, z + 13), rng, 0.6)
			lampPost(nature, Vector3.new(-P - 2.5, 0, z + 13), 9)
		end
	end
	-- grass tufts all over the open lawn
	for _ = 1, 260 do
		local x = rng:NextNumber(-W + 4, W - 4)
		local z = rng:NextNumber(NORTH + 4, SOUTH - 4)
		if isClear(blocked, x, z, 1) and math.abs(z - center.Z) > 22 then
			grassTuft(nature, Vector3.new(x, 0, z), rng)
		end
	end
	-- beach umbrellas, towels, driftwood and shells on the sand
	local beach = Instance.new("Folder")
	beach.Name = "Beach"
	beach.Parent = world
	for i = 1, 18 do
		local onSide = rng:NextNumber() < 0.7
		local x = onSide and ((rng:NextNumber() < 0.5 and -1 or 1) * (W + rng:NextNumber(4, 11))) or rng:NextNumber(-W + 20, W - 20)
		local z = onSide and rng:NextNumber(NORTH, SOUTH) or (SOUTH + rng:NextNumber(4, 11))
		local spot = Vector3.new(x, -0.4, z)
		if i % 3 == 0 then
			local color = FLOWER_COLORS[rng:NextInteger(1, #FLOWER_COLORS)]
			newPart(beach, { Name = "UmbrellaPole", Size = Vector3.new(0.3, 7, 0.3), CFrame = CFrame.new(spot + Vector3.new(0, 3.5, 0)), Color = WHITE, Material = MAT.Wood })
			for k = 0, 7 do
				trim(beach, { Name = "Umbrella", Size = Vector3.new(2.4, 0.15, 3.4),
					CFrame = CFrame.new(spot + Vector3.new(0, 6.9, 0)) * CFrame.Angles(0, k * math.pi / 4, 0) * CFrame.new(0, 0, 1.55) * CFrame.Angles(math.rad(-18), 0, 0),
					Color = (k % 2 == 0) and color or WHITE, Material = MAT.Fabric, CastShadow = true })
			end
			trim(beach, { Name = "Towel", Size = Vector3.new(2.4, 0.06, 4.5), CFrame = CFrame.new(spot + Vector3.new(1.8, 0.03, 1)) * CFrame.Angles(0, rng:NextNumber(), 0),
				Color = color:Lerp(WHITE, 0.3), Material = MAT.Fabric })
		elseif i % 3 == 1 then
			trim(beach, { Name = "Driftwood", Size = Vector3.new(0.6, 0.6, rng:NextNumber(4, 7)), CFrame = CFrame.new(spot + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, rng:NextNumber() * math.pi, 0.2),
				Color = Color3.fromRGB(185, 165, 140), Material = MAT.Wood })
		else
			for _ = 1, 3 do
				trim(beach, { Name = "Shell", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.45,
					CFrame = CFrame.new(spot + Vector3.new(rng:NextNumber(-2, 2), 0.05, rng:NextNumber(-2, 2))), Color = Color3.fromRGB(255, 225, 215) })
			end
		end
	end

	world.Parent = workspace
	return world
end

return WorldBuilder
