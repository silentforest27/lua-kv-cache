local Cache = require("cache")

local function assert_eq(actual, expected, msg)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", msg, tostring(expected), tostring(actual)))
    end
end

print("Running tests...")

-- Test Basic Set/Get
local c = Cache.new({ max_size = 2, default_ttl = 10 })
c:set("a", 1)
assert_eq(c:get("a"), 1, "Basic get failed")

-- Test TTL
local c_ttl = Cache.new({ default_ttl = 0 })
c_ttl:set("short", "gone", 0)
-- Wait slightly for expiration
local start = os.time()
while os.time() == start do end
assert_eq(c_ttl:get("short"), nil, "TTL expiration failed")

-- Test Capacity/Eviction
local c_cap = Cache.new({ max_size = 2 })
c_cap:set("1", "one")
c_cap:set("2", "two")
c_cap:set("3", "three") -- Should evict "1"
assert_eq(c_cap:get("1"), nil, "Eviction failed")
assert_eq(c_cap:get("2"), "two", "Wrong key evicted")
assert_eq(c_cap:get("3"), "three", "New key not found")

print("All tests passed!")