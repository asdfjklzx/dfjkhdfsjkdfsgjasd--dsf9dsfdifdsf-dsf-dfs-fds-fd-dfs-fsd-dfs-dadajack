-- PancakeVisuals (ModuleScript in ReplicatedStorage)
-- Builds the 3D look of pans, pancakes, mix-ins and toppings from basic parts.
-- Used by the server (the station's pan and shop stand) and the client (pancakes, toppings, shop previews).
-- Swap any of these for custom meshes later: just keep the same names and sizes.

local GameConfig = require(script.Parent:WaitForChild("GameConfig"))
local TEX = GameConfig.Textures

local PancakeVisuals = {}

PancakeVisuals.THICKNESS = 0.35
local THICK = PancakeVisuals.THICKNESS
local FLAT = CFrame.Angles(0, 0, math.rad(90))     -- lays a cylinder flat / stands it upright
local FACING = CFrame.Angles(0, math.rad(90), 0)   -- points a cylinder's round face along Z
local BLACK = Color3.new(0, 0, 0)
local WHITE = Color3.new(1, 1, 1)
local WOOD = Color3.fromRGB(95, 60, 38)
local STEEL = Color3.fromRGB(175, 175, 185)

local function newPart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = Enum.Material.SmoothPlastic
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
PancakeVisuals.NewPart = newPart

--------------------------------------------------------------------
-- CREATOR STORE MODELS (installed into ReplicatedStorage > Assets, see GameConfig.Assets)
--------------------------------------------------------------------
-- Returns a fresh copy of an installed model, or nil if it isn't installed.
-- The copy is anchored, can't be bumped into, has no scripts, and its pivot is its bottom-center.
function PancakeVisuals.GetAsset(name)
	local folder = game:GetService("ReplicatedStorage"):FindFirstChild("Assets")
	local source = folder and folder:FindFirstChild(name)
	if not source then return nil end
	local model = source:Clone()
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
		end
	end
	model.PrimaryPart = nil
	local box, size = model:GetBoundingBox()
	model.WorldPivot = CFrame.new(box.Position - Vector3.new(0, size.Y / 2, 0))
	return model
end

-- Scales a model so its biggest side (or its height with "Y", or its footprint with "XZ") is maxSize
function PancakeVisuals.FitAsset(model, maxSize, axis)
	local _, size = model:GetBoundingBox()
	local measure
	if axis == "Y" then
		measure = size.Y
	elseif axis == "XZ" then
		measure = math.max(size.X, size.Z)
	else
		measure = math.max(size.X, size.Y, size.Z)
	end
	if measure > 0 then
		model:ScaleTo(model:GetScale() * maxSize / measure)
	end
	return model
end

-- Copies, sizes and places an installed model with its bottom-center at bottomCFrame. Returns nil if not installed.
function PancakeVisuals.PlaceAsset(name, bottomCFrame, maxSize, axis, parent)
	local model = PancakeVisuals.GetAsset(name)
	if not model then return nil end
	PancakeVisuals.FitAsset(model, maxSize, axis)
	model:PivotTo(bottomCFrame)
	model.Parent = parent
	return model
end

local function disk(parent, name, thickness, diameter, cframe, color, material)
	return newPart({
		Name = name, Shape = Enum.PartType.Cylinder, Size = Vector3.new(thickness, diameter, diameter),
		CFrame = cframe * FLAT, Color = color, Material = material or Enum.Material.SmoothPlastic, Parent = parent,
	})
end
PancakeVisuals.Disk = disk

local function ball(parent, size, position, color, material)
	return newPart({ Name = "Ball", Shape = Enum.PartType.Ball, Size = Vector3.one * size, CFrame = CFrame.new(position),
		Color = color, Material = material or Enum.Material.SmoothPlastic, Parent = parent })
end

--------------------------------------------------------------------
-- PANS
--------------------------------------------------------------------
local function addPanParticles(panItem, base, direction)
	local kind = panItem.Particles
	if not kind then return end

	local emitter = Instance.new("ParticleEmitter")
	emitter.LightEmission = 1
	emitter.LightInfluence = 0
	emitter.EmissionDirection = direction
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-90, 90)
	if kind == "Sparkle" then
		emitter.Texture = TEX.Sparkle
		emitter.Color = ColorSequence.new(Color3.fromRGB(255, 230, 120))
		emitter.Size = NumberSequence.new(0.5, 0)
		emitter.Rate = 6
		emitter.Lifetime = NumberRange.new(0.6, 1.2)
		emitter.Speed = NumberRange.new(0.5, 1.5)
	elseif kind == "Shine" then
		emitter.Texture = TEX.Sparkle
		emitter.Color = ColorSequence.new(WHITE, Color3.fromRGB(150, 230, 255))
		emitter.Size = NumberSequence.new(0.6, 0)
		emitter.Rate = 8
		emitter.Lifetime = NumberRange.new(0.5, 1)
		emitter.Speed = NumberRange.new(0.3, 1)
	elseif kind == "Fire" then
		emitter.Texture = TEX.Fire
		emitter.Color = ColorSequence.new(Color3.fromRGB(255, 200, 60), Color3.fromRGB(255, 50, 10))
		emitter.Size = NumberSequence.new(0.9, 0)
		emitter.Transparency = NumberSequence.new(0.2, 1)
		emitter.Rate = 14
		emitter.Lifetime = NumberRange.new(0.3, 0.6)
		emitter.Speed = NumberRange.new(2, 4)
	elseif kind == "Stars" then
		emitter.Texture = TEX.Sparkle
		emitter.Color = ColorSequence.new(Color3.fromRGB(210, 170, 255), Color3.fromRGB(120, 200, 255))
		emitter.Size = NumberSequence.new(0.35, 0)
		emitter.Rate = 12
		emitter.Lifetime = NumberRange.new(1.5, 2.5)
		emitter.Speed = NumberRange.new(0.3, 1)
	end
	emitter.Parent = base
