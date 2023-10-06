-- LibEvents provides methods for creating eventManagers.
-- Use :New(target) to retrieve new manager. Assign methods to the manager with events name and events parameters.
-- Use events:Disable() to temporarily disable events registered through given manager
-- Use events:Enable() to enable all events
-- Use events:EVENT_NAME(argument1, argument2, etc) to call registered eventhandler manually

-- SAMPLE OF USAGE:

-- local events = LibStub("LibEvents-1.0"):New(); -- creates event manager
--
-- function events:CHAT_MSG_SAY(text, playerName, ...)
--		print(playerName, "just said '", text, "'");
-- end
-- 
--
-- function events:PLAYER_ENTERING_WORLD()
--		print("You just entered the world");
-- end

-- events:PLAYER_ENTERING_WORLD() -- prints 'You just entered the world'
-- events:Disable()
-- events:PLAYER_ENTERING_WORLD() -- does not print anything as events were disabled
-- events:Enable()

-- events.PLAYER_ENTERING_WORLD = nil
-- events:PLAYER_ENTERING_WORLD() -- throws an error since this event is no longer registered within eventManager

local LibEvents = LibStub:NewLibrary("LibEvents-1.0", 1);
if not LibEvents then return end

local debugLevel = -1;
local log = LibStub("LibLogger-1.0"):New("LibEvents", debugLevel);

local LibPrototype = LibStub("LibPrototype-1.0");
local EventListenerPrototype = LibPrototype:CreatePrototype();

local function CreateEvocatableObject(name, callback)
	local result = {}
	setmetatable(result, { __tostring = function() return name end, __call = callback })
	return result
end

local disabledEventsHandler = CreateEvocatableObject("This event was disabled", function() log:Log(50, "Disabled event call ignored") end)

local function ListenerInterceptWrite(self, key, value)
	log:Log(60, "Assignment of", key, "was intercepted");
	
	local state = rawget(self, "state");
	
	if value == nil then
		state.events[key] = nil
		LibEvents.Registry:UnregisterEvent(self, key);
	else
		if type(value) ~= "function" then
			error("value must be type of func or nil")
		end
		
		local oldValue = value;
		value = function(this, ...) oldValue(state.target, ...) end
		state.events[key] = value
		
		if state.enabled then
			LibEvents.Registry:RegisterEvent(self, key, value);
		end
	end
end

local function ListenerInterceptRead(self, key)
	log:Log(60, "Read of", key, "was intercepted");
		
	local state = rawget(self, "state");
	
	local handler = state.events[key]
	if handler ~= nil then
		if not state.enabled then
			return disabledEventsHandler
		end
		
		log:Log(60, "Returned modified call");
		local result = function(self, ...) handler(self.state.target, ...) end
		return result
	else
		return nil
	end
	
	log:Log(60, "No value resolved for", key);
end

-- Creates new instance of EventListener
-- @target object that wil be passed as self argument for called methods. Example: eventListener:New({name = 'hello'}); eventListener:PLAYER_ENTERING_WORLD() print(self.name) end;
function LibEvents:New(target)
	local eventListener = EventListenerPrototype:CreateChild();
	eventListener.state = {}
	eventListener.state.enabled = true
	eventListener.state.target = target or eventListener;
	eventListener.state.events = {}
	
	eventListener:InterceptRead(function(...) return ListenerInterceptRead(...) end);
	eventListener:InterceptWrite(function(...) return ListenerInterceptWrite(...) end);
	
	return eventListener;
end

-- returns true if event was registered within given listener
function EventListenerPrototype:IsEventRegistered(eventName)
	return LibEvents.Registry:IsEventRegistered(self, eventName)
end

-- registers event in a common way, advised to use 'function eventListener:EVENT_NAME(arg1, arg2, ...) end' instead
function EventListenerPrototype:RegisterEvent(eventName, handler)
	if type(handler) ~= "function" then error() end
	if eventName == nil then error() end
	self[eventName] = handler -- going to be intercepted by write interceptor
end

-- unregisters event in a common way, advised to use 'eventListener.EVENT_NAME = nil' instead
function EventListenerPrototype:UnregisterEvent(eventName)
	if eventName == nil then error() end
	self[eventName] = nil -- going to be intercepted by write interceptor
end

-- removes all registered events within given listener
function EventListenerPrototype:UnregisterAllEvents()
	for eventName, callback in pairs(self.state.events) do
		self:UnregisterEvent(eventName);
	end
end

-- temporarily disables all registered events
function EventListenerPrototype:Disable()
	self.state.enabled = false;
	
	for eventName, callback in pairs(self.state.events) do
		LibEvents.Registry:UnregisterEvent(self, eventName)
	end
end

-- enables back all disabled events
function EventListenerPrototype:Enable()
	if self.state.enabled == false then
		self.state.enabled = true;
	
		for eventName, callback in pairs(self.state.events) do
			LibEvents.Registry:RegisterEvent(self, eventName, callback)
		end
	end
end

-- returns the list of all registered events
function EventListenerPrototype:GetEventList()
	local list = {}
	
	for name, value in pairs(self.state.events) do
		if type(value) == "function" then
			list[name] = value;
		end
	end
	
	return list;
end

-- returns object passed as target for :New(target) method.
function EventListenerPrototype:GetOwner()
	return self.state.target;
end