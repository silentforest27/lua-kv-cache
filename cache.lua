local Cache = {}
Cache.__index = Cache

local function remove_node(self, node)
    if node.prev then
        node.prev.next = node.next
    else
        self._head = node.next
    end
    if node.next then
        node.next.prev = node.prev
    else
        self._tail = node.prev
    end
    node.prev = nil
    node.next = nil
end

local function append_tail(self, node)
    node.prev = self._tail
    node.next = nil
    if self._tail then
        self._tail.next = node
    end
    self._tail = node
    if not self._head then
        self._head = node
    end
end

local function move_to_tail(self, node)
    if node == self._tail then
        return
    end
    remove_node(self, node)
    append_tail(self, node)
end

local function collect_keys(...)
    local keys = {}
    local count = select("#", ...)
    for i = 1, count do
        local arg = select(i, ...)
        if arg ~= nil then
            if type(arg) == "table" then
                local numeric = {}
                local others = {}
                for k in pairs(arg) do
                    if type(k) == "number" then
                        numeric[#numeric + 1] = k
                    else
                        others[#others + 1] = k
                    end
                end
                table.sort(numeric)
                if #numeric > 0 then
                    for _, index in ipairs(numeric) do
                        local value = arg[index]
                        if value ~= nil then
                            keys[#keys + 1] = value
                        end
                    end
                else
                    for _, key in ipairs(others) do
                        keys[#keys + 1] = key
                    end
                end
            else
                keys[#keys + 1] = arg
            end
        end
    end
    return keys
end

function Cache.new(options)
    options = options or {}
    local self = setmetatable({}, Cache)
    self.max_size = options.max_size
    if self.max_size == nil then
        self.max_size = 1000
    end
    self.default_ttl = options.default_ttl
    if self.default_ttl == nil then
        self.default_ttl = 3600
    end
    self._entries = {}
    self._head = nil
    self._tail = nil
    self._size = 0
    return self
end

function Cache:_expired(node)
    return node.expires ~= nil and os.time() >= node.expires
end

function Cache:purge()
    local removed = 0
    for key, node in pairs(self._entries) do
        if self:_expired(node) then
            remove_node(self, node)
            self._entries[key] = nil
            self._size = self._size - 1
            removed = removed + 1
        end
    end
    return removed
end

function Cache:size()
    self:purge()
    return self._size
end

Cache.count = Cache.size

function Cache:clear()
    self._entries = {}
    self._head = nil
    self._tail = nil
    self._size = 0
    return self
end

function Cache:get(key)
    if key == nil then
        return nil
    end
    local node = self._entries[key]
    if not node then
        return nil
    end
    if self:_expired(node) then
        remove_node(self, node)
        self._entries[key] = nil
        self._size = self._size - 1
        return nil
    end
    move_to_tail(self, node)
    return node.value
end

function Cache:peek(key)
    if key == nil then
        return nil
    end
    local node = self._entries[key]
    if not node then
        return nil
    end
    if self:_expired(node) then
        remove_node(self, node)
        self._entries[key] = nil
        self._size = self._size - 1
        return nil
    end
    return node.value
end

function Cache:exists(key)
    if key == nil then
        return false
    end
    local node = self._entries[key]
    if not node then
        return false
    end
    if self:_expired(node) then
        remove_node(self, node)
        self._entries[key] = nil
        self._size = self._size - 1
        return false
    end
    return true
end

Cache.has = Cache.exists

function Cache:delete(key)
    if key == nil then
        return false
    end
    local node = self._entries[key]
    if not node then
        return false
    end
    remove_node(self, node)
    self._entries[key] = nil
    self._size = self._size - 1
    return true
end

function Cache:set(key, value, ttl)
    if key == nil then
        return true
    end
    if ttl == nil then
        ttl = self.default_ttl
    end
    local ttl_seconds = ttl
    if type(ttl_seconds) ~= "number" then
        ttl_seconds = tonumber(ttl_seconds) or 0
    end

    local node = self._entries[key]
    if node then
        if self:_expired(node) then
            remove_node(self, node)
            self._entries[key] = nil
            self._size = self._size - 1
            node = nil
        else
            node.value = value
            node.expires = os.time() + ttl_seconds
            move_to_tail(self, node)
            return true
        end
    end

    self:purge()
    if self.max_size ~= nil and self.max_size <= 0 then
        return true
    end
    if self.max_size ~= nil then
        while self._size >= self.max_size and self._head do
            local lru = self._head
            remove_node(self, lru)
            self._entries[lru.key] = nil
            self._size = self._size - 1
        end
    end

    local new_node = {
        key = key,
        value = value,
        expires = os.time() + ttl_seconds,
        prev = nil,
        next = nil
    }
    self._entries[key] = new_node
    append_tail(self, new_node)
    self._size = self._size + 1
    return true
end

function Cache:mset(data, ttl)
    if type(data) ~= "table" then
        return 0
    end
    local count = 0
    for key, value in pairs(data) do
        if key ~= nil then
            self:set(key, value, ttl)
            count = count + 1
        end
    end
    return count
end

function Cache:mget(...)
    local result = {}
    local keys = collect_keys(...)
    for _, key in ipairs(keys) do
        result[key] = self:get(key)
    end
    return result
end

function Cache:mdelete(...)
    local keys = collect_keys(...)
    local removed = 0
    for _, key in ipairs(keys) do
        if self:delete(key) then
            removed = removed + 1
        end
    end
    return removed
end

Cache.mdel = Cache.mdelete

function Cache:touch(key, ttl)
    if key == nil then
        return false
    end
    local node = self._entries[key]
    if not node or self:_expired(node) then
        if node then
            remove_node(self, node)
            self._entries[key] = nil
            self._size = self._size - 1
        end
        return false
    end
    if ttl == nil then
        ttl = self.default_ttl
    end
    local ttl_seconds = ttl
    if type(ttl_seconds) ~= "number" then
        ttl_seconds = tonumber(ttl_seconds) or 0
    end
    node.expires = os.time() + ttl_seconds
    move_to_tail(self, node)
    return true
end

function Cache:ttl(key)
    if key == nil then
        return -1
    end
    local node = self._entries[key]
    if not node then
        return -1
    end
    if self:_expired(node) then
        remove_node(self, node)
        self._entries[key] = nil
        self._size = self._size - 1
        return -1
    end
    local remaining = node.expires - os.time()
    if remaining < 0 then
        remaining = 0
    end
    return remaining
end

function Cache:keys()
    self:purge()
    local result = {}
    local node = self._head
    while node do
        result[#result + 1] = node.key
        node = node.next
    end
    return result
end

function Cache:values()
    self:purge()
    local result = {}
    local node = self._head
    while node do
        result[#result + 1] = node.value
        node = node.next
    end
    return result
end

function Cache:get_all()
    self:purge()
    local result = {}
    local node = self._head
    while node do
        result[node.key] = node.value
        node = node.next
    end
    return result
end

function Cache:increment(key, amount, ttl)
    if key == nil then
        return 0
    end
    if amount == nil then
        amount = 1
    end
    if type(amount) ~= "number" then
        amount = tonumber(amount) or 0
    end

    local node = self._entries[key]
    if node and self:_expired(node) then
        remove_node(self, node)
        self._entries[key] = nil
        self._size = self._size - 1
        node = nil
    end

    if not node then
        local value = amount
        self:set(key, value, ttl)
        return value
    end

    local current = tonumber(node.value)
    if current == nil then
        current = 0
    end
    local value = current + amount
    node.value = value
    if ttl ~= nil then
        local ttl_seconds = ttl
        if type(ttl_seconds) ~= "number" then
            ttl_seconds = tonumber(ttl_seconds) or 0
        end
        node.expires = os.time() + ttl_seconds
    end
    move_to_tail(self, node)
    return value
end

function Cache:decrement(key, amount, ttl)
    if amount == nil then
        amount = 1
    end
    if type(amount) ~= "number" then
        amount = tonumber(amount) or 0
    end
    return self:increment(key, -amount, ttl)
end

function Cache:get_or_set(key, default, ttl)
    if key ~= nil then
        local node = self._entries[key]
        if node and not self:_expired(node) then
            return self:get(key)
        end
        if node then
            remove_node(self, node)
            self._entries[key] = nil
            self._size = self._size - 1
        end
    end

    local value = default
    if type(default) == "function" then
        value = default()
    end
    if key ~= nil then
        self:set(key, value, ttl)
    end
    return value
end

Cache.remember = Cache.get_or_set
Cache.fetch = Cache.get_or_set

function Cache:setnx(key, value, ttl)
    if key == nil then
        return false
    end
    if self:exists(key) then
        return false
    end
    self:set(key, value, ttl)
    return true
end

function Cache:getset(key, value, ttl)
    local old = nil
    if key ~= nil then
        old = self:get(key)
        self:set(key, value, ttl)
    end
    return old
end

return Cache
