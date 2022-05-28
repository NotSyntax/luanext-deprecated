local lexer = require('source/parser/lexer')
local parser = require('source/parser/parser')

return function()
    while true do
        io.write('> ')
        local command = io.read()
        local tokens = lexer:new(command):lex()
        local ast = parser:new(tokens, command):parse(true)
    end
end