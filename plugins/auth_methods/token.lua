--- Token-based auth. Checks various parts of the request and assumes
-- if one of them exists, it contains the key. By default, checks only the
-- Authorization header. Other bits may be enabled via options.
--
-- Options:
-- headers: A list of headers to check.
-- get_params: A list of GET parameters to check.
-- post_params: List of POST parameters or (if JSON body) JSON first-level
--      entries to check. Parsing POST requests has a slight performace cost.


local resty_random = require("resty.random")
local cjson = require("cjson")

return function(options, api_config)

    local AuthMethod = {}

    local headers = options.headers or { "Authorization" }
    local get_params = options.get_params
    local post_params = options.post_params

    AuthMethod.name = "Token-Based"

    function AuthMethod.detect(ctx, req)
        local req_headers = ngx.req.get_headers()
        for i, header in ipairs(self.headers) do
            if req_headers[header] then
                return headers[header], nil
            end
        end

        if get_params and #get_params > 0 then
            local params = ngx.req.get_uri_args()
            for i, param in ipairs(get_params) do
                if params[param] then
                    return params[param], nil
                end
            end
        end

        if post_params and #post_params > 0 then
            if req_headers["Content-Type"] == "application/x-www-form-urlencoded" then
                ngx.req.read_body()
                local params = ngx.req.get_post_args()
                for i, param in ipairs(post_params) do
                    if params[param] then
                        return params[param], nil
                    end
                end
            elseif req_headers["Content-Type"] == "application/json" then
                ngx.req.read_body()
                local json = cjson.decode(ngx.req.get_body_data())
                if json then
                    for i, param in ipairs(post_params) do
                        if json[param] and type(json[param]) == "string" then
                            return params[param], nil
                        end
                    end
                end
            end
        end

        return nil, nil
    end

    function AuthMethod.generate_key()
        local kid = str.to_hex(resty_random.bytes(32))
        return kid, { kind = "Token" }
    end

end
