-- To subscribe to any event we have to create a new frame for every addon and call multiple events on top of it, this objects purpose is to allow registering/unregistering events within a single instance

-- Typical usage:
-- local eventsRegistry = LibStub("LibEvents-1.0").Registry
-- local myAddon = {}
-- eventsRegistry:RegisterEvent(myAddon, "PLAYER_ENTERING_WORLD", function() print("You just entered the world") end)

-- For simplicity, use eventManager instead. Check out LibEvents-1.0.lua for more information

local LibEvents = LibStub("LibEvents-1.0")
if LibEvents.Registry then return end

local eventsFrame = CreateFrame("Frame")
local eventsRegistry = 
{
	private = {},
	entries = {}
}

eventsFrame:SetScript("OnEvent", function(self, ...) eventsRegistry.private.OnEvent(eventsRegistry, ...) end)
LibEvents.Registry = eventsRegistry

function eventsRegistry.private:OnEvent(eventName, ...)
	local eventHandlers = self.entries[eventName];
	
	for owner, handler in pairs(eventHandlers) do
		handler(owner, ...);
	end
end

function eventsRegistry:RegisterEvent(owner, eventName, handler, doNotOverride)
	if owner == nil then error("owner was nil") end
	if eventName == nil then error("eventName was nil") end
	if type(eventName) ~= "string" then error("eventName must be string but was " .. type(eventName)) end
	if handler == nil then error("handler was nil") end
	
	if self.entries[eventName] == nil then
		self.entries[eventName] = {}
		eventsFrame:RegisterEvent(eventName);
	end
	
	if doNotOverride and self.entries[eventName][owner] ~= nil then
		return false;
	end
	
	self.entries[eventName][owner] = handler;
	return true;
end

function eventsRegistry:UnregisterEvent(owner, eventName)
	local eventHandlers = self.entries[eventName]
	
	if eventHandlers ~= nil then
		if #eventHandlers > 1 then
			table.remove(eventHandlers, owner)
		else
			self.entries[eventName] = nil;
			eventsFrame:UnregisterEvent(eventName);
		end
	end
end

-- works relatively slow, try avoid erasing events by id. Advisied to use eventManager instead.
function eventsRegistry:UnregisterAllEvents(id)
	for eventName, eventHandlers in pairs(self.entries) do
		for eventHandler, callback in pairs(eventHandlers) do
			if eventHandler == id then
				self:UnregisterEvent(id, eventName)
			end
		end
	end
end

function IsEventRegistered(id, eventName)
	return self.entries[eventName] and self.entries[eventName][self] ~= nil
end

local function SetCallConventionForAllCalls(isSemicolonConvention, target, name, excludedMembers)
	for memberName, value in pairs(target) do
		if type(value) == "function" and (not excludedMembers or not excludedMembers[value]) then
			local handler
			if isSemicolonConvention then
				handler = function(maybeSelf, ...)
					if maybeSelf ~= target then 
						error("Please call methods of this object using semicolon like following: '" .. (name or "obj") .. ":".. memberName .. "'.")
					end
					return value(maybeSelf, ...)
				end
			else
				handler = function(maybeSelf, ...)
					if maybeSelf == target then 
						error("Please call methods of this object using dot like following: '" .. (name or "obj") .. ".".. memberName .. "'.")
					end
					return value(maybeSelf, ...)
				end
			end
			
			target[memberName] = handler
		end
	end
end

SetCallConventionForAllCalls(true, eventsRegistry, "eventsRegistry", {private = true})
