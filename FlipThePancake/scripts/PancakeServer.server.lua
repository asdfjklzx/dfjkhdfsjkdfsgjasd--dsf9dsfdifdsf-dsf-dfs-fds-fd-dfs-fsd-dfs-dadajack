-- PancakeServer (Script in ServerScriptService)
-- Builds the town, the 6 restaurants and the shop, enforces all the rules and hands out Butter.
-- The client only sends "pour", "flip with this power" and "serve". The server decides everything else.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local PanConfig = require(ReplicatedStorage:WaitForChild("PanConfig"))
local SizeConfig = require(ReplicatedStorage:WaitForChild("SizeConfig"))
local PancakeConfig = require(ReplicatedStorage:WaitForChild("PancakeConfig"))
local ToppingConfig = require(ReplicatedStorage:WaitForChild("ToppingConfig"))
local PancakeVisuals = require(ReplicatedStorage:WaitForChild("PancakeVisuals"))
local DataManager = require(script.Parent:WaitForChild("DataManager"))
local EventManager = require(script.Parent:WaitForChild("EventManager"))
local OrderManager = require(script.Parent:WaitForChild("OrderManager"))
local WorldBuilder = require(script.Parent:WaitForChild("WorldBuilder"))

--------------------------------------------------------------------
-- LIGHTING: plain, clean daytime (no bloom or glow).
-- Environment lighting lets metal, glass and marble pick up reflections from the sky,
-- and soft shadows give every part some depth.
--------------------------------------------------------------------
for _, name in ipairs({ "PancakeBloom", "PancakeColor", "PancakeSunRays", "PancakeAtmosphere" }) do
	local old = Lighting:FindFirstChild(name) -- effects left over from older versions of the game
	if old then
		old:Destroy()
	end
end
Lighting.ClockTime = 14
Lighting.Brightness = 2
Lighting.GlobalShadows = true
Lighting.ShadowSoftness = 0.3
Lighting.EnvironmentDiffuseScale = 1
Lighting.EnvironmentSpecularScale = 1
Lighting.Ambient = Color3.fromRGB(70, 70, 80)
Lighting.OutdoorAmbient = Color3.fromRGB(135, 135, 150)

--------------------------------------------------------------------
-- REMOTES
--------------------------------------------------------------------
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"

local function newRemote(className, name)
	local remote = Instance.new(className)
	remote.Name = name
	remote.Parent = remotes
	return remote
end

local PourRemote = newRemote("RemoteFunction", "Pour")
local FlipRemote = newRemote("RemoteFunction", "Flip")
local ServeRemote = newRemote("RemoteFunction", "Serve")
local LeaveRemote = newRemote("RemoteEvent", "LeaveStation")
local StationEvent = newRemote("RemoteEvent", "StationEvent") -- server -> client: "Enter" / "Leave" / "PanChanged"
local ShopRemote = newRemote("RemoteFunction", "Shop")        -- client -> server: ("Buy" or "Equip", category, id)
local GetDataRemote = newRemote("RemoteFunction", "GetData")  -- client asks for its shop data
local DataEvent = newRemote("RemoteEvent", "DataUpdate")      -- server -> client: shop data changed
local OpenShopEvent = newRemote("RemoteEvent", "OpenShop")    -- server -> client: player used the shop stand
remotes.Parent = ReplicatedStorage


--------------------------------------------------------------------
-- BUILD THE KITCHEN LINE (one station per cook, all from basic parts)
-- Later you can swap these parts for custom meshes.
--------------------------------------------------------------------
local FLAT = CFrame.Angles(0, 0, math.rad(90))     -- lays a cylinder flat
local STAND_UP = FLAT                              -- cylinder standing upright
local FACE_OUT = CFrame.Angles(0, math.rad(90), 0) -- cylinder facing the player

-- Material by name, so a material Roblox doesn't know yet falls back to plastic instead of erroring
local MAT = {}
for key, name in pairs({ Marble = "Marble", Slate = "Slate", Plaster = "Plaster", Tiles = "CeramicTiles", Wood = "Wood",
	Planks = "WoodPlanks", Metal = "Metal", Glass = "Glass", Fabric = "Fabric", Leather = "Leather" }) do
	local ok, material = pcall(function()
		return Enum.Material[name]
	end)
	MAT[key] = ok and material or Enum.Material.SmoothPlastic
end

local function newPart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if props.Shape then
		part.Shape = props.Shape
	end
	for key, value in pairs(props) do
		if key ~= "Parent" and key ~= "Shape" then
			part[key] = value
		end
	end
	part.Parent = props.Parent
	return part
end

local stationsFolder = Instance.new("Folder")
stationsFolder.Name = "Stations"
stationsFolder.Parent = workspace

-- Jars and bottles on the shelves: { x, height, jar color, lid color }
local SHELF_ITEMS = {
	{ -7.7, 0.9, Color3.fromRGB(255, 190, 60), Color3.fromRGB(200, 60, 60) },   -- honey
	{ -6.5, 0.9, Color3.fromRGB(200, 50, 70), Color3.fromRGB(245, 245, 245) },  -- jam
	{ -5.3, 0.9, Color3.fromRGB(245, 240, 225), Color3.fromRGB(90, 140, 200) }, -- flour
	{ 5.3, 1.2, Color3.fromRGB(130, 65, 20), Color3.fromRGB(210, 50, 50) },     -- maple syrup
	{ 6.5, 0.9, Color3.fromRGB(70, 80, 170), Color3.fromRGB(245, 245, 245) },   -- blueberries
	{ 7.7, 1.2, Color3.fromRGB(130, 65, 20), Color3.fromRGB(210, 50, 50) },     -- maple syrup
}

local function surfaceText(part, face, text, stroke, name)
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
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = stroke and 0 or 1
	label.Text = text
	label.Name = name or "Text"
	label.Parent = surface
	return label
end

