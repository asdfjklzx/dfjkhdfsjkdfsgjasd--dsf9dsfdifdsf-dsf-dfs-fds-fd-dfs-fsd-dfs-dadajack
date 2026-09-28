-- ShopController (LocalScript in StarterPlayer > StarterPlayerScripts)
-- The shop: a big animated panel with 4 tabs (Pans, Sizes, Pancakes, Toppings).
--   * Cards are built from the config modules, colored by rarity, with spinning 3D previews
--   * A details panel shows a big preview, stat bars and a comparison with what you have equipped
--   * Buying something plays an unlock celebration
-- The server does the real buying/equipping; this script just shows it and asks.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = workspace.CurrentCamera

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local PanConfig = require(ReplicatedStorage:WaitForChild("PanConfig"))
local SizeConfig = require(ReplicatedStorage:WaitForChild("SizeConfig"))
local PancakeConfig = require(ReplicatedStorage:WaitForChild("PancakeConfig"))
local ToppingConfig = require(ReplicatedStorage:WaitForChild("ToppingConfig"))
local PancakeVisuals = require(ReplicatedStorage:WaitForChild("PancakeVisuals"))
local Effects = require(script.Parent:WaitForChild("Effects"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ShopRemote = Remotes:WaitForChild("Shop")
local GetDataRemote = Remotes:WaitForChild("GetData")
local DataEvent = Remotes:WaitForChild("DataUpdate")
local OpenShopEvent = Remotes:WaitForChild("OpenShop")

local FONT = Enum.Font.FredokaOne
local WHITE = Color3.new(1, 1, 1)
local DARK = Color3.fromRGB(60, 35, 20)
local CREAM = Color3.fromRGB(255, 246, 228)
local GOLD = Color3.fromRGB(255, 200, 50)
local GREEN = Color3.fromRGB(80, 200, 100)
local RED = Color3.fromRGB(230, 75, 75)
local BLUE = Color3.fromRGB(80, 160, 255)
local GRAY = Color3.fromRGB(150, 150, 150)
local BROWN_TEXT = Color3.fromRGB(125, 90, 60)
local THICK = PancakeVisuals.THICKNESS
local PANEL_SIZE = Vector2.new(1000, 580)

local CATEGORIES = {
	{ Key = "Pans", Title = "🍳 PANS", Config = PanConfig, Color = Color3.fromRGB(255, 140, 60), Unlock = "NEW PAN UNLOCKED!",
		Info = "Better pans cook faster, widen the ⭐ zone and multiply your Butter." },
	{ Key = "Pancakes", Title = "🥞 PANCAKES", Config = PancakeConfig, Color = Color3.fromRGB(240, 90, 150), Unlock = "NEW PANCAKE UNLOCKED!",
		Info = "Fancier pancakes are worth way more, but cook slower with a smaller ⭐ zone." },
	{ Key = "Toppings", Title = "🍓 TOPPINGS", Config = ToppingConfig, Color = Color3.fromRGB(110, 195, 85), Unlock = "NEW TOPPING UNLOCKED!",
		Info = "" }, -- filled in with your topping slots
}
local CATEGORY_BY_KEY = {}
for _, category in ipairs(CATEGORIES) do
	CATEGORY_BY_KEY[category.Key] = category
end
local EQUIP_SLOT = { Pans = "Pan", Pancakes = "Pancake" }

-- Stats shown as bars in the details panel. LowerIsBetter flips the bar and the ▲/▼ comparison.
local STAT_DEFS = {
	Pans = {
		{ Label = "🧈 Butter", Get = function(item) return item.Multiplier end, Format = function(v) return ("x%g"):format(v) end },
		{ Label = "⚡ Speed", Get = function(item) return item.CookSpeed end, Format = function(v) return ("x%g"):format(v) end },
		{ Label = "⭐ Zone", Get = function(item) return item.PerfectBonus * 200 end, Format = function(v) return ("+%d%%"):format(math.floor(v + 0.5)) end },
	},
	Sizes = {
		{ Label = "🥞 Per flip", Get = function(item) return item.Count end, Format = function(v) return tostring(v) end },
		{ Label = "🧈 Value", Get = function(item) return item.Count * (item.ValueMultiplier or 1) end, Format = function(v) return ("x%g"):format(v) end },
		{ Label = "🎯 Control", Get = function(item) return (item.FlipTolerance or 1) * 100 end, Format = function(v) return ("%d%%"):format(math.floor(v + 0.5)) end },
	},
	Pancakes = {
		{ Label = "🧈 Value", Get = function(item) return item.BaseValue end, Format = function(v) return GameConfig.FormatNumber(v) end },
		{ Label = "⏱ Cook time", Get = function(item) return item.CookTime end, Format = function(v) return ("%gs"):format(v) end, LowerIsBetter = true },
		{ Label = "⭐ Zone", Get = function(item) return (GameConfig.PerfectHalfWidth - item.Difficulty) * 200 end, Format = function(v) return ("%.1f%%"):format(v) end },
	},
	Toppings = {
		{ Label = "🧈 Bonus", Get = function(item) return item.Bonus * 100 end, Format = function(v) return ("+%d%%"):format(math.floor(v + 0.5)) end },
	},
}

local data = nil          -- snapshot from the server: Butter, TotalButter, Owned, Equipped, Slots
local currentTab = "Pans"
local selected = nil      -- the item shown in the details panel
local isOpen = false
local cards = {}          -- the cards on the current tab
local spinners = {}       -- 3D previews that slowly rotate

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
	return create("UIStroke", { Thickness = thickness or 3, Color = color or DARK, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

local function textStroke(thickness)
	return create("UIStroke", { Thickness = thickness or 2, Color = DARK })
end

local function padding(top, bottom)
	return create("UIPadding", { PaddingTop = UDim.new(0, top or 6), PaddingBottom = UDim.new(0, bottom or top or 6) })
end

local function fmt(n)
	return GameConfig.FormatNumber(n)
end

local function hoverGrow(button)
	local uiScale = create("UIScale", { Parent = button })
	button.MouseEnter:Connect(function()
		TweenService:Create(uiScale, TweenInfo.new(0.12), { Scale = 1.05 }):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(uiScale, TweenInfo.new(0.12), { Scale = 1 }):Play()
	end)
	return uiScale
end

local function rainbow(t, offset)
	return Color3.fromHSV(((t or os.clock()) * 0.35 + (offset or 0)) % 1, 0.7, 1)
end

--------------------------------------------------------------------
-- LAYOUT
--------------------------------------------------------------------
local gui = create("ScreenGui", {
	Name = "ShopGui",
	ResetOnSpawn = false,
	DisplayOrder = 2,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = playerGui,
})

-- The SHOP button on the left side of the screen
local openButton = create("TextButton", {
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 16, 0.5, 0),
	Size = UDim2.fromOffset(92, 92),
	BackgroundColor3 = Color3.fromRGB(255, 170, 50),
	AutoButtonColor = false,
	Font = FONT,
	TextScaled = true,
	TextColor3 = WHITE,
	Text = "🛒\nSHOP",
	Parent = gui,
}, { corner(22), border(4, DARK), create("UIPadding", {
	PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8),
}), textStroke(2), create("UIGradient", { Rotation = 90, Color = ColorSequence.new(WHITE, Color3.fromRGB(255, 200, 150)) }) })
-- The button's size is driven by one loop (below) so it always settles back to full size
local openScale = create("UIScale", { Parent = openButton })
create("UIAspectRatioConstraint", { AspectRatio = 1, Parent = openButton })
local openHovered = false
openButton.MouseEnter:Connect(function()
	openHovered = true
end)
openButton.MouseLeave:Connect(function()
	openHovered = false
end)

local badge = create("TextLabel", { -- red "!" when you can afford something new
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(1, -4, 0, 4),
	Size = UDim2.fromOffset(30, 30),
	BackgroundColor3 = RED,
	Font = FONT,
	TextScaled = true,
	TextColor3 = WHITE,
	Text = "!",
	Visible = false,
	ZIndex = 3,
	Parent = openButton,
}, { corner(15), border(2, WHITE) })

-- Soft blur behind the shop
local blur = Instance.new("BlurEffect")
blur.Size = 0
blur.Parent = camera

-- Holder is scaled to fit the screen; the panel inside pops in and out
local holder = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(PANEL_SIZE.X, PANEL_SIZE.Y),
	BackgroundTransparency = 1,
	Visible = false,
	Parent = gui,
})
local fitScale = create("UIScale", { Parent = holder })

