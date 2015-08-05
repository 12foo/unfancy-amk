--- An auth plugin that just uses Unfancy's default redis server.
local helpers = require("unfancy.helpers")

-- Every plugin module must return a builder function that constructs the
-- plugin. The builder function receives the plugin's options table from the
-- configuration file.
return function(options)
    local Plugin = {}

    --- Run this plugin (during the auth phase).
    -- @param ctx The current request context (persists between plugins).
    -- @param req The incoming API HTTP request, from nginx.
    -- @param auth The authentication bit extracted from the request (hashed key, etc) (For auth plugins).
    -- @returns false when auth is invalid or not for this plugin, true for valid auth (use default quota)
    -- or a quota name string to use the specified quota from the config file.
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
    function Plugin.create_user(email, name, password, profile)
        local user = { email = email, name = name, profile = profile }
    end

    return Plugin
end
