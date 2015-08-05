require("unfancy.ext_lib").prepare("lua-resty-http")
http = require("resty.http")

helpers = require("unfancy.helpers")
cjson = require("cjson")

local API = {}
local API_mt = { __index = API }

function API:init_context(ctx, req)
    ctx.cost = 1
end

function API:find_auth_bit(ctx, req)
    local headers = ngx.req.get_headers()
    for i, header in ipairs(self.check_headers) do
        if headers[header] then
            return headers[header]
        end
    end
    if not self.check_query or #self.check_query == 0 then return nil end
    local params = ngx.req.get_uri_args()
    for i, param in ipairs(self.check_query) do
        if params[param] then
            return params[param]
        end
    end
    return nil
end

function API:perform_auth(ctx, req, auth)
    ctx.phase = "auth"
end

function API:quota_check(ctx, req)
end

function API:upstream(ctx, req)
    local upstream
    if #self.upstreams == 1 then
        upstream = self.upstreams[1]
    else
        upstream = self.upstreams[math.random(#self.upstreams)]
    end
    local client = http:new()
    client:set_timeout(500)
    local ok, err = client:connect(upstream.host, upstream.port)
    if not ok then
        ngx.status = 503
        ngx.print(cjson.encode({ error = "Could not connect to upstream API server." }))
        ngx.exit(200)
    end
    client:set_timeout(5000)
    local res = client:proxy_request()
    return client, res
end

function API:run_chain(chain_name, ctx, req)
    ctx.phase = chain_name
    if #self.plugin_chains[chain_name] == 0 then return end
    for ci, plugin in ipairs(self.plugin_chains[chain_name]) do
        plugin.run(ctx, req)
    end
end

function API:run_chain_res(chain_name, ctx, req, res)
    ctx.phase = chain_name
    if #self.plugin_chains[chain_name] == 0 then return end
    for ci, plugin in ipairs(self.plugin_chains[chain_name]) do
        plugin.run(ctx, req, res)
    end
end

local function timer_after_response(prem, api, ctx, req, res)
    API.run_chain_res(api, "after_response", ctx, req, res)
end

function API:run()
    local ctx = ngx.ctx
    local req = ngx.req
    self:init_context(ctx, req)

    local auth = self:find_auth_bit(ctx, req)
    self:perform_auth(ctx, req, auth)
    self:run_chain("after_auth", ctx, req)
    self:quota_check(ctx, req)

    self:run_chain("before_upstream", ctx, req)
    local client, res = self:upstream(ctx, req)
    self:run_chain_res("after_upstream", ctx, req, res)
    client:proxy_response(res)
    client:set_keepalive()

    if #self.plugin_chains.after_response > 0 then
        ngx.timer.at(0, timer_after_response, api, ctx, req, res)
    end
end

local APIBuilder = {}

local chain_names = { "after_auth", "before_upstream", "after_upstream", "after_response" }

function APIBuilder.build(api_config)
    local api = {}
    setmetatable(api, API_mt)

    api.upstreams = {}
    for ui, url in ipairs(api_config.upstreams) do
        local url, n = string.gsub(url, "http://", "")
        local host, port
        string.gsub(url, ":%(d+)", function(portstr) port = tonumber(portstr) end)
        string.gsub(url, "^(.-):?", function(hoststr) port = hoststr end)
        table.insert(api.upstreams, { host = host, port = port })
    end

    api.check_headers = api_config.auth.check_headers or { "Authorization" }
    api.check_query = api_config.auth.check_query or { "api_key" }

    api.plugin_chains = {}
    for ci, chain_name in ipairs(chain_names) do
        local chain = {}
        for pi, pconfig in ipairs(api_config.plugins[chain_name]) do
            local ok, pbuilder = pcall(require, pconfig.module)
            if not ok then
                ngx.status = 500
                ngx.print(cjson.encode({ error = "API build error. Plugin not found: '" .. pconfig.module .. "'."}))
                ngx.exit(200)
            end
            local plugin, err = pbuilder(pconfig.options)
            if err then
                ngx.status = 500
                ngx.print(cjson.encode({ error = "API build error in plugin '" .. pconfig.module .. "': " .. err }))
                ngx.exit(200)
            end
            if not plugin then
                ngx.status = 500
                ngx.print(cjson.encode({ error = "API build error. Plugin '" .. pconfig.module .. "' did not build anything." }))
                ngx.exit(200)
            end
            table.insert(chain, plugin)
        end
        api.plugin_chains[chain_name] = chain
    end
    return api
end

return APIBuilder
