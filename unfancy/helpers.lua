local redis = require("resty.redis")
local cjson = require("cjson")
local config = require("unfancy_config")

local Helpers = {}

local function report_error(reporter_module, status, reason, ctx)
    local reporter = require(reporter_module)
    reporter_module:on_error(status, reason, ctx)
end

function Helpers.abort(reason, ctx)
    ngx.status = 500
    ngx.print(cjson.encode({ error = reason }))
    if config.error_reports then
        ngx.timer.at(0, report_error, config.error_reports, 500, reason, ctx)
    end
    ngx.exit(200)
end

function Helpers.get_redis_or(error_msg, ctx)
    local r = redis:new()
    r:set_timeout(500)
    local ok, err = r:connect(config.redis.host, config.redis.port)
    if not ok then
        Helpers.abort("Failed to connect to Redis.", ctx)
    end
    return r
end

function Helpers.release_redis(r)
    r:set_keepalive(10000, 50)
end

return Helpers