end


-- Points spaced around the pan's top edge (for gems, stars, crystals...)
local function rimPoints(sizeItem, count, inset)
	local points = {}
	for i = 1, count do
		local angle = (i - 0.5) / count * math.pi * 2
		if sizeItem.Shape == "Griddle" then
			local hx, hz = sizeItem.PlateSize.X / 2 + 0.125 - inset, sizeItem.PlateSize.Y / 2 + 0.125 - inset
			-- walk around the rectangle
			local c, s = math.cos(angle), math.sin(angle)
			local scale = 1 / math.max(math.abs(c) / hx, math.abs(s) / hz)
			table.insert(points, Vector3.new(c * scale, 0.42, s * scale))
		else
			local radius = sizeItem.PanRadius + 0.05 - inset
			table.insert(points, Vector3.new(math.cos(angle) * radius, 0.42, math.sin(angle) * radius))
		end
	end
	return points
end

-- Random spots on the cooking surface
local function surfacePoints(sizeItem, count, rng)
	local points = {}
	for _ = 1, count do
		if sizeItem.Shape == "Griddle" then
			local plate = sizeItem.PlateSize
			table.insert(points, Vector3.new((rng:NextNumber() - 0.5) * (plate.X - 0.6), 0.13, (rng:NextNumber() - 0.5) * (plate.Y - 0.6)))
		else
			local angle = rng:NextNumber() * math.pi * 2
			local radius = (0.3 + 0.7 * math.sqrt(rng:NextNumber())) * (sizeItem.PanRadius - 0.3)
			table.insert(points, Vector3.new(math.cos(angle) * radius, 0.13, math.sin(angle) * radius))
		end
	end
	return points
end

-- A picture on the pan's cooking surface (like the Galaxy Pan), or nil
local function panImage(panItem)
	if panItem.SurfaceImage and panItem.SurfaceImage ~= "" then
		return panItem.SurfaceImage
	end
	if panItem.StudioPreviewImage and game:GetService("RunService"):IsStudio() then
		return panItem.StudioPreviewImage -- local preview copy, only works in Studio on this PC
	end
	return nil
end
PancakeVisuals.PanImage = panImage

-- Unique decorations for each pan
local PAN_DECOR = {}

PAN_DECOR.Rusty = function(model, sizeItem, rng)
	for _, point in ipairs(surfacePoints(sizeItem, 7, rng)) do -- rust spots
		disk(model, "Rust", 0.02, 0.3 + rng:NextNumber() * 0.5, CFrame.new(point), Color3.fromRGB(165, 85, 40), Enum.Material.CorrodedMetal)
	end
end

PAN_DECOR.Nonstick = function(model)
	-- the little red "ready" spot in the middle of nonstick pans
	disk(model, "HeatSpot", 0.02, 0.9, CFrame.new(0, 0.135, 0), Color3.fromRGB(200, 50, 50))
	disk(model, "HeatSpotRing", 0.018, 1.2, CFrame.new(0, 0.133, 0), Color3.fromRGB(90, 30, 30))
end

PAN_DECOR.Copper = function(model, sizeItem)
	for _, point in ipairs(rimPoints(sizeItem, 10, 0)) do -- polished rivets on the rim
		ball(model, 0.16, point, Color3.fromRGB(255, 200, 140), Enum.Material.Metal)
	end
end

PAN_DECOR.Golden = function(model, sizeItem)
	for i, point in ipairs(rimPoints(sizeItem, 8, 0)) do -- jewels set in the rim
		local gem = ball(model, 0.26, point, (i % 2 == 0) and Color3.fromRGB(230, 30, 60) or Color3.fromRGB(40, 120, 255), Enum.Material.Glass)
		gem.Reflectance = 0.4
	end
end

PAN_DECOR.Diamond = function(model, sizeItem)
	for _, point in ipairs(rimPoints(sizeItem, 12, 0)) do -- crystal spikes around the rim
		newPart({ Name = "Crystal", Size = Vector3.new(0.22, 0.45, 0.22),
			CFrame = CFrame.new(point + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, math.rad(45), math.rad(12)),
			Color = Color3.fromRGB(200, 245, 255), Material = Enum.Material.Glass, Transparency = 0.25, Reflectance = 0.4, Parent = model })
	end
end

PAN_DECOR.Lava = function(model, sizeItem, rng)
	for _, point in ipairs(surfacePoints(sizeItem, 3, rng)) do -- little pools of molten lava
		local pool = disk(model, "LavaPool", 0.015, 0.4 + rng:NextNumber() * 0.4, CFrame.new(point), Color3.fromRGB(255, 120, 30), Enum.Material.Neon)
		pool.Transparency = 0.1
	end
	for _, point in ipairs(surfacePoints(sizeItem, 9, rng)) do -- glowing cracks in the surface
		newPart({ Name = "Crack", Size = Vector3.new(0.07, 0.02, 0.6 + rng:NextNumber() * 1.1),
			CFrame = CFrame.new(point + Vector3.new(0, 0.005, 0)) * CFrame.Angles(0, rng:NextNumber() * math.pi, 0),
			Color = Color3.fromRGB(255, 220, 90), Material = Enum.Material.Neon, Parent = model })
	end
