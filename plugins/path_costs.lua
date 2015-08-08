--- A plugin that assigns a higher cost to certain paths.
--
-- Options:
-- A list(!) of tables of the form { path = "", cost = 1 }.

return function(options, api_config)

    if not options or type(options) ~= "table" or #options == 0 then
        return nil, "There were no path cost mappings given."
    end

    local Plugin = {}

    function Plugin.run(ctx, req)
        for i, path in ipairs(options) do
            if ctx.path:find(path.path) == 1 then
                ctx.cost = path.cost
                return
            end
        end
    end

    return Plugin, nil

end
