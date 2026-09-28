-- OrderManager (ModuleScript in ServerScriptService)
-- NPC customers walk up to a cook's station with an order in a speech bubble,
-- like "3x Blueberry with Whipped Cream, PERFECT cook!". Serving exactly that pays 3x.
-- If they wait too long they leave, and a new customer comes.
-- The current order is also put on the station model (attributes OrderText / OrderDeadline) for the HUD.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local PancakeConfig = require(ReplicatedStorage:WaitForChild("PancakeConfig"))
local ToppingConfig = require(ReplicatedStorage:WaitForChild("ToppingConfig"))
local EventManager = require(script.Parent:WaitForChild("EventManager"))

local OrderManager = {}

local ORDERS = GameConfig.Orders
local active = {} -- [station] = { GetData, Token, Customer, Head, Bubble, Order, Deadline }

--------------------------------------------------------------------
-- CUSTOMER MODELS (simple blocky people built from parts)
--------------------------------------------------------------------
local SKIN = { Color3.fromRGB(255, 205, 160), Color3.fromRGB(235, 175, 125), Color3.fromRGB(190, 130, 90),
	Color3.fromRGB(140, 90, 60), Color3.fromRGB(255, 225, 190) }
local SHIRTS = { Color3.fromRGB(230, 70, 70), Color3.fromRGB(70, 140, 230), Color3.fromRGB(90, 190, 100),
	Color3.fromRGB(250, 190, 60), Color3.fromRGB(170, 90, 220), Color3.fromRGB(255, 130, 190), Color3.fromRGB(60, 200, 200) }
local PANTS = { Color3.fromRGB(50, 60, 100), Color3.fromRGB(40, 40, 45), Color3.fromRGB(110, 80, 60), Color3.fromRGB(80, 90, 110) }
local HATS = { "None", "Cap", "Beanie", "Chef", "None" }

