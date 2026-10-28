local Cache = {}
Cache.__index = Cache

local function is_expired(node)
    return node ~= nil and os.time() > node.expires
end

function Cache.new(options)
    options = options or {}
    local self = setmetatable({}, Cache)
    self.max_size = (options.max_size == nil) and 1000 or options.max_size
    self.default_ttl = (options.default_ttl == nil) and 3600 or options.default_ttl
    self.data = {}

    -- LRU Doubly Linked List
    self.head = nil
    self.tail = nil

    self.size = 0
    return self
end

local function detach_node(self, node)
    if node.prev then
        node.prev.next = node.next
    else
        self.head = node.next
    end
    if node.next then
        node.next.prev = node.prev
    else
        self.tail = node.prev
    end
    node.next = nil
    node.prev = nil
end

local function attach_to_head(self, node)
    node.next = self.head
    node.prev = nil
    if self.head then
        self.head.prev = node
    end
    self.head = node
    if not self.tail then
        self.tail = node
    end
end

function Cache:purge()
    local now = os.time()
    local expired = {}
    local node = self.head
    while node do
        local next_node = node.next
        if now > node.expires then
            expired[#expired + 1] = node.key
        end
        node = next_node
    end
    for _, key in ipairs(expired) do
        self:delete(key)
    end
end

function Cache:set(key, value, ttl)
    if self.max_size ~= nil and self.max_size <= 0 then
        if self.data[key] then
            self:delete(key)
        end
        return
    end

    local node = self.data[key]
    if node and is_expired(node) then
        self:delete(key)
        node = nil
    end

    local expiration_ttl = (ttl == nil) and self.default_ttl or ttl
    local expiration = os.time() + expiration_ttl

    if node then
        -- Update existing
        node.value = value
        node.expires = expiration
        detach_node(self, node)
        attach_to_head(self, node)
    else
        -- Remove expired entries before enforcing capacity.
        if self.max_size ~= nil and self.size >= self.max_size then
            self:purge()
        end

        -- Evict least recently used entries until there is room.
        while self.max_size ~= nil and self.size >= self.max_size do
            local oldest = self.tail
            if not oldest then
                break
            end
            self:delete(oldest.key)
        end

        node = { key = key, value = value, expires = expiration }
        self.data[key] = node
        attach_to_head(self, node)
        self.size = self.size + 1
    end
end

function Cache:mset(table_data, ttl)
    for key, value in pairs(table_data or {}) do
        self:set(key, value, ttl)
    end
end

function Cache:get(key)
    local node = self.data[key]
    if not node then return nil end

    if os.time() > node.expires then
        self:delete(key)
        return nil
    end

    -- Move to head (most recently used)
    detach_node(self, node)
    attach_to_head(self, node)

    return node.value
end

function Cache:mget(keys)
    local result = {}
    for _, key in ipairs(keys) do
        result[key] = self:get(key)
    end
    return result
end

function Cache:exists(key)
    local node = self.data[key]
    if not node then return false end
    if is_expired(node) then
        self:delete(key)
        return false
    end
    return true
end

function Cache:delete(key)
    local node = self.data[key]
    if node then
        detach_node(self, node)
        self.data[key] = nil
        self.size = self.size - 1
        return true
    end
    return false
end

function Cache:size()
    self:purge()
    return self.size
end

function Cache:check_expiry(key)
    local node = self.data[key]
    if node and os.time() > node.expires then
        self:delete(key)
        return true
    end
    return false
end

function Cache:clear()
    self.data = {}
    self.head = nil
    self.tail = nil
    self.size = 0
end

function Cache:touch(key, ttl)
    local node = self.data[key]
    if node then
        if is_expired(node) then
            self:delete(key)
            return false
        end
        local expiration_ttl = (ttl == nil) and self.default_ttl or ttl
        node.expires = os.time() + expiration_ttl
        detach_node(self, node)
        attach_to_head(self, node)
        return true
    end
    return false
end

function Cache:ttl(key)
    local node = self.data[key]
    if node then
        if os.time() > node.expires then
            self:delete(key)
            return 0
        end
        return node.expires - os.time()
    end
    return -1
end

function Cache:keys()
    local now = os.time()
    local keys = {}
    local expired = {}
    local node = self.head
    while node do
        local next_node = node.next
        if now > node.expires then
            expired[#expired + 1] = node.key
        else
            keys[#keys + 1] = node.key
        end
        node = next_node
    end
    for _, key in ipairs(expired) do
        self:delete(key)
    end
    return keys
end

function Cache:values()
    local now = os.time()
    local values = {}
    local expired = {}
    local node = self.head
    while node do
        local next_node = node.next
        if now > node.expires then
            expired[#expired + 1] = node.key
        else
            values[#values + 1] = node.value
        end
        node = next_node
    end
    for _, key in ipairs(expired) do
        self:delete(key)
    end
    return values
end

function Cache:get_all()
    local result = {}
    local now = os.time()
    local expired = {}
    for key, node in pairs(self.data) do
        if now > node.expires then
            expired[#expired + 1] = key
        else
            result[key] = node.value
        end
    end
    for _, key in ipairs(expired) do
        self:delete(key)
    end
    return result
end

function Cache:increment(key, amount, ttl)
    amount = (amount == nil) and 1 or amount
    local val = self:get(key)
    if type(val) ~= "number" then
        val = 0
    end
    local new_val = val + amount
    self:set(key, new_val, ttl)
    return new_val
end

function Cache:decrement(key, amount, ttl)
    amount = (amount == nil) and 1 or amount
    local val = self:get(key)
    if type(val) ~= "number" then
        val = 0
    end
    local new_val = val - amount
    self:set(key, new_val, ttl)
    return new_val
end

function Cache:mdelete(keys, ...)
    local list = {}
    if type(keys) == "table" then
        if #keys > 0 and keys[1] ~= nil then
            for _, key in ipairs(keys) do
                list[#list + 1] = key
            end
        else
            for key in pairs(keys) do
                list[#list + 1] = key
            end
        end
    else
        list = { keys, ... }
    end

    local count = 0
    for _, key in ipairs(list) do
        if self:delete(key) then
            count = count + 1
        end
    end
    return count
end

function Cache:get_or_set(key, default_value, ttl)
    local node = self.data[key]
    if node then
        if is_expired(node) then
            self:delete(key)
        else
            detach_node(self, node)
            attach_to_head(self, node)
            return node.value
        end
    end

    local value = default_value
    if type(default_value) == "function" then
        value = default_value()
    end
    self:set(key, value, ttl)
    return value
end

function Cache:setnx(key, value, ttl)
    if self.max_size ~= nil and self.max_size <= 0 then
        return false
    end
    if self:exists(key) then
        return false
    end
    self:set(key, value, ttl)
    return true
end

function Cache:getset(key, value, ttl)
    local old = self:get(key)
    self:set(key, value, ttl)
    return old
end

-- Common aliases
Cache.has = Cache.exists
Cache.count = Cache.size
Cache.mdel = Cache.mdelete
Cache.delete_many = Cache.mdelete
Cache.remember = Cache.get_or_set
Cache.fetch = Cache.get_or_set

return Cache
