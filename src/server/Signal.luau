--!strict
-- Minimal event between server modules. Unlike a BindableEvent, which hands
-- listeners a copy of every table it fires (so `enemy == trackedEnemy` and
-- lookups keyed by the table fail), listeners get the same values. Each
-- listener runs in its own thread (task.spawn), so one that yields or errors
-- does not block the others. Outside Roblox (tests) listeners run in place.

export type Connection = {
	Disconnect: (self: Connection) -> (),
}

export type Signal = {
	Connect: (self: Signal, listener: (...any) -> ()) -> Connection,
	Fire: (self: Signal, ...any) -> (),
}

local spawn: (listener: (...any) -> (), ...any) -> ()
if task ~= nil then
	spawn = function(listener, ...)
		task.spawn(listener, ...)
	end
else
	spawn = function(listener, ...)
		listener(...)
	end
end

local Signal = {}

function Signal.new(): Signal
	local listeners: { (...any) -> () } = {}
	local signal = {}

	function signal.Connect(_self: Signal, listener: (...any) -> ()): Connection
		table.insert(listeners, listener)
		local connection = {}
		function connection.Disconnect(_connection: Connection)
			local index = table.find(listeners, listener)
			if index then
				table.remove(listeners, index)
			end
		end
		return connection :: Connection
	end

	function signal.Fire(_self: Signal, ...: any)
		-- Copy so listeners that connect or disconnect while firing are safe.
		for _, listener in table.clone(listeners) do
			spawn(listener, ...)
		end
	end

	return signal :: Signal
end

return Signal
