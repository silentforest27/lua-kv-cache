# lua-kv-cache

A simple, high-performance in-memory key-value cache for Lua with support for TTL (time-to-live) and LRU (least recently used) eviction.

## Usage

```lua
local Cache = require("cache")

local cache = Cache.new({
    max_size = 1000,
    default_ttl = 3600
})

cache:set("user:1", { name = "Ada" })
print(cache:get("user:1").name)

cache:set("short", "value", 5)
cache:touch("short", 10)
print(cache:ttl("short"))

cache:mset({ a = 1, b = 2, c = 3 })
local values = cache:mget({ "a", "b", "missing" })
print(values.a, values.b, values.missing)

cache:increment("counter")
cache:increment("counter", 5)
print(cache:get("counter"))

print(cache:exists("a"))
print(cache:size())
print(table.concat(cache:keys(), ", "))

-- Remove all expired entries.
cache:purge()

-- Remove everything.
cache:clear()
```

## API

- `Cache.new(options)` creates a cache. Options: `max_size`, `default_ttl`.
- `set(key, value, ttl)` stores a value.
- `get(key)` returns a value and marks it recently used.
- `mset(table, ttl)` stores multiple values.
- `mget(keys)` returns values for multiple keys.
- `exists(key)` / `has(key)` checks whether a key exists.
- `delete(key)` removes a key.
- `mdelete(keys, ...)` / `mdel(...)` removes multiple keys.
- `size()` / `count()` returns the number of live entries.
- `clear()` removes all entries.
- `purge()` removes expired entries.
- `touch(key, ttl)` extends a key's TTL.
- `ttl(key)` returns remaining TTL.
- `keys()` returns live keys in LRU order.
- `values()` returns live values in LRU order.
- `get_all()` returns a table of live key/value pairs.
- `increment(key, amount, ttl)` and `decrement(key, amount, ttl)` update numeric values.
- `get_or_set(key, default, ttl)` / `remember(...)` / `fetch(...)` returns or creates a value.
- `setnx(key, value, ttl)` stores only when the key is absent.
- `getset(key, value, ttl)` replaces a value and returns the previous one.

## Running tests

```sh
lua test.lua
```
