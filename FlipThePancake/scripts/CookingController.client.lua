-- CookingController (LocalScript in StarterPlayer > StarterPlayerScripts)
-- Handles input, the HUD, the cook meter, the power bar and the pancake animations.
-- The extra "juice" (sounds, particles, combo counter, confetti...) lives in the Effects module.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = workspace.CurrentCamera

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local PancakeVisuals = require(ReplicatedStorage:WaitForChild("PancakeVisuals"))
local Effects = require(script.Parent:WaitForChild("Effects"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local PourRemote = Remotes:WaitForChild("Pour")
local FlipRemote = Remotes:WaitForChild("Flip")
local ServeRemote = Remotes:WaitForChild("Serve")
local LeaveRemote = Remotes:WaitForChild("LeaveStation")
local StationEvent = Remotes:WaitForChild("StationEvent")

local stationsFolder = workspace:WaitForChild("Stations")
local stationModel = stationsFolder:WaitForChild("Station1") -- the station you're cooking at (set when you enter)
local stationCFrame = GameConfig.GetStationCFrame(1) -- where your kitchen is and which way it faces

--------------------------------------------------------------------
-- CONSTANTS
--------------------------------------------------------------------
local FONT = Enum.Font.FredokaOne
local WHITE = Color3.new(1, 1, 1)
local DARK = Color3.fromRGB(60, 35, 20)
local GOLD = Color3.fromRGB(255, 220, 50)
local FLAT = CFrame.Angles(0, 0, math.rad(90)) -- lays a cylinder flat
local FLIPPED = CFrame.Angles(math.pi, 0, 0)
local THICK = PancakeVisuals.THICKNESS
local CAMERA_OFFSET = Vector3.new(0, 8, 15)
local BASE_FOV = 70

local floorY = GameConfig.StationPosition.Y + 0.2
local STACK_STEP = PancakeVisuals.THICKNESS + 0.02

local function stackHeight()
	return stationModel:GetAttribute("StackHeight") or 0
end

-- Where a pancake lands on your stack plate (on top of whatever is already stacked)
local function stackTop(extra)
	local plate = (stationCFrame * CFrame.new(GameConfig.StackPlateOffset + Vector3.new(0, 0.1, 0))).Position
	return plate + Vector3.new(0, PancakeVisuals.THICKNESS / 2 + (stackHeight() + (extra or 0)) * STACK_STEP, 0)
end

--------------------------------------------------------------------
-- THE PAN (the server rebuilds it when you change pans or sizes)
--------------------------------------------------------------------
local pan, panRoot, panHome
local rot = CFrame.new() -- the kitchen's rotation (restaurants face the path from both sides)
local restCenter -- center of the pancakes when they sit in the pan

local function panArea()
	local base = pan:FindFirstChild("PanBase")
	if not base then
		return 4.5, 4.5
	end
	if base.Shape == Enum.PartType.Cylinder then
		return base.Size.Y, base.Size.Z
	end
	return base.Size.X, base.Size.Z
end

local function setPan(model)
	pan = model or stationModel:WaitForChild("Pan")
	if not pan:FindFirstChild("PanRoot") and pan.Parent == nil then
		pan = stationModel:WaitForChild("Pan")
	end
	panRoot = pan:WaitForChild("PanRoot")
	panHome = pan:GetPivot()
	local surface = panRoot.Position.Y + (pan:GetAttribute("SurfaceHeight") or 0.125)
	restCenter = Vector3.new(panRoot.Position.X, surface + THICK / 2, panRoot.Position.Z)
	rot = panRoot.CFrame.Rotation
end

setPan(nil)

--------------------------------------------------------------------
-- UI HELPERS
--------------------------------------------------------------------
local function create(className, props, children)
	local obj = Instance.new(className)
	for key, value in pairs(props or {}) do
		if key ~= "Parent" then
			obj[key] = value
		end
	end
	for _, child in ipairs(children or {}) do
		child.Parent = obj
	end
	if props and props.Parent then
		obj.Parent = props.Parent
	end
	return obj
end

local function corner(radius)
	return create("UICorner", { CornerRadius = UDim.new(0, radius or 12) })
end

local function border(thickness, color)
	return create("UIStroke", {
		Thickness = thickness or 3,
		Color = color or DARK,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

--------------------------------------------------------------------
-- HUD
--------------------------------------------------------------------
local gui = create("ScreenGui", {
	Name = "PancakeHUD",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = playerGui,
})

-- Butter counter (top center)
local butterFrame = create("Frame", {
	Name = "ButterCounter",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 8),
	Size = UDim2.fromOffset(230, 56),
	BackgroundColor3 = Color3.fromRGB(255, 222, 89),
	Parent = gui,
}, { corner(16), border(3, Color3.fromRGB(150, 100, 20)) })
local butterScale = create("UIScale", { Parent = butterFrame })
local butterLabel = create("TextLabel", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Font = FONT,
	TextScaled = true,
	TextColor3 = Color3.fromRGB(110, 60, 10),
	Text = "🧈 0",
	Parent = butterFrame,
}, { create("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }) })

-- Hint text under the counter
local hintLabel = create("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 70),
	Size = UDim2.new(0.9, 0, 0, 28),
	BackgroundTransparency = 1,
	Font = FONT,
	TextScaled = true,
	TextColor3 = WHITE,
	TextStrokeTransparency = 0.2,
	Text = "",
	Parent = gui,
}, { create("UISizeConstraint", { MaxSize = Vector2.new(600, 28) }) })

-- Big action button (Pour / Hold to flip / Serve)
local actionButton = create("TextButton", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -24),
	Size = UDim2.fromOffset(280, 84),
	BackgroundColor3 = Color3.fromRGB(255, 190, 60),
	AutoButtonColor = false,
	Font = FONT,
	TextScaled = true,
	TextColor3 = WHITE,
	TextStrokeTransparency = 0.3,
	Text = "",
	Visible = false,
	Parent = gui,
}, {
	corner(20),
	create("UIPadding", { PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12) }),
})
local actionStroke = border(4, DARK)
actionStroke.Parent = actionButton
local actionScale = create("UIScale", { Parent = actionButton })

-- Leave button (next to the Butter counter, so it doesn't sit under Roblox's player list)
local leaveButton = create("TextButton", {
	AnchorPoint = Vector2.new(0, 0),
	Position = UDim2.new(0.5, 125, 0, 8),
	Size = UDim2.fromOffset(120, 44),
	BackgroundColor3 = Color3.fromRGB(220, 70, 70),
	Font = FONT,
	TextScaled = true,
	TextColor3 = WHITE,
	Text = "✕ Leave",
	Visible = false,
	Parent = gui,
}, { corner(12), border(3, DARK), create("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }) })

-- STACK button (right of the big button): stack finished pancakes, or serve the whole stack
local stackButton = create("TextButton", {
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0.5, 152, 1, -30),
	Size = UDim2.fromOffset(190, 72),
	BackgroundColor3 = Color3.fromRGB(80, 160, 255),
	AutoButtonColor = false,
	Font = FONT,
	TextScaled = true,
	TextColor3 = WHITE,
	TextStrokeTransparency = 0.3,
	Text = "🥞 STACK",
	Visible = false,
	Parent = gui,
}, { corner(18), border(4, DARK), create("UIPadding", {
	PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8),
}) })
local stackScale = create("UIScale", { Parent = stackButton })

-- ORDER card (left side): what your customer wants and how patient they are
local orderCard = create("Frame", {
	AnchorPoint = Vector2.new(0, 0),
	Position = UDim2.new(0, 16, 0.5, 62),
	Size = UDim2.fromOffset(250, 118),
	BackgroundColor3 = WHITE,
	Visible = false,
	Parent = gui,
}, { corner(16), border(3, DARK) })
local orderScale = create("UIScale", { Parent = orderCard })
create("TextLabel", {
	Position = UDim2.fromOffset(10, 6),
	Size = UDim2.new(1, -20, 0, 24),
	BackgroundTransparency = 1,
	Font = FONT,
	TextScaled = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = Color3.fromRGB(230, 110, 40),
	Text = "📋 ORDER  •  pays x" .. GameConfig.Orders.RewardMultiplier .. "!",
	Parent = orderCard,
})
local orderText = create("TextLabel", {
	Position = UDim2.fromOffset(10, 32),
	Size = UDim2.new(1, -20, 0, 62),
	BackgroundTransparency = 1,
	Font = FONT,
	TextScaled = true,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = DARK,
	Text = "",
	Parent = orderCard,
})
local orderBarBack = create("Frame", {
	Position = UDim2.new(0, 10, 1, -16),
	Size = UDim2.new(1, -20, 0, 8),
	BackgroundColor3 = Color3.fromRGB(230, 220, 205),
	Parent = orderCard,
}, { corner(4) })
local orderBar = create("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.fromRGB(90, 200, 100),
	Parent = orderBarBack,
}, { corner(4) })

-- Flip power bar
local powerFrame = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -136),
	Size = UDim2.new(0.8, 0, 0, 34),
	BackgroundColor3 = Color3.fromRGB(90, 25, 25), -- too weak = flop
	Visible = false,
	Parent = gui,
}, { corner(8), border(3, DARK), create("UISizeConstraint", { MaxSize = Vector2.new(480, 34) }) })

