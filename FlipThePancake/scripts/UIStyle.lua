-- UIStyle (ModuleScript in ReplicatedStorage)
-- Gives the flat UI a bit of material: every solid, rounded panel or button gets a soft
-- top-to-bottom sheen (bright on top, a little darker at the bottom), like glossy plastic.
-- It works on UI built later too (shop cards, popups), and never touches anything that
-- already has its own UIGradient. Put a "NoGloss" attribute on an object to skip it.

local UIStyle = {}

local SHEEN = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
	ColorSequenceKeypoint.new(0.45, Color3.fromRGB(246, 246, 246)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(205, 205, 205)),
})

local function styleable(object)
	return object:IsA("Frame") or object:IsA("TextButton") or object:IsA("TextLabel") or object:IsA("TextBox")
end

function UIStyle.Apply(object)
	if not object or not object.Parent or not styleable(object) then return end
	if object:GetAttribute("NoGloss") or object.BackgroundTransparency > 0.4 then return end
	if not object:FindFirstChildOfClass("UICorner") then return end -- only rounded panels and buttons
	for _, child in ipairs(object:GetChildren()) do
		if child:IsA("UIGradient") then return end
	end
	local sheen = Instance.new("UIGradient")
	sheen.Name = "Sheen"
	sheen.Rotation = 90
	sheen.Color = SHEEN
	sheen.Parent = object
end

local function onAdded(descendant)
	if descendant:IsA("UIGradient") and descendant.Name ~= "Sheen" then
		-- the game added its own gradient: that one wins
		local old = descendant.Parent and descendant.Parent:FindFirstChild("Sheen")
		if old and old:IsA("UIGradient") then
			old:Destroy()
		end
	elseif descendant:IsA("UICorner") then
		task.defer(UIStyle.Apply, descendant.Parent)
	elseif styleable(descendant) then
		task.defer(UIStyle.Apply, descendant) -- deferred so its UICorner/UIGradient children are in place
	end
end

-- Styles everything under root now, and anything added to it later
function UIStyle.Polish(root)
	for _, descendant in ipairs(root:GetDescendants()) do
		if styleable(descendant) then
			UIStyle.Apply(descendant)
		end
	end
	root.DescendantAdded:Connect(onAdded)
end

return UIStyle