local panel = create("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = CREAM,
	Parent = holder,
}, { corner(24), border(5, DARK), create("UIGradient", { Rotation = 90, Color = ColorSequence.new(WHITE, Color3.fromRGB(255, 232, 200)) }) })
local panelScale = create("UIScale", { Parent = panel })

-- Header
local header = create("Frame", {
	Size = UDim2.new(1, 0, 0, 66),
	BackgroundColor3 = Color3.fromRGB(255, 185, 65),
	Parent = panel,
}, { corner(24), create("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(255, 215, 110), Color3.fromRGB(255, 160, 50)) }) })
create("Frame", { -- squares off the header's bottom corners
	Position = UDim2.new(0, 0, 1, -24),
	Size = UDim2.new(1, 0, 0, 24),
	BackgroundColor3 = Color3.fromRGB(255, 160, 50),
	BorderSizePixel = 0,
	Parent = header,
})
create("TextLabel", {
	Position = UDim2.fromOffset(22, 8),
	Size = UDim2.new(0, 400, 0, 50),
	BackgroundTransparency = 1,
	Font = FONT,
	TextScaled = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = WHITE,
	Text = "🥞 PANCAKE SHOP",
	ZIndex = 2,
	Parent = header,
}, { textStroke(3) })

local shopButter = create("TextLabel", {
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -80, 0.5, 0),
	Size = UDim2.fromOffset(200, 44),
	BackgroundColor3 = Color3.fromRGB(255, 225, 100),
	Font = FONT,
	TextScaled = true,
	TextColor3 = Color3.fromRGB(110, 60, 10),
	Text = "🧈 0",
	ZIndex = 2,
	Parent = header,
}, { corner(14), border(3, Color3.fromRGB(150, 100, 20)), padding(6) })

local closeButton = create("TextButton", {
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -16, 0.5, 0),
	Size = UDim2.fromOffset(48, 48),
	BackgroundColor3 = RED,
	Font = FONT,
	TextScaled = true,
	TextColor3 = WHITE,
	Text = "✕",
	ZIndex = 2,
	Parent = header,
}, { corner(14), border(3, DARK) })
hoverGrow(closeButton)

-- Tabs
local tabBar = create("Frame", {
	Position = UDim2.fromOffset(16, 78),
	Size = UDim2.new(0, 624, 0, 48),
	BackgroundTransparency = 1,
	Parent = panel,
}, { create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8) }) })

