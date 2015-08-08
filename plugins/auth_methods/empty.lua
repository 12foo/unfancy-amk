--- Empty auth method template. Use for your own auth methods.

return function(options, api_config)

    local AuthMethod = {}

    -- Override display name of this auth method. If missing, defaults to
    -- module name.
    AuthMethod.name = "Auth Method Template"

    --- Detect if this auth method is being used in the request. If so, return
    -- something that an auth store can use to retrieve the proper key.
    --
    -- This function is required for every auth method module.
    --
    -- @param ctx Current request context.
    -- @param req nginx request.
    -- @returns unique_key_id, (optionally) an object that will be available to the
    --              verify function.
    function AuthMethod.detect(ctx, req)
    end

    --- Generate a key that is verifiable by this auth method.
    -- This function is optional. If present, keys of this type will become available
    -- for creation in the developer portal API.
    --
    -- This should return a unique key ID and a key object containing the fields "kind"
    -- and "extras". Use "kind" to store the kind/type of your key, and "extras" to store
    -- extra bits for verification (like signing keys). These two fields must be JSON-serializable
    -- and are guaranteed to be stored in the backing auth_store.
    --
    -- @returns unique_key_id, key_object
    function AuthMethod.generate_key()
    end

    --- Verify a key after retrieving additional information from an auth store.
    -- This function is optional. If not present, Unfancy assumes that finding
    -- the key in the auth store is verification enough.
    --
    -- @param detected The detected object (2nd retval from the detect function).
    -- @param store_key Matching key object retrieved from an auth store module.
    -- @param auth_store_module Name of the auth store module.
    -- @returns True or false.
    function AuthMethod.verify(detected, store_key, auth_store_module)
    end

    return AuthMethod, nil

end
