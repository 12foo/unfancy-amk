--- Plugin that restricts the referrer and the authenticated key in two ways:
-- If no referrer is given (native app), auth/key kind must be one of a certain set
-- and
-- if a referrer is given, it must match the key's "app" (the domain).
--
-- Options:
-- native_allowed: List of key kinds that are allowed for native apps (default: {"HMAC"}).
-- native_only: Only restrict native apps; don't force web requests to the key's domain (default: false).

local cjson = require("cjson")

return function(options, api_config)

    local Plugin = {}

    local native_allowed = options.native_allowed or { "HMAC" }
    local native_only = options.native_only or false

    function Plugin.run(ctx, req)
        -- If this is a keyless request, we don't care anyway.
        if not ctx.key then return end

        local ref = ngx.var.referer
        if (not ref or #ref == 0) then
            for i, kind in allowed_kinds do
                if ctx.key.kind == kind then return end
            end
            ngx.status = 403
            ngx.print(cjson.encode({
                error = "Access from native applications is only allowed with certain kinds of keys.",
                native_allowed = native_allowed
            }))
            ngx.exit(200)
        elseif not native_only then
            local domain = ref:match("https?://(.-)[:/]")
            local found = domain:find(ctx.key.app)
            if found and found == #domain - #ctx.key.app + 1 then return end
            ngx.status = 403
            ngx.print(cjson.encode({
                error = "This key works only for access from a particular domain.",
                domain = ctx.key.app
            }))
            ngx.exit(200)
        end
    end

end