-- Info line + collection progress
local infoLabel = create("TextLabel", {
	Position = UDim2.fromOffset(20, 132),
	Size = UDim2.fromOffset(616, 22),
	BackgroundTransparency = 1,
	Font = FONT,
	TextScaled = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = BROWN_TEXT,
	Text = "",
	Parent = panel,
})
local progressBack = create("Frame", {
	Position = UDim2.fromOffset(20, 160),
	Size = UDim2.fromOffset(470, 16),
	BackgroundColor3 = Color3.fromRGB(235, 215, 185),
	Parent = panel,
}, { corner(8), border(2, Color3.fromRGB(200, 160, 120)) })
local progressFill = create("Frame", {
	Size = UDim2.fromScale(0, 1),
	BackgroundColor3 = GREEN,
	Parent = progressBack,
}, { corner(8) })
local progressLabel = create("TextLabel", {
	Position = UDim2.fromOffset(500, 157),
	Size = UDim2.fromOffset(136, 22),
	BackgroundTransparency = 1,
	Font = FONT,
	TextScaled = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = BROWN_TEXT,
	Text = "",
	Parent = panel,
})

local grid = create("ScrollingFrame", {
	Position = UDim2.fromOffset(16, 186),
	Size = UDim2.new(0, 624, 1, -200),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 8,
	ScrollBarImageColor3 = Color3.fromRGB(200, 150, 100),
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollingDirection = Enum.ScrollingDirection.Y,
	Parent = panel,
}, {
	create("UIGridLayout", { CellSize = UDim2.fromOffset(190, 240), CellPadding = UDim2.fromOffset(12, 12), SortOrder = Enum.SortOrder.LayoutOrder }),
	create("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), PaddingBottom = UDim.new(0, 10) }),
})

-- Details panel (right side)
local details = create("Frame", {
	Position = UDim2.fromOffset(652, 78),
	Size = UDim2.new(0, 332, 1, -94),
	BackgroundColor3 = WHITE,
	Parent = panel,
}, { corner(18) })
local detailsStroke = border(4, Color3.fromRGB(215, 175, 130))
detailsStroke.Parent = details
local detailsGradient = create("UIGradient", { Rotation = 90, Parent = details })

local detailViewport = create("ViewportFrame", {
	Position = UDim2.fromOffset(12, 12),
	Size = UDim2.new(1, -24, 0, 190),
	BackgroundColor3 = Color3.fromRGB(255, 238, 205),
	Ambient = Color3.fromRGB(190, 190, 190),
	LightColor = WHITE,
	LightDirection = Vector3.new(-1, -2, -1),
	Parent = details,
}, { corner(14) })
local detailRibbon = create("TextLabel", {
	Position = UDim2.fromOffset(20, 20),
	Size = UDim2.fromOffset(110, 24),
	BackgroundColor3 = GRAY,
	Font = FONT,
	TextScaled = true,
	TextColor3 = WHITE,
	Text = "COMMON",
	ZIndex = 3,
	Parent = details,
}, { corner(8), padding(3), textStroke(1.5) })
local detailName = create("TextLabel", {
	Position = UDim2.fromOffset(14, 210),
	Size = UDim2.new(1, -28, 0, 34),
	BackgroundTransparency = 1,
	Font = FONT,
	TextScaled = true,
	TextColor3 = DARK,
	Text = "",
	Parent = details,
})
local detailDescription = create("TextLabel", {
	Position = UDim2.fromOffset(14, 246),
	Size = UDim2.new(1, -28, 0, 36),
	BackgroundTransparency = 1,
	Font = FONT,
	TextScaled = true,
	TextWrapped = true,
	TextColor3 = BROWN_TEXT,
	Text = "",
	Parent = details,
})

local statRows = {}
for i = 1, 3 do
	local row = create("Frame", {
		Position = UDim2.fromOffset(14, 288 + (i - 1) * 38),
		Size = UDim2.new(1, -28, 0, 32),
		BackgroundTransparency = 1,
		Parent = details,
	})
	local label = create("TextLabel", {
		Size = UDim2.fromOffset(104, 22),
		BackgroundTransparency = 1,
		Font = FONT,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = DARK,
		Parent = row,
	})
	local barBack = create("Frame", {
		Position = UDim2.fromOffset(0, 24),
		Size = UDim2.new(1, 0, 0, 8),
		BackgroundColor3 = Color3.fromRGB(235, 220, 200),
		Parent = row,
	}, { corner(4) })
	local barFill = create("Frame", {
		Size = UDim2.fromScale(0.5, 1),
		BackgroundColor3 = GREEN,
		Parent = barBack,
	}, { corner(4) })
	local value = create("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(190, 22),
		BackgroundTransparency = 1,
		Font = FONT,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Right,
		RichText = true,
		TextColor3 = DARK,
		Parent = row,
	})
	statRows[i] = { Row = row, Label = label, Fill = barFill, Value = value }
end

local detailButton = create("TextButton", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -12),
	Size = UDim2.new(1, -24, 0, 50),
	BackgroundColor3 = GREEN,
	AutoButtonColor = false,
	Font = FONT,
	TextScaled = true,
	TextColor3 = WHITE,
	Text = "",
	Parent = details,
}, { corner(14), border(3, DARK), textStroke(2), padding(9) })
hoverGrow(detailButton)

-- Little message at the bottom of the shop ("Bought Golden Pan!")
local toast = create("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -14),
	Size = UDim2.fromOffset(480, 40),
	BackgroundColor3 = GREEN,
	Font = FONT,
	TextScaled = true,
	TextColor3 = WHITE,
	Text = "",
	Visible = false,
	ZIndex = 20,
	Parent = panel,
}, { corner(12), border(3, DARK), padding(6) })
local toastToken = 0

