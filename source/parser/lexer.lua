local lexer = {}

local frog = require('source/lib/frog')
local scanner = require('source/parser/scanner')

local types = {
    string = require('source/parser/tokens/string'),
    whitespace = require('source/parser/tokens/whitespace'),
    comment = require('source/parser/tokens/comment'),
    number = require('source/parser/tokens/number'),
    identifier = require('source/parser/tokens/identifier'),
    symbol = require('source/parser/tokens/symbol')
}

local symbols = types.symbol.symbols
local symbolIndex = {}

for key, symbol in pairs(symbols) do
    table.insert(symbolIndex, key)
end

table.sort(symbolIndex, function(a, b)
    return #a > #b
end)

function lexer:new(input)
    if not input then return end

    local _class = {}

    setmetatable(_class, self)
    self.__index = self

    _class.scanner = scanner:new(input)
    _class.token = false
    _class.tokens = {}
    _class.errored = false

    return _class
end

function lexer:step()
    if self.scanner:eof() then
        if self.token and self.token.type ~= 'comment' then
            local type = self.token.type
            self.token.range[2] = self.scanner.character
            self.token.line = self.scanner.line

            frog:token(self.scanner.lines, self.scanner.line, self.scanner.character - 1, { type = 'LexError', error = 'Unfinished token, type ' .. type })
            table.insert(self.tokens, { error = frog.errors.unfinished_token, token = self.token })
            
            self.error = true

            self.token = false
            return { type = 'LexError', error = 'Unfinished token, type ' .. type }
        end

        return false
    end

    local line = self.scanner.line
    local column = self.scanner.character

    local character = self.scanner:consume()

    if not self.token then
        ---- whitespace

        if string.match(character, '%s') ~= nil then
            self.token = {}
            self.token.range = { self.scanner.character - 1 }

            for key, value in pairs(types.whitespace.token) do
                if type(value) == "table" then
                    self.token[key] = {}
                else
                    self.token[key] = value
                end
            end

            self.token.characters = { character }
            self.token.range[2] = self.scanner.character - 1
            self.token.line = self.scanner.line
            table.insert(self.tokens, self.token)
            self.token = false

            return true
        end

        ---- string

        if character == types.string.multiline.start or types.string.delimiters[character] then
            local inbetweens = 0
            local escape = false
            
            if character == types.string.multiline.start then
                while self.scanner:grab(inbetweens + 2) ~= nil do
                    local character = self.scanner:grab(inbetweens + 2)

                    if character == '=' then
                        inbetweens = inbetweens + 1
                    elseif character == '[' then
                        break
                    else
                        escape = true
                        break
                    end
                end
            end

            if not escape then
                self.token = {}
                self.token.range = { self.scanner.character - 1 }

                for key, value in pairs(types.string.token) do
                    if type(value) == "table" then
                        self.token[key] = {}
                    else
                        self.token[key] = value
                    end
                end

                if character == types.string.multiline.start then
                    for i = 1, inbetweens + 1 do self.scanner:consume() end
                    
                    self.token.multiline = true
                    self.token.inbetweens = inbetweens

                    for i = 1, #types.string.multiline.start - 1 do self.scanner:consume() end
                else
                    self.token.delimiter = character
                end            

                return self.token
            end
        end

        ---- comment

        if self.scanner:peek(#types.comment.delimiters.start) == types.comment.delimiters.start or self.scanner:peek(#types.comment.delimiters.env) == types.comment.delimiters.env then
            self.token = {}
            self.token.range = { self.scanner.character - 1 }

            for key, value in pairs(types.comment.token) do
                if type(value) == "table" then
                    self.token[key] = {}
                else
                    self.token[key] = value
                end
            end

            for i = 1, #types.comment.delimiters.start - 1 do self.scanner:consume() end

            return self.token
        end

        ---- numbers

        if string.match(character, '%d') or (string.match(character, '%.') and string.match(self.scanner.buffer[self.scanner.cursor] or '', '%d')) then
            self.token = {}
            self.token.range = { self.scanner.character - 1 }

            for key, value in pairs(types.number.token) do
                if type(value) == "table" then
                    self.token[key] = {}
                else
                    self.token[key] = value
                end
            end

            if character == '.' then
                self.token.radix = true
            end

            if self.scanner:eof() then
                self.token.characters = { character }
                self.token.range[2] = self.scanner.character - 1
                self.token.line = self.scanner.line
                table.insert(self.tokens, self.token)

                self.token = false

                return true
            end

            if self.token then 
                if not self.token.radix then
                    if not string.match(self.scanner.buffer[self.scanner.cursor] or '', '[%dx%.]') then
                        self.token.characters = { character }
                        self.token.range[2] = self.scanner.character - 1
                        self.token.line = self.scanner.line
                        table.insert(self.tokens, self.token)

                        self.token = false
                    end
                end

                if self.token then
                    self.token.characters = { character }
                end
            end

            return self.token or true
        end

        ---- identifier

        if string.match(character, '[_abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ]') and not string.match(character, '%d') then
            self.token = {}
            self.token.range = { self.scanner.character - 1 }

            for key, value in pairs(types.identifier.token) do
                if type(value) == "table" then
                    self.token[key] = {}
                else
                    self.token[key] = value
                end
            end

            self.token.characters = { character }

            if self.scanner:eof() or not string.match(self.scanner:peek(), '[_1234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ]') then
                self.token.range[2] = self.scanner.character - 1
                self.token.line = self.scanner.line
                table.insert(self.tokens, self.token)

                self.token = false

                return true
            end

            return self.token
        end

        ---- symbol

        for i, symbol in pairs(symbolIndex) do
            local typed = symbols[symbol]
            if self.scanner:peek(#symbol) == symbol then
                self.token = {}
                self.token.range = { self.scanner.character - 1 }

                for key, value in pairs(types.comment.token) do
                    if type(value) == "table" then
                        self.token[key] = {}
                    else
                        self.token[key] = value
                    end
                end

                self.token.type = typed
                self.token.characters = { character }

                for i = 2, #symbol do
                    self.scanner:consume()
                    table.insert(self.token.characters, symbol:sub(i, i))
                end

                self.token.range[2] = self.scanner.character
                self.token.line = self.scanner.line
                table.insert(self.tokens, self.token)
                self.token = false
                return true
            end
        end
    else
        ---- string

        if self.token.type == 'string' then
            if character == '\\' and not self.token.escaped then
                self.token.escaped = true
                return true
            elseif character == '\\' then
                self.token.escaped = false
                table.insert(self.token.characters, character)
                return true
            end

            if self.token.delimiter then
                if character == '\n' then
                    local delimiter = self.token.delimiter
                    frog:token(self.scanner.lines, line, column, { type = 'LexError', error = 'Unfinished string, expected: ' .. delimiter })
                    self.error = true

                    self.token.range[2] = self.scanner.character
                    self.token.line = self.scanner.line
                    table.insert(self.tokens, { error = frog.errors.malformed_string, token = self.token })
                    self.token = false
                    return { type = 'LexError', error = 'Unfinished string, expected: ' .. delimiter }
                end
                if character == self.token.delimiter and not self.token.escaped then
                    self.token.range[2] = self.scanner.character
                    self.token.line = self.scanner.line
                    table.insert(self.tokens, self.token)
                    self.token = false
                elseif character == self.token.delimiter then
                    self.token.escaped = false
                end
            elseif self.token.multiline and character == types.string.multiline.close then
                local inbetweens = 0
                local escape = false

                while self.scanner:grab(inbetweens + 2) ~= nil do
                    local character = self.scanner:grab(inbetweens + 2)

                    if character == '=' then
                        inbetweens = inbetweens + 1
                    elseif character == ']' then
                        break
                    else
                        escape = true
                        break
                    end
                end

                if self.scanner:grab(inbetweens + 2) == nil then
                    return true
                end
    
                if not escape and inbetweens == self.token.inbetweens then
                    self.token.range[2] = self.scanner.character
                    self.token.line = self.scanner.line
                    table.insert(self.tokens, self.token)
                    for i = 1, #types.string.multiline.close + self.token.inbetweens do self.scanner:consume() end

                    self.token = false
                end
            end

            if self.token then
                if character ~= '\\' and self.token.escaped then
                    self.token.escaped = false
                    table.insert(self.token.characters, '\\' .. character)
                else
                    table.insert(self.token.characters, character)
                end
            end

            return true
        end

        ---- comment

        if self.token.type == 'comment' then
            if not self.token.counting and #self.token.characters == 0 and character == types.comment.delimiters.multiline then
                self.token.counting = true
                return true
            elseif self.token.counting then
                if character == types.comment.delimiters.inbetween then
                    self.token.inbetweens = self.token.inbetweens + 1
                    return true
                elseif character == types.comment.delimiters.multiline then
                    self.token.counting = false
                    self.token.multiline = true
                    return true
                else
                    self.token.counting = false
                end
            end

            local multiline = types.comment.delimiters.close .. string.rep(types.comment.delimiters.inbetween, self.token.inbetweens) .. types.comment.delimiters.close

            if not self.token.multiline and (character == '\n' or self.scanner:eof()) then
                if self.scanner:eof() then
                    self.token.range[2] = self.scanner.character
                    self.token.line = self.scanner.line
                    table.insert(self.token.characters, character)
                    table.insert(self.tokens, self.token)

                    self.token = false

                    return true
                else
                    self.token.range[2] = self.scanner.character
                    self.token.line = self.scanner.line
                    table.insert(self.tokens, self.token)

                    self.token = false

                    return true
                end
            elseif self.token.multiline and self.scanner:peek(#multiline) == multiline then
                for i = 1, #multiline - 1 do self.scanner:consume() end

                self.token.range[2] = self.scanner.character
                self.token.line = self.scanner.line
                table.insert(self.tokens, self.token)
                self.token = false

                return true
            else
                table.insert(self.token.characters, character)
                return true
            end
        end

        ---- number

        if self.token.type == 'number' then
            if character == 'x' then
                if self.token.radix or self.token.characters[1] ~= '0' then
                    self.token.range[2] = self.scanner.character
                    self.token.line = self.scanner.line
                    frog:token(self.scanner.lines, line, column, { type = 'LexError', error = 'Unexpected radix: ' .. character })
                    self.error = true
                    table.insert(self.tokens, { error = frog.errors.unexpected_radix, token = self.token or character })
                    
                    self.token = false
                    return { type = 'LexError', error = 'Unexpected radix: ' .. character }
                else
                    self.token.radix = true
                    self.token.hex = true

                    table.insert(self.token.characters, 'x')
                end
            elseif character == '.' then
                if self.token.radix then
                    self.token.range[2] = self.scanner.character
                    self.token.line = self.scanner.line
                    frog:token(self.scanner.lines, line, column, { type = 'LexError', error = 'Unexpected radix: ' .. character })
                    self.error = true
                    table.insert(self.tokens, { error = frog.errors.unexpected_radix, token = self.token or character })
                    
                    self.token = false
                    return { type = 'LexError', error = 'Unexpected radix: ' .. character }
                else
                    self.token.radix = true

                    table.insert(self.token.characters, '.')
                end
            elseif self.token.hex then
                if string.match(character, '%x') then
                    table.insert(self.token.characters, character)
                else
                    self.token.range[2] = self.scanner.character
                    self.token.line = self.scanner.line
                    frog:token(self.scanner.lines, line, column, { type = 'LexError', error = 'Unexpected character: ' .. character })
                    self.error = true
                    table.insert(self.tokens, { error = frog.errors.unexpected_token, token = self.token or character })
                    
                    self.token = false
                    return { type = 'LexError', error = 'Unexpected character: ' .. character }
                end
            else
                if string.match(character, '%d') then
                    table.insert(self.token.characters, character)
                else
                    self.token.range[2] = self.scanner.character
                    self.token.line = self.scanner.line
                    frog:token(self.scanner.lines, line, column, { type = 'LexError', error = 'Unexpected character: ' .. character })
                    self.error = true
                    table.insert(self.tokens, { error = frog.errors.unexpected_character, token = self.token or character })
                    
                    self.token = false
                    return { type = 'LexError', error = 'Unexpected character: ' .. character }
                end
            end

            if self.scanner:eof() then
                self.token.range[2] = self.scanner.character
                self.token.line = self.scanner.line

                if self.token.hex and #self.token.characters < 3 then
                    frog:token(self.scanner.lines, line, column, { type = 'LexError', error = 'Expected hex digit to follow radix: ' .. character })
                    self.error = true
                    table.insert(self.tokens, { error = frog.errors.hex_malform, token = self.token or character })
                    
                    self.token = false
                    return { type = 'LexError', error = 'Expected hex digit to follow radix: ' .. character }
                end

                table.insert(self.tokens, self.token)
                self.token = false

                return true
            end

            if self.token.hex then
                if not string.match(self.scanner.buffer[self.scanner.cursor] or '', '%x') then
                    self.token.range[2] = self.scanner.character
                    self.token.line = self.scanner.line
                    if #self.token.characters < 3 then
                        frog:token(self.scanner.lines, line, column, { type = 'LexError', error = 'Expected hex digit to follow radix.' })
                        self.error = true
                        table.insert(self.tokens, { error = frog.errors.hex_malform, token = self.token or character })
                        
                        self.token = false
                        return { type = 'LexError', error = 'Expected hex digit to follow radix.' }
                    end
                    
                    table.insert(self.tokens, self.token)
                    self.token = false
                end
            elseif not self.token.radix then
                if not string.match(self.scanner.buffer[self.scanner.cursor] or '', '[%dx%.]') then
                    self.token.range[2] = self.scanner.character
                    self.token.line = self.scanner.line
                    table.insert(self.tokens, self.token)
                    self.token = false
                end
            else
                if not string.match(self.scanner.buffer[self.scanner.cursor] or '', '[%dx%.]') then
                    if self.token.characters[#self.token.characters] == '.' or self.token.characters[#self.token.characters] == 'x' then
                        frog:token(self.scanner.lines, line, column, { type = 'LexError', error = 'Expected digit to follow radix.' })
                        self.error = true
                        table.insert(self.tokens, { error = frog.errors.num_malform, token = self.token or character })
                        
                        self.token = false
                        return { type = 'LexError', error = 'Expected digit to follow radix.' }
                    end

                    self.token.range[2] = self.scanner.character
                    self.token.line = self.scanner.line
                    table.insert(self.tokens, self.token)
                    self.token = false
                end
            end

            return true
        end

        ---- identifier

        if self.token.type == 'identifier' then
            if string.match(character, '[_1234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ]') then
                table.insert(self.token.characters, character)
            end

            if self.scanner:eof() or not string.match(self.scanner:peek(), '[_1234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ]') then
                self.token.range[2] = self.scanner.character
                self.token.line = self.scanner.line

                for i, reserved in ipairs(types.identifier.reserved) do
                    if table.concat(self.token.characters, '') == reserved then
                        self.token.type = reserved
                    end
                end

                table.insert(self.tokens, self.token)
                self.token = false
            end

            return true
        end
    end

    frog:token(self.scanner.lines, line, column, { type = 'LexError', error = 'Unexpected character: ' .. character })
    self.error = true
    table.insert(self.tokens, { error = frog.errors.unexpected_token, token = self.token or character })
                    
    self.token = false
    return { type = 'LexError', error = 'Unexpected character: ' .. character }
end

function lexer:lex()
    repeat until not self:step()

    if self.error then os.exit() end

    return self.tokens
end

return lexer