local function buildStation(index)
	local stationCFrame = GameConfig.GetStationCFrame(index) -- position + which way the kitchen faces
	local P = stationCFrame.Position
	local theme = GameConfig.Restaurants[index]
	local model = Instance.new("Model")
	model.Name = "Station" .. index
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent -- always loaded on every client
	model:SetAttribute("Index", index)
	model:SetAttribute("StackHeight", 0)
	model:SetAttribute("RestaurantName", theme.Name)

	-- the restaurant building around the kitchen (walls, door, windows, sign, tables...)
	WorldBuilder.BuildRestaurant(model, stationCFrame, theme)

	local function at(x, y, z)
		return stationCFrame * CFrame.new(x, y, z)
	end

	-- Decoration only: can't be walked into, clicked through or hit by the camera
	local function detail(props)
		props.CanCollide = false
		props.CanQuery = false
		props.CanTouch = false
		props.CastShadow = props.CastShadow or false
		props.Parent = model
		return newPart(props)
	end
	local CHROME = Color3.fromRGB(215, 218, 225)
	local IRON = Color3.fromRGB(40, 40, 45)
	local CABINET = Color3.fromRGB(205, 65, 65)

	-- Checkered diner floor: polished marble tiles (the pattern lines up across neighboring stations)
	for ix = 0, 8 do
		for iz = 0, 6 do
			local worldColumn = math.floor(P.X / 2 + 0.5) - 4 + ix
			local light = ((worldColumn + iz) % 2 == 0)
			newPart({ Name = "FloorTile", Size = Vector3.new(2, 0.2, 2), CFrame = at(-8 + ix * 2, 0.1, -4.5 + iz * 2),
				Color = light and Color3.fromRGB(250, 248, 240) or Color3.fromRGB(45, 45, 55),
				Material = light and MAT.Marble or MAT.Slate, Reflectance = 0.04, Parent = model })
		end
	end

	-- Back wall: plaster, a tiled backsplash with chrome trim and a crown molding
	newPart({ Name = "Wall", Size = Vector3.new(18, 12, 0.5), CFrame = at(0, 6, -3.75),
		Color = theme.Wall, Material = MAT.Plaster, Parent = model })
	newPart({ Name = "Backsplash", Size = Vector3.new(18, 3, 0.1), CFrame = at(0, 5.1, -3.45),
		Color = Color3.fromRGB(245, 245, 240), Material = MAT.Tiles, Parent = model })
	for _, y in ipairs({ 3.6, 6.6 }) do
		detail({ Name = "BacksplashTrim", Size = Vector3.new(18, 0.15, 0.16), CFrame = at(0, y, -3.4), Color = CHROME, Material = MAT.Metal })
	end
	detail({ Name = "CrownMolding", Size = Vector3.new(18.4, 0.5, 0.5), CFrame = at(0, 11.75, -3.4), Color = Color3.fromRGB(250, 248, 240), Material = MAT.Wood })
	detail({ Name = "CrownMolding", Size = Vector3.new(18.4, 0.2, 0.7), CFrame = at(0, 11.4, -3.35), Color = Color3.fromRGB(250, 248, 240), Material = MAT.Wood })

	-- Utensils hanging from a rail on the backsplash
	detail({ Name = "UtensilRail", Size = Vector3.new(7.5, 0.12, 0.12), CFrame = at(0, 6.3, -3.28), Color = CHROME, Material = MAT.Metal })
	for _, x in ipairs({ -3.75, 3.75 }) do
		detail({ Name = "UtensilRailMount", Size = Vector3.new(0.2, 0.3, 0.2), CFrame = at(x, 6.3, -3.33), Color = CHROME, Material = MAT.Metal })
	end
	local UTENSILS = { -- x, handle length, head shape, head color
		{ -3, 1.1, "Ladle" }, { -1.6, 0.9, "Whisk" }, { 1.6, 1, "Turner" }, { 3, 1.1, "Spoon" },
	}
	for _, tool in ipairs(UTENSILS) do
		local x, length, kind = tool[1], tool[2], tool[3]
		detail({ Name = "UtensilHook", Size = Vector3.new(0.05, 0.25, 0.05), CFrame = at(x, 6.15, -3.28), Color = CHROME, Material = MAT.Metal })
		detail({ Name = "UtensilHandle", Size = Vector3.new(0.1, length, 0.08), CFrame = at(x, 6.05 - length / 2, -3.28),
			Color = (kind == "Spoon") and Color3.fromRGB(170, 120, 75) or CHROME, Material = (kind == "Spoon") and MAT.Wood or MAT.Metal })
		local headY = 6.05 - length - 0.2
		if kind == "Ladle" then
			detail({ Name = "LadleCup", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.5, CFrame = at(x, headY, -3.22), Color = CHROME, Material = MAT.Metal })
		elseif kind == "Whisk" then
			for i = -1, 1 do
				detail({ Name = "WhiskWire", Size = Vector3.new(0.04, 0.55, 0.04), CFrame = at(x + i * 0.09, headY, -3.28) * CFrame.Angles(0, 0, i * 0.18), Color = CHROME, Material = MAT.Metal })
			end
		elseif kind == "Turner" then
			detail({ Name = "TurnerBlade", Size = Vector3.new(0.45, 0.5, 0.04), CFrame = at(x, headY, -3.28), Color = CHROME, Material = MAT.Metal })
		else
			detail({ Name = "SpoonBowl", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.35, CFrame = at(x, headY + 0.05, -3.25), Color = Color3.fromRGB(170, 120, 75), Material = MAT.Wood })
		end
	end

	-- Side counters: cabinets with two doors, chrome pulls, a dark kickplate and a marble top
	for _, side in ipairs({ -1, 1 }) do
		newPart({ Name = "Counter", Size = Vector3.new(4, 3.5, 5), CFrame = at(6.5 * side, 1.85, 0),
			Color = CABINET, Material = MAT.Wood, Parent = model })
		detail({ Name = "Kickplate", Size = Vector3.new(3.9, 0.45, 0.1), CFrame = at(6.5 * side, 0.43, 2.52), Color = IRON, Material = MAT.Metal })
		for _, dx in ipairs({ -0.95, 0.95 }) do
			detail({ Name = "CabinetDoor", Size = Vector3.new(1.75, 2.6, 0.08), CFrame = at(6.5 * side + dx, 2, 2.53),
				Color = CABINET:Lerp(Color3.new(1, 1, 1), 0.08), Material = MAT.Wood })
			detail({ Name = "CabinetInset", Size = Vector3.new(1.25, 2.05, 0.06), CFrame = at(6.5 * side + dx, 2, 2.58),
				Color = CABINET:Lerp(Color3.new(0, 0, 0), 0.12), Material = MAT.Wood })
			detail({ Name = "CabinetPull", Size = Vector3.new(0.12, 0.8, 0.12), CFrame = at(6.5 * side + dx - (dx > 0 and 0.62 or -0.62), 2.35, 2.66),
				Color = CHROME, Material = MAT.Metal })
		end
		newPart({ Name = "CounterTop", Size = Vector3.new(4.2, 0.3, 5.2), CFrame = at(6.5 * side, 3.75, 0),
			Color = Color3.fromRGB(235, 230, 222), Material = MAT.Marble, Parent = model })
		detail({ Name = "CounterEdge", Size = Vector3.new(4.25, 0.12, 0.08), CFrame = at(6.5 * side, 3.62, 2.63), Color = CHROME, Material = MAT.Metal })
		newPart({ Name = "Shelf", Size = Vector3.new(4, 0.25, 0.9), CFrame = at(6.5 * side, 7.2, -3.05),
			Color = Color3.fromRGB(150, 100, 60), Material = MAT.Wood, Parent = model })
		for _, dx in ipairs({ -1.5, 1.5 }) do
			detail({ Name = "ShelfBracket", Size = Vector3.new(0.12, 0.5, 0.7), CFrame = at(6.5 * side + dx, 6.85, -3.15), Color = IRON, Material = MAT.Metal })
		end
	end
	-- Jars: glass with the food inside, a metal lid and a paper label
	for _, item in ipairs(SHELF_ITEMS) do
		local x, height, color, lidColor = item[1], item[2], item[3], item[4]
		newPart({ Name = "Jar", Shape = Enum.PartType.Cylinder, Size = Vector3.new(height, 0.65, 0.65),
			CFrame = at(x, 7.325 + height / 2, -3.05) * STAND_UP, Color = Color3.fromRGB(225, 240, 245), Material = MAT.Glass,
			Transparency = 0.55, Parent = model })
		detail({ Name = "JarFill", Shape = Enum.PartType.Cylinder, Size = Vector3.new(height * 0.8, 0.56, 0.56),
			CFrame = at(x, 7.325 + height * 0.42, -3.05) * STAND_UP, Color = color })
		newPart({ Name = "Lid", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.15, 0.7, 0.7),
			CFrame = at(x, 7.325 + height + 0.075, -3.05) * STAND_UP, Color = lidColor, Material = MAT.Metal, Parent = model })
		detail({ Name = "JarLabel", Size = Vector3.new(0.4, 0.3, 0.04), CFrame = at(x, 7.325 + height * 0.45, -2.72), Color = Color3.fromRGB(255, 250, 235) })
	end

	-- Wall clock with hour marks
	newPart({ Name = "ClockRim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.15, 2.3, 2.3),
		CFrame = at(-7.25, 9.6, -3.42) * FACE_OUT, Color = Color3.fromRGB(210, 45, 55), Material = MAT.Metal, Parent = model })
	newPart({ Name = "ClockFace", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.15, 2, 2),
		CFrame = at(-7.25, 9.6, -3.35) * FACE_OUT, Color = Color3.fromRGB(250, 250, 245), Parent = model })
	for i = 0, 11 do
		local angle = i / 12 * math.pi * 2
		local long = (i % 3 == 0)
		detail({ Name = "ClockMark", Size = Vector3.new(0.07, long and 0.22 or 0.12, 0.03),
			CFrame = at(-7.25 + math.sin(angle) * 0.82, 9.6 + math.cos(angle) * 0.82, -3.27) * CFrame.Angles(0, 0, -angle), Color = IRON })
	end
	newPart({ Name = "MinuteHand", Size = Vector3.new(0.1, 0.8, 0.05), CFrame = at(-7.25, 9.98, -3.25),
		Color = IRON, Parent = model })
	newPart({ Name = "HourHand", Size = Vector3.new(0.14, 0.55, 0.05),
		CFrame = at(-7.25, 9.6, -3.24) * CFrame.Angles(0, 0, math.rad(-60)) * CFrame.new(0, 0.26, 0),
		Color = IRON, Parent = model })
	detail({ Name = "ClockPin", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.08, 0.16, 0.16), CFrame = at(-7.25, 9.6, -3.2) * FACE_OUT, Color = Color3.fromRGB(210, 45, 55), Material = MAT.Metal })

	-- Neon OPEN sign on a dark backing board
	local openSign = newPart({ Name = "OpenSign", Size = Vector3.new(2, 0.9, 0.15), CFrame = at(7.25, 9.6, -3.4),
		Color = Color3.fromRGB(255, 90, 170), Material = Enum.Material.Neon, Parent = model })
	surfaceText(openSign, Enum.NormalId.Back, "OPEN", false)
	detail({ Name = "OpenSignBoard", Size = Vector3.new(2.4, 1.3, 0.08), CFrame = at(7.25, 9.6, -3.48), Color = Color3.fromRGB(30, 30, 38), Material = MAT.Metal })
	for _, dx in ipairs({ -0.9, 0.9 }) do
		detail({ Name = "OpenSignWire", Size = Vector3.new(0.04, 1.1, 0.04), CFrame = at(7.25 + dx, 10.8, -3.46), Color = IRON })
	end

	-- Left counter: the plate you stack pancakes on + a syrup bottle
	newPart({ Name = "StackPlate", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, 2.7, 2.7),
		CFrame = stationCFrame * CFrame.new(GameConfig.StackPlateOffset + Vector3.new(0, 0.05, 0)) * STAND_UP,
		Color = Color3.fromRGB(250, 250, 250), Material = MAT.Marble, Parent = model })
	newPart({ Name = "StackPlateRim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.06, 2.95, 2.95),
		CFrame = stationCFrame * CFrame.new(GameConfig.StackPlateOffset + Vector3.new(0, 0.03, 0)) * STAND_UP,
		Color = Color3.fromRGB(120, 180, 230), Material = MAT.Marble, Parent = model })
	newPart({ Name = "SyrupBottle", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.4, 0.7, 0.7),
		CFrame = at(-7.6, 4.6, -1.5) * STAND_UP, Color = Color3.fromRGB(130, 65, 20), Material = MAT.Glass, Transparency = 0.1, Parent = model })
	newPart({ Name = "SyrupCap", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 0.4, 0.4),
		CFrame = at(-7.6, 5.45, -1.5) * STAND_UP, Color = Color3.fromRGB(210, 50, 50), Parent = model })
	detail({ Name = "SyrupLabel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, 0.72, 0.72),
		CFrame = at(-7.6, 4.55, -1.5) * STAND_UP, Color = Color3.fromRGB(245, 235, 210), Parent = model })
	-- a flour sack, salt and pepper
	detail({ Name = "FlourSack", Size = Vector3.new(1.1, 1.3, 0.8), CFrame = at(-5.2, 4.55, -1.9) * CFrame.Angles(0, 0.3, 0.04),
		Color = Color3.fromRGB(240, 232, 212), Material = MAT.Fabric, CastShadow = true })
	detail({ Name = "FlourSackTop", Size = Vector3.new(0.8, 0.35, 0.6), CFrame = at(-5.2, 5.3, -1.9) * CFrame.Angles(0, 0.3, 0.2),
		Color = Color3.fromRGB(230, 220, 195), Material = MAT.Fabric })
	detail({ Name = "FlourSackBand", Size = Vector3.new(1.12, 0.3, 0.82), CFrame = at(-5.2, 4.55, -1.9) * CFrame.Angles(0, 0.3, 0.04),
		Color = Color3.fromRGB(90, 140, 200), Material = MAT.Fabric })
	for i, color in ipairs({ Color3.fromRGB(250, 250, 250), Color3.fromRGB(60, 60, 65) }) do
		detail({ Name = "Shaker", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.55, 0.3, 0.3), CFrame = at(-5.5 + i * 0.4, 4.18, 1.6) * STAND_UP,
			Color = color, Material = MAT.Glass })
		detail({ Name = "ShakerCap", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12, 0.32, 0.32), CFrame = at(-5.5 + i * 0.4, 4.5, 1.6) * STAND_UP,
			Color = CHROME, Material = MAT.Metal })
	end

	-- Right counter: a batter bowl + a butter dish
	newPart({ Name = "Bowl", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.9, 1.8, 1.8),
		CFrame = at(7.2, 4.35, -1.2) * STAND_UP, Color = Color3.fromRGB(120, 190, 230), Material = MAT.Glass, Parent = model })
	detail({ Name = "BowlRim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12, 1.95, 1.95), CFrame = at(7.2, 4.77, -1.2) * STAND_UP,
		Color = Color3.fromRGB(245, 245, 250), Material = MAT.Glass })
	detail({ Name = "BowlFoot", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12, 1.3, 1.3), CFrame = at(7.2, 3.95, -1.2) * STAND_UP,
		Color = Color3.fromRGB(100, 170, 215), Material = MAT.Glass })
	newPart({ Name = "Batter", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.05, 1.6, 1.6),
		CFrame = at(7.2, 4.8, -1.2) * STAND_UP, Color = Color3.fromRGB(250, 236, 200), Material = MAT.Plaster, Parent = model })
	newPart({ Name = "ButterDish", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12, 1.3, 1.3),
		CFrame = at(6.2, 3.96, 1.5) * STAND_UP, Color = Color3.fromRGB(250, 250, 250), Material = MAT.Marble, Parent = model })
	newPart({ Name = "Butter", Size = Vector3.new(0.7, 0.4, 0.5), CFrame = at(6.2, 4.22, 1.5),
		Color = Color3.fromRGB(255, 225, 90), Material = Enum.Material.SmoothPlastic, Parent = model })
	-- a stack of clean plates and an egg carton
	for i = 0, 3 do
		detail({ Name = "CleanPlate", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.08, 1.3, 1.3), CFrame = at(5.2, 3.95 + i * 0.1, -1.6) * STAND_UP,
			Color = Color3.fromRGB(250, 250, 250), Material = MAT.Marble })
	end
	detail({ Name = "EggCarton", Size = Vector3.new(1.4, 0.35, 0.7), CFrame = at(7.8, 4.08, 1.3) * CFrame.Angles(0, -0.2, 0), Color = Color3.fromRGB(190, 175, 150), Material = MAT.Fabric })
	for i = 0, 2 do
		detail({ Name = "Egg", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.32, CFrame = at(7.8, 4.25, 1.3) * CFrame.Angles(0, -0.2, 0) * CFrame.new(-0.4 + i * 0.4, 0, 0),
			Color = Color3.fromRGB(250, 245, 235) })
	end

	-- Real Creator Store models replace the simple part versions when they're installed (see GameConfig.Assets)
	local function swapIn(assetName, replaces, bottomCFrame, maxSize, axis)
		local asset = PancakeVisuals.GetAsset(assetName)
		if not asset then return nil end
		for _, child in ipairs(model:GetChildren()) do
			if table.find(replaces, child.Name) then
				child:Destroy()
			end
		end
		PancakeVisuals.FitAsset(asset, maxSize, axis)
		asset:PivotTo(bottomCFrame)
		asset.Name = assetName .. "Display"
		asset.Parent = model
		return asset
	end
	swapIn("SyrupBottle", { "SyrupBottle", "SyrupCap", "SyrupLabel" }, at(-7.6, 3.9, -1.5) * CFrame.Angles(0, math.rad(30), 0), 1.9, "Y")
	swapIn("Butter", { "Butter" }, at(6.2, 4.02, 1.5) * CFrame.Angles(0, 0.5, 0), 1.1)
	swapIn("Spatula", {}, at(7.2, 4.45, -1.2) * CFrame.Angles(0, 0, math.rad(-15)), 2.4, "Y") -- standing in the batter bowl

	-- Station sign: a wooden board with a darker frame
	local sign = newPart({ Name = "Sign", Size = Vector3.new(11, 2.6, 0.3), CFrame = at(0, 9.5, -3.4),
		Color = theme.Accent, Material = MAT.Wood, Parent = model })
	surfaceText(sign, Enum.NormalId.Back, "🥞 " .. theme.Name .. " 🥞", false, "RestaurantName")
	detail({ Name = "SignFrame", Size = Vector3.new(11.6, 3.2, 0.2), CFrame = at(0, 9.5, -3.5), Color = Color3.fromRGB(110, 70, 42), Material = MAT.Wood })
	for _, x in ipairs({ -5.2, 5.2 }) do
		detail({ Name = "SignBolt", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.22, CFrame = at(x, 10.55, -3.23), Color = CHROME, Material = MAT.Metal })
		detail({ Name = "SignBolt", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.22, CFrame = at(x, 8.45, -3.23), Color = CHROME, Material = MAT.Metal })
	end

	-- Stove: brushed steel body, dark enamel cooktop, a coil burner and a control strip
	local stove = newPart({ Name = "Stove", Size = Vector3.new(8, 3.5, 5), CFrame = at(0, 1.85, 0),
		Color = Color3.fromRGB(225, 227, 232), Material = MAT.Metal, Parent = model })
	newPart({ Name = "StoveTop", Size = Vector3.new(8.2, 0.3, 5.2), CFrame = at(0, 3.75, 0),
		Color = Color3.fromRGB(45, 45, 50), Material = MAT.Metal, Parent = model })
	detail({ Name = "StoveTopEdge", Size = Vector3.new(8.3, 0.12, 0.1), CFrame = at(0, 3.62, 2.63), Color = CHROME, Material = MAT.Metal })
	detail({ Name = "StoveKick", Size = Vector3.new(7.8, 0.45, 0.1), CFrame = at(0, 0.43, 2.52), Color = IRON, Material = MAT.Metal })
	newPart({ Name = "Burner", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, 4, 4),
		CFrame = at(0, 3.95, 0) * FLAT, Color = Color3.fromRGB(230, 90, 40), Material = Enum.Material.SmoothPlastic, Parent = model })
	detail({ Name = "DripPan", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.06, 4.6, 4.6), CFrame = at(0, 3.92, 0) * FLAT,
		Color = CHROME, Material = MAT.Metal })
	for _, side in ipairs({ -1, 1 }) do -- small back burners with iron grates
		detail({ Name = "SmallBurner", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.08, 1.3, 1.3), CFrame = at(side * 3.1, 3.93, -1.6) * FLAT,
			Color = Color3.fromRGB(30, 30, 34), Material = MAT.Metal })
		for _, angle in ipairs({ 0, 90 }) do
			detail({ Name = "Grate", Size = Vector3.new(1.5, 0.1, 0.12), CFrame = at(side * 3.1, 3.98, -1.6) * CFrame.Angles(0, math.rad(angle), 0),
				Color = IRON, Material = MAT.Metal })
		end
	end
	detail({ Name = "ControlStrip", Size = Vector3.new(7.8, 0.75, 0.08), CFrame = at(0, 3.2, 2.52), Color = Color3.fromRGB(55, 55, 62), Material = MAT.Metal })

	-- Oven door: dark glass with a warm glow inside, a chrome handle, feet and knobs with pointers
	newPart({ Name = "OvenWindow", Size = Vector3.new(5, 1.6, 0.1), CFrame = at(0, 1.5, 2.55),
		Color = Color3.fromRGB(30, 30, 38), Material = MAT.Glass, Reflectance = 0.2, Parent = model })
	detail({ Name = "OvenDoorFrame", Size = Vector3.new(5.6, 2.3, 0.06), CFrame = at(0, 1.55, 2.52), Color = Color3.fromRGB(200, 202, 210), Material = MAT.Metal })
	detail({ Name = "OvenRack", Size = Vector3.new(4.4, 0.06, 0.04), CFrame = at(0, 1.25, 2.6), Color = Color3.fromRGB(110, 110, 118), Material = MAT.Metal })
	local ovenGlow = detail({ Name = "OvenGlow", Size = Vector3.new(4.6, 0.25, 0.04), CFrame = at(0, 0.85, 2.6), Color = Color3.fromRGB(255, 150, 60), Material = MAT.Glass, Transparency = 0.3 })
	local ovenLight = Instance.new("PointLight")
	ovenLight.Color = Color3.fromRGB(255, 160, 80)
	ovenLight.Range = 5
	ovenLight.Brightness = 0.6
	ovenLight.Parent = ovenGlow
	newPart({ Name = "OvenHandle", Size = Vector3.new(5, 0.2, 0.25), CFrame = at(0, 2.65, 2.62),
		Color = Color3.fromRGB(180, 180, 190), Material = MAT.Metal, Parent = model })
	for _, x in ipairs({ -2.4, 2.4 }) do
		detail({ Name = "HandleMount", Size = Vector3.new(0.2, 0.2, 0.2), CFrame = at(x, 2.65, 2.55), Color = Color3.fromRGB(180, 180, 190), Material = MAT.Metal })
	end
	-- a tea towel hanging over the handle
	detail({ Name = "TeaTowel", Size = Vector3.new(1, 1.4, 0.05), CFrame = at(1.4, 2.05, 2.78), Color = Color3.fromRGB(245, 245, 240), Material = MAT.Fabric })
	for _, y in ipairs({ 1.65, 2.35 }) do
		detail({ Name = "TowelStripe", Size = Vector3.new(1.02, 0.12, 0.06), CFrame = at(1.4, y, 2.78), Color = theme.Accent, Material = MAT.Fabric })
	end
	for _, x in ipairs({ -3.6, 3.6 }) do
		detail({ Name = "StoveFoot", Size = Vector3.new(0.5, 0.2, 0.5), CFrame = at(x, 0.2, 2.2), Color = IRON, Material = MAT.Metal })
	end
	for _, x in ipairs({ -3, -1.8, 1.8, 3 }) do
		newPart({ Name = "Knob", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.25, 0.45, 0.45),
			CFrame = at(x, 3.2, 2.6) * FACE_OUT, Color = IRON, Material = MAT.Metal, Parent = model })
		detail({ Name = "KnobRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.06, 0.6, 0.6), CFrame = at(x, 3.2, 2.56) * FACE_OUT, Color = CHROME, Material = MAT.Metal })
		detail({ Name = "KnobPointer", Size = Vector3.new(0.05, 0.17, 0.04), CFrame = at(x, 3.28, 2.74) * CFrame.Angles(0, 0, (x > 0) and -0.6 or 0.4), Color = Color3.fromRGB(255, 255, 255) })
	end
	-- a little temperature light between the knobs
	detail({ Name = "PilotLight", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.2, CFrame = at(0, 3.2, 2.56), Color = Color3.fromRGB(255, 80, 60), Material = Enum.Material.Neon })

	-- "Start Cooking" prompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Start Cooking"
	prompt.ObjectText = theme.Name
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = stove

	model.Parent = stationsFolder
	return {
		Index = index,
		Origin = P,
		CFrame = stationCFrame,
		Model = model,
		Prompt = prompt,
		StandPosition = (stationCFrame * CFrame.new(0, 3, 5)).Position,
		Owner = nil,
		Pan = nil,
		StackModel = nil,
	}
end

WorldBuilder.Build() -- the island, water, paths, plazas, plots and nature

local stations = {}
for index = 1, GameConfig.StationCount do
	stations[index] = buildStation(index)
end

-- Pan: rebuilt from the cook's equipped pan + size whenever they start cooking or change gear
local function rebuildPan(station, loadout)
	if station.Pan then
		station.Pan:Destroy()
	end
	local pan = PancakeVisuals.BuildPan(loadout.Pan, loadout.Size)
	pan:PivotTo(station.CFrame * CFrame.new(0, 4.125, 0))
	pan.Parent = station.Model
	station.Pan = pan
	return pan
end

for _, station in ipairs(stations) do
	rebuildPan(station, GameConfig.GetLoadout(nil))
end


--------------------------------------------------------------------
-- SHOP STAND (a little striped kiosk next to the path from spawn)
--------------------------------------------------------------------
local shopStand = Instance.new("Model")
shopStand.Name = "ShopStand"
shopStand.ModelStreamingMode = Enum.ModelStreamingMode.Persistent

local STAND_SPOT = GameConfig.Island.Spawn + Vector3.new(-24, 0.18, 4) -- in the spawn plaza
local STAND_FACES = GameConfig.Island.Spawn + Vector3.new(0, 0.18, 4) -- turn the front toward the spawn point
local STAND = CFrame.lookAt(STAND_SPOT, STAND_SPOT - (STAND_FACES - STAND_SPOT)) -- local +Z = front
local SHOP_RED = Color3.fromRGB(220, 50, 60)
local SHOP_CREAM = Color3.fromRGB(255, 248, 235)

local function standPart(props)
	props.CFrame = STAND * props.CFrame
	props.Parent = shopStand
	return newPart(props)
end

standPart({ Name = "Mat", Size = Vector3.new(10, 0.1, 7), CFrame = CFrame.new(0, 0.05, 1.5), Color = Color3.fromRGB(190, 60, 60), Material = MAT.Fabric })
local counter = standPart({ Name = "Counter", Size = Vector3.new(7, 3.4, 2.4), CFrame = CFrame.new(0, 1.9, 0), Color = SHOP_CREAM, Material = MAT.Planks })
for _, y in ipairs({ 1.1, 2.5 }) do
	standPart({ Name = "Stripe", Size = Vector3.new(7.04, 0.4, 2.44), CFrame = CFrame.new(0, y, 0), Color = SHOP_RED, Material = MAT.Wood, CanCollide = false })
end
standPart({ Name = "CounterTop", Size = Vector3.new(7.4, 0.3, 2.8), CFrame = CFrame.new(0, 3.75, 0), Color = Color3.fromRGB(170, 120, 75), Material = MAT.Wood })
for _, x in ipairs({ -3.45, 3.45 }) do
	standPart({ Name = "Post", Size = Vector3.new(0.35, 8.6, 0.35), CFrame = CFrame.new(x, 4.3, -1.1), Color = SHOP_CREAM, Material = MAT.Wood })
end
standPart({ Name = "BackPanel", Size = Vector3.new(7, 4.4, 0.2), CFrame = CFrame.new(0, 6.1, -1.2), Color = Color3.fromRGB(255, 205, 130), Material = MAT.Planks })
for _, y in ipairs({ 5.2, 7 }) do
	standPart({ Name = "Shelf", Size = Vector3.new(6.4, 0.18, 0.7), CFrame = CFrame.new(0, y, -0.85), Color = Color3.fromRGB(150, 100, 60), Material = Enum.Material.Wood })
end

-- Striped awning with a scalloped front edge
for i = -3, 3 do
	local color = (i % 2 == 0) and SHOP_RED or SHOP_CREAM
	standPart({ Name = "Awning", Size = Vector3.new(1.02, 0.15, 3.4), CFrame = CFrame.new(i, 8.7, 0.4) * CFrame.Angles(math.rad(18), 0, 0), Color = color, Material = Enum.Material.Fabric })
	standPart({ Name = "Valance", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, 1, 1), CFrame = CFrame.new(i, 8.1, 2.02) * CFrame.Angles(0, math.rad(90), 0),
		Color = color, Material = Enum.Material.Fabric })
end

-- Chrome trim, a service bell and a little price board on the counter
standPart({ Name = "CounterEdge", Size = Vector3.new(7.5, 0.1, 0.08), CFrame = CFrame.new(0, 3.62, 1.43), Color = Color3.fromRGB(215, 218, 225),
	Material = MAT.Metal, CanCollide = false, CastShadow = false })
standPart({ Name = "Kickplate", Size = Vector3.new(7.06, 0.35, 2.46), CFrame = CFrame.new(0, 0.37, 0), Color = Color3.fromRGB(150, 100, 60),
	Material = MAT.Wood, CanCollide = false })
standPart({ Name = "BellBase", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, 0.6, 0.6), CFrame = CFrame.new(2.9, 3.95, 0.8) * STAND_UP,
	Color = Color3.fromRGB(60, 60, 65), Material = MAT.Metal, CanCollide = false })