end

PAN_DECOR.Galaxy = function(model, sizeItem, rng, panItem)
	local NEON = Enum.Material.Neon
	local STAR_BLUE = Color3.fromRGB(170, 210, 255)
	local STAR_PINK = Color3.fromRGB(255, 200, 240)

	-- with the galaxy picture on the surface, just add the little stars in the glowing rim
	if panItem and panImage(panItem) then
		for i, point in ipairs(rimPoints(sizeItem, 14, 0)) do
			ball(model, 0.08 + rng:NextNumber() * 0.08, point + Vector3.new(0, 0.04, 0), (i % 3 == 0) and STAR_BLUE or WHITE, NEON)
		end
		return
	end
	local maxRadius = (sizeItem.Shape == "Griddle")
		and math.min(sizeItem.PlateSize.X, sizeItem.PlateSize.Y) / 2 - 0.3
		or sizeItem.PanRadius - 0.3

	-- soft glowing nebula clouds in pink, purple and blue (see-through so they blend)
	local nebulaColors = {
		Color3.fromRGB(255, 70, 190), Color3.fromRGB(130, 70, 255),
		Color3.fromRGB(50, 160, 255), Color3.fromRGB(210, 60, 255),
	}
	for i, point in ipairs(surfacePoints(sizeItem, 8, rng)) do
		local cloud = disk(model, "Nebula", 0.012, 1 + rng:NextNumber() * 1.5,
			CFrame.new(point + Vector3.new(0, i * 0.001, 0)), nebulaColors[(i - 1) % #nebulaColors + 1], NEON)
		cloud.Transparency = 0.7 + rng:NextNumber() * 0.15
	end

	-- a bright core in the middle
	disk(model, "CoreGlow", 0.012, 1.4, CFrame.new(0, 0.138, 0), Color3.fromRGB(200, 150, 255), NEON).Transparency = 0.55
	disk(model, "Core", 0.014, 0.55, CFrame.new(0, 0.141, 0), Color3.fromRGB(255, 240, 255), NEON).Transparency = 0.15

	-- two spiral arms made of stars
	for arm = 0, 1 do
		for i = 1, 20 do
			local t = i / 20
			local angle = arm * math.pi + t * math.pi * 2.3
			local radius = 0.35 + t * (maxRadius - 0.35)
			local wobble = (rng:NextNumber() - 0.5) * 0.25
			disk(model, "ArmStar", 0.015, 0.05 + rng:NextNumber() * 0.08,
				CFrame.new(math.cos(angle) * (radius + wobble), 0.143, math.sin(angle) * (radius + wobble)),
				(i % 4 == 0) and STAR_PINK or WHITE, NEON)
		end
	end

	-- a field of tiny stars in different sizes
	for _, point in ipairs(surfacePoints(sizeItem, 45, rng)) do
		local roll = rng:NextNumber()
		disk(model, "Star", 0.015, 0.03 + roll ^ 3 * 0.1, CFrame.new(point + Vector3.new(0, 0.014, 0)),
			(roll < 0.2) and STAR_BLUE or WHITE, NEON)
	end

	-- a few big four-point twinkle stars
	for _, point in ipairs(surfacePoints(sizeItem, 4, rng)) do
		local spin = rng:NextNumber() * math.pi
		for k = 0, 1 do
			newPart({ Name = "Twinkle", Size = Vector3.new(0.55, 0.015, 0.05),
				CFrame = CFrame.new(point + Vector3.new(0, 0.02, 0)) * CFrame.Angles(0, spin + k * math.pi / 2, 0),
				Color = WHITE, Material = NEON, Parent = model })
		end
	end

	-- little stars set into the glowing rim
	for i, point in ipairs(rimPoints(sizeItem, 14, 0)) do
		ball(model, 0.08 + rng:NextNumber() * 0.08, point + Vector3.new(0, 0.04, 0), (i % 3 == 0) and STAR_BLUE or WHITE, NEON)
	end
end

-- A long frying-pan handle: metal shaft, rivets, a grip and a hanging hole
local function addLongHandle(model, startX, panItem)
	local metal = panItem.Color:Lerp(STEEL, 0.5)
	newPart({ Name = "HandleShaft", Size = Vector3.new(1.1, 0.22, 0.32), CFrame = CFrame.new(startX + 0.55, 0.3, 0),
		Color = metal, Material = Enum.Material.Metal, Parent = model })
	for _, z in ipairs({ -0.09, 0.09 }) do
		ball(model, 0.1, Vector3.new(startX + 0.2, 0.42, z), STEEL, Enum.Material.Metal)
	end
	local gripColor = panItem.HandleColor or WOOD
	newPart({ Name = "Handle", Size = Vector3.new(2.6, 0.36, 0.56), CFrame = CFrame.new(startX + 2.35, 0.33, 0),
		Color = gripColor, Material = Enum.Material.Wood, Parent = model })
	newPart({ Name = "GripBand", Size = Vector3.new(0.14, 0.4, 0.6), CFrame = CFrame.new(startX + 1.15, 0.33, 0),
		Color = metal, Material = Enum.Material.Metal, Parent = model })
	newPart({ Name = "HandleEnd", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.36, 0.56, 0.56),
		CFrame = CFrame.new(startX + 3.65, 0.33, 0) * FLAT, Color = gripColor, Material = Enum.Material.Wood, Parent = model })
	disk(model, "HangingHole", 0.38, 0.18, CFrame.new(startX + 3.5, 0.33, 0), Color3.fromRGB(25, 18, 12))
	-- a bracket joining the handle to the pan wall, with rivets on both sides
	newPart({ Name = "HandleBracket", Size = Vector3.new(0.3, 0.42, 0.5), CFrame = CFrame.new(startX + 0.05, 0.28, 0),
		Color = metal, Material = Enum.Material.Metal, Parent = model })
	for _, z in ipairs({ -0.26, 0.26 }) do
		ball(model, 0.09, Vector3.new(startX + 0.05, 0.3, z), STEEL, Enum.Material.Metal)
	end
	-- finger ridges on the grip
	for i = 0, 3 do
		newPart({ Name = "GripRidge", Size = Vector3.new(0.08, 0.38, 0.58), CFrame = CFrame.new(startX + 1.6 + i * 0.35, 0.33, 0),
			Color = gripColor:Lerp(BLACK, 0.25), Material = Enum.Material.Wood, Parent = model })
	end
end

-- Two U-shaped carry handles on the short sides of a griddle
local function addSideHandles(model, halfX, panItem)
	local metal = panItem.Color:Lerp(STEEL, 0.55)
	for _, side in ipairs({ -1, 1 }) do
		local x = side * (halfX + 0.55)
		newPart({ Name = "SideHandle", Size = Vector3.new(0.18, 0.18, 1.6), CFrame = CFrame.new(x, 0.35, 0),
			Color = metal, Material = Enum.Material.Metal, Parent = model })
		newPart({ Name = "SideHandleGrip", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 0.26, 0.26), CFrame = CFrame.new(x, 0.35, 0) * CFrame.Angles(0, math.rad(90), 0),
			Color = panItem.HandleColor or WOOD, Material = Enum.Material.Wood, Parent = model })
		for _, z in ipairs({ -0.7, 0.7 }) do
			ball(model, 0.1, Vector3.new(side * (halfX + 0.12), 0.42, z), STEEL, Enum.Material.Metal)
		end
		for _, z in ipairs({ -0.7, 0.7 }) do
			newPart({ Name = "SideHandleArm", Size = Vector3.new(0.5, 0.16, 0.16), CFrame = CFrame.new(side * (halfX + 0.35), 0.35, z),
				Color = metal, Material = Enum.Material.Metal, Parent = model })
		end
	end
