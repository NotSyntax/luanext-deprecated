local compiler = {}

local luau = require('source/compiler/luau')

function compiler:compile(ast)
    local options = ast.options
    
    if options.target == 'lua' then
        return luau:compile(ast)
    end
end

return compiler