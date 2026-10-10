local Cache = {}
Cache.__index = Cache

function Cache.new(options)
    local self = setmetatable({}, Cache)
    self.max_size = options.max_size or 1000
    self.default_ttl = options.default_ttl or 3600
    self.data = {}
    self.access_order = {}
    self.order_map = {}
    self.size = 0
    return self
end

local function remove_oldest(self)
    for k, v in pairs(self.access_order) do
        local key = v
        self.data[key] = nil
        self.order_map[key] = nil
        self.size = self.size - 1
        -- Clear the access order list (simplified LRU)
        self.access_order = {}
        self.order_map = {}
        break
    end
end

function Cache:set(key, value, ttl)
    local expiration = os.time() + (ttl or self.default_ttl)
    
    if self.data[key] then
        self.size = self.size - 1
    end

    if self.size >= self.max_size then
        remove_oldest(self)
    end

    self.data[key] = { value = value, expires = expiration }
    self.size = self.size + 1
    
    -- Update LRU order
    self.access_order[os.clock()] = key
    self.order_map[key] = os.clock()
end

function Cache:get(key)
    local item = self.data[key]
    if not item then return nil end

    if os.time() > item.expires then
        self:delete(key)
        return nil
    end

    -- Update LRU order on access
    local now = os.clock()
    self.access_order[now] = key
    self.order_map[key] = now
    
    return item.value
end

function Cache:delete(key)
    if self.data[key] then
        self.data[key] = nil
        self.size = self.size - 1
        return true
    end
    return false
end

function Cache:clear()
    self.data = {}
    self.access_order = {}
    self.order_map = {}
    self.size = 0
end

return Cache