end

-- Builds a pan at the origin. Its pivot (PanRoot) is the center of the pan base.
-- The cooking surface is SurfaceHeight studs above the pivot.
function PancakeVisuals.BuildPan(panItem, sizeItem)
	local model = Instance.new("Model")
	model.Name = "Pan"
	local rng = Random.new(#panItem.Id * 31 + #sizeItem.Id)

	local root = newPart({ Name = "PanRoot", Size = Vector3.new(0.2, 0.2, 0.2), CFrame = CFrame.new(), Transparency = 1, Parent = model })
	local color = panItem.Color
	local wallColor = panItem.RimColor or color:Lerp(BLACK, 0.25)
	local wallMaterial = panItem.RimMaterial or panItem.Material
	local lipColor = panItem.LipColor or color:Lerp(WHITE, 0.18)
	local lipMaterial = panItem.LipMaterial or panItem.Material
	local underColor = color:Lerp(BLACK, 0.45)
	local material = panItem.Material
	local reflectance = panItem.Reflectance or 0
	local base

	if sizeItem.Shape == "Griddle" then
		local plate = sizeItem.PlateSize
		local hx, hz = plate.X / 2, plate.Y / 2
		base = newPart({ Name = "PanBase", Size = Vector3.new(plate.X, 0.25, plate.Y), CFrame = CFrame.new(),
			Color = color, Material = material, Reflectance = reflectance, Parent = model })
		newPart({ Name = "Underside", Size = Vector3.new(plate.X - 0.2, 0.15, plate.Y - 0.2), CFrame = CFrame.new(0, -0.18, 0),
			Color = underColor, Material = material, Parent = model })
		for _, side in ipairs({ -1, 1 }) do
			newPart({ Name = "Rim", Size = Vector3.new(plate.X + 0.5, 0.5, 0.25), CFrame = CFrame.new(0, 0.125, side * (hz + 0.125)),
				Color = wallColor, Material = wallMaterial, Reflectance = reflectance, Parent = model })
			newPart({ Name = "Rim", Size = Vector3.new(0.25, 0.5, plate.Y), CFrame = CFrame.new(side * (hx + 0.125), 0.125, 0),
				Color = wallColor, Material = wallMaterial, Reflectance = reflectance, Parent = model })
			newPart({ Name = "Lip", Size = Vector3.new(plate.X + 0.6, 0.07, 0.34), CFrame = CFrame.new(0, 0.41, side * (hz + 0.125)),
				Color = lipColor, Material = lipMaterial, Reflectance = reflectance, Parent = model })
			newPart({ Name = "Lip", Size = Vector3.new(0.34, 0.07, plate.Y), CFrame = CFrame.new(side * (hx + 0.125), 0.41, 0),
				Color = lipColor, Material = lipMaterial, Reflectance = reflectance, Parent = model })
		end
		-- grease channel along the front edge
		newPart({ Name = "GreaseChannel", Size = Vector3.new(plate.X - 0.5, 0.02, 0.22), CFrame = CFrame.new(0, 0.13, hz - 0.22),
			Color = color:Lerp(BLACK, 0.55), Material = material, Parent = model })
		-- little feet under the corners
		for _, sx in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -1, 1 }) do
				newPart({ Name = "Foot", Size = Vector3.new(0.35, 0.12, 0.35), CFrame = CFrame.new(sx * (hx - 0.4), -0.3, sz * (hz - 0.4)),
					Color = Color3.fromRGB(30, 30, 30), Parent = model })
			end
		end
		addSideHandles(model, hx + 0.25, panItem)
		addPanParticles(panItem, base, Enum.NormalId.Top)
	else
		local radius = sizeItem.PanRadius
		base = newPart({ Name = "PanBase", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.25, radius * 2, radius * 2),
			CFrame = FLAT, Color = color, Material = material, Reflectance = reflectance, Parent = model })
		disk(model, "Underside", 0.15, radius * 2 - 0.25, CFrame.new(0, -0.18, 0), underColor, material)
		local image = panImage(panItem)
		if image then
			-- a picture covering the cooking surface (the cylinder is rotated, so its "Right" face points up)
			local decal = Instance.new("Decal")
			decal.Name = "SurfaceImage"
			decal.Texture = image
			decal.Face = Enum.NormalId.Right
			decal.Parent = base
		else
			-- a slightly lighter cooking circle so the pan doesn't look flat
			disk(model, "CookingSurface", 0.01, radius * 2 - 0.5, CFrame.new(0, 0.128, 0), color:Lerp(WHITE, 0.06), material)
		end

		-- a smooth wall: many thin segments, each long enough to meet its neighbors on the OUTSIDE edge (no gaps)
		local count = math.max(48, math.ceil(2 * math.pi * (radius + 0.2) / 0.3))
		local wallLength = 2 * math.pi * (radius + 0.18) / count + 0.03
		local lipLength = 2 * math.pi * (radius + 0.27) / count + 0.03
		for i = 1, count do
			local turn = CFrame.Angles(0, i / count * math.pi * 2, 0)
			newPart({ Name = "Rim", Size = Vector3.new(0.25, 0.5, wallLength),
				CFrame = turn * CFrame.new(radius + 0.05, 0.125, 0),
				Color = wallColor, Material = wallMaterial, Reflectance = reflectance, Parent = model })
			-- a rolled lip on top, slightly flared outward
			newPart({ Name = "Lip", Size = Vector3.new(0.38, 0.09, lipLength),
				CFrame = turn * CFrame.new(radius + 0.09, 0.415, 0),
				Color = lipColor, Material = lipMaterial, Reflectance = reflectance, Parent = model })
		end
		-- a ring under the pan (the part that sits on the burner)
		disk(model, "BaseRing", 0.08, radius * 1.25, CFrame.new(0, -0.28, 0), underColor:Lerp(BLACK, 0.2), material)
		if not image then
			-- a worn, slightly darker circle in the middle where the pancakes cook
			disk(model, "WearMark", 0.01, radius * 1.3, CFrame.new(0, 0.13, 0), color:Lerp(BLACK, 0.1), material)
		end
		addLongHandle(model, radius + 0.2, panItem)
		if radius >= 3 then
			-- big pans get a helper handle on the other side
			newPart({ Name = "HelperHandle", Size = Vector3.new(0.7, 0.2, 1.2), CFrame = CFrame.new(-(radius + 0.5), 0.3, 0),
				Color = color:Lerp(STEEL, 0.5), Material = Enum.Material.Metal, Parent = model })
		end
		addPanParticles(panItem, base, Enum.NormalId.Right) -- the cylinder is rotated, so "Right" points up
	end

	local decor = PAN_DECOR[panItem.Id]
	if decor then
		decor(model, sizeItem, rng, panItem)
	end

	model.PrimaryPart = root
	model:SetAttribute("SurfaceHeight", 0.125)
	return model