local function showToast(text, color)
	toastToken += 1
	local myToken = toastToken
	toast.Text = text
	toast.BackgroundColor3 = color
	toast.Visible = true
	toast.Position = UDim2.new(0.5, 0, 1, 10)
	TweenService:Create(toast, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Position = UDim2.new(0.5, 0, 1, -14) }):Play()
	task.delay(2.2, function()
		if myToken == toastToken then
			toast.Visible = false
		end
	end)
end

--------------------------------------------------------------------
-- 3D PREVIEWS
--------------------------------------------------------------------
local function buildPreview(categoryKey, item)
	if categoryKey == "Pans" then
		return PancakeVisuals.BuildPan(item, SizeConfig.Items[1])
	elseif categoryKey == "Sizes" then
		local model = PancakeVisuals.BuildPan(PanConfig.Items[3], item)
		for _, offset in ipairs(item.Offsets) do
			local pancake = PancakeVisuals.BuildPancake(PancakeConfig.Items[1], item.Diameter, 0.66)
			pancake:PivotTo(CFrame.new(offset + Vector3.new(0, 0.125 + THICK / 2, 0)))
			pancake.Parent = model
		end
		return model
	elseif categoryKey == "Pancakes" then
		-- a little stack of three
		local model = Instance.new("Model")
		for i = 1, 3 do
			local pancake = PancakeVisuals.BuildPancake(item, 3.4 - (i - 1) * 0.12, 0.66)
			pancake:PivotTo(CFrame.new(0, (i - 1) * (THICK + 0.02), 0) * CFrame.Angles(0, i * 0.9, 0))
			pancake.Parent = model
		end
		model.WorldPivot = CFrame.new()
		return model
	else
		local model = PancakeVisuals.BuildPancake(PancakeConfig.Items[1], 3.4, 0.66)
		local toppings = PancakeVisuals.BuildToppings({ item }, 3.4, 5)
		toppings:PivotTo(CFrame.new(0, THICK / 2 + 0.02, 0))
		toppings.Parent = model
		return model
	end
end

-- Puts a model in a viewport with a camera that slowly orbits it
local function showInViewport(viewport, model, spinSpeed)
	for _, child in ipairs(viewport:GetChildren()) do
		if child:IsA("Model") or child:IsA("Camera") then
			child:Destroy()
		end
	end
	model.Parent = viewport
	local previewCamera = Instance.new("Camera")
	previewCamera.FieldOfView = 30
	previewCamera.Parent = viewport
	viewport.CurrentCamera = previewCamera
	local center, size = model:GetBoundingBox()
	local spinner = {
		Viewport = viewport,
		Camera = previewCamera,
		Center = center.Position,
		Distance = (size.Magnitude / 2) / math.tan(math.rad(15)) * 1.05,
		Speed = spinSpeed or 0.5,
		Offset = math.random() * math.pi * 2,
	}
	table.insert(spinners, spinner)
	return spinner
end

local function updateSpinner(spinner, t)
	local angle = t * spinner.Speed + spinner.Offset
	local direction = Vector3.new(math.sin(angle) * 0.8, 0.75, math.cos(angle) * 0.8).Unit
	spinner.Camera.CFrame = CFrame.lookAt(spinner.Center + direction * spinner.Distance, spinner.Center)
end

--------------------------------------------------------------------
-- ITEM STATE
--------------------------------------------------------------------
local function isOwned(categoryKey, id)
	return data ~= nil and data.Owned[categoryKey] ~= nil and data.Owned[categoryKey][id] == true
end

-- "Equipped", "On", "Owned", "Buy" or "Locked"
local function itemState(categoryKey, item)
	if categoryKey == "Toppings" then
		if data and table.find(data.Equipped.Toppings, item.Id) then
			return "On"
		end
	elseif data and data.Equipped[EQUIP_SLOT[categoryKey]] == item.Id then
		return "Equipped"
	end
	if isOwned(categoryKey, item.Id) then
		return "Owned"
	end
	if data and data.Butter >= item.Price then
		return "Buy"
	end
	return "Locked"
end

local STATE_COLORS = { Equipped = GOLD, On = GOLD, Owned = BLUE, Buy = GREEN, Locked = GRAY }

local function buttonText(categoryKey, item, stateName, long)
	if stateName == "Equipped" then
		return "✓ EQUIPPED"
	elseif stateName == "On" then
		return long and "✓ ON  (tap to take off)" or "✓ ON"
	elseif stateName == "Owned" then
		return categoryKey == "Toppings" and "TURN ON" or "EQUIP"
	elseif stateName == "Buy" then
		return "BUY 🧈 " .. fmt(item.Price)
	end
	return "🔒 🧈 " .. fmt(item.Price)
end

local function shortStats(categoryKey, item)
	local lines = {}
	for _, stat in ipairs(STAT_DEFS[categoryKey]) do
		table.insert(lines, stat.Label .. " " .. stat.Format(stat.Get(item)))
	end
	return table.concat(lines, "\n")
end

