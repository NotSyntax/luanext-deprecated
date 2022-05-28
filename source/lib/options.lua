local options = {}
local scanner = require('source/parser/scanner')
local frog = require('source/lib/frog')

options['default'] = {
    -- Utilities
    ["strict"] = true, -- Use type inferences and use the full semantic evaluator
    ["minify"] = true, -- Make compiled output as small as possible
    ["vanilla"] = true, -- Disable all LuaNext extensions
    ["experimental"] = true, -- Enable experimental features

    -- Debug
    ["ast"] = true, -- Dump AST in current working directory
    ["tokens"] = true, -- Dump tokens in current working directory

    -- Disable
    ["no-options"] = true, -- Options are not allowed at the top of files `'strict' ...`
    ["no-special-equality"] = true, -- Disables special equalities `x *= 2`
    ["no-operators"] = true, -- Disable new operands within LuaNext
    ["no-close-case"] = true, -- Don't require end after final case in a switch statement "case x do ... case y do ... end"
    ["no-define"] = true, -- Remove the `define` keyword
    ["no-switch"] = true, -- Remove the `switch` keyword
    ["no-class"] = true, -- Remove the `class` keyword
    ["no-method"] = true, -- Remove the `method` keyword
    ["no-new"] = true, -- Remove the `new` keyword
    ["no-global"] = true, -- Remove the `global` keyword
    ["no-enum"] = true, -- Remove the `enum` keyword
    ["no-label"] = true, -- Only allows old label syntax `::label::`
    ["no-arrays"] = true, -- Removes the array datatype `[ x, y, z ]`
    ["no-jumping"] = true, -- Removes labels and goto statements `label x` `::x::` `goto x`
    ["no-semicolons"] = true, -- Disables the use of semicolons in statements `;`
    ["no-extends"] = true, -- Disable the extension of classes `class x extends y`

    -- Breaking Changes
    ["breaking"] = true, -- LuaNext with all breaking features
    ["enforce-arrays"] = true, -- tables `{}` only support keys + values, and arrays `[]` only support values (affects all array tables in lua)
    ["typecheck"] = true, -- Use the LuaNext type system
    ["luau-typecheck"] = true, -- Use the Luau type system
    ["unicode"] = true, -- Allows the use of Unicode characters in identifiers

    -- Fix
    ["fix"] = true, -- Disable features that may break certain programs
    ["no-multiplex"] = true, -- Disables syntactic sugar of defining multiple variables from one value `x, y, z = 0` (might change lua functionality)
    ["no-balance-equality"] = true, -- Disables errors whenever there are more values than variables `x, y = 1, 2, 3` `x = 1, 2, 3, 4`
    ["no-enforce-vararg"] = true, -- Allows the use of `...` in any block with no errors
    ["no-enforce-constructor"] = true, -- Allows the use of multiple constructor functions (the last constructor will be the one to be compiled)
    ["no-enforce-eof"] = true, -- Allows the use of *any* characters following a toplevel return

    -- Targets
    ["target"] = {
        ["luau"] = {

        },
        ["lua"] = {  -- DEFAULT

        }
    }
}

function options:parse(options, combine)
    combine = combine or {}

    local characters = scanner:new(options)
    local output = {}
    local token = false

    while true do
        local character = characters:peek()
        
        if token then
            if characters:eof() then
                if self['default'][table.concat(token, '')] or self['default'][table.concat(token.name or {}, '')] then
                    if token.value then
                        if type(self['default'][table.concat(token.name, '')]) == "boolean" then
                            frog:token(characters.lines, characters.line, characters.character - 1, { type = 'Warning', error = 'The option "' .. table.concat(token, '') .. '" does not expect a value.' })
                        else
                            if self['default'][table.concat(token.name, '')][table.concat(token.value, '')]then
                                output[string.lower(table.concat(token.name, ''))] = table.concat(token.value, '')
                            else
                                frog:token(characters.lines, characters.line, characters.character - 1, { type = 'Warning', error = 'Could not find value of "' .. table.concat(token.value, '') .. '" for option "' .. table.concat(token.name, '') .. '".' })
                            end
                        end
                    else
                        if type(self['default'][table.concat(token, '')]) ~= 'table' then
                            token = table.concat(token, '')
                            output[string.lower(token)] = true
                        else
                            frog:token(characters.lines, characters.line, characters.character - 1, { type = 'Warning', error = 'The option "' .. table.concat(token, '') .. '" expects a value.' })
                        end
                    end
                else
                    frog:token(characters.lines, characters.line, characters.character - 1, { type = 'Warning', error = 'Could not find option titled "' .. table.concat(token, '') .. '"' })
                end

                token = false
                break
            elseif character == ":" then
                characters:consume() -- consume `:`

                if string.match(character, '%s') ~= nil then
                    characters:consume() -- consume whitespace
                    token.name = token
                    token.value = {}
                else
                    token.name = token
                    token.value = {}
                end
            elseif string.match(character, '%s') ~= nil then
                if self['default'][table.concat(token, '')] or self['default'][table.concat(token.name or {}, '')] then
                    if token.value then
                        if type(self['default'][table.concat(token.name, '')]) == "boolean" then
                            frog:token(characters.lines, characters.line, characters.character - 1, { type = 'Warning', error = 'The option "' .. table.concat(token, '') .. '" does not expect a value.' })
                        else
                            if self['default'][table.concat(token.name, '')][table.concat(token.value, '')]then
                                output[string.lower(table.concat(token.name, ''))] = table.concat(token.value, '')
                            else
                                frog:token(characters.lines, characters.line, characters.character - 1, { type = 'Warning', error = 'Could not find value of "' .. table.concat(token.value, '') .. '" for option "' .. table.concat(token.name, '') .. '".' })
                            end
                        end
                    else
                        if type(self['default'][table.concat(token, '')]) ~= 'table' then
                            token = table.concat(token, '')
                            output[string.lower(token)] = true
                        else
                            frog:token(characters.lines, characters.line, characters.character - 1, { type = 'Warning', error = 'The option "' .. table.concat(token, '') .. '" expects a value.' })
                        end
                    end
                else
                    frog:token(characters.lines, characters.line, characters.character - 1, { type = 'Warning', error = 'Could not find a valid option titled "' .. table.concat(token, '') .. '"' })
                end

                token = false
            elseif string.match(character, '[-abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ]') ~= nil then
                if not token.value then
                    table.insert(token, character)
                else
                    table.insert(token.value, character)
                end
            else
                frog:token(characters.lines, characters.line, characters.character, { type = 'Warning', error = 'Unexpected character: "' .. character .. '" in options.' })
            end
        else
            if characters:eof() then
                break
            elseif string.match(character, '[-abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ]') ~= nil then
                token = {
                    character
                }
            elseif string.match(character, '%s') == nil then
                frog:token(characters.lines, characters.line, characters.character, { type = 'Warning', error = 'Unexpected character: "' .. character .. '" in options.' })
            end
        end

        characters:consume()
    end

    for option, value in pairs(output) do
        combine[option] = value
    end

    function combine:has(value)
        return not not self[value]
    end

    return combine
end

return options