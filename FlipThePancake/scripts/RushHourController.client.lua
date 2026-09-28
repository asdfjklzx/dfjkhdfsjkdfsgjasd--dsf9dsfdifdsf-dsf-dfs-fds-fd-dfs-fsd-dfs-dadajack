-- RushHourController (LocalScript in StarterPlayer > StarterPlayerScripts)
-- Shows the RUSH HOUR banner, countdown and red glow around the screen.
-- The server (EventManager) sets workspace attributes: RushHour, RushHourEnds, NextRushHour.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local Effects = require(script.Parent:WaitForChild("Effects"))

local FONT = Enum.Font.FredokaOne
local WHITE = Color3.new(1, 1, 1)
local DARK = Color3.fromRGB(60, 35, 20)
local RED = Color3.fromRGB(235, 50, 50)

local gui = Instance.new("ScreenGui")
gui.Name = "RushHourGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 3
gui.Parent = player:WaitForChild("PlayerGui")

-- Red glow around the edges of the screen
local edges = {}
local EDGE_SETUP = {
	{ AnchorPoint = Vector2.new(0, 0), Position = UDim2.fromScale(0, 0), Size = UDim2.new(1, 0, 0, 90), Rotation = 90 },
	{ AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 90), Rotation = -90 },
	{ AnchorPoint = Vector2.new(0, 0), Position = UDim2.fromScale(0, 0), Size = UDim2.new(0, 90, 1, 0), Rotation = 0 },
	{ AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0, 90, 1, 0), Rotation = 180 },
}
for _, setup in ipairs(EDGE_SETUP) do
	local edge = Instance.new("Frame")
	edge.AnchorPoint = setup.AnchorPoint
	edge.Position = setup.Position
	edge.Size = setup.Size
	edge.BackgroundColor3 = RED
	edge.BorderSizePixel = 0
	edge.Visible = false
	edge.Parent = gui
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = setup.Rotation
	gradient.Transparency = NumberSequence.new(0.35, 1)
	gradient.Parent = edge
	table.insert(edges, { Frame = edge, Gradient = gradient })
end

-- Banner under the Butter counter
local banner = Instance.new("Frame")
banner.AnchorPoint = Vector2.new(0.5, 0)
banner.Position = UDim2.new(0.5, 0, 0, 172)
banner.Size = UDim2.fromOffset(430, 62)
banner.BackgroundColor3 = RED
banner.Visible = false
banner.Parent = gui
Instance.new("UICorner", banner).CornerRadius = UDim.new(0, 16)
local bannerStroke = Instance.new("UIStroke")
bannerStroke.Thickness = 4
bannerStroke.Color = DARK
bannerStroke.Parent = banner
local bannerGradient = Instance.new("UIGradient")
bannerGradient.Rotation = 90
bannerGradient.Color = ColorSequence.new(Color3.fromRGB(255, 150, 90), Color3.fromRGB(255, 255, 255))
bannerGradient.Parent = banner
local bannerScale = Instance.new("UIScale")
bannerScale.Parent = banner

local bannerTitle = Instance.new("TextLabel")
bannerTitle.Position = UDim2.fromOffset(10, 4)
bannerTitle.Size = UDim2.new(1, -20, 0, 34)
bannerTitle.BackgroundTransparency = 1
bannerTitle.Font = FONT
bannerTitle.TextScaled = true
bannerTitle.TextColor3 = WHITE
bannerTitle.Text = ("🔥 RUSH HOUR! x%d BUTTER 🔥"):format(GameConfig.RushHour.ButterMultiplier)
bannerTitle.Parent = banner
local titleStroke = Instance.new("UIStroke")
titleStroke.Thickness = 2.5
titleStroke.Color = DARK
titleStroke.Parent = bannerTitle

local bannerTimer = Instance.new("TextLabel")
bannerTimer.Position = UDim2.new(0, 10, 0, 38)
bannerTimer.Size = UDim2.new(1, -20, 0, 20)
bannerTimer.BackgroundTransparency = 1
bannerTimer.Font = FONT
bannerTimer.TextScaled = true
bannerTimer.TextColor3 = Color3.fromRGB(255, 240, 200)
bannerTimer.Text = ""
bannerTimer.Parent = banner

-- Small "Rush Hour in 0:25" warning before it starts
local warning = Instance.new("TextLabel")
warning.AnchorPoint = Vector2.new(0.5, 0)
warning.Position = UDim2.new(0.5, 0, 0, 172)
warning.Size = UDim2.fromOffset(300, 30)
warning.BackgroundTransparency = 1
warning.Font = FONT
warning.TextScaled = true
warning.TextColor3 = Color3.fromRGB(255, 200, 80)
warning.TextStrokeTransparency = 0.2
warning.Visible = false
warning.Parent = gui