create("TextLabel", {
	Position = UDim2.new(0, 0, 0, -30),
	Size = UDim2.new(1, 0, 0, 26),
	BackgroundTransparency = 1,
	Font = FONT,
	TextScaled = true,
	TextColor3 = WHITE,
	TextStrokeTransparency = 0.2,
	Text = "HOLD, then RELEASE on the ⭐ GOLD!",
	Parent = powerFrame,
})

local function addBand(from, to, color, zIndex)
	create("Frame", {
		Position = UDim2.fromScale(from, 0),
		Size = UDim2.fromScale(to - from, 1),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = zIndex,
		Parent = powerFrame,
	})
end

for _, trick in ipairs(GameConfig.FlipTricks) do
	local function band(tolerance)
		return math.max(trick.Min, trick.Sweet - tolerance), math.min(trick.Max, trick.Sweet + tolerance)
	end
	addBand(trick.Min, trick.Max, Color3.fromRGB(200, 50, 50), 2) -- red = drop risk
	local a, b = band(trick.Sloppy)
	addBand(a, b, Color3.fromRGB(245, 150, 50), 3)
	a, b = band(trick.Good)
	addBand(a, b, Color3.fromRGB(110, 205, 90), 4)
	a, b = band(trick.Perfect)
	addBand(a, b, Color3.fromRGB(255, 225, 60), 5)

	create("Frame", { -- divider between tricks
		Position = UDim2.fromScale(trick.Min, 0),
		Size = UDim2.new(0, 2, 1, 0),
		BackgroundColor3 = DARK,
		BorderSizePixel = 0,
		ZIndex = 6,
		Parent = powerFrame,
	})
	create("TextLabel", {
		Position = UDim2.new(trick.Min, 0, 1, 3),
		Size = UDim2.new(trick.Max - trick.Min, 0, 0, 16),
		BackgroundTransparency = 1,
		Font = FONT,
		TextScaled = true,
		TextColor3 = WHITE,
		TextStrokeTransparency = 0.2,
		Text = trick.ShortLabel,
		Parent = powerFrame,
	})
end

local needle = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0, 0.5),
	Size = UDim2.new(0, 6, 1, 14),
	BackgroundColor3 = WHITE,
	BorderSizePixel = 0,
	ZIndex = 10,
	Parent = powerFrame,
}, { border(2, DARK) })

-- Big popup text in the middle of the screen (outlined, with a color gradient)
local popupLabel = create("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.3),
	Size = UDim2.new(0.85, 0, 0, 120),
	BackgroundTransparency = 1,
	Font = FONT,
	TextScaled = true,
	TextColor3 = WHITE,
	TextTransparency = 1,
	Text = "",
	Parent = gui,
}, { create("UISizeConstraint", { MaxSize = Vector2.new(720, 120) }) })
local popupStroke = create("UIStroke", { Thickness = 5, Color = DARK, Transparency = 1, Parent = popupLabel })
local popupGradient = create("UIGradient", { Rotation = 90, Parent = popupLabel })
local popupScale = create("UIScale", { Parent = popupLabel })
local popupToken = 0

local function showPopup(text, color)
	popupToken += 1
	local myToken = popupToken
	popupLabel.Text = text
	popupGradient.Color = ColorSequence.new(WHITE, color or WHITE)
	popupLabel.TextTransparency = 0
	popupStroke.Transparency = 0
	popupScale.Scale = 0.3
	popupLabel.Rotation = math.random(-12, 12)
	local pop = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	TweenService:Create(popupScale, pop, { Scale = 1 }):Play()
	TweenService:Create(popupLabel, pop, { Rotation = 0 }):Play()
	task.delay(1.1, function()
		if myToken ~= popupToken then return end
		local fade = TweenInfo.new(0.4)
		TweenService:Create(popupLabel, fade, { TextTransparency = 1 }):Play()
		TweenService:Create(popupStroke, fade, { Transparency = 1 }):Play()
	end)
end

--------------------------------------------------------------------
-- COOK METER (floats above the pan)
--------------------------------------------------------------------
local cookMeter = create("BillboardGui", {
	Name = "CookMeter",
	Adornee = panRoot,
	Size = UDim2.fromOffset(280, 60),
	StudsOffsetWorldSpace = Vector3.new(0, 3.4, 0),
	AlwaysOnTop = true,
	ResetOnSpawn = false,
	Enabled = false,
	Parent = playerGui,
})
local meterLabel = create("TextLabel", {
	Size = UDim2.fromScale(1, 0.5),
	BackgroundTransparency = 1,
	Font = FONT,
	TextScaled = true,
	TextColor3 = WHITE,
	TextStrokeTransparency = 0,
	Text = "",
	Parent = cookMeter,
})
local meterLabelScale = create("UIScale", { Parent = meterLabel })
local meterBar = create("Frame", {
	Position = UDim2.fromScale(0, 0.56),
	Size = UDim2.fromScale(1, 0.4),
	BackgroundColor3 = DARK,
	BorderSizePixel = 0,
	Parent = cookMeter,
})
local meterStroke = border(3, DARK)
meterStroke.Parent = meterBar

