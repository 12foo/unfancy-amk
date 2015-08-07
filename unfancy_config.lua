-- Configuration shared between APIs, such as Unfancy's redis server.

return {
    redis = { host = "127.0.0.1", port = 6379 },

    -- Unfancy tries to provide more-or-less secure password hashes using only
    -- built-in packages out of the box, without having to install native libs
    -- (meaning the AES and SHA-type cryptography that comes with nginx).
    -- These are pretty cheap by the standards of modern brute force attacks.
    -- If you want stronger hashing, such as bcrypt or scrypt, you can install
    -- the native libs, and plug in the appropriate contrib here. See those files
    -- for details.
    --
    -- password_hashing = require("contrib.password_hashing.bcrypt")
    -- password_hashing = require("contrib.password_hashing.scrypt")
    password_hashing = require("unfancy.password_hashing")
}
