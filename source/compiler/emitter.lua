local emitter = {}

function emitter:new(options)
    self = {}

    setmetatable(self, {
        __index = emitter
    })

    self.output = ""
    self.length = 0
    self.tab = 0
    self.options = options

    return self
end

function emitter:emit(characters)
    if type(characters) == "string" then
        self.output = self.output .. characters
    else
        for i, character in ipairs(characters) do
            self.output = self.output .. character
        end
    end

    return self.output
end

-- Whitespace
function emitter:indent()
    self.tab = self.tab + 1
end

function emitter:unindent()
    self.tab = self.tab - 1
end

function emitter:whitespace()
    return self:emit(' ')
end

function emitter:optional()
    if not self.options.minify then
        return self:emit(' ')
    end
end

function emitter:newline()
    if self.options.minify then
        self:whitespace()
        return
    end

    self:emit('\n')

    for i = 1, self.tab do
        self:emit('\t')
    end
end

return emitter