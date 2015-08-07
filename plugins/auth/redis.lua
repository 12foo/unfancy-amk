--- An auth plugin that just uses Unfancy's default redis server.
local helpers = require("unfancy.helpers")
local cjson = require("cjson")
local resty_random = require("resty.random")
local str = require("resty.string")

-- Every plugin module must return a builder function that constructs the
-- plugin. The builder function receives the plugin's options table from the
-- configuration file.
return function(options)
    local Plugin = {}

    local pf = (options.prefix or "redis-auth") .. ":"

    --- Run this plugin (during the auth phase).
    --
    -- This function receives an auth bit from the incoming API request and
    -- should resolve it to its key, and from there to a quota name. Unfancy
    -- then applies that quota. The quota is cached for the duration, so this
    -- function is actually only called whenever the current quota window
    -- has expired and a new request comes in.
    --
    -- If this returns a string, the quota with that name is applied. If such
    -- a quota doesn't exist, the default quota is used.
    -- If this returns true, the default quota is used.
    -- If this returns false, access is denied.
    --
    -- @param ctx The current request context (persists between plugins).
    -- @param req The incoming API HTTP request, from nginx.
    -- @param auth The authentication bit extracted from the request (hashed key, etc).
    -- @returns quota name, true, or false.
    function Plugin.run(ctx, req, auth)
    end

    -- Auth plugins may support additional operations. If they do, they can
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

    --- Add a key for a user, optionally assigning a non-default quota.
    -- @param uid Unique user ID.
    -- @param quota_name Name of a non-default quota (may be nil).
    -- @returns Unique JSON-encodable key ID, error string.
    function Plugin.add_key(uid, quota_name)
        local kid = str.to_hex(resty_random.bytes(32))
        local q = quota_name or "default"
        local r = helpers.get_redis()
        r:set(pf .. "key:" .. kid, q)
        r:sadd(pf .. "user:" .. uid .. ":keys", kid)
        r:keepalive()
        return kid, nil
    end

    --- Get quota for a given key.
    -- @param kid Unique key ID.
    -- @returns quota name (string), true or "default" for default quota,
    -- false for no access.
    function Plugin.get_quota_for_key(kid)
        local r = helpers.get_redis()
        local q = r:get(pf .. "key:" .. kid)
        r:keepalive()
        if not q or q == ngx.null then
            return false
        end
        return q
    end

    return Plugin
end