local meterPointer = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0, 0.5),
	Size = UDim2.new(0, 5, 1, 10),
	BackgroundColor3 = WHITE,
	BorderSizePixel = 0,
	ZIndex = 5,
	Parent = meterBar,
}, { border(2, DARK) })

-- The zones change with your pan and pancake type, so they're rebuilt each pour
local zoneFrames = {}
local function buildMeterZones(zones)
	for _, frame in ipairs(zoneFrames) do
		frame:Destroy()
	end
	zoneFrames = {}
	local zoneStart = 0
	for _, zone in ipairs(zones) do
		local zoneEnd = math.min(zone.End, 1)
		table.insert(zoneFrames, create("Frame", {
			Position = UDim2.fromScale(zoneStart, 0),
			Size = UDim2.fromScale(zoneEnd - zoneStart, 1),
			BackgroundColor3 = zone.Color,
			BorderSizePixel = 0,
			Parent = meterBar,
		}))
		zoneStart = zoneEnd
	end
end

local ZONE_TEXT = {
	Raw = { "Raw...", Color3.fromRGB(255, 245, 220) },
	Golden = { "Golden", Color3.fromRGB(140, 235, 110) },
	Perfect = { "⭐ PERFECT! ⭐", GOLD },
	Burnt = { "🔥 BURNING! 🔥", Color3.fromRGB(255, 80, 60) },
}

