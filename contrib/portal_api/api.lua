local ext_lib = require("unfancy.ext_lib").prepare("lua-resty-hmac", "lua-resty-jwt")
local jwt = require("resty.jwt")
local cjson = require("cjson")

local KeyAPI = {}

function KeyAPI.api()
    local path = ngx.var[1]
    local h = require("unfancy.helpers")
    local p = h.hash_password("blort")
    ngx.say(p)
    ngx.say(h.check_password(p, "blort"))
    ngx.say(h.check_password(p, "goof"))
    ngx.print(cjson.encode({ path = path }))
end

return KeyAPI