--------------------------------------------------------------------
-- UNLOCK CELEBRATION
--------------------------------------------------------------------
local unlockGui = create("ScreenGui", {
	Name = "UnlockGui",
	IgnoreGuiInset = true,
	ResetOnSpawn = false,
	DisplayOrder = 4, -- above the shop, below the confetti
	Enabled = false,
	Parent = playerGui,
})
local unlockBackdrop = create("TextButton", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 0.35,
	AutoButtonColor = false,
	Text = "",
	Parent = unlockGui,
})
local rays = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.47),
	Size = UDim2.fromOffset(950, 950),
	BackgroundTransparency = 1,
	Parent = unlockGui,
})
local rayFrames = {}
for i = 1, 12 do
	local ray = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, 70, 1, 0),
		Rotation = i * 15,
		BackgroundColor3 = GOLD,
		BorderSizePixel = 0,
		Parent = rays,
	}, { create("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.45), NumberSequenceKeypoint.new(1, 1),
	}) }) })
	rayFrames[i] = ray
end
local unlockContent = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(560, 560),
	BackgroundTransparency = 1,
	Parent = unlockGui,
})
local unlockScale = create("UIScale", { Parent = unlockContent })
local unlockTitle = create("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0),
	Size = UDim2.new(1, 0, 0, 70),
	BackgroundTransparency = 1,
	Font = FONT,
	TextScaled = true,
	TextColor3 = WHITE,
	Text = "",
	Parent = unlockContent,
}, { textStroke(4) })
local unlockTitleGradient = create("UIGradient", { Rotation = 90, Parent = unlockTitle })
local unlockViewport = create("ViewportFrame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.48),
	Size = UDim2.fromOffset(330, 330),
	BackgroundTransparency = 1,
	Ambient = Color3.fromRGB(200, 200, 200),
	LightColor = WHITE,
	LightDirection = Vector3.new(-1, -2, -1),
	Parent = unlockContent,
})
local unlockName = create("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0.78, 0),
	Size = UDim2.new(1, 0, 0, 52),
	BackgroundTransparency = 1,
	Font = FONT,
	TextScaled = true,
	TextColor3 = WHITE,
	Text = "",
	Parent = unlockContent,
}, { textStroke(3) })
local unlockRarity = create("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0.78, 58),
	Size = UDim2.fromOffset(170, 30),
	BackgroundColor3 = GRAY,
	Font = FONT,
	TextScaled = true,
	TextColor3 = WHITE,
	Text = "",
	Parent = unlockContent,
}, { corner(10), padding(4), textStroke(1.5) })
create("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.fromScale(0.5, 1),
	Size = UDim2.new(1, 0, 0, 26),
	BackgroundTransparency = 1,
	Font = FONT,
	TextScaled = true,
	TextColor3 = Color3.fromRGB(230, 230, 230),
	Text = "Tap anywhere to continue",
	Parent = unlockContent,
})
local unlockSpinner = nil
local unlockRarityData = nil
local unlockToken = 0

