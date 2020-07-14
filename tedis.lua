box.cfg {
    listen = 3301;
}

local fiber = require('fiber')

FIELD = {
    KEY = 1,
    VALUE = 2,
    EXPIRES = 3,
}
FIRST_TUPLE = 1
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
        parts = { FIELD.EXPIRES, 'unsigned' },
        unique = false,
        if_not_exists = true,
    })
    box.schema.user.grant('guest', 'read,write,execute', 'universe')
end

function GET(key)
    local t = box.space['strings']:select(key)[FIRST_TUPLE]
    if t ~= nil then return t[FIELD.VALUE] else return nil end
end

function SET(key, value)
    return box.space['strings']:replace({key, value, NOT_EXPIRE})
end

function SETEX(key, value, expire)
    local now = math.floor(fiber.time())
    return box.space['strings']:replace({key, value, now + expire})
end

function EXPIRE(key, seconds)
    local t = box.space['strings']:select(key)[FIRST_TUPLE]
    if t ~= nil then
        local now = math.floor(fiber.time())
        return box.space['strings']:update({key}, {{'=', FIELD.EXPIRES, now + seconds}} )
    end
    return NOT_FOUND
end

function TTL(key)
    local t = box.space['strings']:select(key)[FIRST_TUPLE]
    if t ~= nil then
        if t[FIELD.EXPIRES] ~= NOT_EXPIRE then
            local now = math.floor(fiber.time())
            return t[FIELD.EXPIRES]- now
        end
        return -1 -- key exists but has no associated expire
    end
    return -2 -- key does not exist
end

function DEL(key)
    local t = box.space['strings']:delete(key)
    if t ~= nil then return t else return NOT_FOUND end
end

local function expiration()
    while true do
        local now = math.floor(fiber.time())
        box.space['strings'].index.expires:pairs({NOT_EXPIRE}, {iterator='GT'}):each(
            function(t)
                if t[FIELD.EXPIRES] <= now then
                    box.space['strings']:delete(t[FIELD.KEY])
                end
            end
        )
        fiber.sleep(1)
    end
end

set = SET
setex = SETEX
get = GET
del = DEL
expire = EXPIRE
ttl = TTL

box.once('tedis-1.0', bootstrap)
fiber.create(expiration):name('strings_expiration')
require('console').start()
