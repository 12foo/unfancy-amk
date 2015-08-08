--- An auth plugin that just uses Unfancy's default redis server.
local helpers = require("unfancy.helpers")
local cjson = require("cjson")
local resty_random = require("resty.random")
local str = require("resty.string")

-- Every plugin module must return a builder function that constructs the
-- plugin. The builder function receives the plugin's options table from the
-- configuration file, and the api configuration as a whole.
return function(options, api_config)
    local Plugin = {}

    local pf = (options.prefix or "redis-auth") .. ":"

    -- The following function must be supported by every auth store.

    --- Get key by key id.
    -- @param kid Unique key id.
    -- @param auth_method Name of the auth method plugin that is requesting the
    --          key for verification. If given, the key object must be in a format
    --          that the auth method expects.
    --          If nil, the key is being requested for a quota check and the returned
    --          object must include a quota field.
    -- @returns A key object or nil if not found.
    function Plugin.get_key(kid, auth_method)
        local r = helpers.get_redis()
        local k = r:get(pf .. "key:" .. kid)
        r:keepalive()
        if not k or k == ngx.null then
            return nil
        end
        return k.quota
    end

    -- Auth store plugins may support additional operations. If they do, they can
    -- be plugged into the key management API and frontend to quickly set up
    -- your developer portal.

    --- Create a user.
    -- @param email Email address.
    -- @param name User's full name.
    -- @param password Password (cleartext).
    -- @param profile A table with additional nonessential profile data.
    -- @returns A JSON-encodable ID that is unique, error string.
    function Plugin.create_user(email, name, password, profile)
        local user = {
            email = email,
            name = name,
            password = helpers.hash_password(password),
            profile = profile,
            active = false
        }
        local r = helpers.get_redis()
        r:setex(pf .. "user:" .. email, 8*60*60, cjson.encode(user))
        r:keepalive()
        return email, nil
    end

    --- Set this to true, and Unfancy will automatically verify the user via email.
    -- The function below will be called on success.
    Plugin.needs_activation = true

    --- Activate a user (after checking their email, etc.)
    -- @param uid Unique user ID.
    -- @returns Error string.
    function Plugin.activate_user(uid)
        local r = helpers.get_redis()
        local u = r:get("user:" .. email)
        if not u or u == ngx.null then return end
        u.active = true
        r:set(pf .. "user:" .. email, cjson.encode(user))
        r:keepalive()
        return nil
    end

    function Plugin.authenticate_user(email, password)
    end

    function Plugin.change_password(email, password)
    end

    function Plugin.get_user(uid)
    end

    function Plugin.update_user(uid, email, name, profile)
    end

    --- Add a key for a user, optionally assigning a non-default quota.
    -- @param uid Unique user ID.
    -- @param kind The kind of this key, in case you have several. May be nil.
    -- @param app App or site identifier that uses this key.
    -- @param quota_name Name of a non-default quota (may be nil).
    -- @returns Unique JSON-encodable key ID, error string.
    function Plugin.add_key(uid, kind, app, quota, extras)
        local q = quota_name or "default"
        local k = {
            kind = nil,
            app = app,
            quota = quota,
            extras = extras
        }
        local r = helpers.get_redis()
        r:set(pf .. "key:" .. kid, k)
        r:sadd(pf .. "user:" .. uid .. ":keys", kid)
        r:keepalive()
        return kid, nil
    end

    function Plugin.get_keys_for_user(uid)
        local r = helpers.get_redis()
        local ks = r:sadd(pf .. "user:" .. uid .. ":keys")
    end

    function Plugin.delete_key(kid)
    end

    function Plugin.delete_user(uid)
    end

    return Plugin
end