end

--------------------------------------------------------------------
-- PANCAKES
--------------------------------------------------------------------
-- Little mix-ins (berries, chips...) on both faces. Offsets are relative to the pancake's center.
function PancakeVisuals.GetBits(pancakeItem, diameter, seed)
	local bits = {}
	local info = pancakeItem.Bits
	if not info then return bits end
	local rng = Random.new(seed or 1)
	local count = math.max(3, math.floor(info.Count * math.sqrt(diameter / 3.4) + 0.5))
	for i = 1, count * 2 do
		local side = (i <= count) and 1 or -1
		local angle = rng:NextNumber() * math.pi * 2
		local radius = math.sqrt(rng:NextNumber()) * (diameter / 2 - 0.3)
		local size = info.Size * (0.8 + rng:NextNumber() * 0.4)
		table.insert(bits, {
			Offset = CFrame.new(math.cos(angle) * radius, side * THICK / 2, math.sin(angle) * radius)
				* CFrame.Angles(0, rng:NextNumber() * math.pi * 2, 0),
			Size = info.Shape == "Ball" and Vector3.one * size or Vector3.new(size, size * 0.6, size),
			Shape = info.Shape == "Ball" and Enum.PartType.Ball or Enum.PartType.Block,
			Color = info.Colors[rng:NextInteger(1, #info.Colors)],
			Material = info.Neon and Enum.Material.Neon or Enum.Material.SmoothPlastic,
		})
	end
	return bits
end

-- Pancakes are lighter and fluffier in the middle than at the edges
PancakeVisuals.CROWN_SCALE = 0.62
function PancakeVisuals.CrownColor(faceColor)
	return faceColor:Lerp(Color3.fromRGB(255, 235, 185), 0.18)
end

-- A finished pancake (used for shop previews). Centered on the origin.
function PancakeVisuals.BuildPancake(pancakeItem, diameter, cookFraction)
	local model = Instance.new("Model")
	model.Name = "Pancake"
	local cooked = GameConfig.GetCookColor(cookFraction or 0.66, pancakeItem)
	local faceMaterial = pancakeItem.FaceMaterial
	disk(model, "Body", THICK, diameter, CFrame.new(), cooked:Lerp(pancakeItem.Raw, 0.3), faceMaterial)
	local top = disk(model, "Top", 0.05, diameter - 0.15, CFrame.new(0, THICK / 2, 0), cooked, faceMaterial)
	disk(model, "Bottom", 0.05, diameter - 0.15, CFrame.new(0, -THICK / 2, 0), cooked, faceMaterial)
	disk(model, "Crown", 0.04, diameter * PancakeVisuals.CROWN_SCALE, CFrame.new(0, THICK / 2 + 0.01, 0),
		PancakeVisuals.CrownColor(cooked), faceMaterial)
	if pancakeItem.Special == "Golden" then
		top.Reflectance = 0.3
	end
	for _, bit in ipairs(PancakeVisuals.GetBits(pancakeItem, diameter, 7)) do
		newPart({ Shape = bit.Shape, Size = bit.Size, CFrame = bit.Offset, Color = bit.Color, Material = bit.Material, Parent = model })
	end
	model.WorldPivot = CFrame.new()
	return model
end

--------------------------------------------------------------------
-- TOPPINGS (built on a pancake's top surface: y = 0 is the surface)
--------------------------------------------------------------------
local RAINBOW = {
	Color3.fromRGB(255, 80, 80), Color3.fromRGB(255, 190, 50), Color3.fromRGB(255, 240, 90),
	Color3.fromRGB(90, 220, 110), Color3.fromRGB(80, 160, 255), Color3.fromRGB(200, 110, 255),
	Color3.fromRGB(255, 140, 200), Color3.fromRGB(255, 255, 255),
}

-- A drizzled line made of short segments between points
local function drizzle(add, points, width, color, material)
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		add({ Size = Vector3.new(width, 0.06, (b - a).Magnitude + width), CFrame = CFrame.lookAt((a + b) / 2, b),
			Color = color, Material = material })
	end
end

-- Zig-zag points across the pancake
local function zigzagPoints(r, zCenter, amplitude, steps, height)
	local points = {}
	for i = 0, steps do
		local x = -r * 0.8 + (r * 1.6) * i / steps
		local z = zCenter + ((i % 2 == 0) and amplitude or -amplitude)
		-- keep the line inside the pancake circle
		local limit = math.sqrt(math.max(r * r * 0.8 - x * x, 0))
		table.insert(points, Vector3.new(x, height, math.clamp(z, -limit, limit)))
	end
	return points
end

local TOPPING_BUILDERS = {}

TOPPING_BUILDERS.Syrup = function(add, s, r, rng)
	local syrup = Color3.fromRGB(175, 95, 25)
	add({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.05, r * 1.6, r * 1.6), CFrame = CFrame.new(0, 0.03, 0) * FLAT,
		Color = syrup, Transparency = 0.12, Reflectance = 0.2 })
	add({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.08, r * 0.8, r * 0.8), CFrame = CFrame.new(0.1 * s, 0.06, -0.1 * s) * FLAT,
		Color = syrup:Lerp(BLACK, 0.1), Transparency = 0.05, Reflectance = 0.25 })
	-- drips running down the sides
	for i = 1, 6 do
		local angle = i / 6 * math.pi * 2 + rng:NextNumber() * 0.5
		local length = (0.25 + rng:NextNumber() * 0.35) * math.max(s, 0.6)
		local x, z = math.cos(angle) * r * 0.97, math.sin(angle) * r * 0.97
		add({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(length, 0.13 * s, 0.13 * s),
			CFrame = CFrame.new(x, -length / 2 + 0.03, z) * FLAT, Color = syrup, Reflectance = 0.2 })
		add({ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.18 * s, CFrame = CFrame.new(x, -length + 0.03, z),
			Color = syrup, Reflectance = 0.2 })
	end
end

TOPPING_BUILDERS.Butter = function(add, s, r, rng, place)
	local butter = Color3.fromRGB(255, 225, 90)
	local spot = CFrame.new(0.35 * s, 0, -0.3 * s) * CFrame.Angles(0, 0.4, 0)
	add({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.03, 1.3 * s, 1.3 * s), CFrame = spot * CFrame.new(0, 0.02, 0) * FLAT,
		Color = Color3.fromRGB(255, 235, 140), Transparency = 0.25, Reflectance = 0.2 }) -- melting puddle
	if place("Butter", spot * CFrame.new(0, 0.02, 0), 0.8 * s) then
		return
	end
	add({ Size = Vector3.new(0.7, 0.26, 0.7) * s, CFrame = spot * CFrame.new(0, 0.13 * s, 0), Color = butter })
	add({ Size = Vector3.new(0.58, 0.06, 0.58) * s, CFrame = spot * CFrame.new(0, 0.28 * s, 0), Color = butter:Lerp(WHITE, 0.3) })