local function pick(list)
	return list[math.random(#list)]
end

local function part(model, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	if props.Shape then
		p.Shape = props.Shape
	end
	for key, value in pairs(props) do
		if key ~= "Shape" then
			p[key] = value
		end
	end
	p.Parent = model
	return p
end

-- Built standing at the origin, facing -Z (Roblox's "front"). Pivot = between the feet.
local function buildCustomer()
	local model = Instance.new("Model")
	model.Name = "Customer"
	local skin, shirt, pants = pick(SKIN), pick(SHIRTS), pick(PANTS)

	for _, x in ipairs({ -0.5, 0.5 }) do
		part(model, { Name = "Leg", Size = Vector3.new(1, 2, 1), CFrame = CFrame.new(x, 1, 0), Color = pants })
	end
	part(model, { Name = "Torso", Size = Vector3.new(2, 2, 1), CFrame = CFrame.new(0, 3, 0), Color = shirt })
	for _, x in ipairs({ -1.5, 1.5 }) do
		part(model, { Name = "Arm", Size = Vector3.new(1, 2, 1), CFrame = CFrame.new(x, 3, 0), Color = skin })
	end
	local head = part(model, { Name = "Head", Size = Vector3.new(1.25, 1.25, 1.25), CFrame = CFrame.new(0, 4.62, 0), Color = skin })
	local face = Instance.new("Decal")
	face.Texture = "rbxasset://textures/face.png"
	face.Face = Enum.NormalId.Front
	face.Parent = head

	local hat = pick(HATS)
	local hatColor = pick(SHIRTS)
	if hat == "Cap" then
		part(model, { Name = "Cap", Size = Vector3.new(1.35, 0.4, 1.35), CFrame = CFrame.new(0, 5.35, 0), Color = hatColor })
		part(model, { Name = "Brim", Size = Vector3.new(1.1, 0.1, 0.7), CFrame = CFrame.new(0, 5.18, -0.9), Color = hatColor })
	elseif hat == "Beanie" then
		part(model, { Name = "Beanie", Size = Vector3.new(1.4, 0.6, 1.4), CFrame = CFrame.new(0, 5.35, 0), Color = hatColor })
		part(model, { Name = "Pompom", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.45, CFrame = CFrame.new(0, 5.8, 0), Color = Color3.new(1, 1, 1) })
	elseif hat == "Chef" then
		part(model, { Name = "ChefBand", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 1.35, 1.35),
			CFrame = CFrame.new(0, 5.4, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.new(1, 1, 1) })
		part(model, { Name = "ChefPuff", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.5, CFrame = CFrame.new(0, 6.1, 0), Color = Color3.new(1, 1, 1) })
	end

	model.WorldPivot = CFrame.new()
	return model, head
end

--------------------------------------------------------------------
-- SPEECH BUBBLE
--------------------------------------------------------------------
local function makeBubble(head)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "OrderBubble"
	billboard.Size = UDim2.fromOffset(230, 104)
	billboard.StudsOffset = Vector3.new(0, 2.9, 0)
	billboard.MaxDistance = 70
	billboard.AlwaysOnTop = true
	billboard.Parent = head

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	frame.Parent = billboard
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.fromRGB(60, 35, 20)
	stroke.Parent = frame

	local text = Instance.new("TextLabel")
	text.Name = "Text"
	text.Position = UDim2.fromOffset(8, 6)
	text.Size = UDim2.new(1, -16, 1, -24)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextWrapped = true
	text.TextColor3 = Color3.fromRGB(60, 35, 20)
	text.Text = ""
	text.Parent = frame

	local barBack = Instance.new("Frame")
	barBack.Position = UDim2.new(0, 10, 1, -14)
	barBack.Size = UDim2.new(1, -20, 0, 8)
	barBack.BackgroundColor3 = Color3.fromRGB(230, 220, 205)
	barBack.Parent = frame
	local barCorner = corner:Clone()
	barCorner.CornerRadius = UDim.new(0, 4)
	barCorner.Parent = barBack

	local bar = Instance.new("Frame")
	bar.Name = "Patience"
	bar.Size = UDim2.fromScale(1, 1)
	bar.BackgroundColor3 = Color3.fromRGB(90, 200, 100)
	bar.Parent = barBack
	local fillCorner = barCorner:Clone()
	fillCorner.Parent = bar

	return billboard, text, bar
end

--------------------------------------------------------------------
-- ORDERS
--------------------------------------------------------------------
local COUNT_WEIGHTS = { 30, 25, 20, 15, 10 } -- small orders are more common

local function randomCount()
	local total = 0
	for i = 1, ORDERS.MaxCount do
		total += COUNT_WEIGHTS[i] or 5
	end
	local roll = math.random() * total
	for i = 1, ORDERS.MaxCount do
		roll -= COUNT_WEIGHTS[i] or 5
		if roll <= 0 then
			return i
		end
	end
	return 1
end

local function newOrder(data)
	-- usually the pancake you have equipped, sometimes another one you own
	local pancake = data.Equipped.Pancake
	local owned = {}
	for id in pairs(data.Owned.Pancakes) do
		if PancakeConfig.ById[id] then
			table.insert(owned, id)
		end
	end
	if #owned > 1 and math.random() < 0.3 then
		pancake = owned[math.random(#owned)]
	end

	-- toppings you own, never more than your topping slots
	local toppings = {}
	local ownedToppings = {}
	for id in pairs(data.Owned.Toppings) do
		if ToppingConfig.ById[id] then
			table.insert(ownedToppings, id)
		end
	end
	if #ownedToppings > 0 and math.random() < ORDERS.ToppingChance then
		local slots = GameConfig.GetToppingSlots(data.Stats.TotalButter)
		local want = math.random(1, math.min(2, slots, #ownedToppings))
		for _ = 1, want do
			table.insert(toppings, table.remove(ownedToppings, math.random(#ownedToppings)))
		end
	end

	return {
		Pancake = pancake,
		Count = randomCount(),
		Toppings = toppings,
		Perfect = math.random() < ORDERS.PerfectChance,
	}
end

function OrderManager.Describe(order)
	local pancake = PancakeConfig.ById[order.Pancake]
	local lines = { ("🥞 %d× %s"):format(order.Count, pancake and pancake.Name or order.Pancake) }
	if #order.Toppings > 0 then
		local names = {}
		for _, id in ipairs(order.Toppings) do
			table.insert(names, ToppingConfig.ById[id].Name)
		end
		table.insert(lines, "with " .. table.concat(names, " + "))
	end
	if order.Perfect then
		table.insert(lines, "⭐ PERFECT cook!")
	end
	return table.concat(lines, "\n")
end

--------------------------------------------------------------------
-- WALKING
--------------------------------------------------------------------
-- Where the customer stands (at the service counter, across from the stacking plate), in world space
local function spotFor(station)
	return (station.CFrame * CFrame.new(-14.5, 0, 3)).Position
end

-- Turns a direction in the station's own space (+Z = toward the front door) into a world direction
local function stationDirection(station, direction)
	return station.CFrame:VectorToWorldSpace(direction)
end

-- Walks a customer between two CFrames with a little bounce. Returns false if they were removed.
local function walk(model, fromCF, toCF, duration)
	local started = os.clock()
	while true do
		if not model.Parent then
			return false
		end
		local t = math.min((os.clock() - started) / duration, 1)
		local bounce = math.abs(math.sin(t * duration * 7)) * 0.25
		model:PivotTo(fromCF:Lerp(toCF, t) + Vector3.new(0, bounce, 0))
		if t >= 1 then
			return true
		end
		RunService.Heartbeat:Wait()
	end
end

local function hop(model, baseCF)
	for i = 1, 2 do
		walk(model, baseCF, baseCF + Vector3.new(0, 1.2, 0), 0.15)
		walk(model, baseCF + Vector3.new(0, 1.2, 0), baseCF, 0.15)
	end
end

local function clearOrder(station, entry)
	entry.Order = nil
	station.Model:SetAttribute("OrderText", nil)
	station.Model:SetAttribute("OrderDeadline", nil)
end

local spawnCustomer -- defined below

local function leave(station, entry, happy)
	local token = entry.Token
	local customer = entry.Customer
	clearOrder(station, entry)
	if customer and customer.Parent then
		if entry.BubbleText then
			entry.BubbleText.Text = happy and "😋 Thank you!!" or "😠 Too slow!"
			entry.BubbleBar.Parent.Visible = false
		end
		local here = customer:GetPivot()
		if happy then
			hop(customer, here)
		else
			task.wait(0.8)
		end
		local exit = here.Position + stationDirection(station, Vector3.new(0, 0, 36))
		walk(customer, CFrame.lookAt(here.Position, exit), CFrame.lookAt(exit, exit + (exit - here.Position).Unit), 4.2)
		customer:Destroy()
	end
	if entry.Token ~= token or active[station] ~= entry then return end
	entry.Customer = nil
	local delay = EventManager.IsRushHour() and ORDERS.RushNextCustomerDelay or ORDERS.NextCustomerDelay
	task.delay(delay, function()
		if entry.Token == token and active[station] == entry then
			spawnCustomer(station, entry)
		end
	end)
end

spawnCustomer = function(station, entry)
	local token = entry.Token
	local data = entry.GetData()
	if not data then
		task.delay(2, function()
			if entry.Token == token then
				spawnCustomer(station, entry)
			end
		end)
		return
	end

	local customer, head = buildCustomer()
	local spot = spotFor(station)
	local start = spot + stationDirection(station, Vector3.new(0, 0, 36)) -- outside, by the front door
	customer:PivotTo(CFrame.lookAt(start, spot))
	customer.Parent = station.Model
	entry.Customer = customer

	if not walk(customer, CFrame.lookAt(start, spot), CFrame.lookAt(spot, spot + (spot - start).Unit), 5) then return end
	if entry.Token ~= token then
		customer:Destroy()
		return
	end
	-- turn toward the cook
	local facing = CFrame.lookAt(spot, spot + stationDirection(station, Vector3.new(1, 0, 0.35))) -- face the counter and the cook
	walk(customer, customer:GetPivot(), facing, 0.25)

	local order = newOrder(data)
	local patience = EventManager.IsRushHour() and ORDERS.RushPatience or ORDERS.Patience
	local deadline = workspace:GetServerTimeNow() + patience
	local _, text, bar = makeBubble(head)
	text.Text = OrderManager.Describe(order)
	entry.Order = order
	entry.Deadline = deadline
	entry.BubbleText = text
	entry.BubbleBar = bar
	station.Model:SetAttribute("OrderText", OrderManager.Describe(order))
	station.Model:SetAttribute("OrderDeadline", deadline)

	-- count down their patience
	while entry.Token == token and entry.Order == order do
		local left = deadline - workspace:GetServerTimeNow()
		local fraction = math.clamp(left / patience, 0, 1)
		bar.Size = UDim2.fromScale(fraction, 1)
		bar.BackgroundColor3 = Color3.fromRGB(230, 70, 60):Lerp(Color3.fromRGB(90, 200, 100), fraction)
		if left <= 0 then
			leave(station, entry, false)
			return
		end
		task.wait(0.25)
	end
end

--------------------------------------------------------------------
-- PUBLIC
--------------------------------------------------------------------
-- Starts sending customers to a station while a cook is there
function OrderManager.Attach(station, getData)
	OrderManager.Detach(station)
	local entry = { GetData = getData, Token = 0 }
	active[station] = entry
	task.delay(1.5, function()
		if active[station] == entry then
			spawnCustomer(station, entry)
		end
	end)
end

function OrderManager.Detach(station)
	local entry = active[station]
	if not entry then return end
	entry.Token += 1
	active[station] = nil
	if entry.Customer then
		entry.Customer:Destroy()
	end
	station.Model:SetAttribute("OrderText", nil)
	station.Model:SetAttribute("OrderDeadline", nil)
end

-- served = list of { Type = pancake id, Toppings = { ids }, Perfect = bool }
-- Returns true (and sends the customer off happy) if it matches the order exactly.
function OrderManager.TryComplete(station, served)
	local entry = active[station]
	local order = entry and entry.Order
	if not order or #served ~= order.Count then
		return false, order
	end
	for _, pancake in ipairs(served) do
		if pancake.Type ~= order.Pancake then
			return false, order
		end
		if order.Perfect and not pancake.Perfect then
			return false, order
		end
		for _, topping in ipairs(order.Toppings) do
			if not table.find(pancake.Toppings, topping) then
				return false, order
			end
		end
	end
	task.spawn(leave, station, entry, true)
	return true, order
end

return OrderManager
