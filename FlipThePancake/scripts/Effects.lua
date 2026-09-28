-- Effects (ModuleScript in StarterPlayer > StarterPlayerScripts)
-- All the "juice": sounds, particles, bubbles, screen flashes, cinematic bars,
-- confetti, flying butter and the combo counter. CookingController calls into this.
-- Sounds and particle textures are listed in GameConfig so they're easy to swap.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local FONT = Enum.Font.FredokaOne
local WHITE = Color3.new(1, 1, 1)
local DARK = Color3.fromRGB(60, 35, 20)
local GOLD = Color3.fromRGB(255, 220, 50)
local TEX = GameConfig.Textures

local Effects = {}

local function seq(a, b)
	return NumberSequence.new(a, b or a)
end

local function colors(a, b)
	return ColorSequence.new(a, b or a)
end

local function range(a, b)
	return NumberRange.new(a, b or a)
end

-- invisible -> visible -> invisible over a particle's life
local function fadeInOut(peak)
	return NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.15, peak),
		NumberSequenceKeypoint.new(1, 1),
	})
end

--------------------------------------------------------------------
-- SOUNDS
--------------------------------------------------------------------
local soundFolder = Instance.new("Folder")
soundFolder.Name = "PancakeSounds"
soundFolder.Parent = SoundService

local templates = {}
local preload = {}
for name, info in pairs(GameConfig.Sounds) do
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = info.Id or info.Ids[1]
	sound.Volume = info.Volume
	sound.PlaybackSpeed = info.Pitch
	sound.Parent = soundFolder
	templates[name] = sound
	table.insert(preload, sound)
	for index = 2, info.Ids and #info.Ids or 0 do
		local variant = sound:Clone()
		variant.SoundId = info.Ids[index]
		variant.Parent = soundFolder
		table.insert(preload, variant)
	end
end

-- Load every sound up front so nothing is silent the first time it plays
task.spawn(function()
	pcall(function()
		game:GetService("ContentProvider"):PreloadAsync(preload)
	end)
end)