end

TOPPING_BUILDERS.Cream = function(add, s, r, rng, place)
	if place("WhippedCream", CFrame.new(0, 0, 0), 1.4 * s, "Y") then
		return
	end
	local cream = Color3.fromRGB(255, 252, 245)
	for i = 1, 6 do -- a swirl that gets smaller as it goes up
		local size = (1.15 - i * 0.14) * s
		add({ Shape = Enum.PartType.Ball, Size = Vector3.one * size,
			CFrame = CFrame.new(math.cos(i * 1.3) * 0.1 * s, (0.2 + i * 0.17) * s, math.sin(i * 1.3) * 0.1 * s), Color = cream })
	end
	-- a cherry on top
	add({ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.34 * s, CFrame = CFrame.new(0, 1.35 * s, 0),
		Color = Color3.fromRGB(210, 20, 40), Reflectance = 0.25 })
	add({ Size = Vector3.new(0.04, 0.4, 0.04) * s, CFrame = CFrame.new(0.06 * s, 1.6 * s, 0) * CFrame.Angles(0, 0, math.rad(-25)),
		Color = Color3.fromRGB(70, 120, 40) })
end

TOPPING_BUILDERS.Berries = function(add, s, r, rng, place)
	-- strawberries with leafy tops and seeds
	for i = 1, 3 do
		local angle = i / 3 * math.pi * 2 + rng:NextNumber() * 0.4
		local center = Vector3.new(math.cos(angle) * r * 0.45, 0.2 * s, math.sin(angle) * r * 0.45)
		if place("Strawberry", CFrame.new(center.X, 0, center.Z) * CFrame.Angles(0, angle, 0), 0.6 * s) then
			continue
		end
		add({ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.48 * s, CFrame = CFrame.new(center), Color = Color3.fromRGB(215, 30, 50) })
		for leaf = 1, 3 do
			add({ Size = Vector3.new(0.26, 0.03, 0.1) * s,
				CFrame = CFrame.new(center + Vector3.new(0, 0.23 * s, 0)) * CFrame.Angles(0, leaf * math.pi * 2 / 3, math.rad(20)),
				Color = Color3.fromRGB(60, 150, 50) })
		end
		for seed = 1, 3 do
			local seedAngle = seed * 2.1
			add({ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.05 * math.max(s, 0.7),
				CFrame = CFrame.new(center + Vector3.new(math.cos(seedAngle) * 0.22 * s, 0.02, math.sin(seedAngle) * 0.22 * s)),
				Color = Color3.fromRGB(255, 225, 120) })
		end
	end
	-- blueberries
	for i = 1, 6 do
		local angle = i / 6 * math.pi * 2 + 0.5
		local center = Vector3.new(math.cos(angle) * r * 0.68, 0.13 * s, math.sin(angle) * r * 0.68)
		if place("Blueberry", CFrame.new(center.X, 0, center.Z), 0.3 * s) then
			continue
		end
		add({ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.28 * s, CFrame = CFrame.new(center), Color = Color3.fromRGB(55, 55, 150) })
		add({ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.08 * s, CFrame = CFrame.new(center + Vector3.new(0, 0.12 * s, 0)),
			Color = Color3.fromRGB(35, 30, 80) })
	end
	-- a mint leaf
	add({ Size = Vector3.new(0.45, 0.03, 0.22) * s, CFrame = CFrame.new(0, 0.08, 0) * CFrame.Angles(0, 0.6, 0),
		Color = Color3.fromRGB(80, 190, 90) })
