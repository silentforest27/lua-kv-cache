local Cache = {}
Cache.__index = Cache

function Cache.new(options)
    local self = setmetatable({}, Cache)
    self.max_size = options.max_size or 1000
    self.default_ttl = options.default_ttl or 3600
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

function Cache:set(key, value, ttl)
    local expiration = os.time() + (ttl or self.default_ttl)
    local node = self.data[key]

    if node then
        -- Update existing
        node.value = value
        node.expires = expiration
        detach_node(self, node)
        attach_to_head(self, node)
    else
        -- New entry
        if self.size >= self.max_size then
            -- Evict least recently used (tail)
            local oldest = self.tail
            if oldest then
                self:delete(oldest.key)
            end
        end
        
        node = { key = key, value = value, expires = expiration }
        self.data[key] = node
        attach_to_head(self, node)
        self.size = self.size + 1
    end
end

function Cache:mset(table_data)
    for key, value in pairs(table_data) do
        self:set(key, value)
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
    return self.data[key] ~= nil
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

function Cache:purge()
    local now = os.time()
    for key, node in pairs(self.data) do
        if now > node.expires then
            self:delete(key)
        end
    end
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
        node.expires = os.time() + (ttl or self.default_ttl)
        detach_node(self, node)
        attach_to_head(self, node)
        return true
    end
    return false
end

function Cache:ttl(key)
    local node = self.data[key]
    if node then
        local remaining = node.expires - os.time()
        return remaining > 0 and remaining or 0
    end
    return -1
end

function Cache:keys()
    local keys = {}
    for k in pairs(self.data) do
        table.insert(keys, k)
    end
    return keys
end

return Cache