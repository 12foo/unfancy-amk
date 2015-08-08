--- HMAC auth that works like the one in Tyk:
-- https://tyk.io/v1.5/access-control/hmac/
-- 
-- Options:
-- headers: List of headers to search for the auth bit.

require("unfancy.ext_lib").prepare("lua-resty-hmac")
hmac = require("resty.hmac")

return function(options, api_config)

    local AuthMethod = {}

    local headers = options.headers or { "Authorization" }

    local function explode_header(header)
        local parts = split(header, ",")
        local fields = {}
        for i, part in ipairs(parts) do
            local name, value = part:match("(.-)=\"(.-)\")")
            fields[name] = value
        end
        return fields
    end

    AuthMethod.name = "HMAC-Based"

    function AuthMethod.detect(ctx, req)
        local req_headers = ngx.req.get_headers()
        for i, header in ipairs(self.headers) do
            if req_headers[header] and req_headers[header]:sub(1, 9) == "Signature" then
                local h = explode_header(req_headers[header])
                if h.keyId and h.algorithm and h.signature and req_headers["Date"] then
                    return h.keyId, {
                        algorithm = h.algorithm,
                        signature = h.signature,
                        date = req_headers["Date"]
                    }
                end
            end
        end

        return nil, nil
    end


    function AuthMethod.generate_key()
        local kid = str.to_hex(resty_random.bytes(32))
        local secret = str.to_hex(resty_random.bytes(32))
        return kid, {
            kind = "HMAC",
            extras = {
                algorithm = "hmac-sha1",
                secret_key = secret
            }
        }
    end


    function AuthMethod.verify(detected, store_key, auth_store_module)
        if store_key.kind ~= "HMAC" then return false end
        signer = hmac:new(store_key.extras.secret_key)
        if not signer then return false end
        -- we use only SHA1 for now
        return signer:check_signature("sha1", detected.date, nil, detected.signature)
    end

    return AuthMethod, nil

end
