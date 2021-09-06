box.cfg {
    listen = 3301;
}

local fiber = require('fiber')

NOT_EXPIRE = 0
NOT_FOUND = 0

local function bootstrap()
    local space = box.schema.create_space('strings', {
        engine = 'memtx',
        if_not_exists = true,
    })
    space:format({
        { name = 'key', type = 'string' },
        { name = 'value', type = 'string' },
        { name = 'expires', type = 'unsigned' },
    })
    space:create_index('primary')
    space:create_index('expires', {
        parts = { 'expires', 'unsigned' },
        unique = false,
        if_not_exists = true,
    })
    box.schema.user.grant('guest', 'read,write,execute', 'universe')
end

function get(key)
    local t = box.space['strings']:get(key)
    if t ~= nil then return t['value'] else return nil end
end

function set(key, value)
    return box.space['strings']:replace({key, value, NOT_EXPIRE})
end

function setex(key, value, expire)
    local now = math.floor(fiber.time())
    return box.space['strings']:replace({key, value, now + expire})
end

function expire(key, seconds)
    local t = box.space['strings']:get(key)
    if t ~= nil then
        local now = math.floor(fiber.time())
        return box.space['strings']:update({key}, {{'=', 'expires', now + seconds}} )
    end
    return NOT_FOUND
end

function ttl(key)
    local t = box.space['strings']:get(key)
    if t ~= nil then
        if t['expires'] ~= NOT_EXPIRE then
            local now = math.floor(fiber.time())
            return t['expires']- now
        end
        return -1 -- key exists but has no associated expire
    end
    return -2 -- key does not exist
end

function del(key)
    local t = box.space['strings']:delete(key)
    if t ~= nil then return t else return NOT_FOUND end
end

local function expiration()
    while true do
        local now = math.floor(fiber.time())
        box.space['strings'].index.expires:pairs({NOT_EXPIRE}, {iterator='GT'}):each(
            function(t)
                if t['expires'] <= now then
                    box.space['strings']:delete(t['key'])
                end
            end
        )
        fiber.sleep(1)
    end
end

box.once('tedis-1.0', bootstrap)
fiber.create(expiration):name('strings_expiration')
require('console').start()
