--[[
    Frog
    * Error handler designed specifically for
    * use in LuaNext and its derivatives
]]--
local frog = {}

---- options
local lineNumbers = true
local showLineBefore = true
local indicateToken = true
local traceBack = false

frog.errors = {
    malformed_string = 1,
    unfinished_token = 2,
    unexpected_token = 3,
    unexpected_radix = 4,
    hex_malform = 5,
}

function frog:croak(error)
    print(error .. '\n')

    if traceback then
        print(traceBack)
    end
end

function frog:createError(init)
    local error = {}
    error.text = init

    function error:insertLine(text)
        error.text = text .. '\n' .. error.text
    end

    function error:appendLine(text)
        error.text = error.text .. '\n'  .. text
    end

    return error
end

function frog:token(lines, line, character, thrown)
    local error = frog:createError((lineNumbers and line .. ' | ' or '') .. lines[line])
    
    if showLineBefore and lines[line - 1] then
        error:insertLine((lineNumbers and line - 1 .. (math.floor(math.log10(line - 1) + 1) == math.floor(math.log10(line) + 1) and '' or ' ') .. ' | ' or '') .. lines[line - 1])
    end

    if indicateToken and lineNumbers then
        error:appendLine(string.rep(' ', math.floor(math.log10(line) + 1) + 3) .. string.rep('-', character - 1) .. '^')
    elseif indicateToken then
        error:appendLine(string.rep('-', character - 1) .. '^')
    end

    error:appendLine(line .. ':' .. character .. ' ' .. thrown.type .. ': ' .. thrown.error)

    frog:croak(error.text)
end

return frog