standPart({ Name = "Bell", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.45, CFrame = CFrame.new(2.9, 4.05, 0.8), Color = Color3.fromRGB(240, 195, 70),
	Material = MAT.Metal, Reflectance = 0.2, CanCollide = false })
local priceBoard = standPart({ Name = "PriceBoard", Size = Vector3.new(1.4, 1, 0.1), CFrame = CFrame.new(-2.9, 4.4, 0.9) * CFrame.Angles(math.rad(-15), 0, 0),
	Color = Color3.fromRGB(40, 45, 45), Material = MAT.Slate, CanCollide = false })
surfaceText(priceBoard, Enum.NormalId.Back, "SALE!", false)
for _, x in ipairs({ -3.2, -2.6 }) do
	standPart({ Name = "PriceBoardLeg", Size = Vector3.new(0.08, 0.7, 0.08), CFrame = CFrame.new(x, 4.05, 1.05) * CFrame.Angles(math.rad(-15), 0, 0),
		Color = Color3.fromRGB(150, 100, 60), Material = MAT.Wood, CanCollide = false })
end

-- Sign on top, in a wooden frame with marquee bulbs
local shopSign = standPart({ Name = "Sign", Size = Vector3.new(5.4, 1.4, 0.25), CFrame = CFrame.new(0, 9.9, -0.6), Color = Color3.fromRGB(255, 185, 65), Material = MAT.Wood })
standPart({ Name = "SignFrame", Size = Vector3.new(5.9, 1.9, 0.15), CFrame = CFrame.new(0, 9.9, -0.75), Color = Color3.fromRGB(120, 75, 40), Material = MAT.Wood,
	CanCollide = false, CastShadow = false })
