local scanner = {}

function scanner:new(input)
    if not input then return end

    local class = {}

    setmetatable(class, self)
    self.__index = self

    local buffer = {}
    for i = 1, #input do
        table.insert(buffer, input:sub(i, i))
    end

    class.buffer = buffer

    class.line = 1
    class.character = 1
    class.cursor = 1
    class.lines = {}

    for line in input:gmatch("([^\n]*)\n?") do
        table.insert(class.lines, line or '')
    end

    return class
end

function scanner:peek(peek)
    peek = peek or 0

    if peek == 0 then
        return self.buffer[self.cursor]
    else
        local characters = ""
        for i = 1, peek do
            if self.buffer[self.cursor + i - 2] then
                characters = characters .. self.buffer[self.cursor + i - 2]
            end
        end

        return characters
    end
end

function scanner:grab(peek)
    peek = peek or 0

    if peek == 0 then
        return self.buffer[self.cursor]
    else
        return self.buffer[self.cursor + peek - 2]
    end
end

function scanner:consume()
    local character = self:peek()

    if character == '\n' then
        self.line = self.line + 1
        self.character = 1
    else
        self.character = self.character + 1
    end

    self.cursor = self.cursor + 1

    return character
end

function scanner:eof()
    return self:peek() == nil
end

return scanner