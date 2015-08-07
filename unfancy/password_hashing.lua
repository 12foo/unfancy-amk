local str = require("resty.string")
local rrandom = require("resty.random")
local AES = require("resty.aes")
local SHA512 = require("resty.sha512")

local PWHash = {}

local runs = 100

local function get_hash(salt, password, runs)
    local r = salt .. password
    local sha = SHA512:new()
    for i = 1, runs do
        sha:reset()
        sha:update(r)
        r = str.to_hex(sha:final())
    end
    return r
end

function PWHash.hash_password(password)
    local salt = rrandom.bytes(32, true)
    while not salt do
        salt = rrandom.bytes(32, true)
    end
    salt = str.to_hex(salt)
    local hashed = get_hash(salt, password, runs)
    return salt .. ":" .. hashed
end

function PWHash.check_password(hash, password)
    local salt, hashed = hash:match("^(.-):(.*)$")
    return get_hash(salt, password, runs) == hashed
end

return PWHash