-- Plays a one-shot sound. Returns it so long sounds (like the whoosh) can be stopped early.
function Effects.Play(name, pitchScale, volumeScale)
	local template = templates[name]
	if not template then return nil end
	local sound = template:Clone()
	local ids = GameConfig.Sounds[name].Ids
	if ids then
		sound.SoundId = ids[math.random(#ids)]
	end
	sound.PlaybackSpeed = template.PlaybackSpeed * (pitchScale or 1)
	sound.Volume = template.Volume * (volumeScale or 1)
	sound.Parent = soundFolder
	sound:Play()
	task.delay(6, function()
		sound:Destroy()
	end)
	return sound
end

local sizzle = templates.Sizzle:Clone()
sizzle.Name = "SizzleLoop"
sizzle.Looped = true
sizzle.Parent = soundFolder

-- 0 = silent, 1 = loudest (right in the PERFECT zone)
function Effects.SetSizzle(intensity)
	if intensity <= 0 then
		if sizzle.IsPlaying then
			sizzle:Stop()
		end
		return
	end
	if not sizzle.IsPlaying then
		sizzle:Play()
	end
	sizzle.Volume = templates.Sizzle.Volume * intensity
	sizzle.PlaybackSpeed = templates.Sizzle.PlaybackSpeed * (0.9 + 0.2 * intensity)
end

--------------------------------------------------------------------
-- 3D EFFECTS (particles, pan light, bubbles)
--------------------------------------------------------------------
local fx = {}
local fxFolder = nil
local restPosition = nil
local bubbles = {}

local function fxPart(name, size, position)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = CFrame.new(position)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Parent = fxFolder
	return part
end

local function newEmitter(parent, props)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Enabled = false
	emitter.LightInfluence = 0
	for key, value in pairs(props) do
		emitter[key] = value
	end
	emitter.Parent = parent
	return emitter
end

function Effects.InitWorld(rest)
	restPosition = rest
	fxFolder = Instance.new("Folder")
	fxFolder.Name = "PancakeFX"
	fxFolder.Parent = workspace

	local cook = fxPart("CookFX", Vector3.new(3, 0.2, 3), rest + Vector3.new(0, 0.25, 0))
	fx.CookPart = cook

	fx.Steam = newEmitter(cook, {
		Texture = TEX.Smoke, Color = colors(WHITE), Transparency = fadeInOut(0.55),
		Size = seq(0.8, 3.2), Lifetime = range(1.6, 2.6), Rate = 5, Speed = range(1.5, 3),
		Acceleration = Vector3.new(0, 1.5, 0), Rotation = range(0, 360), RotSpeed = range(-40, 40),
		SpreadAngle = Vector2.new(15, 15), LightInfluence = 0.6,
	})

	fx.Smoke = newEmitter(cook, {
		Texture = TEX.Smoke, Color = colors(Color3.fromRGB(45, 40, 40)), Transparency = fadeInOut(0.15),
		Size = seq(1, 4.5), Lifetime = range(1.5, 2.5), Rate = 20, Speed = range(3, 6),
		Acceleration = Vector3.new(0, 2, 0), Rotation = range(0, 360), RotSpeed = range(-60, 60),
		SpreadAngle = Vector2.new(20, 20), LightInfluence = 0.8,
	})

	fx.Sparkles = newEmitter(cook, {
		Texture = TEX.Sparkle, Color = colors(GOLD, WHITE), LightEmission = 1,
		Size = seq(0.9, 0), Lifetime = range(0.6, 1.1), Speed = range(10, 18),
		SpreadAngle = Vector2.new(55, 55), Acceleration = Vector3.new(0, -28, 0), Drag = 1.5,
		Rotation = range(0, 360), RotSpeed = range(-200, 200),
	})

	local center = Instance.new("Attachment")
	center.Parent = cook
	fx.Ring = newEmitter(center, {
		Texture = TEX.Ring, Color = colors(GOLD), LightEmission = 1, Size = seq(1, 10),
		Transparency = seq(0.1, 1), Lifetime = range(0.45), Speed = range(0),
	})

	fx.Light = Instance.new("PointLight")
	fx.Light.Color = Color3.fromRGB(255, 150, 60)
	fx.Light.Range = 12
	fx.Light.Brightness = 0
	fx.Light.Parent = cook

	-- A ring of fire around the pan for big combos
	fx.Fire = {}
	fx.FireAttachments = {}
	for i = 1, 12 do
		local angle = i / 12 * math.pi * 2
		local attachment = Instance.new("Attachment")
		attachment.Position = Vector3.new(math.cos(angle) * 2.5, -0.15, math.sin(angle) * 2.5)
		attachment.Parent = cook
		table.insert(fx.FireAttachments, attachment)
		table.insert(fx.Fire, newEmitter(attachment, {
			Texture = TEX.Fire, Color = colors(Color3.fromRGB(255, 200, 60), Color3.fromRGB(255, 60, 20)),
			LightEmission = 1, Size = seq(1.3, 0.2), Transparency = seq(0.15, 1), Lifetime = range(0.35, 0.65),
			Rate = 6, Speed = range(3, 5), SpreadAngle = Vector2.new(12, 12),
			Rotation = range(0, 360), RotSpeed = range(-90, 90),
		}))
	end

	-- Batter splatter when a pancake hits the floor
	fx.SplatPart = fxPart("SplatFX", Vector3.new(1, 0.2, 1), rest)
	fx.Splat = newEmitter(fx.SplatPart, {
		Texture = TEX.Square, Color = colors(Color3.fromRGB(245, 225, 170)), Size = seq(0.45, 0),
		Lifetime = range(0.5, 0.9), Speed = range(8, 14), SpreadAngle = Vector2.new(70, 70),
		Acceleration = Vector3.new(0, -40, 0), Rotation = range(0, 360), RotSpeed = range(-300, 300),
		LightInfluence = 1,
	})

	-- Batter bubbles that pop on the raw side
	for i = 1, 16 do
		local bubble = Instance.new("Part")
		bubble.Name = "Bubble"
		bubble.Shape = Enum.PartType.Ball
		bubble.Size = Vector3.new(0.2, 0.2, 0.2)
		bubble.Color = Color3.fromRGB(255, 250, 232)
		bubble.Material = Enum.Material.SmoothPlastic
		bubble.Anchored = true
		bubble.CanCollide = false
		bubble.CanQuery = false
		bubble.CanTouch = false
		bubble.CastShadow = false
		bubble.Transparency = 1
		bubble.Parent = fxFolder
		bubbles[i] = { Part = bubble, Busy = false }
	end
end

function Effects.SetSteam(on)
	if fx.Steam then fx.Steam.Enabled = on end
end

function Effects.SetSmoke(on)
	if fx.Smoke then fx.Smoke.Enabled = on end
end

function Effects.SetPanLight(brightness)
	if fx.Light then fx.Light.Brightness = brightness end
end

function Effects.Sparkle(count)
	if fx.Sparkles then fx.Sparkles:Emit(count or 40) end
end

function Effects.Ring()
	if fx.Ring then fx.Ring:Emit(1) end
end

function Effects.Splat(position)
	if not fx.Splat then return end
	fx.SplatPart.CFrame = CFrame.new(position)
	fx.Splat:Emit(35)
end

-- Fits the steam, smoke, sparkles and combo fire ring to the current pan
function Effects.ConfigureArea(center, sizeX, sizeZ, rotation)
	if not fx.CookPart then return end
	fx.CookPart.Size = Vector3.new(sizeX, 0.2, sizeZ)
	fx.CookPart.CFrame = CFrame.new(center + Vector3.new(0, 0.25, 0)) * (rotation or CFrame.new())
	for i, attachment in ipairs(fx.FireAttachments) do
		local angle = i / #fx.FireAttachments * math.pi * 2
		attachment.Position = Vector3.new(math.cos(angle) * (sizeX / 2 + 0.3), -0.15, math.sin(angle) * (sizeZ / 2 + 0.3))
	end
end

-- A little batter bubble that grows and pops at a spot on a pancake
function Effects.SpawnBubble(position)
	for _, bubble in ipairs(bubbles) do
		if not bubble.Busy then
			bubble.Busy = true
			local part = bubble.Part
			local size = 0.14 + math.random() * 0.14
			part.Size = Vector3.new(0.05, 0.05, 0.05)
			part.Position = position
			part.Transparency = 0.15
			TweenService:Create(part, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Size = Vector3.one * size }):Play()
			task.delay(0.35 + math.random() * 0.5, function()
				local pop = TweenService:Create(part, TweenInfo.new(0.1), { Size = Vector3.one * size * 1.5, Transparency = 1 })
				pop:Play()
				pop.Completed:Wait()
				bubble.Busy = false
			end)
			return
		end
	end
end

function Effects.ClearBubbles()
	for _, bubble in ipairs(bubbles) do
		bubble.Part.Transparency = 1
	end
end

--------------------------------------------------------------------
-- SCREEN EFFECTS (flash, cinematic bars, confetti, flying butter)
--------------------------------------------------------------------
local fxGui, flash, barTop, barBottom

-- Combo counter
local comboFrame, comboScale, comboText, comboLabel, comboGradient
local flames = {}
local COMBO_POSITION = UDim2.new(1, -30, 0.42, 0)
local currentCombo = 0

local COMBO_COLORS = {
	[2] = Color3.fromRGB(255, 255, 255),
	[3] = Color3.fromRGB(255, 240, 120),
	[4] = Color3.fromRGB(255, 210, 60),
	[5] = Color3.fromRGB(255, 160, 40),
	[6] = Color3.fromRGB(255, 110, 40),
	[7] = Color3.fromRGB(255, 60, 60),
	[8] = Color3.fromRGB(240, 60, 160),
	[9] = Color3.fromRGB(170, 80, 255),
}

local CONFETTI_COLORS = {
	Color3.fromRGB(255, 90, 90), Color3.fromRGB(255, 200, 60), Color3.fromRGB(90, 210, 120),
	Color3.fromRGB(80, 170, 255), Color3.fromRGB(200, 110, 255), Color3.fromRGB(255, 140, 200),
}

local function label(props)
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Font = FONT
	text.TextScaled = true
	text.TextColor3 = WHITE
	for key, value in pairs(props) do
		if key ~= "Parent" then
			text[key] = value
		end
	end
	text.Parent = props.Parent
	return text
end

local function textStroke(parent, thickness)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = thickness
	stroke.Color = DARK
	stroke.Parent = parent
	return stroke
end

function Effects.InitUI(hudGui)
	local playerGui = player:WaitForChild("PlayerGui")

	-- Full-screen layer (covers the top bar too) for flashes, bars and flying butter
	fxGui = Instance.new("ScreenGui")
	fxGui.Name = "PancakeFX_UI"
	fxGui.IgnoreGuiInset = true
	fxGui.ResetOnSpawn = false
	fxGui.DisplayOrder = 5
	fxGui.Parent = playerGui

	flash = Instance.new("Frame")
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = WHITE
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.Parent = fxGui

	barTop = Instance.new("Frame")
	barTop.AnchorPoint = Vector2.new(0, 1)
	barTop.Position = UDim2.fromScale(0, 0)
	barTop.Size = UDim2.fromScale(1, 0.11)
	barTop.BackgroundColor3 = Color3.new(0, 0, 0)
	barTop.BorderSizePixel = 0
	barTop.ZIndex = 2
	barTop.Parent = fxGui

	barBottom = barTop:Clone()
	barBottom.AnchorPoint = Vector2.new(0, 0)
	barBottom.Position = UDim2.fromScale(0, 1)
	barBottom.Parent = fxGui

	-- Combo counter (right side of the screen)
	comboFrame = Instance.new("Frame")
	comboFrame.Name = "Combo"
	comboFrame.AnchorPoint = Vector2.new(1, 0.5)
	comboFrame.Position = COMBO_POSITION
	comboFrame.Size = UDim2.fromOffset(200, 160)
	comboFrame.BackgroundTransparency = 1
	comboFrame.Visible = false
	comboFrame.Parent = hudGui

	comboScale = Instance.new("UIScale")
	comboScale.Parent = comboFrame

	comboText = label({ Size = UDim2.fromScale(1, 0.66), Text = "x2", ZIndex = 3, Parent = comboFrame })
	textStroke(comboText, 6)
	comboGradient = Instance.new("UIGradient")
	comboGradient.Rotation = 90
	comboGradient.Parent = comboText

	comboLabel = label({ Position = UDim2.fromScale(0, 0.64), Size = UDim2.fromScale(1, 0.3), Text = "COMBO!", ZIndex = 3, Parent = comboFrame })
	textStroke(comboLabel, 4)

	for i = 1, 3 do
		flames[i] = label({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.2 + (i - 1) * 0.3, 0.02),
			Size = UDim2.fromOffset(52, 52),
			Text = "🔥",
			ZIndex = 2,
			Visible = false,
			Parent = comboFrame,
		})
	end
