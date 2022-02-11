local lexer = require('source/parser/lexer')

return function(files)
    if #files == 0 then
        print('Usage: luanext <file>')
        print('For help: luanext -h')
        return
    end

    for i, name in pairs(files) do
        if type(i) == 'number' and i > 0 then
            local file = io.open(name, "r") or io.open(name .. '.lua', "r")

            if file then
                io.input(file)
                local text = io.read("*all")
                local tokens = lexer:new(text):lex()
            else
                print('Could not locate file "' .. name .. '"!')
                return
            end
        end
    end
end