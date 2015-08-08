require("unfancy.ext_lib").prepare("lua-resty-http")
http = require("resty.http")

helpers = require("unfancy.helpers")
cjson = require("cjson")

local API = {}
local API_mt = { __index = API }

function API:init_context(ctx, req)
    ctx.path = ngx.var[1]
    ctx.cost = 1
    ctx.api_name = self.name
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
        ngx.print(cjson.encode({ error = "Could not connect to upstream API server: " .. err .. "." }))
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

function API.run_chain_res(self, chain_name, ctx, req, res)
    ctx.phase = chain_name
    if #self.plugin_chains[chain_name] == 0 then return end
    for ci, plugin in ipairs(self.plugin_chains[chain_name]) do
        plugin.run(ctx, req, res)
    end
end

local function timer_after_response(prem, chain, ctx, req, res)
    for i, plugin in ipairs(chain) do
        plugin.run(ctx, req, res)
    end
end

local function auth_abort(error_msg)
    ngx.status = 403
    ngx.print(cjson.encode({ error = error_msg }))
    ngx.exit(200)
end

function API:run_auth(ctx, req)
    for ami, auth_method in ipairs(self.auth_methods) do
        local kid, detected = auth_method.detect(ctx, req)
        if kid then

            -- see if we're caching this auth in redis
            local redis = helpers.get_redis()
            local cached_key = redis:get("auth_cache:" .. kid)
            redis:set_keepalive()
            if cached_key and key ~= ngx.null then
                ctx.key = cjson.decode(cached_key)
                ctx.quota = self.quotas[ctx.key.quota] or self.quotas.default
                return
            end

            -- sadly not-- reauth!
            for asi, auth_store in ipairs(self.auth_stores) do
                local kobj = auth_store.get_key(kid, self.auth_method_names[ami])
                if kobj then
                    if auth_method.verify then
                        if not auth_method.verify(detected, kobj, self.auth_store_names[asi]) then
                            return auth_abort("This API is access restricted. Your key was found, but not valid.")
                        end 
                    end
                    ctx.key = kobj
                    ctx.quota = self.quotas[ctx.key.quota] or self.quotas.default

                    -- cache before we return
                    redis = helpers.get_redis()
                    redis:setex("auth_cache:" .. kid, self.auth_cache_period * 60, cjson.encode(kobj))
                    return
                end
            end
            return auth_abort("This API is access restricted. Your key was not found.")
        end
    end
    if self.keyless_allowed then
        ctx.keyless = true
        ctx.quota = self.quotas.keyless or self.quotas.default
        ctx.key = nil
        return
    else
        return auth_abort("This API is access restricted. No auth parameters found in your request.")
    end
end

function API:run()
    -- might want to use ngx.ctx here instead of local table. check performance
    -- when writing to ngx.ctx.
    local ctx = {}
    local req = ngx.req
    self:init_context(ctx, req)

    self:run_auth(ctx, req)

    self:run_chain("after_auth", ctx, req)
    self:quota_check(ctx, req)

    self:run_chain("before_upstream", ctx, req)
    local client, res = self:upstream(ctx, req)
    self:run_chain_res("after_upstream", ctx, req, res)
    client:proxy_response(res)
    client:set_keepalive()

    if #self.plugin_chains.after_response > 0 then
        ngx.timer.at(0, timer_after_response, self.plugin_chains.after_response, ctx, req, res)
    end
end

local APIBuilder = {}

local chain_names = { "after_auth", "before_upstream", "after_upstream", "after_response" }

local function build_plugin(pconfig, api_config)
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
    return plugin
end

function APIBuilder.build(api_config)
    local api = {}
    setmetatable(api, API_mt)

    api.upstreams = {}
    for ui, url in ipairs(api_config.upstreams) do
        local url, n = string.gsub(url, "http://", "")
        local host
        local port = 80
        string.gsub(url, ":(%d+)", function(portstr) port = tonumber(portstr) end)
        string.gsub(url, "^(.-)[:/$]", function(hoststr) host = hoststr end)
        table.insert(api.upstreams, { host = host, port = port })
    end

    api.auth_cache_period = api_config.auth_cache_period or 10
    api.keyless_allowed = api_config.keyless_allowed or false

    api.quotas = api_config.quotas
    if not api.quotas.default then
        ngx.status = 500
        ngx.print(cjson.encode({ error = "Your API configuration must define at least a default quota." }))
        ngx.exit(200)
    end

    api.auth_methods = {}
    api.auth_method_names = {}
    for ami, amconfig in ipairs(api_config.auth.auth_methods) do
        local plugin = build_plugin(amconfig, api_config)
        if not plugin.detect then
            ngx.status = 500
            ngx.print(cjson.encode({ error = "API build error. Auth method '" .. amconfig.module .. "' does not have a 'detect' function." }))
            ngx.exit(200)
        end
        table.insert(api.auth_methods, plugin)
        table.insert(api.auth_method_names, amconfig.module)
    end

    api.auth_stores = {}
    api.auth_store_names = {}
    for asi, asconfig in ipairs(api_config.auth.auth_stores) do
        local plugin = build_plugin(asconfig, api_config)
        if not plugin.get_key then
            ngx.status = 500
            ngx.print(cjson.encode({ error = "API build error. Auth store '" .. asconfig.module .. "' does not have a 'get_key' function." }))
            ngx.exit(200)
        end
        table.insert(api.auth_stores, plugin)
        table.insert(api.auth_store_names, asconfig.module)
    end

    api.plugin_chains = {}
    for ci, chain_name in ipairs(chain_names) do
        local chain = {}
        for pi, pconfig in ipairs(api_config.plugins[chain_name]) do
            local plugin = build_plugin(pconfig, api_config)
            if not plugin.run then
                ngx.status = 500
                ngx.print(cjson.encode({ error = "API build error. Plugin '" .. pconfig.module .. "' does not have a 'run' function." }))
                ngx.exit(200)
            end
            table.insert(chain, plugin)
        end
        api.plugin_chains[chain_name] = chain
    end
    return api
end

return APIBuilder