for i = 0, 6 do
	standPart({ Name = "SignBulb", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.22, CFrame = CFrame.new(-2.55 + i * 0.85, 10.72, -0.5),
		Color = Color3.fromRGB(255, 235, 180), Material = MAT.Glass, CanCollide = false, CastShadow = false })
end
local shopSignGui = Instance.new("SurfaceGui")
shopSignGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
shopSignGui.PixelsPerStud = 40
shopSignGui.Face = Enum.NormalId.Back -- the side facing the front (+Z)
shopSignGui.Parent = shopSign
local shopSignText = Instance.new("TextLabel")
shopSignText.Size = UDim2.fromScale(1, 1)
shopSignText.BackgroundTransparency = 1
shopSignText.Font = Enum.Font.FredokaOne
shopSignText.TextScaled = true
shopSignText.TextColor3 = Color3.new(1, 1, 1)
shopSignText.TextStrokeTransparency = 0
shopSignText.Text = "🛒 PANCAKE SHOP"
shopSignText.Parent = shopSignGui
standPart({ Name = "SignGlow", Size = Vector3.new(5.6, 0.12, 0.35), CFrame = CFrame.new(0, 9.12, -0.6), Color = Color3.fromRGB(255, 230, 120), Material = Enum.Material.Neon })

-- Warm light under the awning
local awningLight = Instance.new("PointLight")
awningLight.Color = Color3.fromRGB(255, 220, 170)
awningLight.Range = 14
awningLight.Brightness = 1.3
awningLight.Parent = shopSign

