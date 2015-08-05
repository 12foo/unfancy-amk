--- Helper functions to dynamically load external libraries.
-- This is useful so we can integrate 3rd party Lua libs as git submodules
-- so Unfancy is a one-clone install and doesn't require luarocks or the like.

local ExtLib = {}
local loaded_libs = {}

--- Prepares an extlib for loading. Once you have called this function (at the
-- top of an init/plugin file, probably), the extlib will be available to the
-- loader. Do not call in hot code paths.
function ExtLib.prepare(...)
    local arg = {...}
    for i, lib_name in ipairs(arg) do
        if not loaded_libs[lib_name] then
            local lib_path = debug.getinfo(1, "S").source:sub(2):match("(.*/)")
            lib_path = lib_path .. "ext_lib/" .. lib_name
            lib_path = lib_path .. "/?.lua;" .. lib_path .. "/lib/?.lua"
            package.path = lib_path .. ";" .. package.path
            loaded_libs[lib_name] = true
        end
    end
end

return ExtLib
