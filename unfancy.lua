local cjson = require("cjson")
local api_builder = require("unfancy.api")
local config = require("unfancy_config")

local api_cache = {}

local Unfancy = {}

--- Plug your API into nginx.
-- @param api_name An API name that must be defined in unfancy_config.lua.
function Unfancy.api(api_name)
    local api = api_cache[api_name]
    if not api then
        local api_config = config.apis[api_name]
        if not api_config then
            ngx.status = 500
            ngx.print(cjson.encode({ error = "API '" .. api_name .. "' not found in configuration." }))
            ngx.exit(200)
        end
        api = api_builder.build(api_config)
        if not api then
            ngx.status = 500
            ngx.print(cjson.encode({ error = "API '" .. api_name .. "' could not be built (unknown error, check logs)." }))
            ngx.exit(200)
        end
    end
    api:run()
end

return Unfancy