local function hideUnlock()
	unlockToken += 1
	unlockGui.Enabled = false
	if unlockSpinner then
		table.remove(spinners, table.find(spinners, unlockSpinner) or #spinners + 1)
		unlockSpinner = nil
	end
end
unlockBackdrop.Activated:Connect(hideUnlock)

local function showUnlock(categoryKey, item)
	unlockToken += 1
	local myToken = unlockToken
	local rarity = GameConfig.GetRarity(item)
	unlockRarityData = rarity
	unlockTitle.Text = CATEGORY_BY_KEY[categoryKey].Unlock
	unlockTitleGradient.Color = ColorSequence.new(WHITE, rarity.Color)
	unlockName.Text = item.Name
	unlockRarity.Text = string.upper(item.Rarity or "Common")
	unlockRarity.BackgroundColor3 = rarity.Color
	for _, ray in ipairs(rayFrames) do
		ray.BackgroundColor3 = rarity.Color:Lerp(WHITE, 0.3)
	end
	if unlockSpinner then
		table.remove(spinners, table.find(spinners, unlockSpinner) or #spinners + 1)
	end
	unlockSpinner = showInViewport(unlockViewport, buildPreview(categoryKey, item), 1.2)

	unlockGui.Enabled = true
	unlockScale.Scale = 0.2
	TweenService:Create(unlockScale, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	Effects.Confetti(rarity.Order >= 5 and 140 or 90)
	Effects.Play("Ding", 1.2)
	Effects.Play("Boom", 1.6, 0.5)
	task.delay(0.15, function()
		Effects.Play("Ding", 1.5)
	end)
	task.delay(4.5, function()
		if myToken == unlockToken then
			hideUnlock()
		end
	end)
end

--------------------------------------------------------------------
-- DETAILS PANEL
--------------------------------------------------------------------
local detailSpinner = nil
local onItemAction -- defined below
local updateCard   -- defined below

local function statMax(categoryKey, stat)
	local best, worst = -math.huge, math.huge
	for _, item in ipairs(CATEGORY_BY_KEY[categoryKey].Config.Items) do
		local value = stat.Get(item)
		best = math.max(best, value)
		worst = math.min(worst, value)
	end
	return best, worst
end

local function equippedItem(categoryKey)
	if not data or not EQUIP_SLOT[categoryKey] then return nil end
	return CATEGORY_BY_KEY[categoryKey].Config.ById[data.Equipped[EQUIP_SLOT[categoryKey]]]
end

local function refreshDetails()
	if not selected then return end
	local categoryKey, item = selected.Category, selected.Item
	local rarity = GameConfig.GetRarity(item)
	local stateName = itemState(categoryKey, item)

	detailName.Text = item.Name
	detailDescription.Text = item.Description or ""
	detailRibbon.Text = string.upper(item.Rarity or "Common")
	detailRibbon.BackgroundColor3 = rarity.Color
	detailGradient.Color = ColorSequence.new(WHITE, rarity.Light)
	detailViewport.BackgroundColor3 = rarity.Light
	detailViewport.ImageColor3 = (stateName == "Locked") and Color3.fromRGB(70, 60, 55) or WHITE
	detailsStroke.Color = (stateName == "Equipped" or stateName == "On") and GOLD or rarity.Color

	local compareTo = equippedItem(categoryKey)
	local stats = STAT_DEFS[categoryKey]
	for i, row in ipairs(statRows) do
		local stat = stats[i]
		row.Row.Visible = stat ~= nil
		if stat then
			local value = stat.Get(item)
			local best, worst = statMax(categoryKey, stat)
			local fill = (best == worst) and 1 or (value - worst) / (best - worst)
			if stat.LowerIsBetter then
				fill = 1 - fill
			end
			row.Label.Text = stat.Label
			row.Fill.Size = UDim2.fromScale(math.clamp(0.08 + 0.92 * fill, 0.08, 1), 1)
			row.Fill.BackgroundColor3 = rarity.Color
			local text = "<b>" .. stat.Format(value) .. "</b>"
			if compareTo and compareTo ~= item then
				local difference = value - stat.Get(compareTo)
				local better = stat.LowerIsBetter and difference < 0 or (not stat.LowerIsBetter and difference > 0)
				if math.abs(difference) > 1e-6 then
					local color = better and "#3cb44b" or "#e04b4b"
					local arrow = better and "▲" or "▼"
					text ..= (' <font color="%s">%s %s</font>'):format(color, arrow, stat.Format(math.abs(difference)):gsub("^[%+x]", ""))
				else
					text ..= ' <font color="#999999">=</font>'
				end
			end
			row.Value.Text = text
		end
	end

	detailButton.Text = buttonText(categoryKey, item, stateName, true)
	detailButton.BackgroundColor3 = STATE_COLORS[stateName]
end

local function selectItem(categoryKey, item)
	selected = { Category = categoryKey, Item = item }
	if detailSpinner then
		table.remove(spinners, table.find(spinners, detailSpinner) or #spinners + 1)
	end
	detailSpinner = showInViewport(detailViewport, buildPreview(categoryKey, item), 0.8)
	for _, card in ipairs(cards) do
		card.Selected = (card.Item == item)
		if card.Button then
			updateCard(card)
		end
	end
	refreshDetails()
end

detailButton.Activated:Connect(function()
	if selected then
		onItemAction(selected.Category, selected.Item, nil)
	end
end)

--------------------------------------------------------------------
-- CARDS
--------------------------------------------------------------------
updateCard = function(card)
	local stateName = itemState(card.Category, card.Item)
	local rarity = card.Rarity
	card.Button.Text = buttonText(card.Category, card.Item, stateName, false)
	card.Button.BackgroundColor3 = STATE_COLORS[stateName]
	local highlighted = stateName == "Equipped" or stateName == "On"
	card.Stroke.Thickness = card.Selected and 5 or (highlighted and 4 or 3)
	if not rarity.Rainbow then
		card.Stroke.Color = highlighted and GOLD or (card.Selected and DARK or rarity.Color)
	end
	card.Check.Visible = highlighted
	-- locked items show as a mystery silhouette
	card.Viewport.ImageColor3 = (stateName == "Locked") and Color3.fromRGB(60, 50, 45) or WHITE
end

local function refreshHeader()
	shopButter.Text = "🧈 " .. fmt(data and data.Butter or 0)
	local category = CATEGORY_BY_KEY[currentTab]
	if currentTab == "Toppings" and data then
		infoLabel.Text = ("🍓 Topping slots: %d / %d used. Earn more Butter to unlock more slots!"):format(#data.Equipped.Toppings, data.Slots)
	else
		infoLabel.Text = category.Info
	end
	local owned, total = 0, #category.Config.Items
	for _, item in ipairs(category.Config.Items) do
		if isOwned(currentTab, item.Id) then
			owned += 1
		end
	end
	progressLabel.Text = ("Collected %d / %d"):format(owned, total)
	progressFill.BackgroundColor3 = category.Color
	TweenService:Create(progressFill, TweenInfo.new(0.3), { Size = UDim2.fromScale(math.max(owned / total, 0.02), 1) }):Play()
end

local function refreshBadge()
	local canBuy = false
	if data then
		for _, category in ipairs(CATEGORIES) do
			for _, item in ipairs(category.Config.Items) do
				if not isOwned(category.Key, item.Id) and item.Price <= data.Butter then
					canBuy = true
				end
			end
		end
	end
	badge.Visible = canBuy
end

local function refreshAll()
	refreshHeader()
	refreshBadge()
	for _, card in ipairs(cards) do
		updateCard(card)
	end
	refreshDetails()
end

local busy = false
onItemAction = function(categoryKey, item, card)
	if busy or not data then return end
	local stateName = itemState(categoryKey, item)
	if stateName == "Locked" then
		showToast("Not enough Butter! You need 🧈 " .. fmt(item.Price - data.Butter) .. " more.", RED)
		Effects.Play("Sad", 1.4, 0.4)
		return
	elseif stateName == "Equipped" then
		showToast("Already equipped!", BLUE)
		return
	end

	busy = true
	local action = (stateName == "Buy") and "Buy" or "Equip"
	local ok, message = ShopRemote:InvokeServer(action, categoryKey, item.Id)
	busy = false
	showToast(message or "Something went wrong.", ok and GREEN or RED)
	if ok and action == "Buy" then
		showUnlock(categoryKey, item)
		if card then
			card.Scale.Scale = 1.15
			TweenService:Create(card.Scale, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end
	elseif ok then
		Effects.Play("Ding", 1.1, 0.6)
		Effects.Play("Coin", 1.3, 0.5)
	end
end

local function buildCard(categoryKey, item, order)
	local rarity = GameConfig.GetRarity(item)
	local frame = create("Frame", {
		BackgroundColor3 = WHITE,
		LayoutOrder = order,
		ClipsDescendants = true,
		Parent = grid,
	}, { corner(16), create("UIGradient", { Rotation = 90, Color = ColorSequence.new(WHITE, rarity.Light) }) })
	local stroke = border(3, rarity.Color)
	stroke.Parent = frame
	local scale = create("UIScale", { Parent = frame })

	-- clicking anywhere on the card (except the button) shows it in the details panel
	local selectArea = create("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		ZIndex = 1,
		Parent = frame,
	})

	local viewport = create("ViewportFrame", {
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.new(1, -16, 0, 110),
		BackgroundColor3 = rarity.Light:Lerp(WHITE, 0.3),
		Ambient = Color3.fromRGB(190, 190, 190),
		LightColor = WHITE,
		LightDirection = Vector3.new(-1, -2, -1),
		ZIndex = 2,
		Parent = frame,
	}, { corner(12) })
	showInViewport(viewport, buildPreview(categoryKey, item), 0.5)

	create("TextLabel", { -- rarity ribbon
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.fromOffset(84, 20),
		BackgroundColor3 = rarity.Color,
		Font = FONT,
		TextScaled = true,
		TextColor3 = WHITE,
		Text = string.upper(item.Rarity or "Common"),
		ZIndex = 4,
		Parent = frame,
	}, { corner(7), padding(3), textStroke(1.2) })

	local check = create("TextLabel", { -- ✓ badge on equipped items
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 12),
		Size = UDim2.fromOffset(28, 28),
		BackgroundColor3 = GOLD,
		Font = FONT,
		TextScaled = true,
		TextColor3 = WHITE,
		Text = "✓",
		ZIndex = 4,
		Visible = false,
		Parent = frame,
	}, { corner(14), border(2, DARK), textStroke(1.5) })

	create("TextLabel", {
		Position = UDim2.fromOffset(8, 122),
		Size = UDim2.new(1, -16, 0, 24),
		BackgroundTransparency = 1,
		Font = FONT,
		TextScaled = true,
		TextColor3 = DARK,
		Text = item.Name,
		ZIndex = 2,
		Parent = frame,
	})
	create("TextLabel", {
		Position = UDim2.fromOffset(10, 148),
		Size = UDim2.new(1, -20, 0, 46),
		BackgroundTransparency = 1,
		Font = FONT,
		TextScaled = true,
		TextWrapped = true,
		TextColor3 = BROWN_TEXT,
		Text = shortStats(categoryKey, item),
		ZIndex = 2,
		Parent = frame,
	})
	local button = create("TextButton", {
		Position = UDim2.new(0, 8, 1, -40),
		Size = UDim2.new(1, -16, 0, 32),
		BackgroundColor3 = GREEN,
		AutoButtonColor = false,
		Font = FONT,
		TextScaled = true,
		TextColor3 = WHITE,
		Text = "",
		ZIndex = 3,
		Parent = frame,
	}, { corner(10), border(2, DARK), textStroke(1.5), padding(5) })
	hoverGrow(button)

	-- a shiny streak that sweeps across Legendary and Mythic cards
	local shine = nil
	if rarity.Shine then
		shine = create("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = WHITE,
			BorderSizePixel = 0,
			ZIndex = 5,
			Active = false,
			Parent = frame,
		})
		create("UIGradient", {
			Rotation = 25,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.42, 1), NumberSequenceKeypoint.new(0.5, 0.55),
				NumberSequenceKeypoint.new(0.58, 1), NumberSequenceKeypoint.new(1, 1),
			}),
			Parent = shine,
		})
	end

	local card = {
		Category = categoryKey, Item = item, Rarity = rarity, Frame = frame, Button = button, Stroke = stroke,
		Viewport = viewport, Scale = scale, Check = check, Shine = shine, Selected = false, Phase = math.random() * 2,
	}
	button.Activated:Connect(function()
		selectItem(categoryKey, item)
		onItemAction(categoryKey, item, card)
	end)
	selectArea.Activated:Connect(function()
		Effects.Play("Coin", 1.4, 0.3)
		selectItem(categoryKey, item)
	end)
	frame.MouseEnter:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1.03 }):Play()
	end)
	frame.MouseLeave:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1 }):Play()
	end)
	updateCard(card)
	return card