end

TOPPING_BUILDERS.Chocolate = function(add, s, r)
	local chocolate = Color3.fromRGB(75, 40, 20)
	for line = -1, 1 do
		drizzle(add, zigzagPoints(r, line * r * 0.4, 0.14 * r, 7, 0.05), 0.1 * s, chocolate)
	end
	for i = 1, 5 do -- a few chocolate chunks
		local angle = i * 1.25
		add({ Size = Vector3.new(0.18, 0.12, 0.18) * s, CFrame = CFrame.new(math.cos(angle) * r * 0.5, 0.08, math.sin(angle) * r * 0.5)
			* CFrame.Angles(0, angle, 0), Color = chocolate:Lerp(BLACK, 0.2) })
	end
end

TOPPING_BUILDERS.Sprinkles = function(add, s, r, rng)
	for _ = 1, 40 do
		local angle = rng:NextNumber() * math.pi * 2
		local radius = math.sqrt(rng:NextNumber()) * r * 0.85
		add({ Size = Vector3.new(0.24, 0.07, 0.07) * math.max(s, 0.6),
			CFrame = CFrame.new(math.cos(angle) * radius, 0.045, math.sin(angle) * radius)
				* CFrame.Angles(0, rng:NextNumber() * math.pi, rng:NextNumber() * 0.4),
			Color = RAINBOW[rng:NextInteger(1, #RAINBOW)] })
	end
end

TOPPING_BUILDERS.Banana = function(add, s, r)
	for i = 1, 6 do
		local angle = i / 6 * math.pi * 2
		local center = Vector3.new(math.cos(angle) * r * 0.52, 0.06 * s, math.sin(angle) * r * 0.52)
		add({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12 * s, 0.62 * s, 0.62 * s), CFrame = CFrame.new(center) * FLAT,
			Color = Color3.fromRGB(245, 220, 140) })
		add({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.02, 0.5 * s, 0.5 * s), CFrame = CFrame.new(center + Vector3.new(0, 0.065 * s, 0)) * FLAT,
			Color = Color3.fromRGB(215, 150, 60), Transparency = 0.1 }) -- caramelized top
		for seed = 1, 3 do
			local seedAngle = seed * math.pi * 2 / 3
			add({ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.05 * math.max(s, 0.7),
				CFrame = CFrame.new(center + Vector3.new(math.cos(seedAngle) * 0.07 * s, 0.075 * s, math.sin(seedAngle) * 0.07 * s)),
				Color = Color3.fromRGB(60, 40, 25) })
		end
	end
	drizzle(add, zigzagPoints(r, 0, 0.25 * r, 6, 0.14 * s), 0.07 * s, Color3.fromRGB(200, 120, 40)) -- caramel drizzle
end

TOPPING_BUILDERS.GoldLeaf = function(add, s, r, rng)
	for i = 1, 10 do
		local angle = rng:NextNumber() * math.pi * 2
		local radius = math.sqrt(rng:NextNumber()) * r * 0.7
		local spot = CFrame.new(math.cos(angle) * radius, 0.06, math.sin(angle) * radius) * CFrame.Angles(0, rng:NextNumber() * math.pi, 0)
		-- each flake is two crinkled halves
		local half = add({ Size = Vector3.new(0.24 * s, 0.025, 0.36 * s), CFrame = spot * CFrame.new(-0.1 * s, 0, 0) * CFrame.Angles(0, 0, math.rad(12)),
			Color = Color3.fromRGB(255, 205, 70), Material = Enum.Material.Foil, Reflectance = 0.35 })
		add({ Size = Vector3.new(0.24 * s, 0.025, 0.32 * s), CFrame = spot * CFrame.new(0.1 * s, 0, 0.03) * CFrame.Angles(0, 0.2, math.rad(-15)),
			Color = Color3.fromRGB(255, 220, 110), Material = Enum.Material.Foil, Reflectance = 0.35 })
		if i <= 2 then
			local sparkle = Instance.new("ParticleEmitter")
			sparkle.Texture = TEX.Sparkle
			sparkle.Color = ColorSequence.new(Color3.fromRGB(255, 230, 120))
			sparkle.Size = NumberSequence.new(0.4, 0)
			sparkle.LightEmission = 1
			sparkle.Rate = 4
			sparkle.Lifetime = NumberRange.new(0.5, 1)
			sparkle.Speed = NumberRange.new(0.5, 1)
			sparkle.Parent = half
		end
	end
end

TOPPING_BUILDERS.Cosmic = function(add, s, r, rng)
	-- layered glowing syrup
	local layers = { { 1.55, Color3.fromRGB(110, 50, 220) }, { 1.1, Color3.fromRGB(200, 70, 255) }, { 0.6, Color3.fromRGB(120, 220, 255) } }
	for index, layer in ipairs(layers) do
		local glow = add({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.04, r * layer[1], r * layer[1]),
			CFrame = CFrame.new(0, 0.03 + index * 0.012, 0) * FLAT, Color = layer[2], Material = Enum.Material.Neon, Transparency = 0.15 })
		if index == 1 then
			local light = Instance.new("PointLight")
			light.Color = layer[2]
			light.Range = 6
			light.Brightness = 1.5
			light.Parent = glow
		end
	end
	-- two spiral arms of stars
	for arm = 0, 1 do
		for i = 1, 8 do
			local angle = arm * math.pi + i * 0.55
			local radius = r * 0.12 * i
			add({ Shape = Enum.PartType.Ball, Size = Vector3.one * (0.14 - i * 0.008) * math.max(s, 0.6),
				CFrame = CFrame.new(math.cos(angle) * radius, 0.1, math.sin(angle) * radius),
				Color = (i % 2 == 0) and WHITE or Color3.fromRGB(180, 240, 255), Material = Enum.Material.Neon })
		end
	end
	-- a tiny ringed planet floating above
	add({ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.4 * s, CFrame = CFrame.new(0, 0.6 * s, 0), Color = Color3.fromRGB(255, 170, 90) })
	add({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.02, 0.75 * s, 0.75 * s),
		CFrame = CFrame.new(0, 0.6 * s, 0) * CFrame.Angles(0.35, 0, 0) * FLAT, Color = Color3.fromRGB(255, 230, 180), Material = Enum.Material.Neon, Transparency = 0.2 })
end

-- Builds all the given toppings stacked on one pancake. Pivot = center of the pancake's top surface.
function PancakeVisuals.BuildToppings(items, diameter, seed)
	local model = Instance.new("Model")
	model.Name = "Toppings"
	local rng = Random.new(seed or 3)
	local s, r = diameter / 3.4, diameter / 2
	for index, item in ipairs(items) do
		local builder = TOPPING_BUILDERS[item.Id]
		if builder then
			local lift = CFrame.new(0, (index - 1) * 0.015, 0)
			local function add(props)
				props.Parent = model
				props.CFrame = lift * props.CFrame
				return newPart(props)
			end
			-- uses an installed Creator Store model if there is one (returns nil if not)
			local function place(assetName, cframe, maxSize, axis)
				local asset = PancakeVisuals.GetAsset(assetName)
				if not asset then return nil end
				PancakeVisuals.FitAsset(asset, maxSize, axis)
				asset:PivotTo(lift * cframe)
				asset.Parent = model
				return asset
			end
			builder(add, s, r, rng, place)
		end
	end
	model.WorldPivot = CFrame.new()
	return model
end

return PancakeVisuals
