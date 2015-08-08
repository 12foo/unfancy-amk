return {

    -- You can plug in an error reporting module here (or nil to disable
    -- reporting).
    error_reports = nil,

    -- Upstream API servers: where your API actually lives.
    -- Unfancy will randomly distribute requests between them. It doesn't
    -- do health checks (yet).
    upstreams = {
        "http://127.0.0.1:8081"
    },

    -- Quota types. Quotas may be defined per key or per IP and will deny
    -- requests once either of them is exhausted.
    quotas = {
        default = {
            per_ip = { max = 30, minutes = 2 }
        },
        keyless = {
            per_ip = { max = 10, minutes = 2 }
        },
        high_volume = {
            per_key = { max = 10000, minutes = 60 },
        }
    },

    -- Whether to allow keyless access. If true, requests without keys have the
    -- "keyless" quota applied if it exists, otherwise the "default" quota.
    keyless_allowed = true,
    
    -- Authorization bits and providers.
    auth = {

        -- How long to cache authentications, i.e. how long to wait before re-validating
        -- any given key from a backing store (in minutes).
        auth_cache_period = 10,

        -- Auth method plugins try to detect the auth method from an incoming request.
        -- They are run in order. If they apply to a request, they return a key ID that
        -- is then looked up in the backing auth stores (below).
        auth_methods = {
            -- Straight-forward API key token.
            { module = "plugins.auth_methods.token", options = { get_params = { "api_key" } } },
            -- HMAC token.
            { module = "plugins.auth_methods.hmac" }
        },

        -- All auth stores can authenticate a given key and return a quota for the
        -- incoming request. They are tried in order until one authenticates. If
        -- none does, the request is denied.
        --
        -- Some auth stores also support user and key management functions. You can
        -- plug this config into unfancy.contrib.portal_api, and it will use the
        -- first store in this list with management support to generate an instant
        -- self-service portal API for developers.
        auth_stores = {
            { module = "plugins.auth_stores.redis" }
        }
    },

    -- Plugins that run at various points in the API request lifecycle (one
    -- after another).
    plugins = {
        after_auth = {
            {
                -- A plugin that makes sure that requests without a HTTP referrer
                -- (i.e. from native apps) stick to certain kinds of keys for auth.
                -- If a referrer is present, makes sure it matches the domain listed
                -- as the key's "app".
                module = "plugins.restrict_referrer"
            },
            {
                -- A plugin that customizes quota cost for certain paths.
                -- The default cost (set by Unfancy at the start) is 1.
                module = "plugins.path_costs",
                options = {
                    { path = "/big_calculation", cost = 2 },
                    { path = "/huge_calculation", cost = 4 },
                    { path = "/always_cached", cost = 0 }
                }
            }
        },
        -- (The quota check happens at this point.)
        before_upstream = {
        },
        -- (The request is sent upstream at this point.)
        after_upstream = {
            {
                -- A plugin that modifies responses on keyless access and
                -- injects quota warning entries into the JSON.
                module = "plugins.keyless_warning"
            }
        },
        -- (The response is sent back at this point; the user is done with us here.)
        -- It's a good idea to do anything that increases latency and isn't needed
        -- by upstream in after_response (GeoIP lookups, logging, etc.)
        after_response = {
            {
                module = "plugins.logging.influxdb",
                options = {
                    influx = "http://127.0.0.1:7001/db"
                }
            }
        }
    }

}
