-- Checks the server Signal: listeners get the very same tables (a BindableEvent
-- hands out copies, which broke raid waves), in order, and can disconnect.
local Signal = require(Server.Signal)

local failures = 0
local function check(label, actual, expected)
	if actual ~= expected then
		failures += 1
		print(`FAIL {label}: expected {expected}, got {actual}`)
	end
end

local signal = Signal.new()
local enemy = { id = "1" }
local tracked = { [enemy] = true }
local received = nil
signal:Connect(function(value)
	received = value
	tracked[value] = nil
end)
signal:Fire(enemy)
check("same table", received == enemy, true)
check("works as a table key", next(tracked) == nil, true)

local calls = {}
local second = Signal.new()
local first = second:Connect(function(...)
	table.insert(calls, select("#", ...))
end)
second:Connect(function()
	table.insert(calls, "b")
end)
second:Fire(1, nil, 3)
check("all arguments", calls[1], 3)
check("every listener", calls[2], "b")
first:Disconnect()
second:Fire()
check("disconnected listener skipped", #calls, 3)

if failures == 0 then
	print("OK: all checks passed")
else
	error(`{failures} checks failed`)
end