-- Floating text that rises from the pan
local function floatText(text, color, startHeight)
	local billboard = create("BillboardGui", {
		Adornee = panRoot,
		Size = UDim2.fromOffset(260, 60),
		StudsOffsetWorldSpace = Vector3.new(0, startHeight or 2, 0),
		AlwaysOnTop = true,
		Parent = playerGui,
	})
	local label = create("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Font = FONT,
		TextScaled = true,
		TextColor3 = color,
		TextStrokeTransparency = 0,
		Text = text,
		Parent = billboard,
	})
	TweenService:Create(billboard, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ StudsOffsetWorldSpace = Vector3.new(0, (startHeight or 2) + 5, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(0.5, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, 0.7),
		{ TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	task.delay(1.3, function()
		billboard:Destroy()
	end)
end

Effects.InitUI(gui)
Effects.InitWorld(restCenter)

local function fitEffectsToPan()
	local sizeX, sizeZ = panArea()
	Effects.ConfigureArea(restCenter, sizeX, sizeZ, rot)
	cookMeter.Adornee = panRoot
end
fitEffectsToPan()

--------------------------------------------------------------------
-- BUTTER COUNTER
--------------------------------------------------------------------
local butterValue = nil
local shownButter = 0
local holdButter = false -- true while flying butter is on its way to the counter
local holdToken = 0

local function setButterText(amount, pop)
	shownButter = amount
	butterLabel.Text = "🧈 " .. GameConfig.FormatNumber(amount)
	if pop then
		butterScale.Scale = 1.25
		TweenService:Create(butterScale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end
end

local function refreshButter(pop)
	if butterValue then
		setButterText(butterValue.Value, pop)
	end
end

local function releaseButterHold()
	holdButter = false
	refreshButter(false)
end

task.spawn(function()
	butterValue = player:WaitForChild("leaderstats"):WaitForChild("Butter")
	refreshButter(false)
	butterValue.Changed:Connect(function()
		if not holdButter then
			refreshButter(true)
		end
	end)
end)

--------------------------------------------------------------------
-- STATE
--------------------------------------------------------------------
-- Away -> Empty -> SideA -> Charging -> Flipping -> SideB -> Busy (serving) -> Empty
local state = "Away"
local session = 0         -- bumps every time we enter/leave, cancels old animations
local cookStart = 0
local chargeStart = 0
local sideAFraction = 0
local loadout = GameConfig.GetLoadout(nil) -- the gear locked in for the current pancake(s)
local pancakes = {}       -- every pancake in the pan right now
local shakeUntil, shakeStrength = 0, 0
local camLook = restCenter
local camPosition = restCenter + CAMERA_OFFSET
local fovPunch = 0
local nextBubble = 0

buildMeterZones(loadout.Zones)

local BUTTON_STYLES = {
	Empty = { "🥣 POUR", Color3.fromRGB(255, 190, 60) },
	SideA = { "✋ HOLD TO FLIP", Color3.fromRGB(255, 130, 50) },
	Charging = { "RELEASE!", Color3.fromRGB(235, 60, 60) },
	SideB = { "🍽️ SERVE", Color3.fromRGB(80, 200, 100) },
}
local BUSY_STYLE = { "...", Color3.fromRGB(150, 150, 150) }

local HINTS = {
	Empty = "Press POUR to start cooking!",
	SideA = "Wait for ⭐ PERFECT, then hold to charge your flip!",
	Charging = "Release when the needle is on the ⭐ gold!",
	SideB = "Serve when the other side is ⭐ PERFECT!",
}

local FLIP_POPUPS = {
	Perfect = { "⭐ PERFECT LANDING! ⭐", GOLD },
	Good = { "NICE FLIP!", Color3.fromRGB(130, 230, 100) },
	Sloppy = { "Sloppy...", Color3.fromRGB(255, 160, 70) },
	Dropped = { "DROPPED! 😭", Color3.fromRGB(255, 70, 70) },
}

local TRICK_COLORS = {
	Color3.fromRGB(255, 255, 255),
	Color3.fromRGB(90, 220, 255),
	Color3.fromRGB(255, 90, 220),
	Color3.fromRGB(180, 110, 255),
}

local function setState(newState)
	state = newState
	local style = BUTTON_STYLES[newState] or BUSY_STYLE
	actionButton.Text = style[1]
	actionButton.BackgroundColor3 = style[2]
	hintLabel.Text = HINTS[newState] or ""
	powerFrame.Visible = (newState == "SideA" or newState == "Charging")
	cookMeter.Enabled = (newState == "SideA" or newState == "Charging" or newState == "SideB")
end

-- The STACK button: "stack these pancakes" while serving, or "serve the stack" when the pan is empty
local function refreshStackButton()
	local height = stackHeight()
	if state == "SideB" then
		stackButton.Visible = true
		stackButton.Text = ("🥞 STACK  (x%.1f)"):format(GameConfig.GetStackMultiplier(height + #pancakes))
		stackButton.BackgroundColor3 = Color3.fromRGB(80, 160, 255)
	elseif state == "Empty" and height > 0 then
		stackButton.Visible = true
		stackButton.Text = ("🍽️ SERVE STACK (%d)"):format(height)
		stackButton.BackgroundColor3 = Color3.fromRGB(80, 200, 100)
	else
		stackButton.Visible = false
	end
end

local function cookFraction()
	return (os.clock() - cookStart) / loadout.CookTime
end

local function cookedSeconds()
	return os.clock() - cookStart
end

local function currentPower()
	local v = ((os.clock() - chargeStart) * GameConfig.PowerChargeSpeed) % 2
	return v <= 1 and v or 2 - v -- bounces 0 -> 1 -> 0
end

local function shake(strength, duration)
	shakeStrength = strength
	shakeUntil = os.clock() + duration
end

-- Runs step(alpha) every frame from 0 to 1. Returns false if we left the station mid-way.
local function animate(duration, step)
	local mySession = session
	local start = os.clock()
	while true do
		if session ~= mySession then
			return false
		end
		local alpha = math.min((os.clock() - start) / duration, 1)
		step(alpha)
		if alpha >= 1 then
			return true
		end
		RunService.RenderStepped:Wait()
	end
end

-- Waits, but gives up (returns false) if we leave the station
local function pause(seconds)
	local mySession = session
	task.wait(seconds)
	return session == mySession
end

--------------------------------------------------------------------
-- PANCAKE VISUALS (body + a face on each side + mix-ins + toppings)
--------------------------------------------------------------------
local function makeDisk(name, thickness, diameter, parent)
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(thickness, diameter, diameter)
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Parent = parent
	return part
end

local function createPancake(offset, pancakeType, diameter, seed)
	local model = Instance.new("Model")
	model.Name = "MyPancake"
	local material = pancakeType.FaceMaterial or Enum.Material.SmoothPlastic
	local body = makeDisk("Body", THICK, diameter, model)
	local faceA = makeDisk("FaceA", 0.05, diameter - 0.15, model) -- starts on the bottom
	local faceB = makeDisk("FaceB", 0.05, diameter - 0.15, model) -- starts on top
	-- lighter, fluffier middle on each side
	local crownA = makeDisk("CrownA", 0.04, diameter * PancakeVisuals.CROWN_SCALE, model)
	local crownB = makeDisk("CrownB", 0.04, diameter * PancakeVisuals.CROWN_SCALE, model)
	for _, part in ipairs({ body, faceA, faceB, crownA, crownB }) do
		part.Color = pancakeType.Raw
		part.Material = material
	end
	if pancakeType.Special == "Golden" then
		faceA.Reflectance = 0.3
		faceB.Reflectance = 0.3
	end

	local bits = {}
	for _, info in ipairs(PancakeVisuals.GetBits(pancakeType, diameter, seed * 17 + math.random(1, 1000))) do
		local bit = PancakeVisuals.NewPart({
			Name = "Bit", Shape = info.Shape, Size = info.Size, Color = info.Color,
			Material = info.Material, CastShadow = false, Parent = model,
		})
		table.insert(bits, { Part = bit, Offset = info.Offset })
	end

	-- Golden glow when it's in the PERFECT zone
	local highlight = Instance.new("Highlight")
	highlight.FillColor = GOLD
	highlight.OutlineColor = Color3.fromRGB(255, 240, 150)
	highlight.FillTransparency = 1
	highlight.OutlineTransparency = 1
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = model

	-- Swirly trail while it's in the air
	local edgeA = Instance.new("Attachment")
	edgeA.Position = Vector3.new(0, diameter * 0.41, 0)
	edgeA.Parent = body
	local edgeB = Instance.new("Attachment")
	edgeB.Position = Vector3.new(0, -diameter * 0.41, 0)
	edgeB.Parent = body
	local trail = Instance.new("Trail")
	trail.Attachment0 = edgeA
	trail.Attachment1 = edgeB
	trail.Color = ColorSequence.new(GOLD, WHITE)
	trail.Transparency = NumberSequence.new(0.35, 1)
	trail.Lifetime = 0.25
	trail.LightEmission = 0.6
	trail.Enabled = false
	trail.Parent = body

	model.Parent = workspace
	local home = restCenter + rot:VectorToWorldSpace(offset)
	return {
		Model = model, Body = body, FaceA = faceA, FaceB = faceB, CrownA = crownA, CrownB = crownB, Bits = bits,
		Highlight = highlight, Trail = trail, Type = pancakeType, Seed = seed,
		Diameter = diameter, Home = home, End = home,
		CFrame = CFrame.new(home), Scale = 1, ToppingLift = 0,
	}
end

-- cf = pancake center; cf.UpVector points out of Face B
local function placePancake(pc, cf, scale)
	scale = scale or pc.Scale
	pc.CFrame = cf
	pc.Scale = scale
	local diameter = pc.Diameter * scale
	local faceDiameter = math.max(diameter - 0.15, 0.05)
	pc.Body.Size = Vector3.new(THICK, diameter, diameter)
	pc.FaceA.Size = Vector3.new(0.05, faceDiameter, faceDiameter)
	pc.FaceB.Size = pc.FaceA.Size
	pc.Body.CFrame = cf * FLAT
	pc.FaceB.CFrame = cf * CFrame.new(0, THICK / 2, 0) * FLAT
	pc.FaceA.CFrame = cf * CFrame.new(0, -THICK / 2, 0) * FLAT
	local crownDiameter = pc.Diameter * PancakeVisuals.CROWN_SCALE * scale
	pc.CrownA.Size = Vector3.new(0.04, crownDiameter, crownDiameter)
	pc.CrownB.Size = pc.CrownA.Size
	pc.CrownB.CFrame = cf * CFrame.new(0, THICK / 2 + 0.01, 0) * FLAT
	pc.CrownA.CFrame = cf * CFrame.new(0, -THICK / 2 - 0.01, 0) * FLAT
	for _, bit in ipairs(pc.Bits) do
		local o = bit.Offset
		bit.Part.CFrame = cf * CFrame.new(o.X * scale, o.Y, o.Z * scale) * o.Rotation
	end
	if pc.Toppings then
		-- toppings sit on whichever side is facing up after the flip
		pc.Toppings:PivotTo(cf * FLIPPED * CFrame.new(0, THICK / 2 + pc.ToppingLift, 0))
	end
end

local function clearPancakes()
	for _, pc in ipairs(pancakes) do
		pc.Model:Destroy()
	end
	pancakes = {}
end

local function panJerk()
	animate(0.25, function(a)
		local lift = math.sin(a * math.pi)
		pan:PivotTo(panHome * CFrame.new(0, 0.9 * lift, 0) * CFrame.Angles(-0.3 * lift, 0, 0))
	end)
	pan:PivotTo(panHome)
end

--------------------------------------------------------------------
-- ACTIONS
--------------------------------------------------------------------
local function pour()
	local mySession = session
	setState("Busy")
	local equipped = PourRemote:InvokeServer()
	if mySession ~= session then return end
	if not equipped then
		setState("Empty")
		return
	end

	loadout = GameConfig.GetLoadout(equipped)
	buildMeterZones(loadout.Zones)
	clearPancakes()
	for i, offset in ipairs(loadout.Size.Offsets) do
		table.insert(pancakes, createPancake(offset, loadout.Pancake, loadout.Size.Diameter, i))
	end

	task.delay(0.13, function() -- TSSSS the moment the batter hits the hot pan
		Effects.Play("PourSizzle", 0.95 + math.random() * 0.1)
	end)

	-- A stream of batter falls onto each spot, then the pancakes spread out
	local streams = {}
	local streamWidth = math.min(0.45, loadout.Size.Diameter * 0.15)
	for i, pc in ipairs(pancakes) do
		streams[i] = makeDisk("BatterStream", 1, streamWidth, workspace)
		streams[i].Color = loadout.Pancake.Raw
		streams[i].Material = loadout.Pancake.FaceMaterial or Enum.Material.SmoothPlastic
	end
	local streamTop = restCenter.Y + 6
	local spread = animate(0.45, function(a)
		local lower = streamTop - (streamTop - restCenter.Y) * math.min(a / 0.3, 1)
		local upper = streamTop - (streamTop - restCenter.Y) * math.clamp((a - 0.6) / 0.4, 0, 1)
		local length = upper - lower
		local grow = math.clamp((a - 0.2) / 0.8, 0, 1)
		for i, pc in ipairs(pancakes) do
			local stream = streams[i]
			stream.Transparency = length < 0.05 and 1 or 0
			stream.Size = Vector3.new(math.max(length, 0.05), streamWidth, streamWidth)
			stream.CFrame = CFrame.new(pc.Home.X, (upper + lower) / 2, pc.Home.Z) * FLAT
			placePancake(pc, CFrame.new(pc.Home) * rot, 0.15 + 0.85 * (1 - (1 - grow) ^ 3))
		end
	end)
	for _, stream in ipairs(streams) do
		stream:Destroy()
	end
	if not spread then return end

	cookStart = os.clock() - 0.45 -- the pour counted as cooking time
	setState("SideA")
end

local function startCharge()
	if cookedSeconds() < GameConfig.MinCookTime then
		showPopup("Let it cook first!", WHITE)
		return
	end
	chargeStart = os.clock()
	setState("Charging")
end

-- One popup that sums up how every pancake landed
local function flipSummary(qualities)
	local counts = { Perfect = 0, Good = 0, Sloppy = 0, Dropped = 0 }
	for _, quality in ipairs(qualities) do
		counts[quality] += 1
	end
	local total = #qualities
	if counts.Dropped == total then
		return FLIP_POPUPS.Dropped
	elseif counts.Dropped > 0 then
		return { counts.Dropped .. " DROPPED! 😬", Color3.fromRGB(255, 110, 70) }
	elseif total > 1 and counts.Perfect == total then
		return { "⭐ ALL PERFECT! ⭐", GOLD }
	end
	for _, quality in ipairs({ "Sloppy", "Good", "Perfect" }) do -- show the worst landing
		if counts[quality] > 0 then
			return FLIP_POPUPS[quality]
		end
	end
	return FLIP_POPUPS.Good
end

local function releaseFlip()
	local power = currentPower()
	local mySession = session
	sideAFraction = cookFraction()
	setState("Flipping")
	Effects.ClearBubbles()
	task.spawn(panJerk)
	shake(0.3, 0.25)

	local result = FlipRemote:InvokeServer(power)
	if mySession ~= session then return end
	if not result then
		setState("SideA")
		return
	end

	local trick = GameConfig.FlipTricks[result.TrickIndex]
	local qualities = result.Qualities

	local whoosh = Effects.Play("Whoosh", 0.9 + result.TrickIndex * 0.1)
	if result.TrickIndex == #GameConfig.FlipTricks then
		Effects.Play("Boom")
		shake(0.7, 0.45)
	end
	if result.TrickIndex > 1 then
		showPopup(trick.Label, TRICK_COLORS[result.TrickIndex])
	end
	if trick.SlowMo then
		Effects.Letterbox(true)
	end

	-- Where each pancake lands: back in the pan, or off to the side on the floor
	for i, pc in ipairs(pancakes) do
		pc.Quality = qualities[i]
		pc.Trail.Enabled = true
		pc.HeightScale = 0.92 + math.random() * 0.16
		pc.WobbleSign = (math.random() < 0.5) and -1 or 1
		if pc.Quality == "Dropped" then
			-- work it out in the kitchen's own directions, then turn it into world space
			local localHome = rot:VectorToObjectSpace(pc.Home - restCenter)
			local side = (localHome.X > 0.1) and 1 or (localHome.X < -0.1) and -1 or ((math.random() < 0.5) and -1 or 1)
			local localEnd = Vector3.new(localHome.X + side * (5 + math.random() * 2), 0, localHome.Z + 2 + math.random() * 2)
			local worldEnd = restCenter + rot:VectorToWorldSpace(localEnd)
			pc.End = Vector3.new(worldEnd.X, floorY + THICK / 2, worldEnd.Z)
		else
			pc.End = pc.Home
		end
	end

	local totalAngle = math.pi * trick.HalfTurns
	local finished = animate(trick.FlightTime, function(t)
		local p = t
		if trick.SlowMo then
			-- fast at the start/end, slow motion at the top of the flip
			p = t + 0.6 * math.sin(2 * math.pi * t) / (2 * math.pi)
		end
		for _, pc in ipairs(pancakes) do
			local pos = pc.Home:Lerp(pc.End, p) + Vector3.new(0, trick.Height * pc.HeightScale * 4 * p * (1 - p), 0)
			local wobble = math.sin(p * math.pi * 3) * 0.2 * pc.WobbleSign
			placePancake(pc, CFrame.new(pos) * rot * CFrame.Angles(totalAngle * p, 0, wobble))
		end
	end)

	if whoosh then
		whoosh:Stop()
	end
	Effects.Letterbox(false)
	if not finished then return end

	-- Split into the ones that landed and the ones on the floor
	local survivors, dropped = {}, {}
	for _, pc in ipairs(pancakes) do
		pc.Trail.Enabled = false
		table.insert(pc.Quality == "Dropped" and dropped or survivors, pc)
	end
	pancakes = survivors

	if #dropped > 0 then
		for _, pc in ipairs(dropped) do
			Effects.Splat(pc.End)
			placePancake(pc, CFrame.new(pc.End) * rot * FLIPPED, 1.3) -- SPLAT
			task.delay(3, function()
				pc.Model:Destroy()
			end)
		end
		Effects.Play("Splat")
		Effects.Play("Sad")
		Effects.Flash(Color3.fromRGB(255, 60, 60), 0.35)
		shake(0.6, 0.35)
	end

	local summary = flipSummary(qualities)
	showPopup(summary[1], summary[2])
	Effects.SetCombo(result.Combo)
	if result.Toppled then
		-- the messy flip knocked the stack over!
		Effects.Play("Sad", 0.7)
		Effects.Play("Boom", 1.2, 0.5)
		Effects.Flash(Color3.fromRGB(255, 60, 60), 0.4)
		shake(0.8, 0.5)
		task.delay(0.8, function()
			showPopup(("😱 STACK TOPPLED! Lost %d"):format(result.Lost), Color3.fromRGB(255, 80, 80))
		end)
	end

	if #survivors == 0 then
		setState("Empty")
		return
	end

	-- Landed in the pan: plop, little squash, then cook side B
	Effects.Play("Land")
	if not animate(0.15, function(a)
		for _, pc in ipairs(survivors) do
			placePancake(pc, CFrame.new(pc.Home) * rot * FLIPPED, 1 + 0.12 * math.sin(a * math.pi))
		end
	end) then return end

	local perfects = 0
	for _, quality in ipairs(qualities) do
		if quality == "Perfect" then
			perfects += 1
		end
	end
	if perfects == #qualities then
		Effects.Play("Ding", 1 + math.min(result.Combo, GameConfig.MaxCombo) * 0.07)
		Effects.Sparkle(45)
		Effects.Ring()
		Effects.Flash(GOLD, 0.3)
		fovPunch = 1
	elseif perfects > 0 or #dropped == 0 then
		Effects.Play("Ding", 0.8, 0.5)
		Effects.Sparkle(12)
	end

	cookStart = os.clock() - 0.15
	setState("SideB")
end

local function servePopup(sideA, sideB)
	if sideA == "Perfect" and sideB == "Perfect" then
		return "⭐ DOUBLE PERFECT! ⭐", GOLD
	elseif sideA == "Burnt" or sideB == "Burnt" then
		return "Extra crispy... 🔥", Color3.fromRGB(255, 120, 60)
	elseif sideA == "Raw" or sideB == "Raw" then
		return "A bit gooey... 🥴", Color3.fromRGB(245, 225, 180)
	end
	return "Tasty! 😋", Color3.fromRGB(130, 230, 100)
end

-- action = "Serve" (sell the pan's pancakes + the whole stack) or "Stack" (add the pan's pancakes to the stack)
local function serve(action)
	action = action or "Serve"
	local fromPan = state == "SideB"
	if fromPan and cookedSeconds() < GameConfig.MinCookTime then
		showPopup("Cook the other side!", WHITE)
		return
	end
	if not fromPan and (state ~= "Empty" or stackHeight() == 0 or action == "Stack") then
		return
	end
	local mySession = session
	local heightBefore = stackHeight()
	local plateBase = (stationCFrame * CFrame.new(GameConfig.StackPlateOffset + Vector3.new(0, 0.1 + THICK / 2, 0))).Position
	setState("Busy")

	-- Hold the counter still so the flying butter can fill it up
	local myHold = nil
	if action == "Serve" then
		holdButter = true
		holdToken += 1
		myHold = holdToken
		task.delay(5, function()
			if holdToken == myHold then
				releaseButterHold()
			end
		end)
	end
	local function giveUp()
		if myHold then
			releaseButterHold()
		end
	end

	local result = ServeRemote:InvokeServer(action)
	if mySession ~= session or not result then
		giveUp()
		if mySession == session then
			setState(fromPan and "SideB" or "Empty")
		end
		return
	end
	if result.Full then
		showPopup("Your stack is full! Serve it first 🍽️", Color3.fromRGB(255, 160, 70))
		setState("SideB")
		return
	end

	if fromPan then
		-- Toppings drop onto every pancake
		if #loadout.Toppings > 0 then
			for _, pc in ipairs(pancakes) do
				pc.Toppings = PancakeVisuals.BuildToppings(loadout.Toppings, pc.Diameter, pc.Seed)
				pc.Toppings.Parent = pc.Model
				pc.ToppingLift = 3
				placePancake(pc, pc.CFrame)
			end
			local landed = animate(0.3, function(a)
				for _, pc in ipairs(pancakes) do
					pc.ToppingLift = 3 * (1 - a * a)
					placePancake(pc, pc.CFrame)
				end
			end)
			if not landed then
				giveUp()
				return
			end
			Effects.Play("Land", 1.6, 0.5)
			Effects.Sparkle(20)
			if not pause(0.35) then
				giveUp()
				return
			end
		end

		-- Toss the pancakes onto your stack plate, one after another
		local starts = {}
		for i, pc in ipairs(pancakes) do
			starts[i] = pc.CFrame.Position
		end
		local stagger = 0.06
		local tossTime = 0.45
		local total = tossTime + stagger * (#pancakes - 1)
		local finished = animate(total, function(a)
			local now = a * total
			for i, pc in ipairs(pancakes) do
				local t = math.clamp((now - (i - 1) * stagger) / tossTime, 0, 1)
				local e = t * t * (3 - 2 * t)
				local target = plateBase + Vector3.new(0, (heightBefore + i - 1) * STACK_STEP, 0)
				local pos = starts[i]:Lerp(target, e) + Vector3.new(0, 4 * math.sin(t * math.pi), 0)
				local shrink = GameConfig.StackPancakeSize / pc.Diameter
				placePancake(pc, CFrame.new(pos) * rot * FLIPPED, 1 + (shrink - 1) * e)
			end
		end)
		if not finished then
			giveUp()
			return
		end
		clearPancakes()
		Effects.Play("Land", 1.4, 0.6)
	end

	if result.ComboBroken then
		Effects.SetCombo(result.Combo)
	end

	if action == "Stack" then
		showPopup(("🥞 STACKED! %d tall"):format(result.StackHeight), Color3.fromRGB(120, 190, 255))
		floatText(("Stack bonus x%.1f"):format(result.StackMultiplier), Color3.fromRGB(150, 210, 255), 3.2)
		stackScale.Scale = 1.2
		TweenService:Create(stackScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		setState("Empty")
		return
	end

	-- SERVED!
	if result.OrderFilled then
		showPopup("✅ ORDER COMPLETE! x" .. GameConfig.Orders.RewardMultiplier, Color3.fromRGB(120, 230, 120))
		Effects.Confetti(110)
		Effects.Play("Ding", 1.4)
		Effects.Play("Boom", 1.8, 0.4)
	elseif result.SideA then
		local text, color = servePopup(result.SideA, result.SideB)
		showPopup(text, color)
		if result.SideA == "Perfect" and result.SideB == "Perfect" then
			Effects.Confetti(80)
			Effects.Play("Ding", 1.5)
		end
	else
		showPopup(("🍽️ Served a %d-stack!"):format(result.Served), GOLD)
	end

	floatText("+" .. GameConfig.FormatNumber(result.Butter) .. " 🧈", Color3.fromRGB(255, 225, 80))
	local bonuses = {}
	if result.Served > 1 then
		table.insert(bonuses, "🥞" .. result.Served)
	end
	if result.StackMultiplier > 1.001 then
		table.insert(bonuses, ("stack x%.1f"):format(result.StackMultiplier))
	end
	if fromPan and result.ComboMultiplier and result.ComboMultiplier >= 2 then
		table.insert(bonuses, "combo x" .. result.ComboMultiplier)
	end
	if result.RushMultiplier > 1 then
		table.insert(bonuses, "🔥 rush x" .. result.RushMultiplier)
	end
	if result.OrderFilled then
		table.insert(bonuses, "📋 order x" .. GameConfig.Orders.RewardMultiplier)
	end
	if #bonuses > 0 then
		floatText(table.concat(bonuses, "  "), Color3.fromRGB(255, 150, 60), 3.2)
	end

	-- Butter flies into the counter (from the stack plate if you served a stack)
	local coins = math.clamp(math.floor(result.Butter / 3), 4, 14)
	local from = shownButter
	local to = from + result.Butter
	local source = (result.FromStack > 0 or not fromPan) and plateBase or restCenter
	Effects.FlyButter(source + Vector3.new(0, 1, 0), butterFrame, coins, function(i)
		if holdToken ~= myHold then return end
		setButterText(math.floor(from + (to - from) * i / coins), true)
		Effects.Play("Coin", 1 + i * 0.06, 0.5)
		if i == coins then
			releaseButterHold()
		end
	end)

	setState("Empty")
end

-- The STACK button / F key / X on a controller
local function onStackPress()
	if state == "SideB" then
		serve("Stack")
	elseif state == "Empty" and stackHeight() > 0 then
		serve("Serve")
	end
end

--------------------------------------------------------------------
-- INPUT (mouse, touch, keyboard, gamepad)
--------------------------------------------------------------------
local function onPress()
	if state == "Empty" then
		pour()
	elseif state == "SideA" then
		startCharge()
	elseif state == "SideB" then
		serve("Serve")
	end
end

local function onRelease()
	if state == "Charging" then
		releaseFlip()
	end
end

local function pressVisual(down)
	TweenService:Create(actionScale, TweenInfo.new(0.08), { Scale = down and 0.92 or 1 }):Play()
end

actionButton.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		pressVisual(true)
		task.spawn(onPress)
	end
end)

-- Release anywhere (so sliding your finger off the button still flips)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		pressVisual(false)
		task.spawn(onRelease)
	end
end)

stackButton.Activated:Connect(function()
	task.spawn(onStackPress)
end)

local function onStackKey(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		task.spawn(onStackPress)
	end
	return Enum.ContextActionResult.Sink
end

local function onActionKey(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		pressVisual(true)
		task.spawn(onPress)
	elseif inputState == Enum.UserInputState.End then
		pressVisual(false)
		task.spawn(onRelease)
	end
	return Enum.ContextActionResult.Sink -- stops Space / A from making you jump
end

--------------------------------------------------------------------
-- CAMERA
--------------------------------------------------------------------
local function updateCamera(dt)
	local lift = 0
	if state == "Flipping" then
		for _, pc in ipairs(pancakes) do
			lift = math.max(lift, pc.CFrame.Position.Y - restCenter.Y)
		end
	end
	local desiredLook = restCenter + Vector3.new(0, 2.5 + lift * 0.6, 0)
	local desiredPosition = restCenter + rot:VectorToWorldSpace(CAMERA_OFFSET + Vector3.new(0, lift * 0.3, lift * 0.3))
	camLook = camLook:Lerp(desiredLook, math.min(dt * 8, 1))
	camPosition = camPosition:Lerp(desiredPosition, math.min(dt * 6, 1)) -- smooth glide in when you start cooking

	local shakeOffset = Vector3.zero
	if os.clock() < shakeUntil then
		shakeOffset = Vector3.new(math.random() - 0.5, math.random() - 0.5, 0) * shakeStrength
	end
	camera.CFrame = CFrame.lookAt(camPosition + shakeOffset, camLook)

	-- quick zoom "punch" on perfect landings
	fovPunch = math.max(fovPunch - dt * 3, 0)
	camera.FieldOfView = BASE_FOV - 9 * math.sin((1 - fovPunch) * math.pi) * math.min(fovPunch * 4, 1)
end

--------------------------------------------------------------------
-- ENTER / LEAVE THE STATION
--------------------------------------------------------------------
local savedWalkSpeed, savedJumpPower, savedJumpHeight

local function freezeCharacter(freeze)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	if freeze then
		savedWalkSpeed, savedJumpPower, savedJumpHeight = humanoid.WalkSpeed, humanoid.JumpPower, humanoid.JumpHeight
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		humanoid.JumpHeight = 0
	elseif savedWalkSpeed then
		humanoid.WalkSpeed = savedWalkSpeed
		humanoid.JumpPower = savedJumpPower
		humanoid.JumpHeight = savedJumpHeight
	end
end

local leaveStation -- defined below

local function enterStation(panModel, stationIndex)
	if state ~= "Away" then return end
	session += 1
	stationIndex = stationIndex or 1
	stationModel = stationsFolder:WaitForChild("Station" .. stationIndex)
	stationCFrame = GameConfig.GetStationCFrame(stationIndex)
	setPan(panModel)
	fitEffectsToPan()
	freezeCharacter(true)

	-- start the camera where it is now, then glide to the stove
	camPosition = camera.CFrame.Position
	camLook = camera.CFrame.Position + camera.CFrame.LookVector * 20
	fovPunch = 0
	camera.CameraType = Enum.CameraType.Scriptable
	RunService:BindToRenderStep("PancakeCamera", Enum.RenderPriority.Camera.Value + 1, updateCamera)

	ContextActionService:BindActionAtPriority("PancakeAction", onActionKey, false,
		Enum.ContextActionPriority.High.Value, Enum.KeyCode.Space, Enum.KeyCode.ButtonA, Enum.KeyCode.ButtonR2)
	ContextActionService:BindActionAtPriority("PancakeLeave", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			leaveStation(true)
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.ButtonB, Enum.KeyCode.Backspace)
	ContextActionService:BindActionAtPriority("PancakeStack", onStackKey, false,
		Enum.ContextActionPriority.High.Value, Enum.KeyCode.F, Enum.KeyCode.ButtonX)

	actionButton.Visible = true
	leaveButton.Visible = true
	setState("Empty")
end

leaveStation = function(tellServer)
	if state == "Away" then return end
	session += 1
	clearPancakes()
	if pan and pan.Parent then
		pan:PivotTo(panHome)
	end
	Effects.Reset()

	RunService:UnbindFromRenderStep("PancakeCamera")
	ContextActionService:UnbindAction("PancakeAction")
	ContextActionService:UnbindAction("PancakeLeave")
	ContextActionService:UnbindAction("PancakeStack")
	stackButton.Visible = false
	orderCard.Visible = false

	camera.CameraType = Enum.CameraType.Custom
	camera.FieldOfView = BASE_FOV
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		camera.CameraSubject = humanoid
	end
	freezeCharacter(false)

	actionButton.Visible = false
	leaveButton.Visible = false
	setState("Away")
	if tellServer then
		LeaveRemote:FireServer()
	end
end

leaveButton.Activated:Connect(function()
	leaveStation(true)
end)

StationEvent.OnClientEvent:Connect(function(message, panModel, stationIndex)
	if message == "Enter" then
		enterStation(panModel, stationIndex)
	elseif message == "Leave" then
		leaveStation(false)
	elseif message == "PanChanged" then
		setPan(panModel)
		fitEffectsToPan()
		Effects.Sparkle(30)
	elseif message == "Message" then
		showPopup(panModel, WHITE) -- (for messages the second value is the text)
	end
end)

--------------------------------------------------------------------
-- YOUR RESTAURANT: a floating marker over it and a glowing line from you to its door
--------------------------------------------------------------------
local homeMarker = create("BillboardGui", {
	Name = "YourRestaurant",
	Size = UDim2.fromOffset(260, 90),
	StudsOffsetWorldSpace = Vector3.new(0, 30, 0),
	AlwaysOnTop = true,
	ResetOnSpawn = false,
	Enabled = false,
	Parent = playerGui,
})
local homeLabel = create("TextLabel", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Font = FONT,
	TextScaled = true,
	TextColor3 = GOLD,
	TextStrokeTransparency = 0,
	Text = "⭐ YOUR RESTAURANT ⭐\n⬇",
	Parent = homeMarker,
})

local guideFolder = Instance.new("Folder")
guideFolder.Name = "RestaurantGuide"
guideFolder.Parent = workspace
local doorAnchor = Instance.new("Part")
doorAnchor.Name = "DoorAnchor"
doorAnchor.Size = Vector3.new(0.2, 0.2, 0.2)
doorAnchor.Transparency = 1
doorAnchor.Anchored = true
doorAnchor.CanCollide = false
doorAnchor.CanQuery = false
doorAnchor.CanTouch = false
doorAnchor.Parent = guideFolder
local doorAttachment = Instance.new("Attachment")
doorAttachment.Parent = doorAnchor
local guide = Instance.new("Beam")
guide.Attachment1 = doorAttachment
guide.Color = ColorSequence.new(GOLD)
guide.Transparency = NumberSequence.new(0.35)
guide.Width0 = 0.6
guide.Width1 = 0.6
guide.FaceCamera = true
guide.Segments = 1
guide.Enabled = false
guide.Parent = doorAnchor

task.spawn(function()
	while true do
		task.wait(0.5)
		local mine = nil
		for _, station in ipairs(stationsFolder:GetChildren()) do
			if station:GetAttribute("OwnerUserId") == player.UserId then
				mine = station
			end
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if mine and root then
			local index = mine:GetAttribute("Index") or 1
			local stationCF = GameConfig.GetStationCFrame(index)
			local door = (stationCF * CFrame.new(GameConfig.RestaurantDoor)).Position + Vector3.new(0, 1, 0)
			doorAnchor.Position = door
			homeMarker.Adornee = doorAnchor
			homeLabel.Text = "⭐ YOUR RESTAURANT ⭐\n⬇"
			local away = state == "Away"
			local far = (root.Position - door).Magnitude > 25
			homeMarker.Enabled = away
			-- the guide line goes from your feet to the front door
			local feet = root:FindFirstChild("GuideAttachment") or Instance.new("Attachment")
			feet.Name = "GuideAttachment"
			feet.Position = Vector3.new(0, -2.5, 0)
			feet.Parent = root
			guide.Attachment0 = feet
			guide.Enabled = away and far
		else
			homeMarker.Enabled = false
			guide.Enabled = false
		end
	end
end)

player.CharacterAdded:Connect(function()
	leaveStation(false)
end)

--------------------------------------------------------------------
-- EVERY FRAME: cook meter, pancake colors, sizzle, bubbles, glow, power needle
--------------------------------------------------------------------
RunService.RenderStepped:Connect(function()
	Effects.Update()
	if state == "Away" then return end

	refreshStackButton()

	-- your customer's order
	local order = stationModel:GetAttribute("OrderText")
	local deadline = stationModel:GetAttribute("OrderDeadline")
	if order and deadline then
		if not orderCard.Visible then
			orderCard.Visible = true
			orderScale.Scale = 0.3
			TweenService:Create(orderScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end
		orderText.Text = order
		local patience = workspace:GetAttribute("RushHour") and GameConfig.Orders.RushPatience or GameConfig.Orders.Patience
		local fraction = math.clamp((deadline - workspace:GetServerTimeNow()) / patience, 0, 1)
		orderBar.Size = UDim2.fromScale(fraction, 1)
		orderBar.BackgroundColor3 = Color3.fromRGB(230, 70, 60):Lerp(Color3.fromRGB(90, 200, 100), fraction)
	else
		orderCard.Visible = false
	end

	-- your stack sways more the taller it gets
	local stack = stationModel:FindFirstChild("Stack")
	local base = stack and stack:GetAttribute("Base")
	if base then
		local amount = math.min(stackHeight() * 0.006, 0.09)
		local now = os.clock()
		stack:PivotTo(base * CFrame.Angles(math.sin(now * 2.3) * amount, 0, math.cos(now * 1.7) * amount))
	end

	local cooking = state == "SideA" or state == "Charging" or state == "SideB"
	if cooking then
		local fraction = cookFraction()
		local t = os.clock()
		meterPointer.Position = UDim2.fromScale(math.clamp(fraction, 0, 1), 0.5)

		local zone = GameConfig.GetCookZone(fraction, loadout.Zones)
		local info = ZONE_TEXT[zone]
		local perfect = zone == "Perfect"
		meterLabel.Text = info[1]
		meterLabel.TextColor3 = info[2]
		meterLabelScale.Scale = perfect and (1 + 0.08 * math.sin(t * 14)) or 1
		meterStroke.Color = perfect and GOLD or DARK

		-- sizzle gets louder and the pan glows brighter as it nears PERFECT
		local closeness = 1 - math.clamp(math.abs(fraction - GameConfig.PerfectCenter) / 0.5, 0, 1)
		Effects.SetSizzle(0.4 + 0.6 * closeness)
		Effects.SetSteam(true)
		Effects.SetSmoke(fraction >= 0.85)
		Effects.SetPanLight(0.2 + 0.5 * closeness)

		for i, pc in ipairs(pancakes) do
			local pancakeType = pc.Type
			if state == "SideB" then
				pc.FaceB.Color = GameConfig.GetCookColor(fraction, pancakeType)
				pc.Body.Color = GameConfig.GetCookColor(math.max(sideAFraction, fraction) * 0.8, pancakeType)
			else
				pc.FaceA.Color = GameConfig.GetCookColor(fraction, pancakeType)
				pc.FaceB.Color = GameConfig.GetCookColor(fraction * 0.3, pancakeType)
				pc.Body.Color = GameConfig.GetCookColor(fraction * 0.8, pancakeType)
			end
			pc.CrownA.Color = PancakeVisuals.CrownColor(pc.FaceA.Color)
			pc.CrownB.Color = PancakeVisuals.CrownColor(pc.FaceB.Color)
			if pancakeType.Special == "Rainbow" then
				pc.Body.Color = Color3.fromHSV((t * 0.25 + i * 0.13) % 1, 0.55, 1)
			end
			pc.Highlight.OutlineTransparency = perfect and 0 or 1
			pc.Highlight.FillTransparency = perfect and (0.75 + 0.1 * math.sin(t * 12)) or 1
		end

		-- bubbles pop on the raw tops, faster as they get closer to ready
		if state ~= "SideB" and #pancakes > 0 and fraction > 0.2 and fraction < 0.9 and t >= nextBubble then
			local pc = pancakes[math.random(#pancakes)]
			local angle = math.random() * math.pi * 2
			local radius = math.sqrt(math.random()) * math.max(pc.Diameter / 2 - 0.35, 0.2)
			Effects.SpawnBubble(pc.Home + Vector3.new(math.cos(angle) * radius, THICK / 2 + 0.02, math.sin(angle) * radius))
			nextBubble = t + (0.08 + 0.3 * (1 - fraction)) / math.sqrt(#pancakes)
		end

		local ready = cookedSeconds() >= GameConfig.MinCookTime
		actionButton.BackgroundTransparency = (ready or state == "Charging") and 0 or 0.45
		actionStroke.Color = perfect and GOLD or DARK
		actionStroke.Thickness = perfect and (5 + 2 * math.sin(t * 12)) or 4
	else
		Effects.SetSizzle(0)
		Effects.SetSteam(false)
		Effects.SetSmoke(false)
		Effects.SetPanLight(0)
		actionButton.BackgroundTransparency = (state == "Empty") and 0 or 0.45
		actionStroke.Color = DARK
		actionStroke.Thickness = 4
	end

	if state == "Charging" then
		needle.Position = UDim2.fromScale(currentPower(), 0.5)
	end
end)