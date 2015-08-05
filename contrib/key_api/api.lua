local ext_lib = require("unfancy.ext_lib").prepare("lua-resty-hmac", "lua-resty-jwt")
local jwt = require("resty.jwt")
local cjson = require("cjson")

local KeyAPI = {}

function KeyAPI.api()
    local path = ngx.var[1]
    ngx.print(cjson.encode({ path = path }))
end

return KeyAPI
