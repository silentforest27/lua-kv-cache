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
assert_eq(c:size(), 1, "Size should be 1")

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

-- Test Purge
local c_purge = Cache.new({ default_ttl = 0 })
c_purge:set("p1", "val1", 0)
c_purge:set("p2", "val2", 100)
local start_p = os.time()
while os.time() == start_p do end
c_purge:purge()
assert_eq(c_purge:size(), 1, "Purge failed to remove expired item")
assert_eq(c_purge:get("p2"), "val2", "Purge removed non-expired item")

-- Test Clear
local c_clear = Cache.new({ max_size = 10 })
c_clear:set("x", 1)
c_clear:set("y", 2)
c_clear:clear()
assert_eq(c_clear:size(), 0, "Clear failed to reset size")
assert_eq(c_clear:get("x"), nil, "Clear failed to remove elements")

print("All tests passed!")