return {

    -- You can plug in an error reporting module here (or nil to disable
    -- reporting).
    error_reports = nil,

    -- Upstream API servers: where your API actually lives.
    -- Unfancy will randomly distribute requests between them.
    upstreams = {
        "http://upstream1:80",
        "http://upstream2:80"
    },

    -- Quota types. Quotas may be defined per key or per IP and will deny
    -- requests once either of them is exhausted.
    quotas = {
        default = {
            per_key = nil, 
            per_ip = { max = 30, minutes = 2 }
        },
        high_volume = {
            per_key = { max = 10000, minutes = 60 },
            per_ip = nil 
        }
    },
    
    -- Whether to enable keyless access to your API and if so, the
    -- allowed quota per IP/minutes.
    keyless = {
        enabled = false,
        per_ip = { max = 50, minutes = 5 }
    },

    -- Authorization bits and providers.
    auth = {

        -- Override which headers and GET query parameters to treat as authorization
        -- bits. These will be checked in order, headers first. Both are optional
        -- (Unfancy defaults to checking the Authorization header and api_key param).
        check_headers = { "Authorization" },
        check_query = { "api_key", "apikey", "user_key" },

        -- At least one of these must return a valid key and optionally the name
        -- of a quota type for the request to proceed (if keyless isn't enabled).
        -- If multiple providers are configured, they will be tried in parallel.
        providers = {
            {
                module = "plugins.auth.postgresql",
                options = {
                    connection = {
                        host = "127.0.0.1",
                        port = 5432,
                        db = "dbname",
                        user = "dbuser",
                        password = "dbpassword",
                        ssl = false
                    }
                }
            }
        }
    },

    -- Plugins that run at various points in the API request lifecycle (one
    -- after another).
    plugins = {
        after_auth = {
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
