local lexer = require('source/parser/lexer')
local parser = require('source/parser/parser')
local compiler = require('source/compiler/compiler')
local options = require('source/lib/options')

return function(files)
    if #files == 0 then
        print('Usage: luanext <file>')
        print('For help: luanext -h')
        return
    end

    for i, name in pairs(files) do
        if type(i) == 'number' and i > 0 then
            local settings = {}

            local config = io.open('.luanext', "r")
            if config then
                io.input(config)
                local text = io.read("*all")
                settings = options:parse(text)
            end

            local file = io.open(name, "r")
            local autofill = false

            if not file then
                autofill = true
                file = io.open(name .. '.lua', "r")
            end

            if file then
                io.input(file)
                
                local text = io.read("*all")
                local tokens = lexer:new(text):lex()
                local ast = parser:new(tokens, text, settings):parse()

                local entry = name .. (autofill and '.lua' or '')
                local out = io.open('o.lua', "w")
                io.output(out)
                io.write(compiler:compile(ast))
                io.close(out)
            else
                print('Could not locate file "' .. name .. '"!')
                return
            end
        end
    end
end