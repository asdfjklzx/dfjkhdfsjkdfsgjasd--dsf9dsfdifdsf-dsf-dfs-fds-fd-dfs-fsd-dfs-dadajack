-- EventManager (ModuleScript in ServerScriptService)
-- RUSH HOUR: every few minutes the whole server gets double Butter and faster, less patient customers.
-- Clients read these workspace attributes to show the banner:
--   RushHour (true/false), RushHourEnds (server time it ends), NextRushHour (server time it starts)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))

local EventManager = {}

local rushing = false

function EventManager.IsRushHour()
	return rushing
end

function EventManager.GetButterMultiplier()
	return rushing and GameConfig.RushHour.ButterMultiplier or 1
end

local function setRush(on, endsAt)
	rushing = on
	workspace:SetAttribute("RushHour", on)
	workspace:SetAttribute("RushHourEnds", endsAt or 0)
end

function EventManager.Start()
	local config = GameConfig.RushHour
	local interval = RunService:IsStudio() and config.StudioInterval or config.Interval
	setRush(false)
	task.spawn(function()
		while true do
			workspace:SetAttribute("NextRushHour", workspace:GetServerTimeNow() + interval)
			task.wait(interval)
			setRush(true, workspace:GetServerTimeNow() + config.Duration)
			task.wait(config.Duration)
			setRush(false)
		end
	end)
end

return EventManager
