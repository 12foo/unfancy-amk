--- Plugin that inserts a warning message into JSON responses
-- if the request was keyless.

local cjson = require("cjson")

return function(options, api_config)
    
    local Plugin = {}

    function Plugin.run(ctx, req, res)
        if not ctx.keyless then return end
        if res.headers["Content-Type"] == "application/json" then
            local json = cjson.decode(res:get_body())
            json.no_api_key = "You are using this API at reduced request rates. Please sign up for an API key before using seriously."
            res:set_body(cjson.encode(json))
        end
    end

    return Plugin
end