end

local tabButtons = {}

local function clearCards()
	for _, card in ipairs(cards) do
		card.Frame:Destroy()
	end
	cards = {}
	local keep = {}
	for _, spinner in ipairs(spinners) do
		if spinner == detailSpinner or spinner == unlockSpinner then
			table.insert(keep, spinner)
		end
	end
	spinners = keep
end

local function showTab(key)
	currentTab = key
	clearCards()
	grid.CanvasPosition = Vector2.zero
	local category = CATEGORY_BY_KEY[key]
	for _, other in ipairs(CATEGORIES) do
		local tab = tabButtons[other.Key]
		local isSelected = other.Key == key
		tab.Button.BackgroundColor3 = isSelected and other.Color or other.Color:Lerp(CREAM, 0.55)
		tab.Stroke.Color = isSelected and DARK or Color3.fromRGB(200, 160, 120)
		tab.Stroke.Thickness = isSelected and 4 or 3
	end
	for index, item in ipairs(category.Config.Items) do
		table.insert(cards, buildCard(key, item, index))
	end
	-- show what you have equipped (or the first item) in the details panel
	local first = equippedItem(key) or category.Config.Items[1]
	if key == "Toppings" and data and data.Equipped.Toppings[1] then
		first = ToppingConfig.ById[data.Equipped.Toppings[1]] or first
	end
	selectItem(key, first)
	refreshHeader()
