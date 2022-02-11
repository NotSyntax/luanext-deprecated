local config = require('config')

local commands = {
    compile = require('source/commands/compile'),
    repl = require('source/commands/repl'),
    help = require('source/commands/help'),
}

local scanner = require('source/parser/scanner')
local lexer = require('source/parser/lexer')

local LuaNext = {
    commands = commands,
    scanner = scanner,
    lexer = lexer,
}

if not debug.getinfo(3) then
    local args = arg
    local command = args[1]
    local value = args[2]

    if #args > 0 then
        if command == 'help' or command == '--help' or command == '-h' then
            commands.help(value)
        elseif command == 'compile' then
            commands.compile({ value })
        elseif command == 'script' then
            if not value then error('Expected script :: string as an argument') return end
            if config.scripts[value] then
                config.scripts[value]()
            else
                error('Could not find script "' .. value .. '" from config.lua')
            end
        elseif command == 'repl' then
            print(string.format('LuaNext v%s | REPL', config.version))
            commands.repl()
        elseif command == 'version' or command == '--version' or command == '-v' then
            print('LuaNext v' .. config.version)
        else
            commands.compile(args)
        end
    else
        commands.compile(args)
    end
end

return LuaNext