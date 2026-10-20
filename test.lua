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

-- Test Exists
local c_ex = Cache.new({ max_size = 10 })
c_ex:set("key", "val")
assert_eq(c_ex:exists("key"), true, "exists() should return true for existing key")
assert_eq(c_ex:exists("missing"), false, "exists() should return false for missing key")

-- Test Touch and TTL
local c_time = Cache.new({ default_ttl = 10 })
c_time:set("t1", "val", 5)
local initial_ttl = c_time:ttl("t1")
assert_eq(initial_ttl <= 5, true, "Initial TTL too high")
assert_eq(initial_ttl > 0, true, "Initial TTL too low")

c_time:touch("t1", 20)
local touched_ttl = c_time:ttl("t1")
assert_eq(touched_ttl <= 20, true, "Touched TTL too high")
assert_eq(touched_ttl > 5, true, "Touched TTL did not increase")
assert_eq(c_time:ttl("missing"), -1, "ttl() for missing key should be -1")

-- Test Keys
local c_keys = Cache.new({ max_size = 10 })
c_keys:set("k1", 1)
c_keys:set("k2", 2)
local keys = c_keys:keys()
assert_eq(#keys, 2, "keys() should return 2 keys")
local found1, found2 = false, false
for _, k in ipairs(keys) do
    if k == "k1" then found1 = true end
    if k == "k2" then found2 = true end
end
assert_eq(found1 and found2, true, "keys() missing expected keys")

-- Test mset
local c_mset = Cache.new({ max_size = 10 })
c_mset:mset({ m1 = "val1", m2 = "val2", m3 = "val3" })
assert_eq(c_mset:size(), 3, "mset() size failed")
assert_eq(c_mset:get("m1"), "val1", "mset() value 1 failed")
assert_eq(c_mset:get("m2"), "val2", "mset() value 2 failed")
assert_eq(c_mset:get("m3"), "val3", "mset() value 3 failed")

-- Test mget
local c_mget = Cache.new({ max_size = 10 })
c_mget:set("g1", "v1")
c_mget:set("g2", "v2")
local results = c_mget:mget({"g1", "g2", "g3"})
assert_eq(results["g1"], "v1", "mget() value g1 failed")
assert_eq(results["g2"], "v2", "mget() value g2 failed")
assert_eq(results["g3"], nil, "mget() should return nil for missing key")

-- Test Increment/Decrement
local c_inc = Cache.new({ max_size = 10 })
assert_eq(c_inc:increment("counter"), 1, "Inc missing key should start at 1")
assert_eq(c_inc:increment("counter"), 2, "Inc existing key failed")
assert_eq(c_inc:increment("counter", 5), 7, "Inc with amount failed")
assert_eq(c_inc:decrement("counter"), 6, "Dec existing key failed")
assert_eq(c_inc:decrement("counter", 3), 3, "Dec with amount failed")
assert_eq(c_inc:decrement("missing"), -1, "Dec missing key should start at 0 then dec")

-- Test Inc/Dec with non-numeric
c_inc:set("string", "not a number")
assert_eq(c_inc:increment("string"), 1, "Inc on non-numeric should reset to 0 then inc")

-- Test get_all
local c_all = Cache.new({ max_size = 10 })
c_all:set("a1", "v1")
c_all:set("a2", "v2", 0)
local start_all = os.time()
while os.time() == start_all do end
local all = c_all:get_all()
assert_eq(all["a1"], "v1", "get_all() missing valid key")
assert_eq(all["a2"], nil, "get_all() should not return expired key")

-- Test Values
local c_values = Cache.new({ max_size = 10 })
c_values:set("v1", 10)
c_values:set("v2", 20)
local values = c_values:values()
assert_eq(#values, 2, "values() count failed")
local found10, found20 = false, false
for _, value in ipairs(values) do
    if value == 10 then found10 = true end
    if value == 20 then found20 = true end
end
assert_eq(found10 and found20, true, "values() missing expected values")

-- Test mdelete
local c_mdel = Cache.new({ max_size = 10 })
c_mdel:set("d1", 1)
c_mdel:set("d2", 2)
c_mdel:set("d3", 3)
local deleted = c_mdel:mdelete({"d1", "d2", "missing"})
assert_eq(deleted, 2, "mdelete() count failed")
assert_eq(c_mdel:size(), 1, "mdelete() size failed")
assert_eq(c_mdel:get("d3"), 3, "mdelete() removed wrong key")

local c_mdel2 = Cache.new({ max_size = 10 })
c_mdel2:set("a", 1)
c_mdel2:set("b", 2)
assert_eq(c_mdel2:mdelete("a", "b"), 2, "mdelete() varargs failed")
assert_eq(c_mdel2:size(), 0, "mdelete() varargs size failed")

-- Test expired entries are treated as absent
local c_exp = Cache.new({ default_ttl = 0 })
c_exp:set("expired", "value", 0)
local start_exp = os.time()
while os.time() == start_exp do end
assert_eq(c_exp:exists("expired"), false, "exists() should be false for expired key")
assert_eq(c_exp:size(), 0, "size() should exclude expired keys")
assert_eq(#c_exp:keys(), 0, "keys() should exclude expired keys")
assert_eq(#c_exp:values(), 0, "values() should exclude expired keys")

-- Test get_or_set
local c_gos = Cache.new({ max_size = 10, default_ttl = 10 })
assert_eq(c_gos:get_or_set("gos", "value"), "value", "get_or_set initial failed")
assert_eq(c_gos:get_or_set("gos", "other"), "value", "get_or_set existing failed")
assert_eq(c_gos:get("gos"), "value", "get_or_set stored failed")
assert_eq(c_gos:get_or_set("factory", function() return 42 end), 42, "get_or_set factory failed")
assert_eq(c_gos:get("factory"), 42, "get_or_set factory stored failed")

-- Test setnx
local c_setnx = Cache.new({ max_size = 10 })
assert_eq(c_setnx:setnx("nx", "value"), true, "setnx() should succeed for missing key")
assert_eq(c_setnx:setnx("nx", "other"), false, "setnx() should fail for existing key")
assert_eq(c_setnx:get("nx"), "value", "setnx() stored wrong value")

-- Test getset
local c_getset = Cache.new({ max_size = 10 })
c_getset:set("gs", "old")
assert_eq(c_getset:getset("gs", "new"), "old", "getset() should return old value")
assert_eq(c_getset:get("gs"), "new", "getset() should store new value")
assert_eq(c_getset:getset("missing", "value"), nil, "getset() should return nil for missing key")

print("All tests passed!")
