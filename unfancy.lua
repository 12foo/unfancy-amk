-- Import Microlight so it's available all throughout Unfancy.
require("unfancy.ext_lib").prepare("Microlight")
require("ml").import()

local cjson = require("cjson")
local api_builder = require("unfancy.api")
local config = require("unfancy_config")

local api_cache = {}

local Unfancy = {}

--- Plug your API into nginx.
-- @param api_name Name of a file in config/, without .lua.
function Unfancy.api(api_name)
    local api = api_cache[api_name]
    if not api then
        local loaded, api_config = pcall(require, "api." .. api_name)
        if not loaded then
            ngx.status = 500
            ngx.print(cjson.encode({ error = "API config '" .. api_name .. ".lua' not found in api/." }))
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