end

for index, category in ipairs(CATEGORIES) do
	local button = create("TextButton", {
		LayoutOrder = index,
		Size = UDim2.new(1 / #CATEGORIES, -6, 1, 0),
		BackgroundColor3 = category.Color,
		AutoButtonColor = false,
		Font = FONT,
		TextScaled = true,
		TextColor3 = WHITE,
		Text = category.Title,
		Parent = tabBar,
	}, { corner(14), textStroke(2), padding(8) })
	local stroke = border(3, DARK)
	stroke.Parent = button
	hoverGrow(button)
	tabButtons[category.Key] = { Button = button, Stroke = stroke }
	button.Activated:Connect(function()
		if currentTab ~= category.Key then
			Effects.Play("Coin", 0.9, 0.4)
			showTab(category.Key)
		end
	end)
end

--------------------------------------------------------------------
-- ANIMATION (spinning previews, shine sweeps, rainbow borders, unlock rays)
--------------------------------------------------------------------
RunService.RenderStepped:Connect(function()
	local t = os.clock()
	if isOpen or unlockGui.Enabled then
		for _, spinner in ipairs(spinners) do
			if spinner.Viewport.Parent then
				updateSpinner(spinner, t)
			end
		end
	end
	if isOpen then
		for _, card in ipairs(cards) do
			if card.Shine then
				local gradient = card.Shine:FindFirstChildOfClass("UIGradient")
				gradient.Offset = Vector2.new(((t * 0.45 + card.Phase) % 2) * 1.6 - 1.6, 0)
			end
			if card.Rarity.Rainbow then
				local stateName = itemState(card.Category, card.Item)
				if stateName ~= "Equipped" and stateName ~= "On" then
					card.Stroke.Color = rainbow(t, card.Phase)
				end
			end
		end
		if selected and GameConfig.GetRarity(selected.Item).Rainbow then
			detailRibbon.BackgroundColor3 = rainbow(t)
		end
	end
	if unlockGui.Enabled then
		rays.Rotation = (t * 25) % 360
		if unlockRarityData and unlockRarityData.Rainbow then
			for i, ray in ipairs(rayFrames) do
				ray.BackgroundColor3 = rainbow(t, i / 12)
			end
		end
	end
end)

--------------------------------------------------------------------
-- OPEN / CLOSE
--------------------------------------------------------------------
local function fitToScreen()
	local viewportSize = camera.ViewportSize
	fitScale.Scale = math.min(1, viewportSize.X * 0.96 / PANEL_SIZE.X, viewportSize.Y * 0.9 / PANEL_SIZE.Y)
end
camera:GetPropertyChangedSignal("ViewportSize"):Connect(fitToScreen)
fitToScreen()

local function openShop()
	if isOpen then return end
	isOpen = true
	holder.Visible = true
	showTab(currentTab)
	panelScale.Scale = 0.4
	TweenService:Create(panelScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	TweenService:Create(blur, TweenInfo.new(0.3), { Size = 14 }):Play()
	Effects.Play("Coin", 1.2, 0.5)
end

local function closeShop()
	if not isOpen then return end
	isOpen = false
	TweenService:Create(blur, TweenInfo.new(0.25), { Size = 0 }):Play()
	local shrink = TweenService:Create(panelScale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0.3 })
	shrink:Play()
	shrink.Completed:Connect(function()
		if not isOpen then
			holder.Visible = false
			clearCards()
		end
	end)
end

openButton.Activated:Connect(function()
	if isOpen then
		closeShop()
	else
		openShop()
	end
end)
closeButton.Activated:Connect(closeShop)
OpenShopEvent.OnClientEvent:Connect(openShop) -- walked up to the shop stand

-- B on the keyboard or Y on a controller also opens/closes the shop
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.B or input.KeyCode == Enum.KeyCode.ButtonY then
		if isOpen then
			closeShop()
		else
			openShop()
		end
	end
end)

-- The SHOP button grows a little when hovered and gently bobs when there's something new to buy.
-- It always eases back to exactly full size, even after clicking.
RunService.RenderStepped:Connect(function(dt)
	local target = openHovered and 1.06 or 1
	if badge.Visible and not isOpen then
		target += 0.08 * math.max(0, math.sin(os.clock() * 3.5)) ^ 4
	end
	openScale.Scale += (target - openScale.Scale) * math.min(dt * 14, 1)
end)

--------------------------------------------------------------------
-- DATA FROM THE SERVER
--------------------------------------------------------------------
DataEvent.OnClientEvent:Connect(function(snapshot)
	data = snapshot
	refreshAll()
end)

task.spawn(function()
	local snapshot = GetDataRemote:InvokeServer()
	if snapshot and not data then
		data = snapshot
		refreshAll()
	end
end)

-- Keep the shop's Butter display in sync with the leaderboard between updates
task.spawn(function()
	local butterValue = player:WaitForChild("leaderstats"):WaitForChild("Butter")
	butterValue.Changed:Connect(function(value)
		if data then
			data.Butter = value
			refreshAll()
		end
	end)
end)