end

function Effects.Flash(color, strength)
	if not flash then return end
	flash.BackgroundColor3 = color
	flash.BackgroundTransparency = 1 - strength
	TweenService:Create(flash, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
end

-- Black movie bars for slow-motion flips
function Effects.Letterbox(on)
	if not barTop then return end
	local info = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(barTop, info, { Position = on and UDim2.fromScale(0, 0.11) or UDim2.fromScale(0, 0) }):Play()
	TweenService:Create(barBottom, info, { Position = on and UDim2.fromScale(0, 0.89) or UDim2.fromScale(0, 1) }):Play()
end

function Effects.Confetti(count)
	if not fxGui then return end
	for _ = 1, count do
		local piece = Instance.new("Frame")
		piece.AnchorPoint = Vector2.new(0.5, 0.5)
		piece.Size = UDim2.fromOffset(math.random(8, 14), math.random(14, 22))
		piece.BackgroundColor3 = CONFETTI_COLORS[math.random(#CONFETTI_COLORS)]
		piece.BorderSizePixel = 0
		piece.Rotation = math.random(0, 360)
		local startX = math.random()
		piece.Position = UDim2.new(startX, 0, 0, -math.random(10, 220))
		piece.ZIndex = 3
		piece.Parent = fxGui
		local duration = 1.6 + math.random() * 1.2
		TweenService:Create(piece, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(startX + (math.random() - 0.5) * 0.25, 0, 1.1, 0),
			Rotation = piece.Rotation + math.random(-720, 720),
		}):Play()
		task.delay(duration, function()
			piece:Destroy()
		end)
	end
end

-- Butter icons fly from a spot in the world to a GUI element, calling onArrive(i) as each one lands
function Effects.FlyButter(worldPosition, targetGui, count, onArrive)
	if not fxGui then return end
	local startPoint = camera:WorldToViewportPoint(worldPosition)
	local inset = GuiService:GetGuiInset()
	local target = targetGui.AbsolutePosition + targetGui.AbsoluteSize / 2 + inset

	for i = 1, count do
		task.delay((i - 1) * 0.06, function()
			local icon = label({
				AnchorPoint = Vector2.new(0.5, 0.5),
				Size = UDim2.fromOffset(0, 0),
				Text = "🧈",
				ZIndex = 4,
				Parent = fxGui,
			})
			local start = Vector2.new(startPoint.X, startPoint.Y) + Vector2.new(math.random(-40, 40), math.random(-30, 30))
			local control = start:Lerp(target, 0.5) + Vector2.new(math.random(-250, 250), -math.random(120, 260))
			local duration = 0.55 + math.random() * 0.2
			local began = os.clock()
			local connection
			connection = RunService.RenderStepped:Connect(function()
				local t = math.min((os.clock() - began) / duration, 1)
				local e = t ^ 1.6
				local a = start:Lerp(control, e)
				local b = control:Lerp(target, e)
				local point = a:Lerp(b, e)
				local size = 46 * math.min(1, t * 6) * (1 - 0.35 * t)
				icon.Position = UDim2.fromOffset(point.X, point.Y)
				icon.Size = UDim2.fromOffset(size, size)
				icon.Rotation = math.sin(t * math.pi * 3) * 25
				if t >= 1 then
					connection:Disconnect()
					icon:Destroy()
					if onArrive then
						onArrive(i)
					end
				end
			end)
		end)
	end
end

--------------------------------------------------------------------
-- COMBO
--------------------------------------------------------------------
local function setComboFire(multiplier)
	local on = multiplier >= 5
	local maxed = multiplier >= GameConfig.MaxCombo
	for _, emitter in ipairs(fx.Fire or {}) do
		emitter.Enabled = on
		emitter.Rate = 4 + math.max(multiplier - 5, 0) * 2
		emitter.Color = maxed
			and colors(Color3.fromRGB(120, 210, 255), Color3.fromRGB(170, 60, 255)) -- cosmic fire at MAX
			or colors(Color3.fromRGB(255, 200, 60), Color3.fromRGB(255, 60, 20))
	end
end

-- combo = the perfect-flip streak from the server
function Effects.SetCombo(combo)
	local previous = currentCombo
	currentCombo = combo
	local multiplier = GameConfig.GetComboMultiplier(combo)
	setComboFire(multiplier)
	if not comboFrame then return end

	if multiplier >= 2 then
		comboFrame.Visible = true
		comboText.Text = "x" .. multiplier
		comboLabel.Text = (multiplier >= GameConfig.MaxCombo) and "MAX COMBO!" or "COMBO!"
		if combo > previous then
			comboScale.Scale = 1.7
			TweenService:Create(comboScale, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end
	elseif previous >= 2 then
		comboText.Text = "💔"
		comboLabel.Text = "COMBO LOST"
		comboScale.Scale = 1.2
		local shrink = TweenService:Create(comboScale, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0 })
		shrink:Play()
		shrink.Completed:Connect(function()
			if GameConfig.GetComboMultiplier(currentCombo) < 2 then
				comboFrame.Visible = false
				comboScale.Scale = 1
			end
		end)
	else
		comboFrame.Visible = false
	end
end

-- Called every frame by CookingController
function Effects.Update()
	if not comboFrame or not comboFrame.Visible then return end
	local multiplier = GameConfig.GetComboMultiplier(currentCombo)
	local t = os.clock()

	local color = WHITE
	if multiplier >= GameConfig.MaxCombo then
		color = Color3.fromHSV((t * 0.5) % 1, 0.75, 1) -- rainbow at MAX
	elseif multiplier >= 2 then
		color = COMBO_COLORS[multiplier] or WHITE
	end
	comboGradient.Color = ColorSequence.new(WHITE, color)

	-- the higher the combo, the more it shakes
	local intensity = math.max(multiplier - 3, 0)
	comboFrame.Position = COMBO_POSITION
		+ UDim2.fromOffset((math.random() - 0.5) * intensity * 1.6, (math.random() - 0.5) * intensity * 1.6)
	comboFrame.Rotation = math.sin(t * 6) * (2 + intensity)

	for i, flame in ipairs(flames) do
		flame.Visible = multiplier >= 5
		local flicker = 48 + math.sin(t * 20 + i) * 8
		flame.Size = UDim2.fromOffset(flicker, flicker)
		flame.Rotation = math.sin(t * 14 + i * 2) * 12
	end
end

-- Turns off everything that runs continuously (used when leaving the station)
function Effects.Reset()
	Effects.SetSizzle(0)
	Effects.SetSteam(false)
	Effects.SetSmoke(false)
	Effects.SetPanLight(0)
	Effects.Letterbox(false)
	Effects.ClearBubbles()
end

return Effects