-- Mini versions of shop items on display
local function displayModel(model, scale, localPosition, spin)
	model:ScaleTo(scale)
	model:PivotTo(STAND * CFrame.new(localPosition) * CFrame.Angles(0, spin or 0, 0))
	model.Parent = shopStand
end
displayModel(PancakeVisuals.BuildPan(PanConfig.ById.Golden, SizeConfig.Items[1]), 0.32, Vector3.new(-2.2, 4.0, 0.3), math.rad(200))
displayModel(PancakeVisuals.BuildPan(PanConfig.ById.Galaxy, SizeConfig.Items[1]), 0.32, Vector3.new(2.4, 4.0, 0.3), math.rad(-20))
for i = 1, 4 do
	local pancake = PancakeVisuals.BuildPancake(PancakeConfig.Items[((i - 1) % #PancakeConfig.Items) + 1], 1.3, 0.66)
	displayModel(pancake, 1, Vector3.new(0.1, 3.9 + 0.18 + (i - 1) * 0.36, 0.3), i * 0.7)
end
local displayToppings = PancakeVisuals.BuildToppings({ ToppingConfig.ById.Syrup, ToppingConfig.ById.Cream }, 1.3, 9)
displayModel(displayToppings, 1, Vector3.new(0.1, 3.9 + 0.18 + 3 * 0.36 + PancakeVisuals.THICKNESS / 2, 0.3))
local shelfPans = { "Rusty", "Nonstick", "CastIron", "Copper", "Diamond", "Lava" }
for i, id in ipairs(shelfPans) do
	local row = (i <= 3) and 5.29 or 7.09
	local column = ((i - 1) % 3) - 1
	displayModel(PancakeVisuals.BuildPan(PanConfig.ById[id], SizeConfig.Items[1]), 0.26, Vector3.new(column * 2.1 - 0.4, row + 0.1, -0.85), math.rad(180))
end

local shopPrompt = Instance.new("ProximityPrompt")
shopPrompt.ActionText = "Open Shop"
shopPrompt.ObjectText = "Pancake Shop"
shopPrompt.MaxActivationDistance = 10
shopPrompt.RequiresLineOfSight = false
shopPrompt.Parent = counter
shopPrompt.Triggered:Connect(function(player)
	OpenShopEvent:FireClient(player)
end)

-- If the Creator Store stall is installed, it replaces the part-built kiosk (the sign and prompt stay)
local stallModel = PancakeVisuals.GetAsset("ShopStall")
if stallModel then
	local keep = { Counter = true, Sign = true, SignGlow = true, Mat = true }
	for _, child in ipairs(shopStand:GetChildren()) do
		if not keep[child.Name] then
			child:Destroy()
		end
	end
	counter.Transparency = 1
	counter.CanCollide = false
	for _, stripe in ipairs(counter:GetChildren()) do
		if stripe:IsA("BasePart") then
			stripe:Destroy()
		end
	end
	PancakeVisuals.FitAsset(stallModel, 9, "XZ")
	stallModel:PivotTo(STAND * CFrame.Angles(0, math.rad(GameConfig.ShopStallTurn or 180), 0))
	stallModel.Name = "ShopStallModel"
	stallModel.Parent = shopStand
	local _, stallSize = stallModel:GetBoundingBox()
	shopSign.CFrame = STAND * CFrame.new(0, stallSize.Y + 1, 0)
	shopStand.SignGlow.CFrame = STAND * CFrame.new(0, stallSize.Y + 0.22, 0)
end

shopStand.Parent = workspace


--------------------------------------------------------------------
-- LEADERSTATS + SAVED DATA
--------------------------------------------------------------------
local combos = {} -- [player] = current perfect-flip streak

-- What the client needs to know for the shop
local function snapshot(data)
	return {
		Butter = data.Butter,
		TotalButter = data.Stats.TotalButter,
		Owned = data.Owned,
		Equipped = data.Equipped,
		Slots = GameConfig.GetToppingSlots(data.Stats.TotalButter),
	}
end

local function sendData(player)
	local data = DataManager.Get(player)
	if data then
		DataEvent:FireClient(player, snapshot(data))
	end
end

local function showButter(player, data)
	local stats = player:FindFirstChild("leaderstats")
	if stats then
		stats.Butter.Value = data.Butter
	end
end

local claimRestaurant -- defined further down (gives the player their own restaurant)

local function setupPlayer(player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"

	local butter = Instance.new("IntValue")
	butter.Name = "Butter"
	butter.Parent = leaderstats

	local bestCombo = Instance.new("IntValue")
	bestCombo.Name = "Best Combo"
	bestCombo.Parent = leaderstats

	leaderstats.Parent = player
	combos[player] = 0

	local data = DataManager.Load(player)
	if not data then return end -- they left while loading
	if RunService:IsStudio() and GameConfig.StudioTestButter > 0 then
		data.Butter = math.max(data.Butter, GameConfig.StudioTestButter)
		warn("[Test] Studio playtest: you start with " .. GameConfig.FormatNumber(data.Butter) .. " Butter (see GameConfig.StudioTestButter).")
	end
	butter.Value = data.Butter
	bestCombo.Value = data.Stats.BestCombo
	sendData(player)
	claimRestaurant(player)
end

GetDataRemote.OnServerInvoke = function(player)
	local data = DataManager.Get(player)
	return data and snapshot(data) or nil
end

local function setCombo(player, value)
	combos[player] = value
	local data = DataManager.Get(player)
	if data and value > data.Stats.BestCombo then
		data.Stats.BestCombo = value
		local stats = player:FindFirstChild("leaderstats")
		if stats then
			stats["Best Combo"].Value = value
		end
	end
end

--------------------------------------------------------------------
-- STACKS (built on each station's plate so everyone can see them)
--------------------------------------------------------------------
local THICK = PancakeVisuals.THICKNESS
local STACK_STEP = THICK + 0.02
local random = Random.new()

local function updateStack(station, stack)
	if station.StackModel then
		station.StackModel:Destroy()
		station.StackModel = nil
	end
	station.Model:SetAttribute("StackHeight", #stack)
	if #stack == 0 then return end

	local model = Instance.new("Model")
	model.Name = "Stack"
	local base = station.CFrame * CFrame.new(GameConfig.StackPlateOffset + Vector3.new(0, 0.1, 0))
	local size = GameConfig.StackPancakeSize
	for i, entry in ipairs(stack) do
		local pancakeType = PancakeConfig.ById[entry.Type] or PancakeConfig.Items[1]
		local pancake = PancakeVisuals.BuildPancake(pancakeType, size, 0.66)
		pancake:PivotTo(base * CFrame.new(0, THICK / 2 + (i - 1) * STACK_STEP, 0) * CFrame.Angles(0, i * 1.3, 0))
		pancake.Parent = model
	end
	-- the top pancake shows its toppings
	local top = stack[#stack]
	if #top.Toppings > 0 then
		local items = {}
		for _, id in ipairs(top.Toppings) do
			table.insert(items, ToppingConfig.ById[id])
		end
		local toppings = PancakeVisuals.BuildToppings(items, size, 17)
		toppings:PivotTo(base * CFrame.new(0, THICK + (#stack - 1) * STACK_STEP + 0.01, 0))
		toppings.Parent = model
	end
	model.WorldPivot = base
	model:SetAttribute("Base", base) -- the cook's client uses this to make the stack wobble
	model.Parent = station.Model
	station.StackModel = model
end

-- The stack falls over for real: every pancake becomes a physics object and tumbles off the counter
local function toppleStack(station)
	local model = station.StackModel
	station.StackModel = nil
	station.Model:SetAttribute("StackHeight", 0)
	if not model then return end
	model.Name = "ToppledStack"
	model:SetAttribute("Base", nil)
	for _, child in ipairs(model:GetChildren()) do
		local body = child:FindFirstChild("Body")
		for _, part in ipairs(child:GetDescendants()) do
			if part:IsA("BasePart") then
				if body and part ~= body then
					local weld = Instance.new("WeldConstraint")
					weld.Part0 = body
					weld.Part1 = part
					weld.Parent = body
				end
				part.CanCollide = (part == body) or not body
			end
		end
		for _, part in ipairs(child:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Anchored = false
			end
		end
		if body then
			body.AssemblyLinearVelocity = Vector3.new(random:NextNumber(-10, 10), random:NextNumber(4, 12), random:NextNumber(3, 12))
			body.AssemblyAngularVelocity = Vector3.new(random:NextNumber(-8, 8), random:NextNumber(-8, 8), random:NextNumber(-8, 8))
		end
	end
	task.delay(4, function()
		model:Destroy()
	end)
end

--------------------------------------------------------------------
-- STATION OWNERSHIP + COOKING STATE
--------------------------------------------------------------------
-- [player] = { Station, Phase, CookStart, Equipped, Loadout, SideA, TrickIndex, Qualities, Stack, LastAction }
local states = {}

-- Each player owns one restaurant while they're in the server. It's named after them.
local function setRestaurantName(station, player)
	local text = player and ("🥞 " .. player.DisplayName .. "'s Pancakes") or "🥞 Open Restaurant"
	for _, label in ipairs(station.Model:GetDescendants()) do
		if label:IsA("TextLabel") and label.Name == "RestaurantName" then
			label.Text = text
		end
	end
	station.Prompt.ObjectText = player and (player.DisplayName .. "'s Restaurant") or "Open Restaurant"
	station.Model:SetAttribute("OwnerUserId", player and player.UserId or nil)
	station.Model:SetAttribute("OwnerName", player and player.DisplayName or nil)
end

for _, station in ipairs(stations) do
	setRestaurantName(station, nil)
end

local function stationOwnedBy(player)
	for _, station in ipairs(stations) do
		if station.Owner == player then
			return station
		end
	end
	return nil
end

claimRestaurant = function(player)
	if stationOwnedBy(player) then return end
	for _, station in ipairs(stations) do
		if station.Owner == nil then
			station.Owner = player
			setRestaurantName(station, player)
			StationEvent:FireClient(player, "Message", "🏠 Your restaurant is ready! Follow the arrow to it.")
			return
		end
	end
	StationEvent:FireClient(player, "Message", "😢 All restaurants are taken right now. Try another server!")
end

-- Stop cooking (the player still owns their restaurant)
local function releaseStation(player)
	local state = states[player]
	states[player] = nil
	if not state then return end
	local station = state.Station
	station.Prompt.Enabled = true
	OrderManager.Detach(station)
	updateStack(station, {})
end

local function unclaimRestaurant(player)
	local station = stationOwnedBy(player)
	if station then
		station.Owner = nil
		setRestaurantName(station, nil)
	end
end

for _, station in ipairs(stations) do
	station.Prompt.Triggered:Connect(function(player)
		if states[player] then return end
		if station.Owner ~= player then
			local mine = stationOwnedBy(player)
			local owner = station.Owner and (station.Owner.DisplayName .. "'s") or "someone else's"
			StationEvent:FireClient(player, "Message", mine and ("This is " .. owner .. " restaurant! Yours has your name on it 🏠")
				or ("This is " .. owner .. " restaurant!"))
			return
		end
		local data = DataManager.Get(player)
		if not data then return end -- still loading
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then return end

		station.Prompt.Enabled = false
		states[player] = { Station = station, Phase = "Empty", LastAction = 0, Stack = {} }
		local pan = rebuildPan(station, GameConfig.GetLoadout(data.Equipped))
		character:PivotTo(CFrame.lookAt(station.StandPosition, station.StandPosition + station.CFrame.LookVector))
		OrderManager.Attach(station, function()
			return DataManager.Get(player)
		end)
		StationEvent:FireClient(player, "Enter", pan, station.Index)
	end)
end

LeaveRemote.OnServerEvent:Connect(releaseStation)

-- Returns the player's state if they're allowed to act right now (also rate-limits)
local function getState(player)
	local state = states[player]
	if not state or state.Station.Owner ~= player then return nil end
	local now = os.clock()
	if now - state.LastAction < 0.2 then return nil end
	state.LastAction = now
	return state
end

-- How long the current side has cooked, allowing a little for network lag
local function cookedSeconds(player, state)
	local ping = 0
	pcall(function()
		ping = player:GetNetworkPing()
	end)
	return os.clock() - state.CookStart - math.clamp(ping, 0, 0.25)
end

local function cookedLongEnough(state)
	return os.clock() - state.CookStart >= GameConfig.MinCookTime * 0.5
end

local function cookZone(player, state)
	local loadout = state.Loadout
	return GameConfig.GetCookZone(cookedSeconds(player, state) / loadout.CookTime, loadout.Zones)
end

--------------------------------------------------------------------
-- POUR
--------------------------------------------------------------------
PourRemote.OnServerInvoke = function(player)
	local state = getState(player)
	if not state or state.Phase ~= "Empty" then return nil end
	local data = DataManager.Get(player)
	if not data then return nil end

	-- Lock in the gear for this pancake (shop changes apply to the next one)
	local equipped = data.Equipped
	state.Equipped = {
		Pan = equipped.Pan,
		Size = equipped.Size,
		Pancake = equipped.Pancake,
		Toppings = table.clone(equipped.Toppings),
	}
	state.Loadout = GameConfig.GetLoadout(state.Equipped)
	state.Phase = "SideA"
	state.CookStart = os.clock()
	return state.Equipped
end

--------------------------------------------------------------------
-- FLIP (every pancake in the pan is judged separately)
--------------------------------------------------------------------
FlipRemote.OnServerInvoke = function(player, power)
	local state = getState(player)
	if not state or state.Phase ~= "SideA" then return nil end
	if typeof(power) ~= "number" or power ~= power then return nil end -- reject NaN / junk
	if not cookedLongEnough(state) then return nil end
	power = math.clamp(power, 0, 1)

	local loadout = state.Loadout
	state.SideA = cookZone(player, state)
	local trickIndex = GameConfig.GetTrickIndex(power)

	local qualities = {}
	local landed, perfects, messy, anyDropped = 0, 0, false, false
	for i = 1, loadout.Size.Count do
		local quality = "Dropped"
		if trickIndex then
			-- extra pancakes wobble a little, so a big pan is riskier
			local wobble = (i > 1) and (random:NextNumber() - 0.5) * 0.03 or 0
			quality = GameConfig.GetFlipQuality(math.clamp(power + wobble, 0, 1), trickIndex, loadout.FlipTolerance)
		end
		qualities[i] = quality
		if quality == "Dropped" or quality == "Sloppy" then
			messy = true
		end
		if quality == "Dropped" then
			anyDropped = true
		else
			landed += 1
		end
		if quality == "Perfect" then
			perfects += 1
		end
	end
	trickIndex = trickIndex or 1
	local trick = GameConfig.FlipTricks[trickIndex]

	if messy then
		setCombo(player, 0)
	elseif perfects == #qualities then
		setCombo(player, (combos[player] or 0) + 1)
	end

	local data = DataManager.Get(player)
	if data then
		data.Stats.PerfectFlips += perfects
		data.Stats.Drops += #qualities - landed
		if trick.Name == "Tornado" and landed > 0 then
			data.Stats.TornadoFlips += 1
		end
	end

	-- A messy flip can knock over a tall stack!
	local toppled, lost = false, 0
	if messy and #state.Stack >= GameConfig.StackSafeHeight then
		if random:NextNumber() < GameConfig.GetToppleChance(#state.Stack, anyDropped) then
			lost = #state.Stack
			state.Stack = {}
			toppleStack(state.Station)
			toppled = true
		end
	end

	if landed == 0 then
		state.Phase = "Empty"
	else
		state.Phase = "SideB"
		state.TrickIndex = trickIndex
		state.Qualities = qualities
		state.CookStart = os.clock() + trick.FlightTime -- side B starts cooking when it lands
	end
	return {
		TrickIndex = trickIndex,
		Qualities = qualities,
		SideA = state.SideA,
		Combo = combos[player] or 0,
		Toppled = toppled,
		Lost = lost,
	}
end

--------------------------------------------------------------------
-- SERVE or STACK
--------------------------------------------------------------------
-- Turns the pancakes in the pan into stack entries: { Value, Type, Toppings, Perfect }
local function takeFinishedPancakes(player, state)
	local loadout = state.Loadout
	local sideA, sideB = state.SideA, cookZone(player, state)
	local trick = GameConfig.FlipTricks[state.TrickIndex]
	local comboMultiplier = GameConfig.GetComboMultiplier(combos[player] or 0)
	local cookMultiplier = (GameConfig.CookMultipliers[sideA] + GameConfig.CookMultipliers[sideB]) / 2
	local base = loadout.Pancake.BaseValue
		* cookMultiplier
		* trick.Multiplier
		* loadout.Pan.Multiplier
		* loadout.ToppingMultiplier
		* loadout.ValueMultiplier
		* comboMultiplier
	local perfect = sideA == "Perfect" and sideB == "Perfect"

	local entries = {}
	for _, quality in ipairs(state.Qualities) do
		if quality ~= "Dropped" then
			table.insert(entries, {
				Value = base * GameConfig.FlipQualityMultipliers[quality],
				Type = loadout.Pancake.Id,
				Toppings = table.clone(state.Equipped.Toppings),
				Perfect = perfect,
			})
		end
	end

	-- Serving a raw or burnt side breaks the combo (after these pancakes are counted)
	local comboBroken = false
	local badSide = sideA == "Raw" or sideA == "Burnt" or sideB == "Raw" or sideB == "Burnt"
	if badSide and (combos[player] or 0) > 0 then
		setCombo(player, 0)
		comboBroken = true
	end

	return entries, {
		SideA = sideA,
		SideB = sideB,
		ComboMultiplier = comboMultiplier,
		ComboBroken = comboBroken,
	}
end

-- action = "Serve" (sell the pan + the whole stack) or "Stack" (put the pan's pancakes on the stack)
ServeRemote.OnServerInvoke = function(player, action)
	action = (action == "Stack") and "Stack" or "Serve"
	local state = getState(player)
	if not state then return nil end
	local data = DataManager.Get(player)
	if not data then return nil end
	local station = state.Station

	local entries, info = {}, {}
	if state.Phase == "SideB" then
		if not cookedLongEnough(state) then return nil end
		entries, info = takeFinishedPancakes(player, state)
	elseif not (state.Phase == "Empty" and action == "Serve" and #state.Stack > 0) then
		return nil -- nothing to serve
	end

	if action == "Stack" then
		local room = GameConfig.MaxStack - #state.Stack
		if room <= 0 then
			return { Action = "Stack", Full = true, StackHeight = #state.Stack }
		end
		for i = 1, math.min(#entries, room) do
			table.insert(state.Stack, entries[i])
		end
		data.Stats.TallestStack = math.max(data.Stats.TallestStack, #state.Stack)
		state.Phase = "Empty"
		updateStack(station, state.Stack)
		info.Action = "Stack"
		info.Stacked = math.min(#entries, room)
		info.StackHeight = #state.Stack
		info.StackMultiplier = GameConfig.GetStackMultiplier(#state.Stack)
		info.Combo = combos[player] or 0
		return info
	end

	-- SERVE: everything in the pan plus the whole stack
	local all = {}
	for _, entry in ipairs(state.Stack) do
		table.insert(all, entry)
	end
	for _, entry in ipairs(entries) do
		table.insert(all, entry)
	end
	if #all == 0 then
		state.Phase = "Empty"
		return nil
	end

	local total = 0
	for _, entry in ipairs(all) do
		total += entry.Value
	end
	local stackMultiplier = GameConfig.GetStackMultiplier(#all)
	local rushMultiplier = EventManager.GetButterMultiplier()
	local orderFilled = OrderManager.TryComplete(station, all)
	local orderMultiplier = orderFilled and GameConfig.Orders.RewardMultiplier or 1
	local butter = math.max(1, math.floor(total * stackMultiplier * rushMultiplier * orderMultiplier + 0.5))

	data.Butter += butter
	data.Stats.PancakesServed += #all
	data.Stats.TotalButter += butter
	if orderFilled then
		data.Stats.OrdersFilled += 1
	end
	showButter(player, data)

	local fromStack = #state.Stack
	state.Stack = {}
	updateStack(station, {})
	state.Phase = "Empty"
	sendData(player) -- total Butter may have unlocked a topping slot

	info.Action = "Serve"
	info.Butter = butter
	info.Served = #all
	info.FromStack = fromStack
	info.StackMultiplier = stackMultiplier
	info.RushMultiplier = rushMultiplier
	info.OrderFilled = orderFilled
	info.ComboMultiplier = info.ComboMultiplier or GameConfig.GetComboMultiplier(combos[player] or 0)
	info.Combo = combos[player] or 0
	return info
end

--------------------------------------------------------------------
-- SHOP (buy and equip; the server checks everything)
--------------------------------------------------------------------
local SHOP_CATEGORIES = {
	Pans = PanConfig,
	Pancakes = PancakeConfig,
	Toppings = ToppingConfig,
}
local EQUIP_SLOT = { Pans = "Pan", Pancakes = "Pancake" }
local lastShopAction = {}

local function equipItem(player, data, category, id)
	if category == "Toppings" then
		local list = data.Equipped.Toppings
		local index = table.find(list, id)
		if index then
			table.remove(list, index)
			return true, "Topping removed."
		end
		if #list >= GameConfig.GetToppingSlots(data.Stats.TotalButter) then
			return false, "All topping slots are full! Turn one off first."
		end
		table.insert(list, id)
		return true, "Topping added!"
	end

	data.Equipped[EQUIP_SLOT[category]] = id
	local state = states[player]
	if category == "Pans" and state then
		local pan = rebuildPan(state.Station, GameConfig.GetLoadout(data.Equipped))
		StationEvent:FireClient(player, "PanChanged", pan)
	end
	return true, "Equipped!"
end

ShopRemote.OnServerInvoke = function(player, action, category, id)
	if typeof(action) ~= "string" or typeof(category) ~= "string" or typeof(id) ~= "string" then
		return false, "Invalid request."
	end
	local now = os.clock()
	if lastShopAction[player] and now - lastShopAction[player] < 0.15 then
		return false, "Slow down!"
	end
	lastShopAction[player] = now

	local data = DataManager.Get(player)
	if not data then return false, "Still loading your data..." end
	local config = SHOP_CATEGORIES[category]
	local item = config and config.ById[id]
	if not item then return false, "That item doesn't exist." end

	local state = states[player]
	local cooking = state ~= nil and state.Phase ~= "Empty"
	local owned = data.Owned[category]
	local ok, message

	if action == "Buy" then
		if owned[id] then return false, "You already own this!" end
		if data.Butter < item.Price then return false, "Not enough Butter!" end
		data.Butter -= item.Price
		owned[id] = true
		showButter(player, data)
		if cooking then
			ok, message = true, "Bought! Equip it after this pancake."
		else
			local equipped, equipMessage = equipItem(player, data, category, id)
			ok, message = true, equipped and ("Bought " .. item.Name .. "!") or ("Bought! " .. equipMessage)
		end
	elseif action == "Equip" then
		if not owned[id] then return false, "You don't own this yet." end
		if cooking then return false, "Finish your pancake first!" end
		ok, message = equipItem(player, data, category, id)
	else
		return false, "Invalid request."
	end

	sendData(player)
	return ok, message
end

--------------------------------------------------------------------
-- PLAYERS
--------------------------------------------------------------------
local function onPlayerAdded(player)
	player.CharacterRemoving:Connect(function()
		if states[player] then
			releaseStation(player)
			StationEvent:FireClient(player, "Leave")
		end
	end)
	setupPlayer(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	releaseStation(player)
	unclaimRestaurant(player)
	combos[player] = nil
	lastShopAction[player] = nil
	DataManager.Release(player)
end)

EventManager.Start()