-- Big announcement in the middle of the screen
local announce = Instance.new("TextLabel")
announce.AnchorPoint = Vector2.new(0.5, 0.5)
announce.Position = UDim2.fromScale(0.5, 0.42)
announce.Size = UDim2.new(0.9, 0, 0, 130)
announce.BackgroundTransparency = 1
announce.Font = FONT
announce.TextScaled = true
announce.TextColor3 = WHITE
announce.TextTransparency = 1
announce.Parent = gui
local announceStroke = Instance.new("UIStroke")
announceStroke.Thickness = 6
announceStroke.Color = DARK
announceStroke.Transparency = 1
announceStroke.Parent = announce
local announceGradient = Instance.new("UIGradient")
announceGradient.Rotation = 90
announceGradient.Color = ColorSequence.new(Color3.fromRGB(255, 240, 120), Color3.fromRGB(255, 60, 40))
announceGradient.Parent = announce
local announceScale = Instance.new("UIScale")
announceScale.Parent = announce
local sizeLimit = Instance.new("UISizeConstraint")
sizeLimit.MaxSize = Vector2.new(900, 130)
sizeLimit.Parent = announce

local function showAnnouncement(text)
	announce.Text = text
	announce.TextTransparency = 0
	announceStroke.Transparency = 0
	announceScale.Scale = 0.2
	announce.Rotation = -8
	TweenService:Create(announceScale, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	TweenService:Create(announce, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Rotation = 0 }):Play()
	task.delay(2.2, function()
		TweenService:Create(announce, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
		TweenService:Create(announceStroke, TweenInfo.new(0.5), { Transparency = 1 }):Play()
	end)
end

-- Optional music (set GameConfig.RushHour.Music to a Creator Store audio id)
local music = nil
if GameConfig.RushHour.Music ~= "" then
	music = Instance.new("Sound")
	music.SoundId = GameConfig.RushHour.Music
	music.Looped = true
	music.Volume = 0.4
	music.Parent = SoundService
end

local function formatTime(seconds)
	seconds = math.max(0, math.floor(seconds))
	return ("%d:%02d"):format(seconds // 60, seconds % 60)
end

local wasRushing = workspace:GetAttribute("RushHour") == true

local function onRushChanged()
	local rushing = workspace:GetAttribute("RushHour") == true
	if rushing == wasRushing then return end
	wasRushing = rushing
	if rushing then
		showAnnouncement("🔥 RUSH HOUR! 🔥")
		Effects.Play("Boom", 1)
		Effects.Play("Ding", 1.3)
		Effects.Flash(RED, 0.35)
		banner.Visible = true
		bannerScale.Scale = 0.3
		TweenService:Create(bannerScale, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		if music then
			music:Play()
		end
	else
		showAnnouncement("Rush Hour is over! 😮‍💨")
		banner.Visible = false
		if music then
			music:Stop()
		end
	end
end
workspace:GetAttributeChangedSignal("RushHour"):Connect(onRushChanged)
banner.Visible = wasRushing

RunService.RenderStepped:Connect(function()
	local now = workspace:GetServerTimeNow()
	local t = os.clock()
	local rushing = workspace:GetAttribute("RushHour") == true

	for _, edge in ipairs(edges) do
		edge.Frame.Visible = rushing
		if rushing then
			local pulse = 0.35 + 0.25 * (0.5 + 0.5 * math.sin(t * 5))
			edge.Gradient.Transparency = NumberSequence.new(pulse, 1)
		end
	end

	if rushing then
		local ends = workspace:GetAttribute("RushHourEnds") or now
		bannerTimer.Text = "Ends in " .. formatTime(ends - now) .. "  •  customers are hungry!"
		-- flashing banner
		banner.BackgroundColor3 = RED:Lerp(Color3.fromRGB(255, 140, 40), 0.5 + 0.5 * math.sin(t * 8))
		banner.Rotation = math.sin(t * 3) * 1.5
		warning.Visible = false
	else
		local nextRush = workspace:GetAttribute("NextRushHour")
		local left = nextRush and (nextRush - now) or math.huge
		warning.Visible = left <= 30 and left > 0
		if warning.Visible then
			warning.Text = "🔥 Rush Hour in " .. formatTime(left) .. "!"
		end
	end
end)
