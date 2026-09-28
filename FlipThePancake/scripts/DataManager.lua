-- DataManager (ModuleScript in ServerScriptService)
-- Loads and saves each player's progress with DataStoreService.
--
-- Saving only works in a PUBLISHED game. To test saving in Studio:
--   File > Publish to Roblox, then Home > Game Settings > Security > "Enable Studio Access to API Services".
-- Without that, the game still plays normally; progress just isn't saved.

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))

local DataManager = {}

-- Every new player starts with this. Add new fields here any time:
-- old saves get the missing fields filled in automatically.
local TEMPLATE = {
	Version = GameConfig.DataVersion,
	Butter = 0,
	Owned = {
		Pans = { Rusty = true },
		Sizes = { Small = true },
		Pancakes = { Classic = true },
		Toppings = {},
	},
	Equipped = {
		Pan = "Rusty",
		Size = "Small",
		Pancake = "Classic",
		Toppings = {},
	},
	Stats = {
		PancakesServed = 0,
		PerfectFlips = 0,
		TornadoFlips = 0,
		Drops = 0,
		BestCombo = 0,
		TotalButter = 0,
		TallestStack = 0,
		OrdersFilled = 0,
	},
}

local store = nil
local storeReady = pcall(function()
	store = DataStoreService:GetDataStore(GameConfig.DataStoreName)
end)
if not storeReady then
	warn("[DataManager] Saving is OFF (the game isn't published yet). Everything else works normally.")
end

local profiles = {} -- [player] = { Data = table, CanSave = bool }

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, inner in pairs(value) do
		copy[key] = deepCopy(inner)
	end
	return copy
end

-- Fills in any fields that are missing from an older save
local function reconcile(data, template)
	for key, value in pairs(template) do
		if data[key] == nil then
			data[key] = deepCopy(value)
		elseif type(value) == "table" and type(data[key]) == "table" then
			reconcile(data[key], value)
		end
	end
end

local function withRetries(callback)
	local attempts = RunService:IsStudio() and 1 or 3
	for attempt = 1, attempts do
		local ok, result = pcall(callback)
		if ok then
			return true, result
		end
		warn(("[DataManager] Attempt %d failed: %s"):format(attempt, tostring(result)))
		if attempt < attempts then
			task.wait(attempt * 1.5)
		end
	end
	return false, nil
end

local function keyFor(player)
	return "Player_" .. player.UserId
end

-- Returns the player's data table (or nil if they left while it was loading)
function DataManager.Load(player)
	local data = nil
	local canSave = false

	if store then
		local ok, result = withRetries(function()
			return store:GetAsync(keyFor(player))
		end)
		if ok then
			data = result
			canSave = true
		else
			warn("[DataManager] Couldn't load " .. player.Name .. "'s data. Progress won't be saved this session.")
		end
	end

	if not player.Parent then
		return nil
	end

	if type(data) ~= "table" then
		data = deepCopy(TEMPLATE)
	end
	reconcile(data, TEMPLATE)
	data.Version = GameConfig.DataVersion

	profiles[player] = { Data = data, CanSave = canSave }
	return data
end

function DataManager.Get(player)
	local profile = profiles[player]
	return profile and profile.Data
end

function DataManager.Save(player)
	local profile = profiles[player]
	if not profile or not profile.CanSave or not store then
		return
	end
	withRetries(function()
		store:SetAsync(keyFor(player), profile.Data)
	end)
end

-- Call when a player leaves: saves one last time and forgets them
function DataManager.Release(player)
	DataManager.Save(player)
	profiles[player] = nil
end

-- Auto-save everyone every minute
task.spawn(function()
	while true do
		task.wait(GameConfig.AutoSaveInterval)
		for player in pairs(profiles) do
			task.spawn(DataManager.Save, player)
		end
	end
end)

-- Save everyone when the server shuts down
game:BindToClose(function()
	if not store then
		return
	end
	local pending = 0
	for player in pairs(profiles) do
		pending += 1
		task.spawn(function()
			DataManager.Save(player)
			pending -= 1
		end)
	end
	local started = os.clock()
	while pending > 0 and os.clock() - started < 25 do
		task.wait(0.1)
	end
end)

return DataManager
